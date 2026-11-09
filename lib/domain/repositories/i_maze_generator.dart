import '../core/result.dart';
import '../entities/maze_config.dart';
import '../entities/maze_grid.dart';

/// Контракт генератора радиально-концентрического PvP-лабиринта (DIP/ISP).
abstract interface class IMazeGenerator {
  /// Генерирует неизменяемую 2D-структуру лабиринта [MazeGrid] по заданной [config].
  Result<MazeGrid> generate(MazeConfig config);
}

