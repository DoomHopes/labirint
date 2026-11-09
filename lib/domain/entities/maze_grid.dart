import 'package:meta/meta.dart';
import 'maze_cell.dart';
import 'maze_config.dart';
import 'maze_enums.dart';
import 'poi_marker.dart';

/// Математическое описание межкольевого перехода (ворот) с угловым смещением.
@immutable
final class RingGateTransition {
  /// Внешнее кольцо, из которого ведет переход.
  final RingTier fromTier;

  /// Внутреннее кольцо (или арена), в которое ведет переход.
  final RingTier toTier;

  /// Координата пробитого прохода в барьерной стене.
  final GridPosition gatePosition;

  /// Радиус Чебышева ($L_\infty$) барьерной стены относительно центра.
  final int barrierRadius;

  /// Полярный угол $\theta$ положения ворот относительно центра (в градусах $[0, 360)$).
  final double angleDegrees;

  /// Угловое смещение $\Delta\theta$ относительно предыдущего перехода (гарантированно $90^\circ\text{–}180^\circ$).
  final double angularOffsetFromPrevious;

  const RingGateTransition({
    required this.fromTier,
    required this.toTier,
    required this.gatePosition,
    required this.barrierRadius,
    required this.angleDegrees,
    required this.angularOffsetFromPrevious,
  });
}

/// Описание границ концентрического кольца в метрике Чебышева ($L_\infty$).
@immutable
final class RingBoundarySpec {
  final RingTier tier;
  final int innerRadius;
  final int outerRadius;

  const RingBoundarySpec({
    required this.tier,
    required this.innerRadius,
    required this.outerRadius,
  });
}

/// Неизменяемая 2D-структура сгенерированного радиально-концентрического лабиринта.
@immutable
final class MazeGrid {
  /// Конфигурация, по которой был построен лабиринт.
  final MazeConfig config;

  /// Размер сетки по горизонтали и вертикали ($N \times N$).
  final int size;

  /// Приватный одномерный неизменяемый буфер клеток (размер $N \times N$).
  final List<MazeCell> _cells;

  /// Приватный неизменяемый список концентрических границ колец.
  final List<RingBoundarySpec> _ringBoundaries;

  /// Приватный неизменяемый список переходов между кольцами.
  final List<RingGateTransition> _gateTransitions;

  MazeGrid({
    required this.config,
    required this.size,
    required List<MazeCell> cells,
    required List<RingBoundarySpec> ringBoundaries,
    required List<RingGateTransition> gateTransitions,
  })  : assert(cells.length == size * size, 'Неверный размер массива клеток'),
        _cells = List<MazeCell>.unmodifiable(cells),
        _ringBoundaries = List<RingBoundarySpec>.unmodifiable(ringBoundaries),
        _gateTransitions =
            List<RingGateTransition>.unmodifiable(gateTransitions);

  /// Координата геометрического центра лабиринта $(c_x, c_z) = (\lfloor N/2 \rfloor, \lfloor N/2 \rfloor)$.
  GridPosition get center => GridPosition(size ~/ 2, size ~/ 2);

  /// Неизменяемое представление всех клеток лабиринта.
  List<MazeCell> get cells => _cells;

  /// Неизменяемое представление границ концентрических колец.
  List<RingBoundarySpec> get ringBoundaries => _ringBoundaries;

  /// Неизменяемое представление межкольевых ворот с угловой телеметрией.
  List<RingGateTransition> get gateTransitions => _gateTransitions;

  /// Проверяет, принадлежит ли координата пределам сетки.
  bool isInBounds(int x, int z) => x >= 0 && x < size && z >= 0 && z < size;

  /// Возвращает клетку по координатам $(x, z)$.
  MazeCell cellAt(int x, int z) {
    if (!isInBounds(x, z)) {
      throw RangeError('Координата ($x, $z) выходит за пределы сетки $size×$size');
    }
    return _cells[z * size + x];
  }

  /// Возвращает клетку по объекту [GridPosition].
  MazeCell cellAtPosition(GridPosition pos) => cellAt(pos.x, pos.z);

  /// Создает новый неизменяемый экземпляр [MazeGrid] с обновленной клеткой.
  MazeGrid withUpdatedCell(MazeCell updatedCell) {
    final pos = updatedCell.position;
    if (!isInBounds(pos.x, pos.z)) {
      return this;
    }
    final nextCells = List<MazeCell>.of(_cells);
    nextCells[pos.z * size + pos.x] = updatedCell;
    return MazeGrid(
      config: config,
      size: size,
      cells: nextCells,
      ringBoundaries: _ringBoundaries,
      gateTransitions: _gateTransitions,
    );
  }

  /// Подсчитывает количество стартовых шахт спавна.
  int get spawnCount =>
      _cells.where((c) => c.poi is CornerSpawnPoi).length;

  /// Подсчитывает количество тупиков.
  int get deadEndCount => _cells.where((c) => c.isDeadEnd).length;

  /// Подсчитывает количество сундуков заданного тира.
  int countChestsByTier(RingTier tier) => _cells
      .where((c) => c.poi is LootChestPoi && (c.poi as LootChestPoi).lootTier == tier)
      .length;

  /// Подсчитывает общее количество сундуков с лутом (обычных и ловушек).
  int get totalChestCount =>
      _cells.where((c) => c.poi is LootChestPoi).length;

  /// Подсчитывает общее количество активных ловушек и спавнеров.
  int get totalTrapAndSpawnerCount => _cells.where((c) {
        final poi = c.poi;
        if (poi is TrapMechanismPoi || poi is MobSpawnerPoi) {
          return true;
        }
        if (poi is LootChestPoi && poi.isTrappedChest) {
          return true;
        }
        return false;
      }).length;
}

