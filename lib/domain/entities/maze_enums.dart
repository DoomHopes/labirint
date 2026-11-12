/// Алгоритм процедурной генерации коридоров внутри концентрических колец.
enum MazeAlgorithm {
  /// Модифицированный алгоритм Прима (высокое ветвление, больше коротких тупиков).
  modifiedPrims(
    title: 'Модифицированный алгоритм Прима',
    shortName: "Prim's (Ветвистый)",
    description:
        'Формирует густую сеть коротких ответвлений и тупиков для засад и лута.',
  ),

  /// Рекурсивный бэктрекинг на базе поиска в глубину (длинные извилистые коридоры).
  recursiveBacktrackerDfs(
    title: 'Рекурсивный бэктрекинг (DFS)',
    shortName: 'DFS (Извилистый)',
    description:
        'Создает длинные запутанные коридоры с вынужденным обходом секторов.',
  );

  final String title;
  final String shortName;
  final String description;

  const MazeAlgorithm({
    required this.title,
    required this.shortName,
    required this.description,
  });
}

/// Концентрическая зона (кольцо) лабиринта от периферии к центру.
enum RingTier {
  /// Внешнее кольцо (Тир 1): стартовые шахты и базовое снаряжение.
  tier1(
    tierNumber: 1,
    title: 'Внешнее кольцо (Тир 1)',
    shortLabel: 'Тир 1',
    description: 'Стартовый периметр, базовое снаряжение и редкие ловушки.',
  ),

  /// Среднее кольцо (Тир 2): повышенная плотность редстоун-ловушек и раздатчиков.
  tier2(
    tierNumber: 2,
    title: 'Среднее кольцо (Тир 2 — Ловушки)',
    shortLabel: 'Тир 2',
    description: 'Зона редстоун-механизмов, нажимных плит и стрелковых раздатчиков.',
  ),

  /// Внутреннее кольцо (Тир 3): опасные мобы (спавнеры) и топовый PvP-лут.
  tier3(
    tierNumber: 3,
    title: 'Внутреннее кольцо (Тир 3 — Мобы)',
    shortLabel: 'Тир 3',
    description: 'Спавнеры опасных мобов, сундуки-ловушки и элитная экипировка.',
  ),

  /// Центральная арена: финальная зона столкновения с пьедесталом главного приза.
  centralArena(
    tierNumber: 4,
    title: 'Центральная арена (Финал)',
    shortLabel: 'Арена',
    description:
        'Односторонний вход, открытое PvP-пространство и пьедестал главного приза.',
  );

  final int tierNumber;
  final String title;
  final String shortLabel;
  final String description;

  const RingTier({
    required this.tierNumber,
    required this.title,
    required this.shortLabel,
    required this.description,
  });
}

/// Тип поверхности клетки на 2D-плане лабиринта.
enum CellSurfaceType {
  /// Обычная внутренняя или внешняя стена лабиринта.
  wall,

  /// Свободный проход (коридор) внутри кольца.
  passage,

  /// Капитальная разделительная стена между концентрическими кольцами.
  ringBarrierWall,

  /// Открытый пол центральной арены.
  arenaFloor,

  /// Ограждающая стена центральной арены.
  arenaWall,

  /// Пьедестал в центре арены.
  pedestal,

  /// Вертикальная стартовая шахта спавна игрока.
  spawnShaft;

  /// Возвращает `true`, если по данной клетке может пройти игрок.
  bool get isWalkable =>
      this == CellSurfaceType.passage ||
      this == CellSurfaceType.arenaFloor ||
      this == CellSurfaceType.pedestal ||
      this == CellSurfaceType.spawnShaft;

  /// Возвращает `true`, если клетка является сплошной стеной.
  bool get isSolidWall =>
      this == CellSurfaceType.wall ||
      this == CellSurfaceType.ringBarrierWall ||
      this == CellSurfaceType.arenaWall;
}

/// Стороны света в системе координат Minecraft (X: Восток+, Z: Юг+).
enum CardinalDirection {
  north(dx: 0, dz: -1, minecraftName: 'north', labelRu: 'Север (-Z)'),
  east(dx: 1, dz: 0, minecraftName: 'east', labelRu: 'Восток (+X)'),
  south(dx: 0, dz: 1, minecraftName: 'south', labelRu: 'Юг (+Z)'),
  west(dx: -1, dz: 0, minecraftName: 'west', labelRu: 'Запад (-X)');

  final int dx;
  final int dz;
  final String minecraftName;
  final String labelRu;

  const CardinalDirection({
    required this.dx,
    required this.dz,
    required this.minecraftName,
    required this.labelRu,
  });

