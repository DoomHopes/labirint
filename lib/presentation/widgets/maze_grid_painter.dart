import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/entities/maze_cell.dart';
import '../../domain/entities/maze_enums.dart';
import '../../domain/entities/maze_grid.dart';
import '../../domain/entities/poi_marker.dart';
import '../../domain/entities/voxel_block_visual.dart';
import '../../domain/entities/voxel_volume.dart';

/// Цветовые константы слоев согласно техническому заданию (плоские контрастные цвета без теней).
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

/// Четкий инженерный `CustomPainter` для послойной по-блочной отрисовки схемы без теней.
final class MazeGridPainter extends CustomPainter {
  /// Отступ под координатные линейки X (сверху) и Z (слева).
  static const double rulerMargin = 22.0;

  final MazeGrid grid;
  final VoxelVolume volume;
  final ViewLayerMode layerMode;
  final int activeYLayer;
  final bool showBlockCodes;
  final bool showAirUnderlay;
  final GridPosition? selectedPosition;
  final GridPosition? hoveredPosition;

  const MazeGridPainter({
    required this.grid,
    required this.volume,
    required this.layerMode,
    required this.activeYLayer,
    required this.showBlockCodes,
    required this.showAirUnderlay,
    required this.selectedPosition,
    required this.hoveredPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullSide = math.min(size.width, size.height);
    final gridAreaSide = math.max(10.0, fullSide - rulerMargin);
    final cellSize = gridAreaSide / grid.size;

    // 1. Отрисовка координатных линеек X (0..N-1) и Z (0..N-1).
    _paintCoordinateRulers(canvas, fullSide, cellSize);

    // Смещаем область рисования клеток на ширину линеек.
    canvas.save();
    canvas.translate(rulerMargin, rulerMargin);

    if (layerMode == ViewLayerMode.voxelSliceByY) {
      _paintExactVoxelLayerSlice(canvas, cellSize);
    } else {
      _paintCompositeOrZoneOverview(canvas, cellSize);
    }

    // Отрисовка четкой координатной сетки между блоками.
    final gridLinePaint = Paint()
      ..color = const Color(0xFF243044)
      ..strokeWidth = 0.75;
    final totalGridPx = cellSize * grid.size;
    for (var i = 0; i <= grid.size; i++) {
      final offset = i * cellSize;
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset, totalGridPx),
        gridLinePaint,
      );
      canvas.drawLine(
        Offset(0, offset),
        Offset(totalGridPx, offset),
        gridLinePaint,
      );
    }

    // В режиме концентрических зон рисуем векторы углового смещения межкольевых ворот.
    if (layerMode == ViewLayerMode.tierZonesOverlay) {
      _paintAngularTransitionVectors(canvas, cellSize);
    }

