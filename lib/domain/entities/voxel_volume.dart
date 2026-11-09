import 'dart:typed_data';
import 'package:meta/meta.dart';

/// Трехмерная координата вокселя в пространстве схемы Minecraft (X, Y, Z).
@immutable
final class VoxelPosition {
  final int x;
  final int y;
  final int z;

  const VoxelPosition(this.x, this.y, this.z);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoxelPosition && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => '($x, $y, $z)';
}

/// Предмет в слоте контейнера Minecraft (сундука или раздатчика).
@immutable
final class ContainerSlotItem {
  /// Номер слота контейнера (0..26 для сундука, 0..8 для раздатчика).
  final int slot;

  /// Идентификатор предмета (например, `minecraft:diamond_sword`).
  final String itemId;

  /// Количество предметов в стаке.
  final int count;

  /// Дополнительный SNBT-тег компонента предмета (например, для фейерверков).
  final String? customSnbtTag;

  const ContainerSlotItem({
    required this.slot,
    required this.itemId,
    required this.count,
    this.customSnbtTag,
  });
}

/// Иерархия блочных сущностей (BlockEntity / TileEntity) внутри 3D-объема схемы.
@immutable
sealed class VoxelBlockEntity {
  /// Позиция блочной сущности в 3D-объеме схемы.
  final VoxelPosition position;

  /// Идентификатор типа блочной сущности (`minecraft:chest`, `minecraft:trapped_chest`, `minecraft:dispenser`, `minecraft:spawner`).
  final String blockEntityId;

  const VoxelBlockEntity({
    required this.position,
    required this.blockEntityId,
  });
}

/// Блочная сущность контейнера (сундук, сундук-ловушка или раздатчик).
@immutable
final class ContainerBlockEntity extends VoxelBlockEntity {
  /// Отображаемое пользовательское имя контейнера.
  final String customName;

  final List<ContainerSlotItem> _items;

  ContainerBlockEntity({
    required super.position,
    required super.blockEntityId,
    required this.customName,
    required List<ContainerSlotItem> items,
  }) : _items = List<ContainerSlotItem>.unmodifiable(items);

  /// Неизменяемый список предметов в инвентаре контейнера.
  List<ContainerSlotItem> get items => _items;
}

/// Блочная сущность спавнера мобов (`minecraft:spawner`).
@immutable
final class SpawnerBlockEntity extends VoxelBlockEntity {
  /// Идентификатор призываемого моба (`minecraft:wither_skeleton`, `minecraft:zombie` и т.д.).
  final String entityId;

  /// Количество мобов за цикл спавна.
  final int spawnCount;

  /// Радиус зоны спавна вокруг блока.
  final int spawnRange;

  /// Минимальная задержка между спавнами в тиках.
  final int minSpawnDelay;

  /// Максимальная задержка между спавнами в тиках.
  final int maxSpawnDelay;

  /// Радиус обнаружения игрока для активации спавнера.
  final int requiredPlayerRange;

  const SpawnerBlockEntity({
    required super.position,
    required this.entityId,
    this.spawnCount = 2,
    this.spawnRange = 4,
    this.minSpawnDelay = 120,
    this.maxSpawnDelay = 280,
    this.requiredPlayerRange = 12,
  }) : super(blockEntityId: 'minecraft:spawner');
}

/// Трехмерный воксельный объем лабиринта, готовый к сериализации в `.schem` или `.mcfunction`.
@immutable
final class VoxelVolume {
  /// Ширина по оси X.
  final int width;

  /// Высота по оси Y (включая подпольный редстоун-слой Y=0, пол Y=1, стены и шахты сброса).
  final int height;

  /// Длина по оси Z.
  final int length;

  /// Палитра строковых состояний блоков (индекс в списке соответствует ID в палитре).
  final List<String> _palette;

  /// Обратный индекс палитры: строка BlockState -> числовой индекс палитры.
  final Map<String, int> _paletteLookup;

  /// Плоский массив индексов палитры в порядке Sponge Schematic: `(y * length + z) * width + x`.
  final Uint16List _blockIndices;

  /// Список блочных сущностей (сундуки с лутом, раздатчики, спавнеры).
  final List<VoxelBlockEntity> _blockEntities;

