import 'dart:typed_data';
import '../core/result.dart';
import '../entities/maze_grid.dart';
import '../entities/voxel_volume.dart';

/// Контракт бинарного компрессора GZip (RFC 1952).
abstract interface class IBinaryCompressor {
  /// Сжимает входной буфер байтов в формат GZip с контрольной суммой CRC-32.
  Uint8List compressGzip(Uint8List rawBytes);
}

/// Контракт экспортера постройки в формат Sponge Schematic (`.schem` v2/v3).
abstract interface class ISchematicExporter {
  /// Экспортирует воксельный объем [volume] и метаданные [grid] в бинарный артефакт `.schem`.
  Result<SchematicBinaryArtifact> exportSchematic({
    required MazeGrid grid,
    required VoxelVolume volume,
  });
}

/// Контракт экспортера постройки в ванильный скрипт `.mcfunction` и цепочку SignalBlock.
abstract interface class ICommandScriptExporter {
  /// Экспортирует [volume] и редстоун-механики [grid] в ванильные команды Minecraft.
  Result<CommandScriptArtifact> exportCommands({
    required MazeGrid grid,
    required VoxelVolume volume,
  });
}

