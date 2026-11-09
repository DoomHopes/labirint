import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/maze_enums.dart';
import '../../domain/entities/maze_grid.dart';
import '../../domain/entities/voxel_volume.dart';
import '../controllers/maze_architect_controller.dart';

/// Правая информационная панель: телеметрия смещения колец, инспектор клетки и экспорт `.schem` / `.mcfunction`.
class TelemetryAndExportPanel extends StatelessWidget {
  final MazeArchitectController controller;

  const TelemetryAndExportPanel({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final grid = controller.grid;
    final volume = controller.volume;
    if (grid == null || volume == null) {
      return const SizedBox(width: 360);
    }

    return Container(
      width: 370,
      decoration: const BoxDecoration(
        color: Color(0xFF121722),
        border: Border(
          left: BorderSide(color: Color(0xFF252D3D)),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: <Widget>[
          MazeStatisticsSummaryCard(grid: grid, volume: volume),
          const SizedBox(height: 12),
          AngularOffsetTelemetryCard(grid: grid),
          const SizedBox(height: 12),
          SelectedCellVoxelInspectorCard(controller: controller),
          const SizedBox(height: 12),
          SchematicExportInspectorCard(controller: controller),
          const SizedBox(height: 12),
          CommandScriptInspectorCard(controller: controller),
        ],
      ),
    );
  }
}

/// Карточка общей статистики сгенерированного лабиринта и 3D-объема.
class MazeStatisticsSummaryCard extends StatelessWidget {
  final MazeGrid grid;
  final VoxelVolume volume;

  const MazeStatisticsSummaryCard({
    super.key,
    required this.grid,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171E2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF28344A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Сводка генерации и POI',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              StatMetricTile(
                label: 'Спавны (Углы)',
                value: '${grid.spawnCount}',
                accentColor: const Color(0xFF00E676),
              ),
              StatMetricTile(
                label: 'Тупики (Dead-ends)',
                value: '${grid.deadEndCount}',
                accentColor: const Color(0xFF00E5FF),
              ),
              StatMetricTile(
                label: 'Сундуки Т1 / Т2 / Т3',
                value:
                    '${grid.countChestsByTier(RingTier.tier1)} / '
                    '${grid.countChestsByTier(RingTier.tier2)} / '
                    '${grid.countChestsByTier(RingTier.tier3)}',
                accentColor: const Color(0xFFFFEA00),
              ),
              StatMetricTile(
                label: 'Ловушки и Спавнеры',
                value: '${grid.totalTrapAndSpawnerCount}',
                accentColor: const Color(0xFFD500F9),
              ),
              StatMetricTile(
                label: 'Воксельный объем',
                value: '${volume.width}×${volume.height}×${volume.length}',
                accentColor: const Color(0xFF2979FF),
              ),
              StatMetricTile(
                label: 'TileEntities в NBT',
                value: '${volume.blockEntities.length}',
                accentColor: const Color(0xFFFF9100),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Компактная плитка метрики.
class StatMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;

  const StatMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 158,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF101520),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF8B99B5)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Телеметрия углового смещения концентрических переходов ($\Delta\theta \in [90^\circ, 180^\circ]$).
class AngularOffsetTelemetryCard extends StatelessWidget {
  final MazeGrid grid;

  const AngularOffsetTelemetryCard({
    super.key,
    required this.grid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171E2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF28344A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.radar_rounded, size: 16, color: Color(0xFF18FFFF)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Математика смещения колец (Δθ ∈ [90°, 180°])',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Прямой проход к центру исключен: каждые следующие межкольевые ворота смещены по азимуту на 90°–180°.',
            style: TextStyle(fontSize: 11, color: Color(0xFF9AA8C4)),
          ),
          const SizedBox(height: 8),
          for (final gate in grid.gateTransitions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF111622),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '${gate.fromTier.shortLabel} → ${gate.toTier.shortLabel} '
                      '${gate.gatePosition}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'θ=${gate.angleDegrees.toStringAsFixed(0)}° '
                      '(Δθ=${gate.angularOffsetFromPrevious.toStringAsFixed(0)}°)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        color: Color(0xFF18FFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Инспектор выбранной клетки и её вертикального среза в 3D-воксельном объеме.
class SelectedCellVoxelInspectorCard extends StatelessWidget {
  final MazeArchitectController controller;

  const SelectedCellVoxelInspectorCard({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final cell = controller.selectedCell;
    final grid = controller.grid;
    final volume = controller.volume;
    if (cell == null || grid == null || volume == null) {
      return const SizedBox.shrink();
    }

    final pos = cell.position;
    final chebyshevR = pos.chebyshevDistanceTo(grid.center);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171E2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF28344A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Инспектор клетки X=${pos.x}, Z=${pos.z} (L∞ r=$chebyshevR)',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Зона: ${cell.ringTier.title}\n'
            'Поверхность: ${cell.surfaceType.name} | Тупик: ${cell.isDeadEnd ? "Да" : "Нет"}\n'
            'POI: ${cell.poi.summaryRu}',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFFB8C4DC)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Послойный воксельный срез (Y=0..4):',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8B99B5),
            ),
          ),
          const SizedBox(height: 4),
          for (var y = 0; y <= 4 && y < volume.height; y++)
            Text(
              'Y=$y: ${volume.blockStateAt(pos.x, y, pos.z)}',
              style: const TextStyle(
                fontSize: 10.5,
                fontFamily: 'monospace',
                color: Color(0xFF00E676),
              ),
            ),
        ],
      ),
    );
  }
}