  VoxelVolume({
    required this.width,
    required this.height,
    required this.length,
    required List<String> palette,
    required Map<String, int> paletteLookup,
    required Uint16List blockIndices,
    required List<VoxelBlockEntity> blockEntities,
  })  : assert(
          blockIndices.length == width * height * length,
          'Некорректный размер воксельного буфера',
        ),
        _palette = List<String>.unmodifiable(palette),
        _paletteLookup = Map<String, int>.unmodifiable(paletteLookup),
        _blockIndices = Uint16List.fromList(blockIndices),
        _blockEntities = List<VoxelBlockEntity>.unmodifiable(blockEntities);

  /// Неизменяемая палитра состояний блоков (`BlockState`).
  List<String> get palette => _palette;

  /// Неизменяемая таблица сопоставления `BlockState -> Palette Index`.
  Map<String, int> get paletteLookup => _paletteLookup;

  /// Защищенная копия индексов блоков в порядке `(y * length + z) * width + x`.
  Uint16List get blockIndices => Uint16List.fromList(_blockIndices);

  /// Прямое чтение индекса палитры по линейному смещению без копирования массива.
  int paletteIndexAtLinear(int linearOffset) => _blockIndices[linearOffset];

  /// Общее количество вокселей в 3D-объеме.
  int get totalVoxels => _blockIndices.length;

  /// Неизменяемый список блочных сущностей (`TileEntities` / `BlockEntities`).
  List<VoxelBlockEntity> get blockEntities => _blockEntities;

  /// Возвращает строковый `BlockState` по координатам $(x, y, z)$.
  String blockStateAt(int x, int y, int z) {
    final linear = (y * length + z) * width + x;
    final idx = _blockIndices[linear];
    return _palette[idx];
  }
}

/// Иерархия результата экспорта постройки.
@immutable
sealed class ExportArtifact {
  /// Рекомендуемое имя файла с расширением.
  final String fileName;

  /// Человекочитаемая сводка экспорта.
  final String summaryRu;

  const ExportArtifact({
    required this.fileName,
    required this.summaryRu,
  });
}

/// Артефакт бинарного экспорта Sponge Schematic (`.schem`).
@immutable
final class SchematicBinaryArtifact extends ExportArtifact {
  final Uint8List _gzippedNbtBytes;
  final Uint8List _rawNbtBytes;
  final int paletteSize;
  final int tileEntityCount;
  final int totalBlocks;

  SchematicBinaryArtifact({
    required super.fileName,
    required super.summaryRu,
    required Uint8List gzippedNbtBytes,
    required Uint8List rawNbtBytes,
    required this.paletteSize,
    required this.tileEntityCount,
    required this.totalBlocks,
  })  : _gzippedNbtBytes = Uint8List.fromList(gzippedNbtBytes),
        _rawNbtBytes = Uint8List.fromList(rawNbtBytes);

  /// Сжатый GZip бинарный поток файла `.schem`.
  Uint8List get gzippedNbtBytes => Uint8List.fromList(_gzippedNbtBytes);

  /// Несжатый NBT-буфер (для инспекции и отладки).
  Uint8List get rawNbtBytes => Uint8List.fromList(_rawNbtBytes);

  /// Размер сжатого файла `.schem` в байтах.
  int get compressedSizeBytes => _gzippedNbtBytes.length;

  /// Размер несжатого NBT-потока в байтах.
  int get uncompressedSizeBytes => _rawNbtBytes.length;
}

/// Артефакт текстового экспорта командного скрипта (`.mcfunction`) и SignalBlock-схемы.
@immutable
final class CommandScriptArtifact extends ExportArtifact {
  /// Полный текст функции постройки `.mcfunction`.
  final String mcFunctionContent;

  /// Команды инициализации цепочки сигнальных блоков (SignalBlock / самосборка без плагинов).
  final String signalBlockBootstrapCommand;

  /// Количество сгенерированных команд `/fill` и `/setblock`.
  final int commandCount;

  const CommandScriptArtifact({
    required super.fileName,
    required super.summaryRu,
    required this.mcFunctionContent,
    required this.signalBlockBootstrapCommand,
    required this.commandCount,
  });
}

