import 'package:flutter/material.dart';

import '../controllers/maze_architect_controller.dart';
import '../widgets/maze_canvas_panel.dart';
import '../widgets/settings_sidebar.dart';
import '../widgets/telemetry_and_export_panel.dart';
import '../widgets/toolbar_header.dart';

/// Главный экран приложения для процедурной генерации и экспорта PvP-лабиринтов Minecraft.
class MazeArchitectScreen extends StatelessWidget {
  final MazeArchitectController controller;

  const MazeArchitectScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0D1119),
          body: Column(
            children: <Widget>[
              ToolbarHeader(controller: controller),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SettingsSidebar(controller: controller),
                    Expanded(
                      child: MazeCanvasPanel(controller: controller),
                    ),
                    TelemetryAndExportPanel(controller: controller),
                  ],
                ),
              ),
              StatusFooterBar(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

/// Нижняя строка состояния с обратной связью по генерации и путям сохраненных файлов.
class StatusFooterBar extends StatelessWidget {
  final MazeArchitectController controller;

  const StatusFooterBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final msg = controller.statusMessage ?? 'Готово к работе';
    final isErr = controller.isStatusError;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isErr ? const Color(0xFF3B1219) : const Color(0xFF0F141E),
        border: const Border(
          top: BorderSide(color: Color(0xFF252D3D)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isErr ? Icons.error_outline : Icons.check_circle_outline,
            size: 15,
            color: isErr ? Colors.redAccent : const Color(0xFF00E676),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFFD0D8E8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Сид: ${controller.config.seed}',
            style: const TextStyle(
              fontSize: 11.5,
              fontFamily: 'monospace',
              color: Color(0xFF00E5FF),
            ),
          ),
        ],
      ),
    );
  }
}

