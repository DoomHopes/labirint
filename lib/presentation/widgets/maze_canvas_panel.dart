import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/entities/maze_cell.dart';
import '../controllers/maze_architect_controller.dart';
import 'maze_grid_painter.dart';

/// Интерактивная панель предпросмотра 2D-карты лабиринта с легендой слоев и ручным редактированием.
class MazeCanvasPanel extends StatelessWidget {
  final MazeArchitectController controller;

  const MazeCanvasPanel({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final grid = controller.grid;
    if (grid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                      color: const Color(0xFF0B0E14),
                      border: Border.all(
                        color: const Color(0xFF2B3548),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
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
                            layerMode: controller.viewLayerMode,
                            selectedPosition: controller.selectedPosition,
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
        const MazeColorLegendBar(),
      ],
    );
  }

  void _handlePointer(Offset localPosition, double boardSize, int gridSize) {
    final cellSize = boardSize / gridSize;
    final x = (localPosition.dx / cellSize).floor();
    final z = (localPosition.dy / cellSize).floor();
    if (x >= 0 && x < gridSize && z >= 0 && z < gridSize) {
      controller.applyToolAtCell(GridPosition(x, z));
    }
  }
}

/// Нижняя полоса цветовой легенды слоев карты согласно ТЗ.
class MazeColorLegendBar extends StatelessWidget {
  const MazeColorLegendBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF121722),
        border: Border(
          top: BorderSide(color: Color(0xFF252D3D)),
        ),
      ),
      child: const Wrap(
        spacing: 16,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: <Widget>[
          LegendColorBadge(
            color: MazeLayerColors.spawnGreen,
            label: 'Спавны (Шахты)',
          ),
          LegendColorBadge(
            color: MazeLayerColors.chestTier1Yellow,
            label: 'Сундук Тир 1',
          ),
          LegendColorBadge(
            color: MazeLayerColors.chestTier2Orange,
            label: 'Сундук Тир 2',
          ),
          LegendColorBadge(
            color: MazeLayerColors.chestTier3Red,
            label: 'Сундук Тир 3',
          ),
          LegendColorBadge(
            color: MazeLayerColors.trapPurple,
            label: 'Ловушки / Спавнеры',
          ),
          LegendColorBadge(
            color: MazeLayerColors.arenaBlueBorder,
            label: 'Центральная арена',
          ),
          LegendColorBadge(
            color: MazeLayerColors.ringGateCyan,
            label: 'Смещенные ворота (90°–180°)',
          ),
          LegendColorBadge(
            color: MazeLayerColors.redstoneWireRed,
            label: 'Подпольный Redstone (Y=0)',
          ),
        ],
      ),
    );
  }
}

/// Отдельный элемент цветовой легенды.
class LegendColorBadge extends StatelessWidget {
  final Color color;
  final String label;

  const LegendColorBadge({
    super.key,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white38, width: 0.8),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFFD0D8E8),
          ),
        ),
      ],
    );
  }
}

