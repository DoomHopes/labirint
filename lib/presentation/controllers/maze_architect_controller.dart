import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../../data/services/file_export_service.dart';
import '../../domain/core/result.dart';
import '../../domain/entities/block_palette.dart';
import '../../domain/entities/maze_cell.dart';
import '../../domain/entities/maze_config.dart';
import '../../domain/entities/maze_enums.dart';
import '../../domain/entities/maze_grid.dart';
import '../../domain/entities/poi_marker.dart';
import '../../domain/entities/voxel_volume.dart';
import '../../domain/repositories/i_maze_exporter.dart';
import '../../domain/repositories/i_maze_generator.dart';
import '../../domain/repositories/i_voxel_compiler.dart';

/// Контроллер состояния архитектора PvP-лабиринтов (Presentation State Manager).
///
/// Зависит исключительно от абстрактных контрактов доменного слоя (DIP).
final class MazeArchitectController extends ChangeNotifier {
  final IMazeGenerator _mazeGenerator;
  final IVoxelCompiler _voxelCompiler;
  final ISchematicExporter _schematicExporter;
  final ICommandScriptExporter _commandExporter;
  final FileExportService _fileExportService;

  MazeConfig _config;
  MazeGrid? _grid;
  VoxelVolume? _volume;
  EditorTool _activeTool = EditorTool.inspect;
  ViewLayerMode _viewLayerMode = ViewLayerMode.compositeTopDown;
  GridPosition? _selectedPosition;
  SchematicBinaryArtifact? _lastSchematicArtifact;
  CommandScriptArtifact? _lastCommandArtifact;
  String? _statusMessage;
  bool _isStatusError = false;

  MazeArchitectController({
    required this._mazeGenerator,
    required this._voxelCompiler,
    required this._schematicExporter,
    required this._commandExporter,
    required this._fileExportService,
    MazeConfig? initialConfig,
  }) : _config = initialConfig ?? MazeConfig.standard() {
    regenerateMaze();
  }

  MazeConfig get config => _config;
  MazeGrid? get grid => _grid;
  VoxelVolume? get volume => _volume;
  EditorTool get activeTool => _activeTool;
  ViewLayerMode get viewLayerMode => _viewLayerMode;
  GridPosition? get selectedPosition => _selectedPosition;
  SchematicBinaryArtifact? get lastSchematicArtifact => _lastSchematicArtifact;
  CommandScriptArtifact? get lastCommandArtifact => _lastCommandArtifact;
  String? get statusMessage => _statusMessage;
  bool get isStatusError => _isStatusError;

  /// Возвращает выбранную пользователем клетку лабиринта (или центральную клетку по умолчанию).
  MazeCell? get selectedCell {
    final currentGrid = _grid;
    if (currentGrid == null) {
      return null;
    }
    final pos = _selectedPosition ?? currentGrid.center;
    if (!currentGrid.isInBounds(pos.x, pos.z)) {
      return currentGrid.cellAtPosition(currentGrid.center);
    }
    return currentGrid.cellAtPosition(pos);
  }

  /// Выполняет полную процедурную генерацию лабиринта и компиляцию 3D-объема.
  void regenerateMaze([MazeConfig? updatedConfig]) {
    if (updatedConfig != null) {
      _config = updatedConfig;
    }

    final genResult = _mazeGenerator.generate(_config);
    switch (genResult) {
      case Failure(:final error):
        _statusMessage = error.toString();
        _isStatusError = true;
        notifyListeners();
      case Success(:final value):
        _grid = value;
        _selectedPosition = value.center;
        _recompileVoxelsAndRefreshArtifacts(
          statusNote:
              'Лабиринт ${value.size}×${value.size} успешно сгенерирован (Сид: ${_config.seed}).',
        );
    }
  }

  /// Генерирует новый случайный сид и перестраивает лабиринт.
  void randomizeSeedAndGenerate() {
    final nextSeed = math.Random().nextInt(89999999) + 10000000;
    regenerateMaze(_config.copyWith(seed: nextSeed));
  }

  void updateSeed(int seed) {
    regenerateMaze(_config.copyWith(seed: seed));
  }

