import 'package:meta/meta.dart';
import 'grid_position.dart';
import 'maze_enums.dart';
import 'poi_marker.dart';

export 'grid_position.dart';

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