/// Карточка инспекции и сохранения бинарного файла Sponge Schematic (`.schem`).
class SchematicExportInspectorCard extends StatelessWidget {
  final MazeArchitectController controller;

  const SchematicExportInspectorCard({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final artifact = controller.lastSchematicArtifact;
    if (artifact == null) {
      return const SizedBox.shrink();
    }

    final previewBytes = artifact.gzippedNbtBytes.take(24).map((b) {
      return b.toRadixString(16).padLeft(2, '0').toUpperCase();
    }).join(' ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171E2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF28344A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '1. Экспорт Sponge Schematic (.schem v2/v3)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Файл: ${artifact.fileName}\n'
            'Размер NBT: ${(artifact.uncompressedSizeBytes / 1024).toStringAsFixed(1)} КБ → '
            'GZip: ${(artifact.compressedSizeBytes / 1024).toStringAsFixed(1)} КБ\n'
            'Совместимость: WorldEdit, FAWE, Axiom, Litematica',
            style: const TextStyle(fontSize: 11, color: Color(0xFFB8C4DC)),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1119),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'GZip Header (Hex): $previewBytes ...',
              style: const TextStyle(
                fontSize: 10.5,
                fontFamily: 'monospace',
                color: Color(0xFFFFEA00),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: controller.saveSchematicToDisk,
              icon: const Icon(Icons.save_alt_rounded, size: 16),
              label: const Text('Сохранить .schem в каталог exports/'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка инспекции и копирования командного скрипта `.mcfunction` и `SignalBlock`.
class CommandScriptInspectorCard extends StatelessWidget {
  final MazeArchitectController controller;

  const CommandScriptInspectorCard({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final artifact = controller.lastCommandArtifact;
    if (artifact == null) {
      return const SizedBox.shrink();
    }

    final previewLines =
        artifact.mcFunctionContent.split('\n').take(14).join('\n');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171E2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF28344A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '2. Командный скрипт (.mcfunction) & SignalBlock',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Всего команд: ${artifact.commandCount} (/fill RLE + /setblock + Redstone старт)',
            style: const TextStyle(fontSize: 11, color: Color(0xFFB8C4DC)),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1119),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              previewLines,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: Color(0xFF80CBC4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: artifact.mcFunctionContent),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Скрипт .mcfunction скопирован в буфер обмена!',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Копировать'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: controller.saveCommandScriptToDisk,
                  icon: const Icon(Icons.save_outlined, size: 15),
                  label: const Text('В файл'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
