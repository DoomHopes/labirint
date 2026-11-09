import 'package:meta/meta.dart';
import 'maze_enums.dart';
import 'poi_marker.dart';

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

/// Неизменяемая модель одной клетки 2D-карты лабиринта.
@immutable
final class MazeCell {
  /// Координата клетки (X, Z) в сетке лабиринта.
  final GridPosition position;

  /// Тип поверхности клетки (стена, проход, барьер кольца, арена, пьедестал, шахта).
  final CellSurfaceType surfaceType;

  /// Концентрическая зона (кольцо), к которой принадлежит клетка.
  final RingTier ringTier;

  /// Точка интереса (POI), расположенная на клетке.
  final PoiMarker poi;

  /// Проходит ли под данной клеткой (на слое Y=0) редстоун-магистраль.
  final bool hasSubfloorRedstone;

  /// Является ли клетка тупиком (ровно 1 открытый соседний проход).
  final bool isDeadEnd;

  const MazeCell({
    required this.position,
    required this.surfaceType,
    required this.ringTier,
    this.poi = const NoPoi(),
    this.hasSubfloorRedstone = false,
    this.isDeadEnd = false,
  });

  /// Создает копию клетки с обновленными параметрами.
  MazeCell copyWith({
    CellSurfaceType? surfaceType,
    RingTier? ringTier,
    PoiMarker? poi,
    bool? hasSubfloorRedstone,
    bool? isDeadEnd,
  }) {
    return MazeCell(
      position: position,
      surfaceType: surfaceType ?? this.surfaceType,
      ringTier: ringTier ?? this.ringTier,
      poi: poi ?? this.poi,
      hasSubfloorRedstone: hasSubfloorRedstone ?? this.hasSubfloorRedstone,
      isDeadEnd: isDeadEnd ?? this.isDeadEnd,
    );
  }
}

