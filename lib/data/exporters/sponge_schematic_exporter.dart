import '../../domain/core/result.dart';
import '../../domain/entities/maze_grid.dart';
import '../../domain/entities/voxel_volume.dart';
import '../../domain/repositories/i_maze_exporter.dart';
import '../nbt/nbt_binary_writer.dart';
import '../nbt/nbt_tag.dart';

/// Реализация экспортера в формат Sponge Schematic (`.schem` v2/v3).
///
/// Генерирует бинарный GZip-сжатый NBT-файл со следующей структурой:
/// * `Version` = 2 (`TAG_Int`), `DataVersion` = 3700 (Minecraft 1.20.4)
/// * `Width`, `Height`, `Length` (`TAG_Short`)
/// * `Palette` (`TAG_Compound`: строковый `BlockState` -> целочисленный индекс)
/// * `BlockData` (`TAG_Byte_Array`: упакованные `VarInt` индексы в порядке `Y -> Z -> X`)
/// * `BlockEntities` (`TAG_List<TAG_Compound>`: инвентари сундуков с тировым лутом,
///   заряженные раздатчики и настроенные спавнеры мобов).
final class SpongeSchematicExporter implements ISchematicExporter {
  final IBinaryCompressor _compressor;

  const SpongeSchematicExporter({
    required this._compressor,
  });

  @override
  Result<SchematicBinaryArtifact> exportSchematic({
    required MazeGrid grid,
    required VoxelVolume volume,
  }) {
    try {
      // 1. Формируем словарь палитры Palette (BlockState -> NbtInt(index)).
      final paletteMap = <String, NbtTag>{};
      final paletteList = volume.palette;
      for (var i = 0; i < paletteList.length; i++) {
        paletteMap[paletteList[i]] = NbtInt(i);
      }

      // 2. Кодируем воксельный массив в компактный VarInt байт-буфер BlockData.
      final rawIndices = volume.blockIndices;
      final varIntBlockData = NbtBinaryWriter.encodeVarIntBlockData(rawIndices);

      // 3. Сериализуем блочные сущности (BlockEntities / TileEntities).
      final blockEntityCompounds = <NbtTag>[];
      for (final entity in volume.blockEntities) {
        blockEntityCompounds.add(_buildBlockEntityCompound(entity));
      }

      final blockEntitiesList = NbtList(
        elementType: NbtTagType.tagCompound,
        items: blockEntityCompounds,
      );

      // 4. Формируем корневой тег Schematic по спецификации Sponge Schematic.
      final rootSchematicCompound = NbtCompound(<String, NbtTag>{
        'Version': const NbtInt(2),
        'DataVersion': const NbtInt(3700),
        'Width': NbtShort(volume.width),
        'Height': NbtShort(volume.height),
        'Length': NbtShort(volume.length),
        'Offset': NbtIntArray(const <int>[0, 0, 0]),
        'Metadata': NbtCompound(<String, NbtTag>{
          'WEOffsetX': const NbtInt(0),
          'WEOffsetY': const NbtInt(0),
          'WEOffsetZ': const NbtInt(0),
          'Name': NbtString('PvP_Radial_Maze_${grid.size}x${grid.size}'),
          'Author': const NbtString('Flutter PvP Maze Architect'),
          'Seed': NbtLong(grid.config.seed),
        }),
        'PaletteMax': NbtInt(paletteList.length),
        'Palette': NbtCompound(paletteMap),
        'BlockData': NbtByteArray(varIntBlockData),
        'BlockEntities': blockEntitiesList,
        'TileEntities': blockEntitiesList,
      });

      final writer = NbtBinaryWriter(
        initialCapacity: varIntBlockData.length + 16384,
      );
      final rawNbtBytes = writer.writeRootCompound(
        rootName: 'Schematic',
        rootTag: rootSchematicCompound,
      );

      final gzippedBytes = _compressor.compressGzip(rawNbtBytes);
      final fileName =
          'pvp_maze_${grid.size}x${grid.size}_seed_${grid.config.seed}.schem';

      return Result.success(
        SchematicBinaryArtifact(
          fileName: fileName,
          summaryRu:
              'Sponge Schematic v2 ($fileName): ${volume.width}×${volume.height}×${volume.length} блоков, '
              'палитра: ${paletteList.length} состояний, TileEntities: ${blockEntityCompounds.length}, '
              'размер GZip: ${(gzippedBytes.length / 1024).toStringAsFixed(1)} КБ',
          gzippedNbtBytes: gzippedBytes,
          rawNbtBytes: rawNbtBytes,
          paletteSize: paletteList.length,
          tileEntityCount: blockEntityCompounds.length,
          totalBlocks: volume.totalVoxels,
        ),
      );
    } catch (e) {
      return Result.failure(
        DomainError(
          code: 'SCHEMATIC_EXPORT_ERROR',
          message: 'Ошибка при сборке бинарного файла .schem.',
          details: e.toString(),
        ),
      );
    }
  }

  NbtCompound _buildBlockEntityCompound(VoxelBlockEntity entity) {
    final posArray = NbtIntArray(<int>[
      entity.position.x,
      entity.position.y,
      entity.position.z,
    ]);

    switch (entity) {
      case ContainerBlockEntity(
          :final blockEntityId,
          :final customName,
          :final items,
        ):
        final nbtItems = <NbtTag>[];
        for (final item in items) {
          nbtItems.add(
            NbtCompound(<String, NbtTag>{
              'Slot': NbtByte(item.slot),
              'id': NbtString(item.itemId.toLowerCase()),
              'Count': NbtByte(item.count),
              if (item.customSnbtTag != null)
                'tag_snbt': NbtString(item.customSnbtTag!),
            }),
          );
        }

        return NbtCompound(<String, NbtTag>{
          'Id': NbtString(blockEntityId),
          'id': NbtString(blockEntityId),
          'Pos': posArray,
          'x': NbtInt(entity.position.x),
          'y': NbtInt(entity.position.y),
          'z': NbtInt(entity.position.z),
          'CustomName': NbtString('{"text":"$customName"}'),
          'Items': NbtList(
            elementType: NbtTagType.tagCompound,
            items: nbtItems,
          ),
        });

      case SpawnerBlockEntity(
          :final entityId,
          :final spawnCount,
          :final spawnRange,
          :final minSpawnDelay,
          :final maxSpawnDelay,
          :final requiredPlayerRange,
        ):
        return NbtCompound(<String, NbtTag>{
          'Id': const NbtString('minecraft:spawner'),
          'id': const NbtString('minecraft:spawner'),
          'Pos': posArray,
          'x': NbtInt(entity.position.x),
          'y': NbtInt(entity.position.y),
          'z': NbtInt(entity.position.z),
          'Delay': const NbtShort(20),
          'MinSpawnDelay': NbtShort(minSpawnDelay),
          'MaxSpawnDelay': NbtShort(maxSpawnDelay),
          'SpawnCount': NbtShort(spawnCount),
          'SpawnRange': NbtShort(spawnRange),
          'RequiredPlayerRange': NbtShort(requiredPlayerRange),
          'MaxNearbyEntities': const NbtShort(6),
          'SpawnData': NbtCompound(<String, NbtTag>{
            'entity': NbtCompound(<String, NbtTag>{
              'id': NbtString(entityId),
            }),
          }),
        });
    }
  }
}
