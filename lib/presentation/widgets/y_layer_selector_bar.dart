import 'package:flutter/material.dart';

import '../../domain/entities/maze_enums.dart';
import '../controllers/maze_architect_controller.dart';

/// Интуитивная панель переключения 2 основных слоев схемы:
/// 1. Слой 1: Пол (разметка зон, проходы и тропинки).
/// 2. Слой 2: Стены (камень), Сундуки с лутом и Загадки (Дверь + Рычаг).
class YLayerSelectorBar extends StatelessWidget {
  final MazeArchitectController controller;

  const YLayerSelectorBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final mode = controller.viewLayerMode;
    final isWallsLayer = mode == ViewLayerMode.wallsAndObjects;

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
                  'Выбор слоя схемы:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(width: 10),
                LayerTabButton(
                  title: 'Слой 2: Стены, Сундуки и Загадки',
                  subtitle: 'Камень, сундуки, двери и рычаги',
                  icon: Icons.castle_rounded,
                  isSelected: isWallsLayer,
                  activeColor: const Color(0xFF00E5FF),
                  onTap: () => controller.selectViewLayerMode(ViewLayerMode.wallsAndObjects),
                ),
                const SizedBox(width: 8),
                LayerTabButton(
                  title: 'Слой 1: Пол (Разметка зон)',
                  subtitle: 'Тиры 1–3, дорожки и арена',
                  icon: Icons.layers_outlined,
                  isSelected: !isWallsLayer,
                  activeColor: const Color(0xFF00E676),
                  onTap: () => controller.selectViewLayerMode(ViewLayerMode.floor),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text(
                    'Подписи объектов (Т1, ДВ, РЫЧ)',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: controller.showBlockCodes,
                  onSelected: controller.toggleShowBlockCodes,
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
                  isWallsLayer
                      ? 'Отображаются стены из камня, сундуки в тупиках и головоломки (запертые двери соединены линиями со скрытыми рычагами).'
                      : 'Отображается напольное покрытие зон: Внешнее кольцо (Т1), Среднее (Т2), Внутреннее (Т3) и Центральная арена.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFD0D8E8),
                  ),
                ),
                const SizedBox(width: 14),
                FocusedBlockReadoutBadge(controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Крупная информативная кнопка-вкладка для переключения между 2 слоями.
class LayerTabButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const LayerTabButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B283E) : const Color(0xFF101520),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF2C394E),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : const Color(0xFF8B99B5),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFFB0BEC5),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isSelected ? activeColor : const Color(0xFF60728F),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Индикатор блока под курсором мыши.
class FocusedBlockReadoutBadge extends StatelessWidget {
  final MazeArchitectController controller;

  const FocusedBlockReadoutBadge({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final cell = controller.selectedCell;
    final pos = controller.focusedPosition;
    if (cell == null || pos == null) {
      return const SizedBox.shrink();
    }

    final isWall = cell.surfaceType.isSolidWall;
    final objectName = cell.poi.summaryRu;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1018),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF384866)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '[X=${pos.x}, Z=${pos.z}]',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isWall ? 'Каменная стена' : objectName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '(${cell.ringTier.shortLabel})',
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFFFFEA00),
            ),
          ),
        ],
      ),
    );
  }
}
