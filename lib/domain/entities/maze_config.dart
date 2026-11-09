import 'package:meta/meta.dart';
import 'block_palette.dart';
import 'maze_enums.dart';

/// Неизменяемая конфигурация генерации радиально-концентрического PvP-лабиринта.
@immutable
final class MazeConfig {
  /// Числовой сид генератора случайных чисел для детерминированной генерации.
  final int seed;

  /// Габарит лабиринта по осям X и Z (нечетное число: 33, 49, 65 и т.д.).
  final int gridSize;

  /// Размер центральной арены (15×15 или 21×21 блок).
  final int arenaSize;

  /// Ширина проходов (1 или 2 блока). Толщина стен фиксирована — 1 блок.
  final int passageWidth;

  /// Высота стен лабиринта (3 или 4 блока).
  final int wallHeight;

  /// Количество концентрических зон (3 или 4 зоны, включая центральную арену).
  final int ringCount;

  /// Алгоритм генерации лабиринта (Модифицированный Прим или Рекурсивный DFS).
  final MazeAlgorithm algorithm;

  /// Механика одностороннего входа в центральную арену.
  final ArenaEntryMode arenaEntryMode;

  /// Плотность сохранения тупиков (от 0.2 до 1.0; при 1.0 все тупики сохраняются).
  final double deadEndDensity;

  /// Процент заполнения тупиков и коридоров ловушками (от 0.0 до 1.0).
  final double trapPercentage;

  /// Выбранная палитра блоков Minecraft.
  final BlockPalette palette;

  const MazeConfig({
    required this.seed,
    required this.gridSize,
    required this.arenaSize,
    required this.passageWidth,
    required this.wallHeight,
    required this.ringCount,
    required this.algorithm,
    required this.arenaEntryMode,
    required this.deadEndDensity,
    required this.trapPercentage,
    required this.palette,
  });

  /// Фабричный конструктор конфигурации по умолчанию (49×49, 4 зоны, арена 15×15).
  factory MazeConfig.standard({int seed = 20261109}) {
    return MazeConfig(
      seed: seed,
      gridSize: 49,
      arenaSize: 15,
      passageWidth: 1,
      wallHeight: 4,
      ringCount: 4,
      algorithm: MazeAlgorithm.modifiedPrims,
      arenaEntryMode: ArenaEntryMode.oneWayIronDoor,
      deadEndDensity: 0.85,
      trapPercentage: 0.45,
      palette: BlockPalette.deepslateObsidian,
    );
  }

  /// Создает копию конфигурации с измененными параметрами.
  MazeConfig copyWith({
    int? seed,
    int? gridSize,
    int? arenaSize,
    int? passageWidth,
    int? wallHeight,
    int? ringCount,
    MazeAlgorithm? algorithm,
    ArenaEntryMode? arenaEntryMode,
    double? deadEndDensity,
    double? trapPercentage,
    BlockPalette? palette,
  }) {
    final nextGridSize = gridSize ?? this.gridSize;
    var nextArenaSize = arenaSize ?? this.arenaSize;
    if (nextGridSize <= 37 && nextArenaSize > 15) {
      nextArenaSize = 15;
    }

    return MazeConfig(
      seed: seed ?? this.seed,
      gridSize: nextGridSize,
      arenaSize: nextArenaSize,
      passageWidth: passageWidth ?? this.passageWidth,
      wallHeight: wallHeight ?? this.wallHeight,
      ringCount: ringCount ?? this.ringCount,
      algorithm: algorithm ?? this.algorithm,
      arenaEntryMode: arenaEntryMode ?? this.arenaEntryMode,
      deadEndDensity: deadEndDensity ?? this.deadEndDensity,
      trapPercentage: trapPercentage ?? this.trapPercentage,
      palette: palette ?? this.palette,
    );
  }
}

