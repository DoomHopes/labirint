import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/entities/maze_cell.dart';
import '../../domain/entities/maze_enums.dart';
import '../../domain/entities/maze_grid.dart';
import '../../domain/entities/poi_marker.dart';
import '../../domain/entities/voxel_volume.dart';
import '../services/texture_service.dart';

/// Цветовые константы слоев согласно ТЗ (без теней).
abstract final class MazeLayerColors {
  static const Color spawnGreen = Color(0xFF00E676);
  static const Color chestTier1Yellow = Color(0xFFFFEA00);
  static const Color chestTier2Orange = Color(0xFFFF9100);
  static const Color chestTier3Red = Color(0xFFFF1744);
  static const Color trapPurple = Color(0xFFD500F9);
  static const Color arenaBlueFloor = Color(0xFF102A56);
  static const Color arenaBlueBorder = Color(0xFF2979FF);
  static const Color pedestalCyan = Color(0xFF00E5FF);
  static const Color redstoneWireRed = Color(0xFFFF3D00);
  static const Color ringGateCyan = Color(0xFF18FFFF);
  static const Color puzzleAColor = Color(0xFF00E5FF);
  static const Color puzzleBColor = Color(0xFFFFD600);
}

/// Высокопроизводительный CustomPainter для 2 слоев схемы:
/// 1. Слой 1: Пол (Разметка зон и тропинки).
/// 2. Слой 2: Стены (текстура камня), Сундуки (текстура сундука), Загадки (Дверь + Рычаг).
final class MazeGridPainter extends CustomPainter {
  static const double rulerMargin = 22.0;

  final MazeGrid grid;
  final VoxelVolume volume;
  final ViewLayerMode layerMode;
  final bool showBlockCodes;
  final GridPosition? selectedPosition;
  final GridPosition? hoveredPosition;
  final TextureService textureService;

