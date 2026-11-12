import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/entities/maze_cell.dart';
import '../../domain/entities/maze_enums.dart';
import '../controllers/maze_architect_controller.dart';
import '../services/texture_service.dart';
import 'maze_grid_painter.dart';
import 'y_layer_selector_bar.dart';

/// Интерактивная панель предпросмотра схемы лабиринта (2 слоя: Пол и Стены/Сундуки/Загадки).
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
                              showBlockCodes: controller.showBlockCodes,
                              selectedPosition: controller.selectedPosition,
                              hoveredPosition: controller.hoveredPosition,
                              textureService: TextureService.instance,
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
        TwoLayerLegendBar(controller: controller),
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

/// Наглядная легенда объектов схемы для 2 слоев.
class TwoLayerLegendBar extends StatelessWidget {
  final MazeArchitectController controller;

  const TwoLayerLegendBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isWallsLayer = controller.viewLayerMode == ViewLayerMode.wallsAndObjects;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF121722),
        border: Border(
          top: BorderSide(color: Color(0xFF252D3D)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: isWallsLayer
              ? const <Widget>[
                  LegendItemBadge(
                    iconColor: Color(0xFF757575),
                    title: 'Камень',
                    subtitle: 'Стены лабиринта',
                  ),
                  SizedBox(width: 14),
                  LegendItemBadge(
                    iconColor: Color(0xFF8B5322),
                    title: 'Сундуки с лутом',
                    subtitle: 'Т1, Т2, Т3 в тупиках',
                  ),
                  SizedBox(width: 14),
                  LegendItemBadge(
                    iconColor: Color(0xFF00E5FF),
                    title: 'Запертая дверь [A/B]',
                    subtitle: 'Головоломка перешейка',
                  ),
                  SizedBox(width: 14),
                  LegendItemBadge(
                    iconColor: Color(0xFFFFD600),
                    title: 'Секретный рычаг [A/B]',
                    subtitle: 'Открывает дверь',
                  ),
                  SizedBox(width: 14),
                  LegendItemBadge(
                    iconColor: Color(0xFF00E676),
                    title: 'Спавны (S1..S4)',
                    subtitle: 'Угловые шахты сброса',
                  ),
                  SizedBox(width: 14),
                  LegendItemBadge(
                    iconColor: Color(0xFFD500F9),
                    title: 'Ловушки / Спавнеры',
                    subtitle: 'Плиты, стрелы, мобы',
                  ),
                ]
              : const <Widget>[
                  LegendItemBadge(
                    iconColor: Color(0xFF2E3D30),
                    title: 'Внешнее кольцо',
                    subtitle: 'Зона Тир 1',
                  ),
                  SizedBox(width: 14),
                  LegendItemBadge(
                    iconColor: Color(0xFF3F3528),
                    title: 'Среднее кольцо',
                    subtitle: 'Зона Тир 2 (ловушки)',
                  ),
                  SizedBox(width: 14),
                  LegendItemBadge(
                    iconColor: Color(0xFF452232),
                    title: 'Внутреннее кольцо',
                    subtitle: 'Зона Тир 3 (мобы)',
                  ),
                  SizedBox(width: 14),
                  LegendItemBadge(
                    iconColor: Color(0xFF102A56),
                    title: 'Центральная арена',
                    subtitle: 'Финальная PvP-зона',
                  ),
                  SizedBox(width: 14),
                  LegendItemBadge(
                    iconColor: Color(0xFFFF3D00),
                    title: 'Redstone линия',
                    subtitle: 'Подпольная проводка',
                  ),
                ],
        ),
      ),
    );
  }
}

class LegendItemBadge extends StatelessWidget {
  final Color iconColor;
  final String title;
  final String subtitle;

  const LegendItemBadge({
    super.key,
    required this.iconColor,
    required this.title,
    required this.subtitle,
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
            color: iconColor,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.white54, width: 0.8),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF8B99B5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
