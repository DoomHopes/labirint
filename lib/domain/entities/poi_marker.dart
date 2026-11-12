import 'package:meta/meta.dart';
import 'grid_position.dart';
import 'maze_enums.dart';

/// Иерархия точек интереса (POI) на клетке лабиринта.
/// Использование `sealed class` гарантирует исчерпывающий pattern matching во всех слоях.
@immutable
sealed class PoiMarker {
  const PoiMarker();

  /// Возвращает краткое описание точки интереса на русском языке.
  String get summaryRu;
}

/// Отсутствие точки интереса на клетке.
@immutable
final class NoPoi extends PoiMarker {
  const NoPoi();

  @override
  String get summaryRu => 'Нет объекта POI';
}

/// Угловая стартовая шахта спавна игрока с вертикальным сбросом поршнем.
@immutable
final class CornerSpawnPoi extends PoiMarker {
  /// Номер стартового сектора (1..4).
  final int spawnIndex;

  /// Высота вертикальной шахты сброса над уровнем пола.
  final int shaftHeight;

  const CornerSpawnPoi({
    required this.spawnIndex,
    this.shaftHeight = 4,
  });

  @override
  String get summaryRu =>
      'Стартовая шахта #$spawnIndex (синхронный поршневой сброс)';
}

/// Сундук с тировым лутом (генерируется исключительно в тупиках).
@immutable
final class LootChestPoi extends PoiMarker {
  /// Тир лута (привязан к глубине кольца: 1, 2 или 3).
  final RingTier lootTier;

  /// Является ли сундук сундуком-ловушкой (`minecraft:trapped_chest`).
  final bool isTrappedChest;

  /// Ориентация лицевой стороны сундука (в сторону единственного выхода из тупика).
  final CardinalDirection facing;

  const LootChestPoi({
    required this.lootTier,
    required this.isTrappedChest,
    required this.facing,
  });

  @override
  String get summaryRu => isTrappedChest
      ? 'Сундук-ловушка (${lootTier.shortLabel}, смотрит на ${facing.labelRu})'
      : 'Сундук с лутом (${lootTier.shortLabel}, смотрит на ${facing.labelRu})';
}

/// Ловушка в коридоре: нажимная плита и подпольный редстоун к раздатчику в стене.
@immutable
final class TrapMechanismPoi extends PoiMarker {
  /// Тип ловушки (стрелковый раздатчик или пиротехнический раздатчик).
  final TrapKind kind;

  /// Направление, в котором ориентирован раздатчик (смотрит из стены на клетку с плитой).
  final CardinalDirection dispenserFacing;

  /// Смещение стены, в которую вмонтирован раздатчик, относительно клетки с плитой.
  final CardinalDirection wallDirection;

  const TrapMechanismPoi({
    required this.kind,
    required this.dispenserFacing,
    required this.wallDirection,
  });

  @override
  String get summaryRu =>
      '${kind.title} (раздатчик в стене: ${wallDirection.labelRu})';
}

/// Спавнер опасных мобов во внутреннем кольце (Тир 3).
@immutable
final class MobSpawnerPoi extends PoiMarker {
  /// Идентификатор сущности моба в Minecraft (например, `minecraft:wither_skeleton`).
  final String entityId;

  /// Отображаемое имя моба на русском языке.
  final String entityNameRu;

  const MobSpawnerPoi({
    required this.entityId,
    required this.entityNameRu,
  });

  @override
  String get summaryRu => 'Спавнер мобов: $entityNameRu ($entityId)';
}

/// Межкольевые ворота (проход через капитальный концентрический барьер).
@immutable
final class RingGatePoi extends PoiMarker {
  /// Из какого кольца ведет переход.
  final RingTier fromTier;

  /// В какое кольцо ведет переход.
  final RingTier toTier;

  /// Полярный угол расположения ворот относительно центра лабиринта (в градусах, 0..360).
  final double angleDegrees;

  const RingGatePoi({
    required this.fromTier,
    required this.toTier,
    required this.angleDegrees,
  });

  @override
  String get summaryRu =>
      'Межкольевой переход ${fromTier.shortLabel} → ${toTier.shortLabel} '
      '(${angleDegrees.toStringAsFixed(1)}°)';
}

/// Односторонний вход в центральную арену.
@immutable
final class ArenaEntryPoi extends PoiMarker {
  /// Режим одностороннего входа (перепад высоты 2 блока или железная дверь с плитой).
  final ArenaEntryMode mode;

  /// Направление входа в арену.
  final CardinalDirection entryDirection;

  /// Полярный угол входа относительно центра.
  final double angleDegrees;

  const ArenaEntryPoi({
    required this.mode,
    required this.entryDirection,
    required this.angleDegrees,
  });

  @override
  String get summaryRu =>
      'Односторонний вход в арену (${mode.title}, ${angleDegrees.toStringAsFixed(1)}°)';
}

/// Центральный пьедестал главного приза с финальным сундуком-ловушкой и салютом победы.
@immutable
final class ArenaPedestalPoi extends PoiMarker {
  /// Ориентация главного сундука.
  final CardinalDirection chestFacing;

  const ArenaPedestalPoi({
    this.chestFacing = CardinalDirection.south,
  });

  @override
  String get summaryRu =>
      'Пьедестал главного приза (финальный сундук-ловушка + салют победы)';
}

/// Запертая железная дверь-головоломка, для открытия которой необходимо найти рычаг.
@immutable
final class PuzzleDoorPoi extends PoiMarker {
  /// Идентификатор головоломки ('A', 'B' и т.д.).
  final String puzzleId;

  /// Ориентация двери.
  final CardinalDirection facing;

  /// Координаты парного рычага, открывающего данную дверь.
  final GridPosition? leverPosition;

  const PuzzleDoorPoi({
    required this.puzzleId,
    required this.facing,
    this.leverPosition,
  });

  @override
  String get summaryRu =>
      'Запертая железная дверь [$puzzleId] (рычаг: ${leverPosition != null ? "${leverPosition!.x}, ${leverPosition!.z}" : "в тупике"})';
}

/// Настенный рычаг-головоломка, открывающий запертую железную дверь.
@immutable
final class PuzzleLeverPoi extends PoiMarker {
  /// Идентификатор головоломки ('A', 'B' и т.д.).
  final String puzzleId;

  /// Направление стены, на которой закреплен рычаг.
  final CardinalDirection wallFacing;

  /// Координаты двери, которую открывает данный рычаг.
  final GridPosition? doorPosition;

  const PuzzleLeverPoi({
    required this.puzzleId,
    required this.wallFacing,
    this.doorPosition,
  });

  @override
  String get summaryRu =>
      'Секретный рычаг [$puzzleId] (открывает дверь: ${doorPosition != null ? "${doorPosition!.x}, ${doorPosition!.z}" : "в проходе"})';
}


