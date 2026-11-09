import 'package:meta/meta.dart';

/// Неизменяемая палитра блоков Minecraft для процедурной генерации лабиринта.
@immutable
final class BlockPalette {
  /// Идентификатор пресета палитры.
  final String id;

  /// Отображаемое название палитры на русском языке.
  final String name;

  /// Краткое описание стиля постройки.
  final String description;

  /// Основной блок стен лабиринта (например, `minecraft:deepslate_bricks`).
  final String primaryWallBlock;

  /// Блок капитальных разделительных стен между концентрическими кольцами.
  final String ringBarrierBlock;

  /// Декоративный акцентный блок верхнего яруса стен.
  final String wallTrimBlock;

  /// Блок пола проходов во внешнем/среднем/внутреннем кольце.
  final String floorBlockTier1;
  final String floorBlockTier2;
  final String floorBlockTier3;

  /// Блок пола центральной арены.
  final String arenaFloorBlock;

  /// Блок пьедестала главного приза в центре арены.
  final String pedestalBlock;

  /// Блок фундамента под полом (слой Y=0, в котором проложены редстоун-каналы).
  final String subfloorFoundationBlock;

  /// RGB-цвет стен для рендеринга на 2D-холсте (0xFFRRGGBB).
  final int wallColorArgb;

  /// RGB-цвет капитальных кольцевых барьеров на 2D-холсте.
  final int barrierColorArgb;

  /// RGB-цвет пола проходов на 2D-холсте.
  final int passageColorArgb;

  const BlockPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryWallBlock,
    required this.ringBarrierBlock,
    required this.wallTrimBlock,
    required this.floorBlockTier1,
    required this.floorBlockTier2,
    required this.floorBlockTier3,
    required this.arenaFloorBlock,
    required this.pedestalBlock,
    required this.subfloorFoundationBlock,
    required this.wallColorArgb,
    required this.barrierColorArgb,
    required this.passageColorArgb,
  });

  /// Пресет 1: Глубокий сланец и Обсидиан (Тёмный Древний Город).
  static const BlockPalette deepslateObsidian = BlockPalette(
    id: 'deepslate_obsidian',
    name: 'Глубокий сланец и Обсидиан',
    description: 'Взрывоустойчивые барьеры из обсидиана и стены из кирпичей сланца',
    primaryWallBlock: 'minecraft:deepslate_bricks',
    ringBarrierBlock: 'minecraft:obsidian',
    wallTrimBlock: 'minecraft:chiseled_deepslate',
    floorBlockTier1: 'minecraft:polished_deepslate',
    floorBlockTier2: 'minecraft:deepslate_tiles',
    floorBlockTier3: 'minecraft:reinforced_deepslate',
    arenaFloorBlock: 'minecraft:crying_obsidian',
    pedestalBlock: 'minecraft:gold_block',
    subfloorFoundationBlock: 'minecraft:Smooth_stone',
    wallColorArgb: 0xFF2B2F3A,
    barrierColorArgb: 0xFF171324,
    passageColorArgb: 0xFF141820,
  );

  /// Пресет 2: Замшелые катакомбы (Классический данж).
  static const BlockPalette mossyCatacombs = BlockPalette(
    id: 'mossy_catacombs',
    name: 'Замшелый булыжник и Каменный кирпич',
    description: 'Атмосфера древней подземной крепости с замшелыми стенами',
    primaryWallBlock: 'minecraft:mossy_stone_bricks',
    ringBarrierBlock: 'minecraft:chiseled_stone_bricks',
    wallTrimBlock: 'minecraft:mossy_cobblestone',
    floorBlockTier1: 'minecraft:cobblestone',
    floorBlockTier2: 'minecraft:stone_bricks',
    floorBlockTier3: 'minecraft:cracked_stone_bricks',
    arenaFloorBlock: 'minecraft:polished_andesite',
    pedestalBlock: 'minecraft:emerald_block',
    subfloorFoundationBlock: 'minecraft:stone',
    wallColorArgb: 0xFF39463A,
    barrierColorArgb: 0xFF253026,
    passageColorArgb: 0xFF171D18,
  );

  /// Пресет 3: Обсидиановый бастион (Максимальная защита от взрывов в PvP).
  static const BlockPalette obsidianBastion = BlockPalette(
    id: 'obsidian_bastion',
    name: 'Чистый Обсидиан и Плачущий обсидиан',
    description: 'Неразрушимая арена для хардкорного PvP с кристаллами и TNT',
    primaryWallBlock: 'minecraft:obsidian',
    ringBarrierBlock: 'minecraft:crying_obsidian',
    wallTrimBlock: 'minecraft:respawn_anchor[charges=4]',
    floorBlockTier1: 'minecraft:blackstone',
    floorBlockTier2: 'minecraft:polished_blackstone_bricks',
    floorBlockTier3: 'minecraft:gilded_blackstone',
    arenaFloorBlock: 'minecraft:obsidian',
    pedestalBlock: 'minecraft:diamond_block',
    subfloorFoundationBlock: 'minecraft:bedrock',
    wallColorArgb: 0xFF231934,
    barrierColorArgb: 0xFF3B1E54,
    passageColorArgb: 0xFF120E1A,
  );

  /// Пресет 4: Чернокаменная цитадель Незера.
  static const BlockPalette blackstoneCitadel = BlockPalette(
    id: 'blackstone_citadel',
    name: 'Чернокамень и Незеритовый кирпич',
    description: 'Бастион в стиле Незера с позолоченным чернокамнем и базальтом',
    primaryWallBlock: 'minecraft:polished_blackstone_bricks',
    ringBarrierBlock: 'minecraft:nether_bricks',
    wallTrimBlock: 'minecraft:chiseled_polished_blackstone',
    floorBlockTier1: 'minecraft:polished_basalt[axis=y]',
    floorBlockTier2: 'minecraft:blackstone',
    floorBlockTier3: 'minecraft:red_nether_bricks',
    arenaFloorBlock: 'minecraft:gilded_blackstone',
    pedestalBlock: 'minecraft:netherite_block',
    subfloorFoundationBlock: 'minecraft:polished_blackstone',
    wallColorArgb: 0xFF34272D,
    barrierColorArgb: 0xFF4A1E24,
    passageColorArgb: 0xFF191316,
  );

  /// Неизменяемый список всех стандартных палитр.
  static const List<BlockPalette> presets = <BlockPalette>[
    deepslateObsidian,
    mossyCatacombs,
    obsidianBastion,
    blackstoneCitadel,
  ];
}

