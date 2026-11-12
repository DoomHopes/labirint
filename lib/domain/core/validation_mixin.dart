import 'result.dart';

/// Миксин горизонтального переиспользования логики валидации геометрии лабиринта.
mixin MazeValidationMixin {
  /// Нормализует размер сетки к валидному числу в диапазоне [33, 99] или 60.
  int normalizeOddDimension(int rawSize) {
    if (rawSize == 60) {
      return 60;
    }
    final clamped = rawSize.clamp(33, 99);
    return clamped.isEven ? clamped + 1 : clamped;
  }

  /// Нормализует размер центральной арены (15 или 21 блок) с учетом габаритов лабиринта.
  int normalizeArenaSize(int requestedArenaSize, int gridSize) {
    if (gridSize <= 37) {
      return 15;
    }
    return requestedArenaSize >= 19 ? 21 : 15;
  }

  /// Проверяет корректность параметров конфигурации лабиринта.
  DomainError? validateParameters({
    required int gridSize,
    required int arenaSize,
    required int passageWidth,
    required int wallHeight,
    required int ringCount,
    required double deadEndDensity,
    required double trapPercentage,
  }) {
    final isValidGrid = (gridSize >= 33 && gridSize <= 101) &&
        (gridSize.isOdd || gridSize == 60);
    if (!isValidGrid) {
      return const DomainError(
        code: 'INVALID_GRID_SIZE',
        message: 'Размер лабиринта должен быть нечетным числом от 33 до 101 или 60×60.',
      );
    }
    if (arenaSize != 15 && arenaSize != 21) {
      return const DomainError(
        code: 'INVALID_ARENA_SIZE',
        message: 'Размер центральной арены должен составлять 15×15 или 21×21 блок.',
      );
    }
    if (arenaSize >= gridSize - 10) {
      return const DomainError(
        code: 'ARENA_TOO_LARGE',
        message:
            'Центральная арена слишком велика для выбранного размера лабиринта.',
      );
    }
    if (passageWidth != 1 && passageWidth != 2) {
      return const DomainError(
        code: 'INVALID_PASSAGE_WIDTH',
        message: 'Ширина проходов должна быть равна 1 или 2 блокам.',
      );
    }
    if (wallHeight < 3 || wallHeight > 4) {
      return const DomainError(
        code: 'INVALID_WALL_HEIGHT',
        message: 'Высота стен должна составлять 3 или 4 блока.',
      );
    }
    if (ringCount < 3 || ringCount > 4) {
      return const DomainError(
        code: 'INVALID_RING_COUNT',
        message: 'Количество концентрических зон должно быть равно 3 или 4.',
      );
    }
    if (deadEndDensity < 0.0 || deadEndDensity > 1.0) {
      return const DomainError(
        code: 'INVALID_DEAD_END_DENSITY',
        message: 'Плотность тупиков должна находиться в диапазоне от 0.0 до 1.0.',
      );
    }
    if (trapPercentage < 0.0 || trapPercentage > 1.0) {
      return const DomainError(
        code: 'INVALID_TRAP_PERCENTAGE',
        message: 'Процент ловушек должен находиться в диапазоне от 0.0 до 1.0.',
      );
    }
    return null;
  }
}