  void updateGridSize(int gridSize) {
    regenerateMaze(_config.copyWith(gridSize: gridSize));
  }

  void updateArenaSize(int arenaSize) {
    regenerateMaze(_config.copyWith(arenaSize: arenaSize));
  }

  void updatePassageWidth(int passageWidth) {
    regenerateMaze(_config.copyWith(passageWidth: passageWidth));
  }

  void updateWallHeight(int wallHeight) {
    regenerateMaze(_config.copyWith(wallHeight: wallHeight));
  }

  void updateRingCount(int ringCount) {
    regenerateMaze(_config.copyWith(ringCount: ringCount));
  }

  void updateAlgorithm(MazeAlgorithm algorithm) {
    regenerateMaze(_config.copyWith(algorithm: algorithm));
  }

  void updateArenaEntryMode(ArenaEntryMode mode) {
    regenerateMaze(_config.copyWith(arenaEntryMode: mode));
  }

  void updateDeadEndDensity(double density) {
    regenerateMaze(_config.copyWith(deadEndDensity: density));
  }

  void updateTrapPercentage(double trapPercentage) {
    regenerateMaze(_config.copyWith(trapPercentage: trapPercentage));
  }

  void updatePalette(BlockPalette palette) {
    regenerateMaze(_config.copyWith(palette: palette));
  }

  void selectEditorTool(EditorTool tool) {
    if (_activeTool == tool) {
      return;
    }
    _activeTool = tool;
    notifyListeners();
  }

  void selectViewLayerMode(ViewLayerMode mode) {
    if (_viewLayerMode == mode) {
      return;
    }
    _viewLayerMode = mode;
    notifyListeners();
  }

  /// Обрабатывает клик или рисование по клетке 2D-сетки в соответствии с активным инструментом.
  void applyToolAtCell(GridPosition pos) {
    final currentGrid = _grid;
    if (currentGrid == null || !currentGrid.isInBounds(pos.x, pos.z)) {
      return;
    }

    _selectedPosition = pos;
    if (_activeTool == EditorTool.inspect) {
      notifyListeners();
      return;
    }

    final existingCell = currentGrid.cellAtPosition(pos);
    final updatedCell = _transformCellWithTool(existingCell, _activeTool);
    _grid = currentGrid.withUpdatedCell(updatedCell);
    _recompileVoxelsAndRefreshArtifacts(
      statusNote:
          'Клетка ${pos.x}, ${pos.z} обновлена инструментом «${_activeTool.title}».',
    );
  }

  MazeCell _transformCellWithTool(MazeCell cell, EditorTool tool) {
    return switch (tool) {
      EditorTool.inspect => cell,
      EditorTool.toggleWallPassage => cell.surfaceType.isSolidWall
          ? cell.copyWith(
              surfaceType: CellSurfaceType.passage,
              poi: const NoPoi(),
            )
          : cell.copyWith(
              surfaceType: CellSurfaceType.wall,
              poi: const NoPoi(),
              hasSubfloorRedstone: false,
            ),
      EditorTool.placeSpawn => cell.copyWith(
          surfaceType: CellSurfaceType.spawnShaft,
          poi: const CornerSpawnPoi(spawnIndex: 1),
          hasSubfloorRedstone: true,
        ),
      EditorTool.placeChestTier1 => cell.copyWith(
          surfaceType: CellSurfaceType.passage,
          poi: const LootChestPoi(
            lootTier: RingTier.tier1,
            isTrappedChest: false,
            facing: CardinalDirection.south,
          ),
          isDeadEnd: true,
        ),
      EditorTool.placeChestTier2 => cell.copyWith(
          surfaceType: CellSurfaceType.passage,
          poi: const LootChestPoi(
            lootTier: RingTier.tier2,
            isTrappedChest: false,
            facing: CardinalDirection.south,
          ),
          isDeadEnd: true,
        ),
      EditorTool.placeChestTier3 => cell.copyWith(
          surfaceType: CellSurfaceType.passage,
          poi: const LootChestPoi(
            lootTier: RingTier.tier3,
            isTrappedChest: false,
            facing: CardinalDirection.south,
          ),
          isDeadEnd: true,
        ),
      EditorTool.placeTrappedChest => cell.copyWith(
          surfaceType: CellSurfaceType.passage,
          poi: LootChestPoi(
            lootTier: cell.ringTier == RingTier.centralArena
                ? RingTier.tier3
                : cell.ringTier,
            isTrappedChest: true,
            facing: CardinalDirection.south,
          ),
          hasSubfloorRedstone: true,
          isDeadEnd: true,
        ),
      EditorTool.placeDispenserTrap => cell.copyWith(
          surfaceType: CellSurfaceType.passage,
          poi: const TrapMechanismPoi(
            kind: TrapKind.arrowDispenser,
            dispenserFacing: CardinalDirection.south,
            wallDirection: CardinalDirection.north,
          ),
          hasSubfloorRedstone: true,
        ),
      EditorTool.placeMobSpawner => cell.copyWith(
          surfaceType: CellSurfaceType.passage,
          poi: const MobSpawnerPoi(
            entityId: 'minecraft:wither_skeleton',
            entityNameRu: 'Визер-скелет',
          ),
        ),
      EditorTool.eraser => cell.copyWith(
          poi: const NoPoi(),
          hasSubfloorRedstone: false,
        ),
    };
  }

