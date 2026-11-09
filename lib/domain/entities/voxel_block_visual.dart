import 'package:meta/meta.dart';

/// Неизменяемая визуальная спецификация конкретного блока Minecraft для плоского 2D-чертежа слоя.
@immutable
final class VoxelBlockVisualSpec {
  /// Полный строковый `BlockState` (например, `minecraft:dispenser[facing=south,triggered=false]`).
  final String fullBlockState;

  /// Базовый идентификатор блока без свойств (например, `minecraft:dispenser`).
  final String baseBlockId;

  /// Короткий код блока (2–3 символа) для отображения прямо внутри клетки сетки.
  final String shortCode;

  /// Символ направления (`▲`, `►`, `▼`, `◄`, `⊙`, `⊗`), если блок имеет свойство `facing`.
  final String facingSymbol;

  /// Понятное название блока на русском языке.
  final String titleRu;

  /// Плоский заливающий цвет клетки (0xAARRGGBB) без теней и градиентов.
  final int fillArgb;

  /// Цвет четкой рамки клетки (0xAARRGGBB).
  final int borderArgb;

  /// Контрастный цвет текста кода внутри клетки (0xAARRGGBB).
  final int textArgb;

  /// Является ли блок воздухом (`minecraft:air`).
  final bool isAir;

  const VoxelBlockVisualSpec({
    required this.fullBlockState,
    required this.baseBlockId,
    required this.shortCode,
    required this.facingSymbol,
    required this.titleRu,
    required this.fillArgb,
    required this.borderArgb,
    required this.textArgb,
    required this.isAir,
  });

  /// Короткая метка вместе со стрелкой ориентации (например, `РЗ►` или `СН▼`).
  String get badgeLabel =>
      facingSymbol.isEmpty ? shortCode : '$shortCode$facingSymbol';
}

/// Чистый доменный классификатор блоков Minecraft для послойной визуализации схемы.
abstract final class VoxelBlockClassifier {
  /// Возвращает понятное описание назначения каждого высотного слоя `Y` схемы.
  static ({String shortTitle, String detailedDescription}) describeYLayer({
    required int y,
    required int wallHeight,
  }) {
    final wallTopY = 1 + wallHeight;
    if (y == 0) {
      return (
        shortTitle: 'Y=0: Подполье и Redstone',
        detailedDescription:
            'Слой Y=0 — Фундамент постройки и скрытая подпольная разводка редстоун-пыли (minecraft:redstone_wire) к ловушкам и шахтам.',
      );
    }
    if (y == 1) {
      return (
        shortTitle: 'Y=1: Пол лабиринта и арены',
        detailedDescription:
            'Слой Y=1 — Напольное покрытие коридоров (Тир 1–3), пол центральной арены и световые блоки под шахтами.',
      );
    }
    if (y == 2) {
      return (
        shortTitle: 'Y=2: Стены, Сундуки, Плиты, Раздатчики',
        detailedDescription:
            'Слой Y=2 (Уровень ног игрока) — Стены, сундуки в тупиках, нажимные плиты, вмонтированные в стены раздатчики, спавнеры, низ железных дверей и основание пьедестала.',
      );
    }
    if (y == 3) {
      return (
        shortTitle: 'Y=3: Стены, Верх дверей, Главный приз',
        detailedDescription:
            'Слой Y=3 (Уровень головы игрока) — Второй ряд стен, верхняя половина железных дверей, финальный сундук главного приза на пьедестале и раздатчики засады.',
      );
    }
    if (y >= 4 && y < wallTopY) {
      return (
        shortTitle: 'Y=$y: Верхние ряды стен',
        detailedDescription:
            'Слой Y=$y — Верхняя кладка стен коридоров и капитальных барьеров колец (проемы арок и перепадов высот).',
      );
    }
    if (y == wallTopY) {
      return (
        shortTitle: 'Y=$y: Декоративный карниз стен',
        detailedDescription:
            'Слой Y=$y — Верхний завершающий карниз стен лабиринта и капитальных межкольевых барьеров.',
      );
    }
    if (y == wallTopY + 1) {
      return (
        shortTitle: 'Y=$y: Стеклянные шахты спавна',
        detailedDescription:
            'Слой Y=$y — Тонированное стекло (minecraft:tinted_glass) вертикальных стартовых капсул над 4 углами.',
      );
    }
    if (y == wallTopY + 2) {
      return (
        shortTitle: 'Y=$y: Липкие поршни сброса',
        detailedDescription:
            'Слой Y=$y — Липкие поршни (minecraft:sticky_piston), удерживающие игроков в 4 стартовых шахтах до сигнала старта.',
      );
    }
    return (
      shortTitle: 'Y=$y: Питание поршней (Redstone)',
      detailedDescription:
          'Слой Y=$y — Верхние редстоун-блоки (minecraft:redstone_block) синхронной активации стартовых поршней.',
    );
  }

