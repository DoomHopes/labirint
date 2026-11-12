import 'package:flutter/material.dart';

import '../../domain/entities/block_palette.dart';
import '../../domain/entities/maze_enums.dart';
import '../controllers/maze_architect_controller.dart';

/// Левая панель настроек генерации лабиринта, геометрии, алгоритма и палитры блоков Minecraft.
class SettingsSidebar extends StatelessWidget {
  final MazeArchitectController controller;

  const SettingsSidebar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final config = controller.config;

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF121722),
        border: Border(
          right: BorderSide(color: Color(0xFF252D3D)),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: <Widget>[
          const SidebarSectionHeader(
            title: '1. Геометрия и Сетка',
            icon: Icons.grid_4x4_rounded,
          ),
          const SizedBox(height: 8),
          GridSizePresetSelector(
            currentSize: config.gridSize,
            onSelectSize: controller.updateGridSize,
          ),
          const SizedBox(height: 10),
          ArenaSizeSelector(
            currentArenaSize: config.arenaSize,
            gridSize: config.gridSize,
            onSelectArenaSize: controller.updateArenaSize,
          ),
          const SizedBox(height: 10),
          PassageAndWallControls(
            passageWidth: config.passageWidth,
            wallHeight: config.wallHeight,
            ringCount: config.ringCount,
            onPassageWidthChanged: controller.updatePassageWidth,
            onWallHeightChanged: controller.updateWallHeight,
            onRingCountChanged: controller.updateRingCount,
          ),
          const Divider(height: 24, color: Color(0xFF252D3D)),
          const SidebarSectionHeader(
            title: '2. Алгоритм и Арена',
            icon: Icons.account_tree_outlined,
          ),
          const SizedBox(height: 8),
          AlgorithmSelectorCard(
            selectedAlgorithm: config.algorithm,
            onChanged: controller.updateAlgorithm,
          ),
          const SizedBox(height: 10),
          ArenaEntryModeCard(
            selectedMode: config.arenaEntryMode,
            onChanged: controller.updateArenaEntryMode,
          ),
          const Divider(height: 24, color: Color(0xFF252D3D)),
          const SidebarSectionHeader(
            title: '3. Баланс POI и Ловушек',
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: 8),
          DensityAndTrapsSliders(
            deadEndDensity: config.deadEndDensity,
            trapPercentage: config.trapPercentage,
            onDeadEndDensityChanged: controller.updateDeadEndDensity,
            onTrapPercentageChanged: controller.updateTrapPercentage,
          ),
          const Divider(height: 24, color: Color(0xFF252D3D)),
          const SidebarSectionHeader(
            title: '4. Палитра блоков Minecraft',
            icon: Icons.palette_outlined,
          ),
          const SizedBox(height: 8),
          MinecraftPaletteSelector(
            selectedPalette: config.palette,
            onSelectPalette: controller.updatePalette,
          ),
        ],
      ),
    );
  }
}

