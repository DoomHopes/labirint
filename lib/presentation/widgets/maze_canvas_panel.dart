import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/entities/maze_cell.dart';
import '../../domain/entities/voxel_block_visual.dart';
import '../controllers/maze_architect_controller.dart';
import 'maze_grid_painter.dart';
import 'y_layer_selector_bar.dart';

/// Интерактивная панель предпросмотра 2D-схемы по слоям Y с линейками координат,
/// зумом (`InteractiveViewer`) и ведомостью блоков активного слоя.
class MazeCanvasPanel extends StatelessWidget {
  final MazeArchitectController controller;

  const MazeCanvasPanel({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final grid = controller.grid;
    final volume = controller.volume;
    if (grid == null || volume == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: <Widget>[
        YLayerSelectorBar(controller: controller),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return Center(
                  child: Container(
                    width: boardSize,
                    height: boardSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E131D),
                      border: Border.all(
                        color: const Color(0xFF2B3548),
                        width: 1.5,
                      ),
                    ),
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: MouseRegion(
                        onHover: (event) => _handleHover(
                          event.localPosition,
                          boardSize,
                          grid.size,
                        ),
                        onExit: (_) => controller.updateHoveredCell(null),
                        child: GestureDetector(
                          onTapDown: (details) => _handlePointer(
                            details.localPosition,
                            boardSize,
                            grid.size,
                          ),
                          onPanUpdate: (details) => _handlePointer(
                            details.localPosition,
                            boardSize,
                            grid.size,
                          ),
                          child: CustomPaint(
                            size: Size.square(boardSize),
                            painter: MazeGridPainter(
                              grid: grid,
                              volume: volume,
                              layerMode: controller.viewLayerMode,
                              activeYLayer: controller.activeYLayer,
                              showBlockCodes: controller.showBlockCodes,
                              showAirUnderlay: controller.showAirUnderlay,
                              selectedPosition: controller.selectedPosition,
                              hoveredPosition: controller.hoveredPosition,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ActiveLayerBlockLegendBar(controller: controller),
      ],
    );
  }

  GridPosition? _resolveGridPosition(
    Offset localPosition,
    double boardSize,
    int gridSize,
  ) {
    const margin = MazeGridPainter.rulerMargin;
    final gridAreaSide = math.max(10.0, boardSize - margin);
    final cellSize = gridAreaSide / gridSize;
    final x = ((localPosition.dx - margin) / cellSize).floor();
    final z = ((localPosition.dy - margin) / cellSize).floor();
    if (x >= 0 && x < gridSize && z >= 0 && z < gridSize) {
      return GridPosition(x, z);
    }
    return null;
  }

  void _handleHover(Offset localPosition, double boardSize, int gridSize) {
    final pos = _resolveGridPosition(localPosition, boardSize, gridSize);
    if (pos != null) {
      controller.updateHoveredCell(pos);
    }
  }

  void _handlePointer(Offset localPosition, double boardSize, int gridSize) {
    final pos = _resolveGridPosition(localPosition, boardSize, gridSize);
    if (pos != null) {
      controller.applyToolAtCell(pos);
    }
  }
}

/// Нижняя ведомость-легенда всех реальных блоков Minecraft, присутствующих на текущем слое `Y`.
class ActiveLayerBlockLegendBar extends StatelessWidget {
  final MazeArchitectController controller;

  const ActiveLayerBlockLegendBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final blockCounts = controller.activeLayerBlockCounts;
    final activeY = controller.activeYLayer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF121722),
        border: Border(
          top: BorderSide(color: Color(0xFF252D3D)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Блоки на активном срезе Y=$activeY (Код на схеме — Назначение — ID блока — Кол-во):',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9AA8C4),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final entry in blockCounts.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: BlockSpecLegendBadge(
                      blockState: entry.key,
                      count: entry.value,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Отдельная карточка блока в нижней ведомости активного слоя.
class BlockSpecLegendBadge extends StatelessWidget {
  final String blockState;
  final int count;

  const BlockSpecLegendBadge({
    super.key,
    required this.blockState,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final spec = VoxelBlockClassifier.classify(blockState);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF171E2C),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2B3548)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Color(spec.fillArgb),
              border: Border.all(color: Color(spec.borderArgb)),
            ),
            child: Text(
              spec.badgeLabel,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                color: Color(spec.textArgb),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${spec.titleRu} ',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
            ),
          ),
          Text(
            '[${spec.baseBlockId}] ×$count',
            style: const TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              color: Color(0xFF00E5FF),
            ),
          ),
        ],
      ),
    );
  }
}
