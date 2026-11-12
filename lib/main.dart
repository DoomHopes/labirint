import 'package:flutter/material.dart';

import 'data/exporters/sponge_schematic_exporter.dart';
import 'data/exporters/vanilla_command_exporter.dart';
import 'data/generators/radial_concentric_maze_generator.dart';
import 'data/nbt/nbt_binary_writer.dart';
import 'data/services/file_export_service.dart';
import 'data/voxels/maze_voxel_compiler.dart';
import 'presentation/controllers/maze_architect_controller.dart';
import 'presentation/screens/maze_architect_screen.dart';
import 'presentation/services/texture_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TextureService.instance.loadTextures();

  // Composition Root: сборка зависимостей через абстракции (Dependency Inversion).
  const generator = RadialConcentricMazeGenerator();
  const voxelCompiler = MazeVoxelCompiler();
  const compressor = PureDartGzipCompressor();
  const schematicExporter = SpongeSchematicExporter(compressor: compressor);
  const commandExporter = VanillaCommandExporter();
  const fileExportService = FileExportService();

  final controller = MazeArchitectController(
    mazeGenerator: generator,
    voxelCompiler: voxelCompiler,
    schematicExporter: schematicExporter,
    commandExporter: commandExporter,
    fileExportService: fileExportService,
  );

  runApp(MazeArchitectApp(controller: controller));
}

/// Корневой виджет кроссплатформенного приложения генерации PvP-лабиринтов для Minecraft.
class MazeArchitectApp extends StatelessWidget {
  final MazeArchitectController controller;

  const MazeArchitectApp({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minecraft PvP Maze & Redstone Architect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
      ),
      home: MazeArchitectScreen(controller: controller),
    );
  }
}
