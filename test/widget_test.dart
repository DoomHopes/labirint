import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:labirint/data/exporters/sponge_schematic_exporter.dart';
import 'package:labirint/data/exporters/vanilla_command_exporter.dart';
import 'package:labirint/data/generators/radial_concentric_maze_generator.dart';
import 'package:labirint/data/nbt/nbt_binary_writer.dart';
import 'package:labirint/data/nbt/nbt_tag.dart';
import 'package:labirint/data/services/file_export_service.dart';
import 'package:labirint/data/voxels/maze_voxel_compiler.dart';
import 'package:labirint/domain/core/result.dart';
import 'package:labirint/domain/entities/maze_config.dart';
import 'package:labirint/domain/entities/maze_enums.dart';
import 'package:labirint/domain/entities/maze_grid.dart';
import 'package:labirint/domain/entities/poi_marker.dart';
import 'package:labirint/domain/entities/voxel_block_visual.dart';
import 'package:labirint/domain/entities/voxel_volume.dart';
import 'package:labirint/main.dart';
import 'package:labirint/presentation/controllers/maze_architect_controller.dart';

void main() {
  group('Генератор радиально-концентрического лабиринта и математика колец', () {
    const generator = RadialConcentricMazeGenerator();

    test(
      'Генерирует валидные сетки 33×33, 49×49 и 65×65 со смещением ворот 90°–180°',
      () {
        for (final size in <int>[33, 49, 65]) {
          for (final algo in MazeAlgorithm.values) {
            final config = MazeConfig.standard(seed: 100 + size).copyWith(
              gridSize: size,
              arenaSize: size >= 49 ? 21 : 15,
              algorithm: algo,
            );
            final result = generator.generate(config);
            expect(result.isSuccess, isTrue);

            final grid = (result as Success<MazeGrid>).value;
            expect(grid.size, equals(size));
            expect(grid.spawnCount, equals(4));
            expect(grid.gateTransitions, isNotEmpty);

            // Проверяем, что все межкольевые переходы имеют смещение строго 90°..180°.
            for (final gate in grid.gateTransitions) {
              expect(
                gate.angularOffsetFromPrevious,
                inInclusiveRange(90.0, 180.0),
              );
            }

            // Проверяем, что сундуки с лутом генерируются исключительно в тупиках.
            for (final cell in grid.cells) {
              if (cell.poi is LootChestPoi) {
                final chest = cell.poi as LootChestPoi;
                expect(
                  cell.isDeadEnd,
                  isTrue,
                  reason:
                      'Сундук на ${cell.position} должен находиться строго в тупике',
                );
                expect(chest.lootTier, equals(cell.ringTier));
              }
            }
          }
        }
      },
    );
  });

  group('Бинарная сериализация NBT, VarInt и GZip (.schem v2/v3)', () {
    const generator = RadialConcentricMazeGenerator();
    const compiler = MazeVoxelCompiler();
    const compressor = PureDartGzipCompressor();
    const schemExporter = SpongeSchematicExporter(compressor: compressor);
    const cmdExporter = VanillaCommandExporter();

    test(
      'Сериализует Sponge Schematic (.schem), корректно распаковывается стандартным GZip и содержит валидный NBT',
      () {
        final config = MazeConfig.standard(seed: 777);
        final grid = (generator.generate(config) as Success<MazeGrid>).value;
        final volume =
            (compiler.compile(grid) as Success<VoxelVolume>).value;

        final schemRes = schemExporter.exportSchematic(
          grid: grid,
          volume: volume,
        );
        expect(schemRes.isSuccess, isTrue);

        final artifact = (schemRes as Success<SchematicBinaryArtifact>).value;
        final gzBytes = artifact.gzippedNbtBytes;

        // Проверка сигнатуры GZip (RFC 1952: 0x1F, 0x8B, CM=0x08).
        expect(gzBytes[0], equals(0x1F));
        expect(gzBytes[1], equals(0x8B));
        expect(gzBytes[2], equals(0x08));

        // Распаковываем стандартным системным декодером dart:io gzip для верификации RFC 1952 + CRC32.
        final decompressed = Uint8List.fromList(gzip.decode(gzBytes));
        expect(decompressed, equals(artifact.rawNbtBytes));

        // Парсим бинарный поток через NbtBinaryReader.
        final parsed = NbtBinaryReader(decompressed).readRootCompound();
        expect(parsed.rootName, equals('Schematic'));

        final root = parsed.rootCompound;
        expect((root['Version'] as NbtInt).value, equals(2));
        expect((root['Width'] as NbtShort).value, equals(grid.size));
        expect((root['Length'] as NbtShort).value, equals(grid.size));

        final blockDataTag = root['BlockData'] as NbtByteArray;
        final decodedIndices = NbtBinaryWriter.decodeVarIntBlockData(
          blockDataTag.bytes,
        );
        expect(decodedIndices.length, equals(volume.totalVoxels));

        final blockEntities = root['BlockEntities'] as NbtList;
        expect(blockEntities.items, isNotEmpty);

        // Проверяем экспорт командного скрипта .mcfunction и SignalBlock.
        final cmdRes = cmdExporter.exportCommands(grid: grid, volume: volume);
        expect(cmdRes.isSuccess, isTrue);
        final cmdArtifact = (cmdRes as Success<CommandScriptArtifact>).value;
        expect(cmdArtifact.mcFunctionContent, contains('fill ~0 ~0 ~0'));
        expect(cmdArtifact.mcFunctionContent, contains('minecraft:sticky_piston'));
        expect(cmdArtifact.mcFunctionContent, contains('SignalBlock Bootstrap'));
      },
    );
  });

  testWidgets('Отрисовка главного экрана MazeArchitectApp', (tester) async {
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = MazeArchitectController(
      mazeGenerator: const RadialConcentricMazeGenerator(),
      voxelCompiler: const MazeVoxelCompiler(),
      schematicExporter: const SpongeSchematicExporter(
        compressor: PureDartGzipCompressor(),
      ),
      commandExporter: const VanillaCommandExporter(),
      fileExportService: const FileExportService(),
    );

    await tester.pumpWidget(MazeArchitectApp(controller: controller));
    await tester.pump();

    expect(
      find.text('Minecraft PvP Maze & Redstone Architect'),
      findsOneWidget,
    );
    expect(find.text('Экспорт .schem'), findsOneWidget);
    expect(find.text('Экспорт .mcfunction'), findsOneWidget);

    // Проверяем по-блочный классификатор и переключение слоев Y.
    final dispSpec = VoxelBlockClassifier.classify(
      'minecraft:dispenser[facing=east,triggered=false]',
    );
    expect(dispSpec.badgeLabel, equals('РЗ►'));
    expect(dispSpec.isAir, isFalse);

    controller.selectYLayer(0);
    await tester.pump();
    expect(controller.activeYLayer, equals(0));
    expect(controller.activeLayerBlockCounts, isNotEmpty);
  });
}