  void _recompileVoxelsAndRefreshArtifacts({required String statusNote}) {
    final currentGrid = _grid;
    if (currentGrid == null) {
      return;
    }

    final compileRes = _voxelCompiler.compile(currentGrid);
    switch (compileRes) {
      case Failure(:final error):
        _statusMessage = error.toString();
        _isStatusError = true;
      case Success(:final value):
        _volume = value;
        final schemRes = _schematicExporter.exportSchematic(
          grid: currentGrid,
          volume: value,
        );
        if (schemRes is Success<SchematicBinaryArtifact>) {
          _lastSchematicArtifact = schemRes.value;
        }
        final cmdRes = _commandExporter.exportCommands(
          grid: currentGrid,
          volume: value,
        );
        if (cmdRes is Success<CommandScriptArtifact>) {
          _lastCommandArtifact = cmdRes.value;
        }
        _statusMessage = statusNote;
        _isStatusError = false;
    }
    notifyListeners();
  }

  /// Сохраняет бинарный файл Sponge Schematic (`.schem`) и уведомляет пользователя.
  Future<Result<String>> saveSchematicToDisk() async {
    final artifact = _lastSchematicArtifact;
    if (artifact == null) {
      const err = DomainError(
        code: 'NO_SCHEMATIC_ARTIFACT',
        message: 'Артефакт .schem еще не сформирован.',
      );
      _statusMessage = err.message;
      _isStatusError = true;
      notifyListeners();
      return const Result.failure(err);
    }

    final res = await _fileExportService.saveBinaryFile(
      fileName: artifact.fileName,
      bytes: artifact.gzippedNbtBytes,
    );
    switch (res) {
      case Success(:final value):
        _statusMessage = 'Sponge Schematic (.schem) сохранен: $value';
        _isStatusError = false;
      case Failure(:final error):
        _statusMessage = error.toString();
        _isStatusError = true;
    }
    notifyListeners();
    return res;
  }

  /// Сохраняет командный скрипт `.mcfunction` / SignalBlock на диск.
  Future<Result<String>> saveCommandScriptToDisk() async {
    final artifact = _lastCommandArtifact;
    if (artifact == null) {
      const err = DomainError(
        code: 'NO_COMMAND_ARTIFACT',
        message: 'Командный скрипт еще не сформирован.',
      );
      _statusMessage = err.message;
      _isStatusError = true;
      notifyListeners();
      return const Result.failure(err);
    }

    final res = await _fileExportService.saveTextFile(
      fileName: artifact.fileName,
      content: artifact.mcFunctionContent,
    );
    switch (res) {
      case Success(:final value):
        _statusMessage = 'Скрипт постройки (.mcfunction) сохранен: $value';
        _isStatusError = false;
      case Failure(:final error):
        _statusMessage = error.toString();
        _isStatusError = true;
    }
    notifyListeners();
    return res;
  }
}