  const MazeGridPainter({
    required this.grid,
    required this.volume,
    required this.layerMode,
    required this.showBlockCodes,
    required this.selectedPosition,
    required this.hoveredPosition,
    required this.textureService,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullSide = math.min(size.width, size.height);
    final gridAreaSide = math.max(10.0, fullSide - rulerMargin);
    final cellSize = gridAreaSide / grid.size;

    // 1. Отрисовка координатных линеек X и Z (без теней)
    _paintCoordinateRulers(canvas, fullSide, cellSize);

    canvas.save();
    canvas.translate(rulerMargin, rulerMargin);

    // 2. Отрисовка одного из 2 понятных слоев
    if (layerMode == ViewLayerMode.floor) {
      _paintFloorLayer(canvas, cellSize);
    } else {
      _paintWallsAndObjectsLayer(canvas, cellSize);
    }

    // 3. Четкая координатная сетка между блоками
    final gridLinePaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..strokeWidth = 0.5;
    final totalGridPx = cellSize * grid.size;
    for (var i = 0; i <= grid.size; i++) {
      final offset = i * cellSize;
      canvas.drawLine(Offset(offset, 0), Offset(offset, totalGridPx), gridLinePaint);
      canvas.drawLine(Offset(0, offset), Offset(totalGridPx, offset), gridLinePaint);
    }

    // 4. Подсветка наведенной клетки под курсором
    final hov = hoveredPosition;
    if (hov != null && grid.isInBounds(hov.x, hov.z)) {
      final hovRect = Rect.fromLTWH(hov.x * cellSize, hov.z * cellSize, cellSize, cellSize);
      canvas.drawRect(
        hovRect.deflate(0.5),
        Paint()
          ..color = Colors.yellowAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // 5. Подсветка выбранной кликом клетки
    final sel = selectedPosition;
    if (sel != null && grid.isInBounds(sel.x, sel.z)) {
      final selRect = Rect.fromLTWH(sel.x * cellSize, sel.z * cellSize, cellSize, cellSize);
      canvas.drawRect(
        selRect.deflate(0.5),
        Paint()
          ..color = Colors.cyanAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    canvas.restore();
  }

  void _paintCoordinateRulers(Canvas canvas, double fullSide, double cellSize) {
    final rulerBg = Paint()..color = const Color(0xFF141B29);
    canvas.drawRect(Rect.fromLTWH(0, 0, fullSide, rulerMargin), rulerBg);
    canvas.drawRect(Rect.fromLTWH(0, 0, rulerMargin, fullSide), rulerBg);

    _drawCenteredText(
      canvas: canvas,
      text: 'X\\Z',
      rect: const Rect.fromLTWH(0, 0, rulerMargin, rulerMargin),
      color: const Color(0xFF00E5FF),
      fontSize: 8.5,
      fontWeight: FontWeight.bold,
    );

    final step = cellSize < 12.0 ? 5 : (cellSize < 20.0 ? 2 : 1);
    for (var i = 0; i < grid.size; i += step) {
      final label = '$i';
      final xRect = Rect.fromLTWH(rulerMargin + i * cellSize, 0, cellSize * step, rulerMargin);
      _drawCenteredText(
        canvas: canvas,
        text: label,
        rect: xRect,
        color: const Color(0xFF9AA8C4),
        fontSize: 8.5,
      );

      final zRect = Rect.fromLTWH(0, rulerMargin + i * cellSize, rulerMargin, cellSize * step);
      _drawCenteredText(
        canvas: canvas,
        text: label,
        rect: zRect,
        color: const Color(0xFF9AA8C4),
        fontSize: 8.5,
      );
    }
  }

  /// Слой 1: Пол (Напольное покрытие, концентрические зоны, дорожки, арена).
  void _paintFloorLayer(Canvas canvas, double cellSize) {
    for (var z = 0; z < grid.size; z++) {
      for (var x = 0; x < grid.size; x++) {
        final cell = grid.cellAt(x, z);
        final rect = Rect.fromLTWH(x * cellSize, z * cellSize, cellSize, cellSize);

        if (cell.surfaceType.isSolidWall) {
          // Фундамент под стенами
          canvas.drawRect(rect, Paint()..color = const Color(0xFF181F2C));
          continue;
        }

        // Цвета пола по зонам лабиринта (без теней)
        final floorColor = switch (cell.ringTier) {
          RingTier.tier1 => const Color(0xFF2E3D30),
          RingTier.tier2 => const Color(0xFF3F3528),
          RingTier.tier3 => const Color(0xFF452232),
          RingTier.centralArena => MazeLayerColors.arenaBlueFloor,
        };

        canvas.drawRect(rect, Paint()..color = floorColor);

        // Пьедестал в центре арены
        if (cell.surfaceType == CellSurfaceType.pedestal) {
          canvas.drawRect(rect, Paint()..color = const Color(0xFF00B8D4));
        }

        // Подпольный редстоун Y=0
        if (cell.hasSubfloorRedstone) {
          canvas.drawCircle(
            rect.center,
            math.max(1.5, cellSize * 0.16),
            Paint()..color = MazeLayerColors.redstoneWireRed,
          );
        }
      }
    }

    // Подписи зон по центру
    final center = grid.center;
    final arenaRadius = grid.config.arenaSize ~/ 2;
    final arenaCenterPx = Offset((center.x + 0.5) * cellSize, (center.z + 0.5) * cellSize);

    canvas.drawCircle(
      arenaCenterPx,
      arenaRadius * cellSize,
      Paint()
        ..color = const Color(0xFF2979FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  /// Слой 2: Стены (текстура камня), Сундуки (текстура сундука) и Загадки (Дверь + Рычаг).
  void _paintWallsAndObjectsLayer(Canvas canvas, double cellSize) {
    final stoneImg = textureService.stoneImage;
    final chestImg = textureService.chestImage;
    final doorImg = textureService.doorImage;
    final leverImg = textureService.leverImage;

    const stoneSrc = Rect.fromLTWH(0, 0, 16, 16);
    const chestSrc = Rect.fromLTWH(0, 0, 16, 16);
    const doorSrc = Rect.fromLTWH(0, 0, 16, 16);
    const leverSrc = Rect.fromLTWH(0, 0, 16, 16);

    final puzzleLinks = <({GridPosition door, GridPosition lever, String id})>[];

    // 1. Отрисовка стен и проходов
    for (var z = 0; z < grid.size; z++) {
      for (var x = 0; x < grid.size; x++) {
        final cell = grid.cellAt(x, z);
        final rect = Rect.fromLTWH(x * cellSize, z * cellSize, cellSize, cellSize);

        if (cell.surfaceType.isSolidWall) {
          // Отрисовка стены: аутентичная текстура камня или четкий цвет
          if (cell.surfaceType == CellSurfaceType.ringBarrierWall ||
              cell.surfaceType == CellSurfaceType.arenaWall) {
            // Капитальный обсидиановый барьер
            canvas.drawRect(rect, Paint()..color = const Color(0xFF241538));
            canvas.drawRect(
              rect.deflate(0.5),
              Paint()
                ..color = const Color(0xFF4A1E74)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );
          } else if (stoneImg != null) {
            canvas.drawImageRect(stoneImg, stoneSrc, rect, Paint());
          } else {
            // Запасная точная отрисовка камня
            canvas.drawRect(rect, Paint()..color = const Color(0xFF757575));
            canvas.drawRect(
              rect.deflate(0.5),
              Paint()
                ..color = const Color(0xFF5A5A5A)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.8,
            );
          }
        } else {
          // Проход: чистый пол без стен
          final passageColor = cell.surfaceType == CellSurfaceType.arenaFloor
              ? const Color(0xFF0F203C)
              : const Color(0xFF0E131C);
          canvas.drawRect(rect, Paint()..color = passageColor);
        }

        // Сохраняем связи для линий загадок
        if (cell.poi is PuzzleDoorPoi) {
          final doorPoi = cell.poi as PuzzleDoorPoi;
          if (doorPoi.leverPosition != null) {
            puzzleLinks.add((
              door: cell.position,
              lever: doorPoi.leverPosition!,
              id: doorPoi.puzzleId,
            ));
          }
        }
      }
    }

    // 2. Линии связи между запертой дверью и ее рычагом
    final linkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final link in puzzleLinks) {
      final doorCenter = Offset(
        (link.door.x + 0.5) * cellSize,
        (link.door.z + 0.5) * cellSize,
      );
      final leverCenter = Offset(
        (link.lever.x + 0.5) * cellSize,
        (link.lever.z + 0.5) * cellSize,
      );

      final linkColor = link.id == 'A'
          ? MazeLayerColors.puzzleAColor
          : MazeLayerColors.puzzleBColor;
      linkPaint.color = linkColor.withValues(alpha: 0.85);

      canvas.drawLine(doorCenter, leverCenter, linkPaint);
    }

    // 3. Отрисовка всех объектов POI (Сундуки, Двери, Рычаги, Спавны, Пьедестал)
    for (var z = 0; z < grid.size; z++) {
      for (var x = 0; x < grid.size; x++) {
        final cell = grid.cellAt(x, z);
        final rect = Rect.fromLTWH(x * cellSize, z * cellSize, cellSize, cellSize);
        final poi = cell.poi;

        switch (poi) {
          case NoPoi():
            break;

          case LootChestPoi(:final lootTier, :final isTrappedChest):
            // Отрисовка текстуры сундука Minecraft
            if (chestImg != null) {
              canvas.drawImageRect(chestImg, chestSrc, rect, Paint());
            } else {
              canvas.drawRect(rect, Paint()..color = const Color(0xFF8B5322));
            }

            // Цветной ободок тира лута
            final tierColor = switch (lootTier) {
              RingTier.tier1 => MazeLayerColors.chestTier1Yellow,
              RingTier.tier2 => MazeLayerColors.chestTier2Orange,
              RingTier.tier3 || RingTier.centralArena => MazeLayerColors.chestTier3Red,
            };

            canvas.drawRect(
              rect.deflate(0.6),
              Paint()
                ..color = isTrappedChest ? MazeLayerColors.trapPurple : tierColor
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0,
            );

            if (showBlockCodes && cellSize >= 11.0) {
              _drawCenteredText(
                canvas: canvas,
                text: isTrappedChest ? 'СЛ' : 'Т${lootTier.tierNumber}',
                rect: rect,
                color: Colors.white,
                fontSize: (cellSize * 0.38).clamp(7.0, 11.0),
                fontWeight: FontWeight.w900,
              );
            }

          case PuzzleDoorPoi(:final puzzleId):
            // Отрисовка запертой двери-головоломки
            if (doorImg != null) {
              canvas.drawImageRect(doorImg, doorSrc, rect, Paint());
            } else {
              canvas.drawRect(rect, Paint()..color = const Color(0xFFB0BEC5));
            }

            final pColor = puzzleId == 'A'
                ? MazeLayerColors.puzzleAColor
                : MazeLayerColors.puzzleBColor;

            canvas.drawRect(
              rect.deflate(0.5),
              Paint()
                ..color = pColor
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.4,
            );

            _drawCenteredText(
              canvas: canvas,
              text: 'ДВ[$puzzleId]',
              rect: rect,
              color: Colors.black,
              fontSize: (cellSize * 0.36).clamp(7.0, 11.0),
              fontWeight: FontWeight.w900,
            );

          case PuzzleLeverPoi(:final puzzleId):
            // Отрисовка секретного рычага в тупике
            canvas.drawRect(rect, Paint()..color = const Color(0xFF263238));
            if (leverImg != null) {
              canvas.drawImageRect(leverImg, leverSrc, rect, Paint());
            }

            final pColor = puzzleId == 'A'
                ? MazeLayerColors.puzzleAColor
                : MazeLayerColors.puzzleBColor;

            canvas.drawCircle(
              rect.center,
              cellSize * 0.45,
              Paint()
                ..color = pColor
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.2,
            );

            _drawCenteredText(
              canvas: canvas,
              text: 'РЫЧ[$puzzleId]',
              rect: rect,
              color: pColor,
              fontSize: (cellSize * 0.34).clamp(6.5, 10.5),
              fontWeight: FontWeight.w900,
            );

          case CornerSpawnPoi(:final spawnIndex):
            final inset = rect.deflate(cellSize * 0.08);
            canvas.drawRect(inset, Paint()..color = MazeLayerColors.spawnGreen);
            _drawCenteredText(
              canvas: canvas,
              text: 'S$spawnIndex',
              rect: inset,
              color: Colors.black,
              fontSize: (cellSize * 0.44).clamp(7.5, 12.0),
              fontWeight: FontWeight.w900,
            );

          case TrapMechanismPoi():
            final inset = rect.deflate(cellSize * 0.1);
            canvas.drawRect(inset, Paint()..color = MazeLayerColors.trapPurple);
            _drawCenteredText(
              canvas: canvas,
              text: 'ПЛТ',
              rect: inset,
              color: Colors.white,
              fontSize: (cellSize * 0.36).clamp(6.5, 10.0),
              fontWeight: FontWeight.w800,
            );

          case MobSpawnerPoi():
            final inset = rect.deflate(cellSize * 0.1);
            canvas.drawRect(inset, Paint()..color = const Color(0xFF880E4F));
            _drawCenteredText(
              canvas: canvas,
              text: 'СПВ',
              rect: inset,
              color: Colors.white,
              fontSize: (cellSize * 0.34).clamp(6.5, 10.0),
              fontWeight: FontWeight.w800,
            );

          case RingGatePoi():
            canvas.drawRect(
              rect,
              Paint()
                ..color = MazeLayerColors.ringGateCyan
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0,
            );

          case ArenaEntryPoi():
            canvas.drawRect(rect, Paint()..color = MazeLayerColors.arenaBlueBorder);
            _drawCenteredText(
              canvas: canvas,
              text: 'ВХОД',
              rect: rect,
              color: Colors.white,
              fontSize: (cellSize * 0.32).clamp(6.5, 9.5),
              fontWeight: FontWeight.w800,
            );

          case ArenaPedestalPoi():
            canvas.drawRect(rect, Paint()..color = MazeLayerColors.pedestalCyan);
            if (chestImg != null) {
              canvas.drawImageRect(chestImg, chestSrc, rect.deflate(cellSize * 0.12), Paint());
            } else {
              canvas.drawCircle(
                rect.center,
                cellSize * 0.25,
                Paint()..color = MazeLayerColors.chestTier3Red,
              );
            }
        }
      }
    }
  }

  void _drawCenteredText({
    required Canvas canvas,
    required String text,
    required Rect rect,
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'monospace',
          fontWeight: fontWeight,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);

    final offset = Offset(
      rect.left + (rect.width - textPainter.width) * 0.5,
      rect.top + (rect.height - textPainter.height) * 0.5,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant MazeGridPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.volume != volume ||
        oldDelegate.layerMode != layerMode ||
        oldDelegate.showBlockCodes != showBlockCodes ||
        oldDelegate.selectedPosition != selectedPosition ||
        oldDelegate.hoveredPosition != hoveredPosition ||
        oldDelegate.textureService.isLoaded != textureService.isLoaded;
  }
}