    // Подсветка клетки под курсором мыши.
    final hov = hoveredPosition;
    if (hov != null && grid.isInBounds(hov.x, hov.z)) {
      final hovRect = Rect.fromLTWH(
        hov.x * cellSize,
        hov.z * cellSize,
        cellSize,
        cellSize,
      );
      canvas.drawRect(
        hovRect.deflate(0.5),
        Paint()
          ..color = Colors.yellowAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // Подсветка выбранной кликом клетки.
    final sel = selectedPosition;
    if (sel != null && grid.isInBounds(sel.x, sel.z)) {
      final selRect = Rect.fromLTWH(
        sel.x * cellSize,
        sel.z * cellSize,
        cellSize,
        cellSize,
      );
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

  /// Отрисовывает координатные линейки X (сверху) и Z (слева).
  void _paintCoordinateRulers(Canvas canvas, double fullSide, double cellSize) {
    final rulerBg = Paint()..color = const Color(0xFF141B29);
    canvas.drawRect(Rect.fromLTWH(0, 0, fullSide, rulerMargin), rulerBg);
    canvas.drawRect(Rect.fromLTWH(0, 0, rulerMargin, fullSide), rulerBg);

    // Угловая ячейка X\Z
    _drawCenteredText(
      canvas: canvas,
      text: 'X\\Z',
      rect: const Rect.fromLTWH(0, 0, rulerMargin, rulerMargin),
      color: const Color(0xFF00E5FF),
      fontSize: 8.5,
      fontWeight: FontWeight.bold,
    );

    final step = cellSize < 12.0 ? 2 : 1;
    for (var i = 0; i < grid.size; i += step) {
      final coordLabel = '$i';
      // Верхняя шкала X
      final xRect = Rect.fromLTWH(
        rulerMargin + i * cellSize,
        0,
        cellSize * step,
        rulerMargin,
      );
      _drawCenteredText(
        canvas: canvas,
        text: coordLabel,
        rect: xRect,
        color: const Color(0xFF9AA8C4),
        fontSize: 8.5,
      );

      // Левая шкала Z
      final zRect = Rect.fromLTWH(
        0,
        rulerMargin + i * cellSize,
        rulerMargin,
        cellSize * step,
      );
      _drawCenteredText(
        canvas: canvas,
        text: coordLabel,
        rect: zRect,
        color: const Color(0xFF9AA8C4),
        fontSize: 8.5,
      );
    }
  }

  /// По-блочная отрисовка выбранного высотного среза `activeYLayer` из 3D-объема `VoxelVolume`.
  void _paintExactVoxelLayerSlice(Canvas canvas, double cellSize) {
    final y = activeYLayer.clamp(0, volume.height - 1);
    final specCache = <String, VoxelBlockVisualSpec>{};

    VoxelBlockVisualSpec resolveSpec(String state) {
      return specCache.putIfAbsent(state, () => VoxelBlockClassifier.classify(state));
    }

    for (var z = 0; z < grid.size; z++) {
      for (var x = 0; x < grid.size; x++) {
        final rect = Rect.fromLTWH(
          x * cellSize,
          z * cellSize,
          cellSize,
          cellSize,
        );
        final state = volume.blockStateAt(x, y, z);
        final spec = resolveSpec(state);

        if (spec.isAir) {
          // Клетка воздуха на текущем слое Y.
          final cell = grid.cellAt(x, z);
          if (showAirUnderlay && y >= 2) {
            // Контурная подложка пола, чтобы пользователь видел, где коридор и арена.
            final underlayColor = switch (cell.ringTier) {
              RingTier.tier1 => const Color(0xFF101920),
              RingTier.tier2 => const Color(0xFF161824),
              RingTier.tier3 => const Color(0xFF1B1522),
              RingTier.centralArena => const Color(0xFF0D1F3C),
            };
            canvas.drawRect(rect, Paint()..color = underlayColor);

            // Если под этим проходом на Y=0 лежит редстоун, показываем маленькую красную точку-маркер.
            if (cell.hasSubfloorRedstone) {
              canvas.drawCircle(
                rect.center,
                math.max(1.5, cellSize * 0.11),
                Paint()..color = const Color(0xFF8E1B1B),
              );
            }
          } else {
            canvas.drawRect(rect, Paint()..color = Color(spec.fillArgb));
          }
          continue;
        }

        // Реальный блок на слое Y: плоская заливка без теней + четкая внутренняя рамка.
        canvas.drawRect(rect, Paint()..color = Color(spec.fillArgb));
        canvas.drawRect(
          rect.deflate(0.8),
          Paint()
            ..color = Color(spec.borderArgb)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );

        // Короткий код блока и символ ориентации внутри клетки (СТН, ОБС, СН▼, РЗ►, ПЛТ, РЕД, СПВ).
        if (showBlockCodes && cellSize >= 9.0) {
          final isSpecialBlock = spec.shortCode != 'СТН' &&
              spec.shortCode != 'ФНД' &&
              spec.shortCode != 'ПОЛ';
          if (cellSize >= 13.5 || isSpecialBlock) {
            final label = cellSize >= 15.0 ? spec.badgeLabel : spec.shortCode;
            final fontSize = (cellSize * 0.34).clamp(6.5, 11.0);
            _drawCenteredText(
              canvas: canvas,
              text: label,
              rect: rect,
              color: Color(spec.textArgb),
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            );
          }
        }
      }
    }
  }

  /// Отрисовка сводного вида сверху или цветовых концентрических зон (без теней).
  void _paintCompositeOrZoneOverview(Canvas canvas, double cellSize) {
    final palette = grid.config.palette;
    final wallPaint = Paint()..color = Color(palette.wallColorArgb);
    final barrierPaint = Paint()..color = Color(palette.barrierColorArgb);
    final passagePaint = Paint()..color = Color(palette.passageColorArgb);
    final arenaFloorPaint = Paint()..color = MazeLayerColors.arenaBlueFloor;
    final arenaWallPaint = Paint()..color = const Color(0xFF1A3E7A);
    final pedestalPaint = Paint()..color = const Color(0xFF1E4E8C);
    final redstonePaint = Paint()..color = MazeLayerColors.redstoneWireRed;

    for (var z = 0; z < grid.size; z++) {
      for (var x = 0; x < grid.size; x++) {
        final cell = grid.cellAt(x, z);
        final rect = Rect.fromLTWH(
          x * cellSize,
          z * cellSize,
          cellSize,
          cellSize,
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

        if (cell.hasSubfloorRedstone &&
            (layerMode == ViewLayerMode.redstoneSubfloor ||
                layerMode == ViewLayerMode.compositeTopDown)) {
          final side = layerMode == ViewLayerMode.redstoneSubfloor
              ? cellSize * 0.55
              : cellSize * 0.28;
          canvas.drawRect(
            Rect.fromCenter(center: rect.center, width: side, height: side),
            redstonePaint,
          );
        }

        _paintPoiMarkerWithLabel(canvas, rect, cell, cellSize);
      }
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

  void _paintPoiMarkerWithLabel(
    Canvas canvas,
    Rect rect,
    MazeCell cell,
    double cellSize,
  ) {
    final poi = cell.poi;
    switch (poi) {
      case NoPoi():
        return;

      case CornerSpawnPoi(:final spawnIndex):
        final inset = rect.deflate(cellSize * 0.08);
        canvas.drawRect(inset, Paint()..color = MazeLayerColors.spawnGreen);
        _drawCenteredText(
          canvas: canvas,
          text: 'S$spawnIndex',
          rect: inset,
          color: Colors.black,
          fontSize: (cellSize * 0.42).clamp(7.0, 11.0),
          fontWeight: FontWeight.w900,
        );

      case LootChestPoi(:final lootTier, :final isTrappedChest):
        final chestColor = switch (lootTier) {
          RingTier.tier1 => MazeLayerColors.chestTier1Yellow,
          RingTier.tier2 => MazeLayerColors.chestTier2Orange,
          RingTier.tier3 || RingTier.centralArena => MazeLayerColors.chestTier3Red,
        };
        final inset = rect.deflate(cellSize * 0.1);
        canvas.drawRect(inset, Paint()..color = chestColor);
        if (isTrappedChest) {
          canvas.drawRect(
            inset,
            Paint()
              ..color = MazeLayerColors.trapPurple
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8,
          );
        }
        _drawCenteredText(
          canvas: canvas,
          text: 'T${lootTier.tierNumber}',
          rect: inset,
          color: Colors.black,
          fontSize: (cellSize * 0.40).clamp(6.5, 10.5),
          fontWeight: FontWeight.w900,
        );

      case TrapMechanismPoi():
        final inset = rect.deflate(cellSize * 0.1);
        canvas.drawRect(inset, Paint()..color = MazeLayerColors.trapPurple);
        _drawCenteredText(
          canvas: canvas,
          text: 'ПЛ',
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
        final inset = rect.deflate(cellSize * 0.12);
        canvas.drawRect(inset, Paint()..color = MazeLayerColors.ringGateCyan);
        _drawCenteredText(
          canvas: canvas,
          text: 'ВР',
          rect: inset,
          color: Colors.black,
          fontSize: (cellSize * 0.36).clamp(6.5, 10.0),
          fontWeight: FontWeight.w800,
        );

      case ArenaEntryPoi():
        final inset = rect.deflate(cellSize * 0.1);
        canvas.drawRect(
          inset,
          Paint()..color = MazeLayerColors.arenaBlueBorder,
        );
        _drawCenteredText(
          canvas: canvas,
          text: 'ВХ',
          rect: inset,
          color: Colors.white,
          fontSize: (cellSize * 0.36).clamp(6.5, 10.0),
          fontWeight: FontWeight.w800,
        );

      case ArenaPedestalPoi():
        final inset = rect.deflate(cellSize * 0.08);
        canvas.drawRect(inset, Paint()..color = MazeLayerColors.pedestalCyan);
        _drawCenteredText(
          canvas: canvas,
          text: 'ПРЗ',
          rect: inset,
          color: Colors.black,
          fontSize: (cellSize * 0.34).clamp(6.5, 10.0),
          fontWeight: FontWeight.w900,
        );
    }
  }

  void _paintAngularTransitionVectors(Canvas canvas, double cellSize) {
    final centerOffset = Offset(
      (grid.center.x + 0.5) * cellSize,
      (grid.center.z + 0.5) * cellSize,
    );
    final vectorPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    for (final gate in grid.gateTransitions) {
      final gateOffset = Offset(
        (gate.gatePosition.x + 0.5) * cellSize,
        (gate.gatePosition.z + 0.5) * cellSize,
      );
      canvas.drawLine(centerOffset, gateOffset, vectorPaint);
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
        oldDelegate.activeYLayer != activeYLayer ||
        oldDelegate.showBlockCodes != showBlockCodes ||
        oldDelegate.showAirUnderlay != showAirUnderlay ||
        oldDelegate.selectedPosition != selectedPosition ||
        oldDelegate.hoveredPosition != hoveredPosition;
  }
}
