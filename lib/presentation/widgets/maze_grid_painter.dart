import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/entities/maze_cell.dart';
import '../../domain/entities/maze_enums.dart';
import '../../domain/entities/maze_grid.dart';
import '../../domain/entities/poi_marker.dart';

/// Цветовые константы слоев согласно техническому заданию:
/// * Спавны — зеленый
/// * Сундуки Tier 1–3 — желтый / оранжевый / красный
/// * Ловушки — фиолетовый
/// * Центральная арена — синий
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
}

/// Высокопроизводительный `CustomPainter` для рендеринга 2D-карты лабиринта сверху.
final class MazeGridPainter extends CustomPainter {
  final MazeGrid grid;
  final ViewLayerMode layerMode;
  final GridPosition? selectedPosition;

  const MazeGridPainter({
    required this.grid,
    required this.layerMode,
    required this.selectedPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dimension = math.min(size.width, size.height);
    final cellSize = dimension / grid.size;
    final palette = grid.config.palette;

    final wallPaint = Paint()..color = Color(palette.wallColorArgb);
    final barrierPaint = Paint()..color = Color(palette.barrierColorArgb);
    final passagePaint = Paint()..color = Color(palette.passageColorArgb);
    final arenaFloorPaint = Paint()..color = MazeLayerColors.arenaBlueFloor;
    final arenaWallPaint = Paint()..color = const Color(0xFF1A3E7A);
    final pedestalPaint = Paint()..color = const Color(0xFF1E4E8C);
    final redstonePaint = Paint()
      ..color = MazeLayerColors.redstoneWireRed.withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;

    // 1. Отрисовка базовых клеток (стены, проходы, барьеры колец, центральная арена).
    for (var z = 0; z < grid.size; z++) {
      for (var x = 0; x < grid.size; x++) {
        final cell = grid.cellAt(x, z);
        final rect = Rect.fromLTWH(
          x * cellSize,
          z * cellSize,
          cellSize + 0.35,
          cellSize + 0.35,
        );

        if (layerMode == ViewLayerMode.tierZonesOverlay &&
            !cell.surfaceType.isSolidWall) {
          canvas.drawRect(rect, _tierZoneOverlayPaint(cell.ringTier));
        } else {
          final basePaint = switch (cell.surfaceType) {
            CellSurfaceType.wall => wallPaint,
            CellSurfaceType.ringBarrierWall => barrierPaint,
            CellSurfaceType.passage => passagePaint,
            CellSurfaceType.arenaFloor => arenaFloorPaint,
            CellSurfaceType.arenaWall => arenaWallPaint,
            CellSurfaceType.pedestal => pedestalPaint,
            CellSurfaceType.spawnShaft => passagePaint,
          };
          canvas.drawRect(rect, basePaint);
        }

        // Отображение подпольной редстоун-разводки (Y=0).
        if (cell.hasSubfloorRedstone &&
            (layerMode == ViewLayerMode.redstoneSubfloor ||
                layerMode == ViewLayerMode.compositeTopDown)) {
          final dotRadius = layerMode == ViewLayerMode.redstoneSubfloor
              ? cellSize * 0.28
              : cellSize * 0.14;
          canvas.drawCircle(rect.center, dotRadius, redstonePaint);
        }

        // 2. Отрисовка маркеров точек интереса (POI) поверх базового слоя.
        _paintPoiMarker(canvas, rect, cell, cellSize);
      }
    }

    // 3. Отрисовка тонкой координатной сетки.
    if (cellSize >= 7.0) {
      final gridLinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..strokeWidth = 0.5;
      for (var i = 0; i <= grid.size; i++) {
        final offset = i * cellSize;
        canvas.drawLine(
          Offset(offset, 0),
          Offset(offset, dimension),
          gridLinePaint,
        );
        canvas.drawLine(
          Offset(0, offset),
          Offset(dimension, offset),
          gridLinePaint,
        );
      }
    }

    // 4. В режиме концентрических зон рисуем векторы углового смещения межкольевых ворот.
    if (layerMode == ViewLayerMode.tierZonesOverlay) {
      _paintAngularTransitionVectors(canvas, cellSize);
    }

    // 5. Подсветка выбранной пользователем клетки.
    final sel = selectedPosition;
    if (sel != null && grid.isInBounds(sel.x, sel.z)) {
      final selRect = Rect.fromLTWH(
        sel.x * cellSize,
        sel.z * cellSize,
        cellSize,
        cellSize,
      );
      final selPaint = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(selRect.deflate(0.5), selPaint);
    }
  }

  Paint _tierZoneOverlayPaint(RingTier tier) {
    final color = switch (tier) {
      RingTier.tier1 => const Color(0xFF1F3327),
      RingTier.tier2 => const Color(0xFF36291A),
      RingTier.tier3 => const Color(0xFF3A1C28),
      RingTier.centralArena => MazeLayerColors.arenaBlueFloor,
    };
    return Paint()..color = color;
  }

  void _paintPoiMarker(
    Canvas canvas,
    Rect rect,
    MazeCell cell,
    double cellSize,
  ) {
    final poi = cell.poi;
    switch (poi) {
      case NoPoi():
        return;

      case CornerSpawnPoi():
        final fill = Paint()..color = MazeLayerColors.spawnGreen;
        final stroke = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        final inset = rect.deflate(cellSize * 0.12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(inset, Radius.circular(cellSize * 0.2)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(inset, Radius.circular(cellSize * 0.2)),
          stroke,
        );

      case LootChestPoi(:final lootTier, :final isTrappedChest):
        final chestColor = switch (lootTier) {
          RingTier.tier1 => MazeLayerColors.chestTier1Yellow,
          RingTier.tier2 => MazeLayerColors.chestTier2Orange,
          RingTier.tier3 || RingTier.centralArena => MazeLayerColors.chestTier3Red,
        };
        final inset = rect.deflate(cellSize * 0.16);
        canvas.drawRect(inset, Paint()..color = chestColor);

        // Если это сундук-ловушка, добавляем фиолетовую рамку ловушки.
        if (isTrappedChest) {
          canvas.drawRect(
            inset,
            Paint()
              ..color = MazeLayerColors.trapPurple
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, cellSize * 0.14),
          );
        }

      case TrapMechanismPoi():
        final center = rect.center;
        final radius = cellSize * 0.34;
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = MazeLayerColors.trapPurple,
        );

      case MobSpawnerPoi():
        final path = Path()
          ..moveTo(rect.center.dx, rect.top + cellSize * 0.12)
          ..lineTo(rect.right - cellSize * 0.12, rect.center.dy)
          ..lineTo(rect.center.dx, rect.bottom - cellSize * 0.12)
          ..lineTo(rect.left + cellSize * 0.12, rect.center.dy)
          ..close();
        canvas.drawPath(path, Paint()..color = MazeLayerColors.trapPurple);
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.redAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1,
        );

      case RingGatePoi():
        final inset = rect.deflate(cellSize * 0.2);
        canvas.drawOval(
          inset,
          Paint()..color = MazeLayerColors.ringGateCyan,
        );

      case ArenaEntryPoi():
        final inset = rect.deflate(cellSize * 0.14);
        canvas.drawRect(
          inset,
          Paint()..color = MazeLayerColors.arenaBlueBorder,
        );
        canvas.drawRect(
          inset,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );

      case ArenaPedestalPoi():
        final inset = rect.deflate(cellSize * 0.08);
        canvas.drawRect(
          inset,
          Paint()..color = MazeLayerColors.pedestalCyan,
        );
        canvas.drawCircle(
          rect.center,
          cellSize * 0.25,
          Paint()..color = MazeLayerColors.chestTier3Red,
        );
    }
  }

  void _paintAngularTransitionVectors(Canvas canvas, double cellSize) {
    final centerOffset = Offset(
      (grid.center.x + 0.5) * cellSize,
      (grid.center.z + 0.5) * cellSize,
    );
    final vectorPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.75)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    for (final gate in grid.gateTransitions) {
      final gateOffset = Offset(
        (gate.gatePosition.x + 0.5) * cellSize,
        (gate.gatePosition.z + 0.5) * cellSize,
      );
      canvas.drawLine(centerOffset, gateOffset, vectorPaint);
      canvas.drawCircle(
        gateOffset,
        cellSize * 0.42,
        Paint()
          ..color = Colors.cyanAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MazeGridPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.layerMode != layerMode ||
        oldDelegate.selectedPosition != selectedPosition;
  }
}

