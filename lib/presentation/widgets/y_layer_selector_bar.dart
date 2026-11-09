import 'package:flutter/material.dart';

import '../../domain/entities/voxel_block_visual.dart';
import '../controllers/maze_architect_controller.dart';

/// Панель переключения высотных слоев `Y = 0 .. H-1` и строка мгновенной индикации блока под курсором.
class YLayerSelectorBar extends StatelessWidget {
  final MazeArchitectController controller;

  const YLayerSelectorBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final volume = controller.volume;
    final grid = controller.grid;
    if (volume == null || grid == null) {
      return const SizedBox.shrink();
    }

    final activeY = controller.activeYLayer.clamp(0, volume.height - 1);
    final layerInfo = VoxelBlockClassifier.describeYLayer(
      y: activeY,
      wallHeight: grid.config.wallHeight,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF141A26),
        border: Border(
          bottom: BorderSide(color: Color(0xFF28344A)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                const Text(
                  'Высотный срез схемы (Слой Y):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(width: 8),
                for (var y = 0; y < volume.height; y++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: YLayerButtonChip(
                      y: y,
                      wallHeight: grid.config.wallHeight,
                      isSelected: activeY == y,
                      onSelect: () => controller.selectYLayer(y),
                    ),
                  ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text(
                    'Подписи блоков (СТН, РЗ►, СН)',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: controller.showBlockCodes,
                  onSelected: controller.toggleShowBlockCodes,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text(
                    'Контур пола под воздухом',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: controller.showAirUnderlay,
                  onSelected: controller.toggleShowAirUnderlay,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                Text(
                  layerInfo.detailedDescription,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFD0D8E8),
                  ),
                ),
                const SizedBox(width: 12),
                FocusedBlockReadoutBadge(controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка выбора конкретного высотного слоя `Y`.
class YLayerButtonChip extends StatelessWidget {
  final int y;
  final int wallHeight;
  final bool isSelected;
  final VoidCallback onSelect;

  const YLayerButtonChip({
    super.key,
    required this.y,
    required this.wallHeight,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final shortTag = _shortLayerTag(y, wallHeight);

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF1C2434),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : const Color(0xFF33415C),
          ),
        ),
        child: Text(
          'Y=$y ($shortTag)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.black : const Color(0xFFD0D8E8),
          ),
        ),
      ),
    );
  }

  String _shortLayerTag(int y, int wallHeight) {
    final wallTopY = 1 + wallHeight;
    if (y == 0) return 'Redstone/Дно';
    if (y == 1) return 'Пол';
    if (y == 2) return 'Механизмы/Стены';
    if (y == 3) return 'Верх дверей/Приз';
    if (y < wallTopY) return 'Стены';
    if (y == wallTopY) return 'Карниз';
    if (y == wallTopY + 1) return 'Шахты';
    if (y == wallTopY + 2) return 'Поршни';
    return 'Питание';
  }
}

/// Плашка мгновенной индикации блока под курсором мыши: координаты `(X, Y, Z)`, код, название и точный ID.
class FocusedBlockReadoutBadge extends StatelessWidget {
  final MazeArchitectController controller;

  const FocusedBlockReadoutBadge({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final volume = controller.volume;
    final pos = controller.focusedPosition;
    if (volume == null || pos == null) {
      return const SizedBox.shrink();
    }

    final y = controller.activeYLayer.clamp(0, volume.height - 1);
    final state = volume.blockStateAt(pos.x, y, pos.z);
    final spec = VoxelBlockClassifier.classify(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1018),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF384866)),
      ),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            '[X=${pos.x}, Y=$y, Z=${pos.z}]',
            style: const TextStyle(
              fontSize: 11.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Color(0xFF00E5FF),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Color(spec.fillArgb),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Color(spec.borderArgb)),
            ),
            child: Text(
              spec.badgeLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                color: Color(spec.textArgb),
              ),
            ),
          ),
          Text(
            spec.titleRu,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            '($state)',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Color(0xFFFFEA00),
            ),
          ),
        ],
      ),
    );
  }
}