  /// Определяет визуальную спецификацию для любого строкового `BlockState`.
  static VoxelBlockVisualSpec classify(String rawBlockState) {
    final normalized = rawBlockState.trim().toLowerCase();
    final bracketIdx = normalized.indexOf('[');
    final baseId =
        bracketIdx == -1 ? normalized : normalized.substring(0, bracketIdx);
    final props = bracketIdx == -1 ? '' : normalized.substring(bracketIdx);

    final facingSymbol = _extractFacingSymbol(props);
    final facingTextRu = _extractFacingRu(props);

    if (baseId == 'minecraft:air') {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: '·',
        facingSymbol: '',
        titleRu: 'Воздух (пустое пространство прохода)',
        fillArgb: 0xFF0E131D,
        borderArgb: 0xFF1A2232,
        textArgb: 0xFF45536D,
        isAir: true,
      );
    }

    // 1. Механизмы, контейнеры и интерактивные блоки (самые яркие и заметные цвета):
    if (baseId == 'minecraft:chest') {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'СН',
        facingSymbol: facingSymbol,
        titleRu: 'Обычный сундук с лутом$facingTextRu',
        fillArgb: 0xFFFFB300,
        borderArgb: 0xFFFFE082,
        textArgb: 0xFF000000,
        isAir: false,
      );
    }

    if (baseId == 'minecraft:trapped_chest') {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'СЛ!',
        facingSymbol: facingSymbol,
        titleRu: 'Сундук-ловушка (дает сигнал Redstone)$facingTextRu',
        fillArgb: 0xFFFF1744,
        borderArgb: 0xFFFF8A80,
        textArgb: 0xFFFFFFFF,
        isAir: false,
      );
    }

    if (baseId == 'minecraft:dispenser') {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'РЗ',
        facingSymbol: facingSymbol,
        titleRu: 'Раздатчик (стрелы / салют)$facingTextRu',
        fillArgb: 0xFFAA00FF,
        borderArgb: 0xFFEA80FC,
        textArgb: 0xFFFFFFFF,
        isAir: false,
      );
    }

    if (baseId == 'minecraft:stone_pressure_plate') {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'ПЛТ',
        facingSymbol: '',
        titleRu: 'Каменная нажимная плита (активатор)',
        fillArgb: 0xFFE040FB,
        borderArgb: 0xFFFFFFFF,
        textArgb: 0xFF000000,
        isAir: false,
      );
    }

    if (baseId == 'minecraft:spawner') {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'СПВ',
        facingSymbol: '',
        titleRu: 'Спавнер опасных мобов (Тир 3)',
        fillArgb: 0xFF880E4F,
        borderArgb: 0xFFFF4081,
        textArgb: 0xFFFFFFFF,
        isAir: false,
      );
    }

    if (baseId == 'minecraft:iron_door') {
      final isUpper = props.contains('half=upper');
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: isUpper ? 'ДВ▲' : 'ДВР',
        facingSymbol: facingSymbol,
        titleRu: isUpper
            ? 'Железная дверь (верхняя часть)$facingTextRu'
            : 'Железная дверь (нижняя часть)$facingTextRu',
        fillArgb: 0xFF00B0FF,
        borderArgb: 0xFFFFFFFF,
        textArgb: 0xFF000000,
        isAir: false,
      );
    }

    if (baseId == 'minecraft:redstone_wire') {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'РЕД',
        facingSymbol: '',
        titleRu: 'Редстоун-проводка (линия сигнала)',
        fillArgb: 0xFFD50000,
        borderArgb: 0xFFFF8A80,
        textArgb: 0xFFFFFFFF,
        isAir: false,
      );
    }

    if (baseId == 'minecraft:redstone_block') {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'РБЛ',
        facingSymbol: '',
        titleRu: 'Блок редстоуна (питание поршня)',
        fillArgb: 0xFFB71C1C,
        borderArgb: 0xFFFF5252,
        textArgb: 0xFFFFFFFF,
        isAir: false,
      );
    }

    if (baseId == 'minecraft:sticky_piston') {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'ПРШ',
        facingSymbol: facingSymbol,
        titleRu: 'Липкий поршень синхронного сброса$facingTextRu',
        fillArgb: 0xFF00E676,
        borderArgb: 0xFFB9F6CA,
        textArgb: 0xFF000000,
        isAir: false,
      );
    }

    if (baseId == 'minecraft:tinted_glass') {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'СТК',
        facingSymbol: '',
        titleRu: 'Тонированное стекло (стенка стартовой шахты)',
        fillArgb: 0xFF26A69A,
        borderArgb: 0xFF80CBC4,
        textArgb: 0xFF000000,
        isAir: false,
      );
    }

    if (baseId == 'minecraft:sea_lantern') {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'ФНР',
        facingSymbol: '',
        titleRu: 'Морской фонарь (освещение шахты / пьедестала)',
        fillArgb: 0xFF84FFFF,
        borderArgb: 0xFFFFFFFF,
        textArgb: 0xFF000000,
        isAir: false,
      );
    }

    // 2. Драгоценные блоки пьедестала:
    if (baseId.contains('gold_block') ||
        baseId.contains('emerald_block') ||
        baseId.contains('diamond_block') ||
        baseId.contains('netherite_block')) {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'ПЬЕ',
        facingSymbol: '',
        titleRu: 'Блок пьедестала центральной арены ($baseId)',
        fillArgb: 0xFF00E5FF,
        borderArgb: 0xFFE0F7FA,
        textArgb: 0xFF000000,
        isAir: false,
      );
    }

    // 3. Капитальные барьерные блоки колец и стен:
    if (baseId == 'minecraft:obsidian' ||
        baseId == 'minecraft:crying_obsidian' ||
        baseId == 'minecraft:chiseled_stone_bricks' ||
        baseId == 'minecraft:nether_bricks') {
      final isCrying = baseId == 'minecraft:crying_obsidian';
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: isCrying ? 'ПОБ' : 'ОБС',
        facingSymbol: '',
        titleRu: isCrying
            ? 'Плачущий обсидиан ($baseId)'
            : 'Капитальный блок барьера / стены ($baseId)',
        fillArgb: isCrying ? 0xFF311B92 : 0xFF4A148C,
        borderArgb: 0xFF9575CD,
        textArgb: 0xFFFFFFFF,
        isAir: false,
      );
    }

    if (baseId.contains('chiseled') || baseId.contains('respawn_anchor')) {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'КРН',
        facingSymbol: '',
        titleRu: 'Верхний карниз стены ($baseId)',
        fillArgb: 0xFF546E7A,
        borderArgb: 0xFF90A4AE,
        textArgb: 0xFFFFFFFF,
        isAir: false,
      );
    }

    if (baseId.contains('bricks')) {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'СТН',
        facingSymbol: '',
        titleRu: 'Кладка стены лабиринта ($baseId)',
        fillArgb: 0xFF37474F,
        borderArgb: 0xFF607D8B,
        textArgb: 0xFFECEFF1,
        isAir: false,
      );
    }

    // 4. Блоки фундамента и пола:
    if (baseId.contains('smooth_stone') ||
        baseId == 'minecraft:stone' ||
        baseId == 'minecraft:bedrock') {
      return VoxelBlockVisualSpec(
        fullBlockState: normalized,
        baseBlockId: baseId,
        shortCode: 'ФНД',
        facingSymbol: '',
        titleRu: 'Плита фундамента ($baseId)',
        fillArgb: 0xFF263238,
        borderArgb: 0xFF37474F,
        textArgb: 0xFF90A4AE,
        isAir: false,
      );
    }

    return VoxelBlockVisualSpec(
      fullBlockState: normalized,
      baseBlockId: baseId,
      shortCode: 'ПОЛ',
      facingSymbol: '',
      titleRu: 'Блок пола ($baseId)',
      fillArgb: 0xFF1C2833,
      borderArgb: 0xFF2E4053,
      textArgb: 0xFFB0BEC5,
      isAir: false,
    );
  }

  static String _extractFacingSymbol(String props) {
    if (props.contains('facing=north')) return '▲';
    if (props.contains('facing=east')) return '►';
    if (props.contains('facing=south')) return '▼';
    if (props.contains('facing=west')) return '◄';
    if (props.contains('facing=up')) return '⊙';
    if (props.contains('facing=down')) return '⊗';
    return '';
  }

  static String _extractFacingRu(String props) {
    if (props.contains('facing=north')) return ' [Север ▲]';
    if (props.contains('facing=east')) return ' [Восток ►]';
    if (props.contains('facing=south')) return ' [Юг ▼]';
    if (props.contains('facing=west')) return ' [Запад ◄]';
    if (props.contains('facing=up')) return ' [Вверх ⊙]';
    if (props.contains('facing=down')) return ' [Вниз ⊗]';
    return '';
  }
}