  /// Противоположное направление.
  CardinalDirection get opposite => switch (this) {
        CardinalDirection.north => CardinalDirection.south,
        CardinalDirection.east => CardinalDirection.west,
        CardinalDirection.south => CardinalDirection.north,
        CardinalDirection.west => CardinalDirection.east,
      };
}

/// Механика одностороннего входа в центральную арену.
enum ArenaEntryMode {
  /// Перепад высоты в 2 блока (спрыгивание с уступа в арену без возможности выпрыгнуть).
  heightDropTwoBlocks(
    title: 'Перепад высоты (2 блока)',
    description:
        'Коридор Тира 3 выходит на карниз высотой +2 блока над полом арены.',
  ),

  /// Железная дверь с нажимной плитой только со стороны коридора лабиринта.
  oneWayIronDoor(
    title: 'Железная дверь с внешней плитой',
    description:
        'Железная дверь открывается нажимной плитой снаружи и блокирует выход изнутри.',
  );

  final String title;
  final String description;

  const ArenaEntryMode({
    required this.title,
    required this.description,
  });
}

/// Разновидность ловушки в коридорах или тупиках.
enum TrapKind {
  /// Нажимная плита + подпольный редстоун + раздатчик со стрелами в стене.
  arrowDispenser(
    title: 'Раздатчик стрел (Нажимная плита)',
  ),

  /// Нажимная плита + подпольный редстоун + раздатчик с боевым пиротехническим зарядом.
  fireworkDispenser(
    title: 'Пиротехническая ловушка (Раздатчик)',
  ),

  /// Сундук-ловушка в тупике, активирующий скрытый раздатчик в соседней стене.
  trappedChestAmbush(
    title: 'Сундук-ловушка с засадой',
  ),

  /// Спавнер агрессивных мобов во внутреннем кольце (Тир 3).
  mobSpawner(
    title: 'Спавнер опасных мобов (Тир 3)',
  );

  final String title;

  const TrapKind({required this.title});
}

/// Инструмент ручного редактирования сетки лабиринта на интерактивном холсте.
enum EditorTool {
  inspect(
    title: 'Инспектор',
    tooltip: 'Просмотр координат, тира, NBT-содержимого и редстоун-связей клетки',
  ),
  toggleWallPassage(
    title: 'Стена / Проход',
    tooltip: 'Клик переключает клетку между стеной и проходом',
  ),
  placeSpawn(
    title: 'Спавн (Шахта)',
    tooltip: 'Разместить стартовую вертикальную шахту сброса игрока',
  ),
  placeChestTier1(
    title: 'Сундук Т1',
    tooltip: 'Разместить сундук Тира 1 (базовый лут)',
  ),
  placeChestTier2(
    title: 'Сундук Т2',
    tooltip: 'Разместить сундук Тира 2 (средний PvP-лут)',
  ),
  placeChestTier3(
    title: 'Сундук Т3',
    tooltip: 'Разместить сундук Тира 3 (элитный PvP-лут)',
  ),
  placeTrappedChest(
    title: 'Сундук-ловушка',
    tooltip: 'Разместить сундук-ловушку с подпольной редстоун-активацией',
  ),
  placeDispenserTrap(
    title: 'Плита + Раздатчик',
    tooltip: 'Разместить нажимную плиту с редстоун-линией к стеновому раздатчику',
  ),
  placeMobSpawner(
    title: 'Спавнер мобов',
    tooltip: 'Разместить спавнер мобов (зомби/скелеты/визер-скелеты)',
  ),
  placePuzzleDoor(
    title: 'Дверь (Замок)',
    tooltip: 'Разместить запертую дверь-головоломку',
  ),
  placePuzzleLever(
    title: 'Рычаг (Ключ)',
    tooltip: 'Разместить настенный рычаг, открывающий дверь',
  ),
  eraser(
    title: 'Очистить POI',
    tooltip: 'Удалить маркер POI и ловушку с выбранной клетки',
  );

  final String title;
  final String tooltip;

  const EditorTool({
    required this.title,
    required this.tooltip,
  });
}

/// Режим отображения слоев на 2D-карте лабиринта (2 наглядных слоя).
enum ViewLayerMode {
  /// Слой 2: Стены (камень), Сундуки с лутом и Загадки (Дверь + Рычаг).
  wallsAndObjects(
    title: 'Слой 2: Стены, Сундуки и Загадки',
    shortTitle: 'Слой 2: Стены и Объекты',
  ),

  /// Слой 1: Пол (напольное покрытие и разметка концентрических зон).
  floor(
    title: 'Слой 1: Пол (Разметка зон)',
    shortTitle: 'Слой 1: Пол',
  );

  final String title;
  final String shortTitle;

  const ViewLayerMode({
    required this.title,
    required this.shortTitle,
  });
}