/// Заголовок секции в боковой панели настроек.
class SidebarSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const SidebarSectionHeader({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 17, color: const Color(0xFF00E5FF)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Селектор размера лабиринта (33×33, 49×49, 60×60, 65×65).
class GridSizePresetSelector extends StatelessWidget {
  final int currentSize;
  final ValueChanged<int> onSelectSize;

  const GridSizePresetSelector({
    super.key,
    required this.currentSize,
    required this.onSelectSize,
  });

  @override
  Widget build(BuildContext context) {
    const presets = <int>[33, 49, 60, 65];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Габариты лабиринта: $currentSize×$currentSize блоков',
          style: const TextStyle(fontSize: 12, color: Color(0xFFB8C4DC)),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            for (final preset in presets)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    label: Text(
                      '$preset×$preset',
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: currentSize == preset,
                    onSelected: (_) => onSelectSize(preset),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Селектор размера центральной арены (15×15 или 21×21 блок).
class ArenaSizeSelector extends StatelessWidget {
  final int currentArenaSize;
  final int gridSize;
  final ValueChanged<int> onSelectArenaSize;

  const ArenaSizeSelector({
    super.key,
    required this.currentArenaSize,
    required this.gridSize,
    required this.onSelectArenaSize,
  });

  @override
  Widget build(BuildContext context) {
    final allow21 = gridSize >= 49;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Центральная арена с пьедесталом:',
          style: TextStyle(fontSize: 12, color: Color(0xFFB8C4DC)),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: ChoiceChip(
                label: const Text('15×15 блоков'),
                selected: currentArenaSize == 15,
                onSelected: (_) => onSelectArenaSize(15),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('21×21 блок'),
                selected: currentArenaSize == 21,
                onSelected: allow21 ? (_) => onSelectArenaSize(21) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Управление шириной проходов (1–2), высотой стен (3–4) и числом колец (3–4).
class PassageAndWallControls extends StatelessWidget {
  final int passageWidth;
  final int wallHeight;
  final int ringCount;
  final ValueChanged<int> onPassageWidthChanged;
  final ValueChanged<int> onWallHeightChanged;
  final ValueChanged<int> onRingCountChanged;

  const PassageAndWallControls({
    super.key,
    required this.passageWidth,
    required this.wallHeight,
    required this.ringCount,
    required this.onPassageWidthChanged,
    required this.onWallHeightChanged,
    required this.onRingCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            const Text(
              'Ширина проходов (стена = 1):',
              style: TextStyle(fontSize: 12, color: Color(0xFFB8C4DC)),
            ),
            SegmentedButton<int>(
              segments: const <ButtonSegment<int>>[
                ButtonSegment<int>(value: 1, label: Text('1 бл.')),
                ButtonSegment<int>(value: 2, label: Text('2 бл.')),
              ],
              selected: <int>{passageWidth},
              onSelectionChanged: (s) => onPassageWidthChanged(s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            const Text(
              'Высота стен лабиринта:',
              style: TextStyle(fontSize: 12, color: Color(0xFFB8C4DC)),
            ),
            SegmentedButton<int>(
              segments: const <ButtonSegment<int>>[
                ButtonSegment<int>(value: 3, label: Text('3 бл.')),
                ButtonSegment<int>(value: 4, label: Text('4 бл.')),
              ],
              selected: <int>{wallHeight},
              onSelectionChanged: (s) => onWallHeightChanged(s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            const Text(
              'Концентрические зоны:',
              style: TextStyle(fontSize: 12, color: Color(0xFFB8C4DC)),
            ),
            SegmentedButton<int>(
              segments: const <ButtonSegment<int>>[
                ButtonSegment<int>(value: 3, label: Text('3 зоны')),
                ButtonSegment<int>(value: 4, label: Text('4 зоны')),
              ],
              selected: <int>{ringCount},
              onSelectionChanged: (s) => onRingCountChanged(s.first),
            ),
          ],
        ),
      ],
    );
  }
}

/// Выбор алгоритма генерации (Прим или Рекурсивный бэктрекинг DFS).
class AlgorithmSelectorCard extends StatelessWidget {
  final MazeAlgorithm selectedAlgorithm;
  final ValueChanged<MazeAlgorithm> onChanged;

  const AlgorithmSelectorCard({
    super.key,
    required this.selectedAlgorithm,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final algo in MazeAlgorithm.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => onChanged(algo),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selectedAlgorithm == algo
                      ? const Color(0xFF1A2942)
                      : const Color(0xFF161C28),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selectedAlgorithm == algo
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFF283246),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      selectedAlgorithm == algo
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 16,
                      color: const Color(0xFF00E5FF),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            algo.shortName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            algo.description,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF9AA8C4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Выбор типа одностороннего входа в центральную арену.
class ArenaEntryModeCard extends StatelessWidget {
  final ArenaEntryMode selectedMode;
  final ValueChanged<ArenaEntryMode> onChanged;

  const ArenaEntryModeCard({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Односторонний вход в арену:',
          style: TextStyle(fontSize: 12, color: Color(0xFFB8C4DC)),
        ),
        const SizedBox(height: 6),
        for (final mode in ArenaEntryMode.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => onChanged(mode),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selectedMode == mode
                      ? const Color(0xFF1A2942)
                      : const Color(0xFF161C28),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selectedMode == mode
                        ? const Color(0xFF2979FF)
                        : const Color(0xFF283246),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      selectedMode == mode
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 16,
                      color: const Color(0xFF2979FF),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mode.title,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ползунки настройки плотности тупиков и процента ловушек.
class DensityAndTrapsSliders extends StatelessWidget {
  final double deadEndDensity;
  final double trapPercentage;
  final ValueChanged<double> onDeadEndDensityChanged;
  final ValueChanged<double> onTrapPercentageChanged;

  const DensityAndTrapsSliders({
    super.key,
    required this.deadEndDensity,
    required this.trapPercentage,
    required this.onDeadEndDensityChanged,
    required this.onTrapPercentageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Плотность тупиков (Dead-ends):',
                style: TextStyle(fontSize: 12, color: Color(0xFFB8C4DC)),
              ),
            ),
            Text(
              '${(deadEndDensity * 100).round()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFEA00),
              ),
            ),
          ],
        ),
        Slider(
          value: deadEndDensity,
          min: 0.25,
          max: 1.0,
          divisions: 15,
          onChanged: onDeadEndDensityChanged,
        ),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Процент ловушек и раздатчиков:',
                style: TextStyle(fontSize: 12, color: Color(0xFFB8C4DC)),
              ),
            ),
            Text(
              '${(trapPercentage * 100).round()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD500F9),
              ),
            ),
          ],
        ),
        Slider(
          value: trapPercentage,
          min: 0.0,
          max: 0.90,
          divisions: 18,
          onChanged: onTrapPercentageChanged,
        ),
      ],
    );
  }
}

/// Выбор палитры материалов Minecraft.
class MinecraftPaletteSelector extends StatelessWidget {
  final BlockPalette selectedPalette;
  final ValueChanged<BlockPalette> onSelectPalette;

  const MinecraftPaletteSelector({
    super.key,
    required this.selectedPalette,
    required this.onSelectPalette,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final preset in BlockPalette.presets)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => onSelectPalette(preset),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selectedPalette.id == preset.id
                      ? const Color(0xFF1F2B3E)
                      : const Color(0xFF161C28),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selectedPalette.id == preset.id
                        ? const Color(0xFF00E676)
                        : const Color(0xFF283246),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Color(preset.wallColorArgb),
                            border: Border.all(color: Colors.white54),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            preset.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Стены: ${preset.primaryWallBlock}\nБарьеры: ${preset.ringBarrierBlock}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: Color(0xFF8B99B5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
