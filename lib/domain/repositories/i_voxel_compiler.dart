import '../core/result.dart';
import '../entities/maze_grid.dart';
import '../entities/voxel_volume.dart';

/// Контракт компилятора 2D-плана лабиринта в 3D-воксельный объем с редстоун-схемами.
abstract interface class IVoxelCompiler {
  /// Транслирует [grid] в трехмерный воксельный объем [VoxelVolume] с контейнерами и спавнерами.
  Result<VoxelVolume> compile(MazeGrid grid);
}

