import 'package:meta/meta.dart';
import 'maze_enums.dart';

/// Двумерная целочисленная координата клетки на плане лабиринта (X, Z).
@immutable
final class GridPosition {
  final int x;
  final int z;

  const GridPosition(this.x, this.z);

  /// Смещение координаты на шаг в указанном направлении.
  GridPosition step(CardinalDirection direction, [int distance = 1]) {
    return GridPosition(
      x + direction.dx * distance,
      z + direction.dz * distance,
    );
  }

  /// Расстояние Чебышева ($L_\infty$) до другой клетки.
  int chebyshevDistanceTo(GridPosition other) {
    final dx = (x - other.x).abs();
    final dz = (z - other.z).abs();
    return dx > dz ? dx : dz;
  }

  /// Манхэттенское расстояние ($L_1$) до другой клетки.
  int manhattanDistanceTo(GridPosition other) {
    return (x - other.x).abs() + (z - other.z).abs();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPosition && x == other.x && z == other.z;

  @override
  int get hashCode => Object.hash(x, z);

  @override
  String toString() => '($x, $z)';
}

