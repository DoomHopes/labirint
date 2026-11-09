import 'package:flutter/material.dart';

import '../../domain/entities/maze_enums.dart';
import '../controllers/maze_architect_controller.dart';

/// Верхняя инструментальная панель для выбора режима слоя, кисти редактирования сетки и быстрого экспорта.
class ToolbarHeader extends StatelessWidget {
  final MazeArchitectController controller;

  const ToolbarHeader({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF121722),
        border: Border(bottom: BorderSide(color: Color(0xFF252D3D))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.hub_rounded, color: Color(0xFF00E5FF), size: 24),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Minecraft PvP Maze & Redstone Architect',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Радиально-концентрический генератор (.schem v2/v3 & SignalBlock)',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF8B99B5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ViewLayerSelectorBar(controller: controller),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: controller.randomizeSeedAndGenerate,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00B8D4),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.casino_outlined, size: 18),
                    label: const Text('Новый сид'),
                  ),
                  FilledButton.icon(
                    onPressed: controller.saveSchematicToDisk,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Экспорт .schem'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.saveCommandScriptToDisk,
                    icon: const Icon(Icons.terminal_rounded, size: 18),
                    label: const Text('Экспорт .mcfunction'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          EditorToolPaletteRow(controller: controller),
        ],
      ),
    );
  }
}

/// Переключатель режимов отображения слоев карты.
class ViewLayerSelectorBar extends StatelessWidget {
  final MazeArchitectController controller;

  const ViewLayerSelectorBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ViewLayerMode>(
      segments: <ButtonSegment<ViewLayerMode>>[
        for (final mode in ViewLayerMode.values)
          ButtonSegment<ViewLayerMode>(
            value: mode,
            label: Text(mode.title, style: const TextStyle(fontSize: 11.5)),
          ),
      ],
      selected: <ViewLayerMode>{controller.viewLayerMode},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          controller.selectViewLayerMode(selection.first);
        }
      },
    );
  }
}

/// Панель выбора инструмента ручного клика по сетке (стены, проходы, спавны, сундуки, ловушки).
class EditorToolPaletteRow extends StatelessWidget {
  final MazeArchitectController controller;

  const EditorToolPaletteRow({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          const Text(
            'Кисть сетки:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9AA8C4),
            ),
          ),
          const SizedBox(width: 10),
          for (final tool in EditorTool.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: tool.tooltip,
                child: ChoiceChip(
                  label: Text(
                    tool.title,
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  selected: controller.activeTool == tool,
                  onSelected: (_) => controller.selectEditorTool(tool),
                  selectedColor: const Color(0xFF1E3A5F),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
