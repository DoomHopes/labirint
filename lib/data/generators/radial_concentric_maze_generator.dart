import 'dart:math' as math;

import '../../domain/core/result.dart';
import '../../domain/core/validation_mixin.dart';
import '../../domain/entities/maze_cell.dart';
import '../../domain/entities/maze_config.dart';
import '../../domain/entities/maze_enums.dart';
import '../../domain/entities/maze_grid.dart';
import '../../domain/entities/poi_marker.dart';
import '../../domain/repositories/i_maze_generator.dart';

/// Реализация генератора радиально-концентрического PvP-лабиринта.
///
/// ### Математика концентрических колец и углового смещения переходов:
/// 1. Вводится квадратная метрика Чебышева ($L_\infty$) относительно центра
///    $c = (c_x, c_z) = (\lfloor N/2 \rfloor, \lfloor N/2 \rfloor)$:
///    $$r(x, z) = \max(|x - c_x|, |z - c_z|)$$
/// 2. Пространство разбивается капитальными кольцевыми барьерами на радиусах
///    $R_{\text{arena}} < R_1 < R_2 < R_{\max}$.
/// 3. Для каждых межкольевых ворот $p_k = (x_k, z_k)$ вычисляется полярный угол:
///    $$\theta_k = \left(\operatorname{atan2}(z_k - c_z, x_k - c_x) \cdot \frac{180}{\pi} + 360^\circ\right) \bmod 360^\circ$$
/// 4. Чтобы исключить прямой проход к центру, каждые следующие ворота $p_{k+1}$
///    выбираются на внутреннем барьере так, чтобы кратчайшее угловое расстояние
///    на окружности $S^1$ удовлетворяло условию:
///    $$\Delta\theta(\theta_{k+1}, \theta_k) = 180^\circ - \bigl||\theta_{k+1} - \theta_k| - 180^\circ\bigr| \in [90^\circ, 180^\circ]$$
final class RadialConcentricMazeGenerator
    with MazeValidationMixin
    implements IMazeGenerator {
  const RadialConcentricMazeGenerator();

  @override
  Result<MazeGrid> generate(MazeConfig config) {
    final validationError = validateParameters(
      gridSize: config.gridSize,
      arenaSize: config.arenaSize,
      passageWidth: config.passageWidth,
      wallHeight: config.wallHeight,
      ringCount: config.ringCount,
      deadEndDensity: config.deadEndDensity,
      trapPercentage: config.trapPercentage,
    );
    if (validationError != null) {
      return Result.failure(validationError);
    }

    try {
      final size = config.gridSize;
      final centerCoord = size ~/ 2;
      final center = GridPosition(centerCoord, centerCoord);
      final maxRadius = centerCoord;
      final arenaRadius = config.arenaSize ~/ 2;

      final random = math.Random(config.seed);

      // 1. Вычисляем радиусы концентрических зон (четные расстояния от края,
      // чтобы барьерные стены попадали точно на узлы стеновой решетки).
      final ringBoundaries = _computeRingBoundaries(
        maxRadius: maxRadius,
        arenaRadius: arenaRadius,
        ringCount: config.ringCount,
      );

      final barrierRadii = <int>{
        for (final spec in ringBoundaries)
          if (spec.tier != RingTier.centralArena) spec.innerRadius,
        maxRadius,
      };

      // 2. Инициализируем матрицу поверхности и тиров.
      final surfaces = List<CellSurfaceType>.filled(
        size * size,
        CellSurfaceType.wall,
      );
      final tiers = List<RingTier>.filled(size * size, RingTier.tier1);
      final pois = List<PoiMarker>.filled(size * size, const NoPoi());
      final redstoneFlags = List<bool>.filled(size * size, false);

      for (var z = 0; z < size; z++) {
        for (var x = 0; x < size; x++) {
          final pos = GridPosition(x, z);
          final r = pos.chebyshevDistanceTo(center);
          final idx = z * size + x;

          final tier = _resolveTierForRadius(r, ringBoundaries);
          tiers[idx] = tier;

          if (r == 0 || r == 1) {
            surfaces[idx] = CellSurfaceType.pedestal;
          } else if (r < arenaRadius) {
            surfaces[idx] = CellSurfaceType.arenaFloor;
          } else if (r == arenaRadius) {
            surfaces[idx] = CellSurfaceType.arenaWall;
          } else if (barrierRadii.contains(r)) {
            surfaces[idx] = CellSurfaceType.ringBarrierWall;
          } else {
            surfaces[idx] = CellSurfaceType.wall;
          }
        }
      }

      // 3. Генерируем связный лабиринт внутри каждого концентрического кольца отдельно.
      for (final boundary in ringBoundaries) {
        if (boundary.tier == RingTier.centralArena) {
          continue;
        }
        _carveRingMaze(
          size: size,
          center: center,
          boundary: boundary,
          passageWidth: config.passageWidth,
          algorithm: config.algorithm,
          random: random,
          surfaces: surfaces,
        );
      }

      // 4. Регулируем плотность тупиков (braiding) при deadEndDensity < 1.0.
      if (config.deadEndDensity < 0.99) {
        _applyDeadEndDensityPruning(
          size: size,
          deadEndDensity: config.deadEndDensity,
          random: random,
          surfaces: surfaces,
          tiers: tiers,
        );
      }

      // 5. Размещаем 4 симметричных угловых спавна во внешнем кольце (Тир 1).
      _placeSymmetricCornerSpawns(
        size: size,
        wallHeight: config.wallHeight,
        surfaces: surfaces,
        tiers: tiers,
        pois: pois,
        redstoneFlags: redstoneFlags,
      );

      // 6. Пробиваем межкольевые переходы со строгим угловым смещением 90°–180°
      // и односторонний вход в центральную арену.
      final gateTransitions = _carveShiftedRingGates(
        size: size,
        center: center,
        ringBoundaries: ringBoundaries,
        arenaEntryMode: config.arenaEntryMode,
        random: random,
        surfaces: surfaces,
        tiers: tiers,
        pois: pois,
        redstoneFlags: redstoneFlags,
      );

      // 7. Размещаем пьедестал главного приза в центре арены и редстоун-цепи салюта.
      _setupCentralArenaPedestal(
        size: size,
        center: center,
        pois: pois,
        redstoneFlags: redstoneFlags,
      );

      // 8. Находим все истинные тупики (dead-ends) и размещаем сундуки с тировым лутом,
      // а также ловушки (нажимные плиты, раздатчики) и спавнеры мобов в Тире 3.
      final deadEndFlags = _populateDeadEndChestsAndTraps(
        size: size,
        trapPercentage: config.trapPercentage,
        random: random,
        surfaces: surfaces,
        tiers: tiers,
        pois: pois,
        redstoneFlags: redstoneFlags,
      );

      // 9. Собираем неизменяемый список MazeCell.
      final cells = List<MazeCell>.generate(size * size, (idx) {
        final x = idx % size;
        final z = idx ~/ size;
        return MazeCell(
          position: GridPosition(x, z),
          surfaceType: surfaces[idx],
          ringTier: tiers[idx],
          poi: pois[idx],
          hasSubfloorRedstone: redstoneFlags[idx],
          isDeadEnd: deadEndFlags[idx],
        );
      });

      return Result.success(
        MazeGrid(
          config: config,
          size: size,
          cells: cells,
          ringBoundaries: ringBoundaries,
          gateTransitions: gateTransitions,
        ),
      );
    } catch (e) {
      return Result.failure(
        DomainError(
          code: 'MAZE_GENERATION_FAILED',
          message: 'Ошибка при процедурной генерации лабиринта.',
          details: e.toString(),
        ),
      );
    }
  }

  /// Вычисляет границы концентрических колец так, чтобы барьерные стены
  /// имели четное смещение от внешнего края $(R_{\max} - r) \bmod 2 == 0$.
  List<RingBoundarySpec> _computeRingBoundaries({
    required int maxRadius,
    required int arenaRadius,
    required int ringCount,
  }) {
    final specs = <RingBoundarySpec>[];
    final outerZoneCount = ringCount - 1; // 2 или 3 кольца вокруг арены
    final totalSpan = maxRadius - arenaRadius;

    if (outerZoneCount == 3) {
      // 3 внешних кольца: Тир 1 (внешний), Тир 2 (средний), Тир 3 (внутренний) + Арена.
      var r1Inner = maxRadius - (totalSpan ~/ 3);
      if ((maxRadius - r1Inner).isOdd) {
        r1Inner--;
      }
      var r2Inner = arenaRadius + (totalSpan ~/ 3);
      if ((maxRadius - r2Inner).isOdd) {
        r2Inner++;
      }
      if (r2Inner >= r1Inner - 2) {
        r2Inner = r1Inner - 2;
      }
      if (r2Inner <= arenaRadius + 2) {
        r2Inner = arenaRadius + 2;
      }

      specs.add(
        RingBoundarySpec(
          tier: RingTier.tier1,
          innerRadius: r1Inner,
          outerRadius: maxRadius,
        ),
      );
      specs.add(
        RingBoundarySpec(
          tier: RingTier.tier2,
          innerRadius: r2Inner,
          outerRadius: r1Inner,
        ),
      );
      specs.add(
        RingBoundarySpec(
          tier: RingTier.tier3,
          innerRadius: arenaRadius,
          outerRadius: r2Inner,
        ),
      );
    } else {
      // 2 внешних кольца (Тир 1 и Тир 2/3) + Центральная арена (всего 3 зоны).
      var midRadius = arenaRadius + (totalSpan ~/ 2);
      if ((maxRadius - midRadius).isOdd) {
        midRadius++;
      }
      specs.add(
        RingBoundarySpec(
          tier: RingTier.tier1,
          innerRadius: midRadius,
          outerRadius: maxRadius,
        ),
      );
      specs.add(
        RingBoundarySpec(
          tier: RingTier.tier2,
          innerRadius: arenaRadius,
          outerRadius: midRadius,
        ),
      );
    }

    specs.add(
      RingBoundarySpec(
        tier: RingTier.centralArena,
        innerRadius: 0,
        outerRadius: arenaRadius,
      ),
    );

    return specs;
  }

  /// Определяет тир кольца для заданного радиуса Чебышева $r$.
  RingTier _resolveTierForRadius(
    int radius,
    List<RingBoundarySpec> boundaries,
  ) {
    for (final spec in boundaries) {
      if (radius > spec.innerRadius && radius <= spec.outerRadius) {
        return spec.tier;
      }
    }
    return RingTier.centralArena;
  }

  /// Вырезает коридоры внутри одного концентрического кольца с помощью
  /// модифицированного алгоритма Прима или рекурсивного бэктрекинга (DFS).
  void _carveRingMaze({
    required int size,
    required GridPosition center,
    required RingBoundarySpec boundary,
    required int passageWidth,
    required MazeAlgorithm algorithm,
    required math.Random random,
    required List<CellSurfaceType> surfaces,
  }) {
    // Собираем все узлы решетки (нечетные координаты (x, z)), лежащие строго внутри кольца.
    final ringNodes = <GridPosition>[];
    final nodeSet = <GridPosition>{};

    for (var z = 1; z < size - 1; z += 2) {
      for (var x = 1; x < size - 1; x += 2) {
        final pos = GridPosition(x, z);
        final r = pos.chebyshevDistanceTo(center);
        if (r > boundary.innerRadius && r < boundary.outerRadius) {
          ringNodes.add(pos);
          nodeSet.add(pos);
        }
      }
    }

    if (ringNodes.isEmpty) {
      return;
    }

    final visited = <GridPosition>{};

    // Обходим все компоненты связности узлов внутри кольца.
    for (final seedNode in ringNodes) {
      if (visited.contains(seedNode)) {
        continue;
      }

      if (algorithm == MazeAlgorithm.recursiveBacktrackerDfs) {
        _runDfsOnRingComponent(
          startNode: seedNode,
          nodeSet: nodeSet,
          visited: visited,
          size: size,
          random: random,
          surfaces: surfaces,
        );
      } else {
        _runModifiedPrimsOnRingComponent(
          startNode: seedNode,
          nodeSet: nodeSet,
          visited: visited,
          size: size,
          random: random,
          surfaces: surfaces,
        );
      }
    }

    // Если ширина проходов равна 2 блокам, расширяем проходы внутри кольца
    // с сохранением капитальных межкольевых барьеров.
    if (passageWidth == 2) {
      _widenPassagesInRing(
        size: size,
        center: center,
        boundary: boundary,
        surfaces: surfaces,
      );
    }

    // Гарантируем кольцевую связность по периметру кольца, чтобы игрок всегда
    // мог обойти кольцо по кругу от входа до смещенного выхода.
    _ensureRingPerimeterConnectivity(
      size: size,
      center: center,
      boundary: boundary,
      surfaces: surfaces,
    );
  }

  /// Рекурсивный бэктрекинг (итеративный DFS со стеком) внутри кольца.
  void _runDfsOnRingComponent({
    required GridPosition startNode,
    required Set<GridPosition> nodeSet,
    required Set<GridPosition> visited,
    required int size,
    required math.Random random,
    required List<CellSurfaceType> surfaces,
  }) {
    final stack = <GridPosition>[startNode];
    visited.add(startNode);
    surfaces[startNode.z * size + startNode.x] = CellSurfaceType.passage;

    while (stack.isNotEmpty) {
      final current = stack.last;
      final directions = List<CardinalDirection>.of(CardinalDirection.values)
        ..shuffle(random);

      GridPosition? chosenNext;
      CardinalDirection? chosenDir;

      for (final dir in directions) {
        final candidate = current.step(dir, 2);
        if (nodeSet.contains(candidate) && !visited.contains(candidate)) {
          chosenNext = candidate;
          chosenDir = dir;
          break;
        }
      }

      if (chosenNext != null && chosenDir != null) {
        final wallBetween = current.step(chosenDir, 1);
        surfaces[wallBetween.z * size + wallBetween.x] =
            CellSurfaceType.passage;
        surfaces[chosenNext.z * size + chosenNext.x] = CellSurfaceType.passage;
        visited.add(chosenNext);
        stack.add(chosenNext);
      } else {
        stack.removeLast();
      }
    }
  }

  /// Модифицированный алгоритм Прима внутри концентрического кольца.
  void _runModifiedPrimsOnRingComponent({
    required GridPosition startNode,
    required Set<GridPosition> nodeSet,
    required Set<GridPosition> visited,
    required int size,
    required math.Random random,
    required List<CellSurfaceType> surfaces,
  }) {
    visited.add(startNode);
    surfaces[startNode.z * size + startNode.x] = CellSurfaceType.passage;

    final frontier = <({GridPosition from, GridPosition to, CardinalDirection dir})>[];

    void addFrontierEdges(GridPosition node) {
      for (final dir in CardinalDirection.values) {
        final neighbor = node.step(dir, 2);
        if (nodeSet.contains(neighbor) && !visited.contains(neighbor)) {
          frontier.add((from: node, to: neighbor, dir: dir));
        }
      }
    }

    addFrontierEdges(startNode);

    while (frontier.isNotEmpty) {
      // Модифицированный выбор: 70% случайное ребро из фронта (ветвистость Прима),
      // 30% одно из последних добавленных ребер (локальная связность коридоров).
      final int pickIndex;
      if (random.nextDouble() < 0.70) {
        pickIndex = random.nextInt(frontier.length);
      } else {
        final tailSpan = math.min(frontier.length, 4);
        pickIndex = frontier.length - 1 - random.nextInt(tailSpan);
      }

      final edge = frontier.removeAt(pickIndex);
      if (visited.contains(edge.to)) {
        continue;
      }

      visited.add(edge.to);
      final bridge = edge.from.step(edge.dir, 1);
      surfaces[bridge.z * size + bridge.x] = CellSurfaceType.passage;
      surfaces[edge.to.z * size + edge.to.x] = CellSurfaceType.passage;

      addFrontierEdges(edge.to);
    }
  }

  /// Расширяет коридоры до 2 блоков при `passageWidth == 2`, не затрагивая
  /// капитальные межкольевые барьеры и сохраняя перегородки лабиринта.
  void _widenPassagesInRing({
    required int size,
    required GridPosition center,
    required RingBoundarySpec boundary,
    required List<CellSurfaceType> surfaces,
  }) {
    final toOpen = <GridPosition>[];
    for (var z = 1; z < size - 2; z++) {
      for (var x = 1; x < size - 2; x++) {
        final pos = GridPosition(x, z);
        final r = pos.chebyshevDistanceTo(center);
        if (r <= boundary.innerRadius + 1 || r >= boundary.outerRadius - 1) {
          continue;
        }
        if (surfaces[z * size + x] == CellSurfaceType.passage) {
          final east = GridPosition(x + 1, z);
          final eastR = east.chebyshevDistanceTo(center);
          if (eastR > boundary.innerRadius + 1 &&
              eastR < boundary.outerRadius - 1 &&
              x.isOdd) {
            toOpen.add(east);
          }
        }
      }
    }
    for (final pos in toOpen) {
      if (surfaces[pos.z * size + pos.x] == CellSurfaceType.wall) {
        surfaces[pos.z * size + pos.x] = CellSurfaceType.passage;
      }
    }
  }

  /// Проверяет и при необходимости объединяет компоненты связности внутри кольца,
  /// чтобы из любой точки кольца можно было дойти до смещенных межкольевых ворот.
  void _ensureRingPerimeterConnectivity({
    required int size,
    required GridPosition center,
    required RingBoundarySpec boundary,
    required List<CellSurfaceType> surfaces,
  }) {
    while (true) {
      final componentByCell = <GridPosition, int>{};
      var compCount = 0;

      for (var z = 1; z < size - 1; z++) {
        for (var x = 1; x < size - 1; x++) {
          final pos = GridPosition(x, z);
          final r = pos.chebyshevDistanceTo(center);
          if (r <= boundary.innerRadius || r >= boundary.outerRadius) {
            continue;
          }
          if (surfaces[z * size + x] != CellSurfaceType.passage ||
              componentByCell.containsKey(pos)) {
            continue;
          }

          compCount++;
          final queue = <GridPosition>[pos];
          componentByCell[pos] = compCount;
          var head = 0;
          while (head < queue.length) {
            final cur = queue[head++];
            for (final dir in CardinalDirection.values) {
              final next = cur.step(dir);
              final nr = next.chebyshevDistanceTo(center);
              if (nr > boundary.innerRadius &&
                  nr < boundary.outerRadius &&
                  surfaces[next.z * size + next.x] == CellSurfaceType.passage &&
                  !componentByCell.containsKey(next)) {
                componentByCell[next] = compCount;
                queue.add(next);
              }
            }
          }
        }
      }

      if (compCount <= 1) {
        break;
      }

      // Ищем внутреннюю стену толщиной 1 блок, разделяющую две разные компоненты.
      var bridged = false;
      for (var z = 1; z < size - 1 && !bridged; z++) {
        for (var x = 1; x < size - 1 && !bridged; x++) {
          final pos = GridPosition(x, z);
          final r = pos.chebyshevDistanceTo(center);
          if (r <= boundary.innerRadius ||
              r >= boundary.outerRadius ||
              surfaces[z * size + x] != CellSurfaceType.wall) {
            continue;
          }

          final neighborComponents = <int>{};
          for (final dir in CardinalDirection.values) {
            final n = pos.step(dir);
            final comp = componentByCell[n];
            if (comp != null) {
              neighborComponents.add(comp);
            }
          }
          if (neighborComponents.length >= 2) {
            surfaces[z * size + x] = CellSurfaceType.passage;
            bridged = true;
          }
        }
      }

      if (!bridged) {
        break;
      }
    }
  }

  /// Уменьшает количество тупиков (соединяя часть тупиков в циклы),
  /// если пользователь снизил параметр `deadEndDensity`.
  void _applyDeadEndDensityPruning({
    required int size,
    required double deadEndDensity,
    required math.Random random,
    required List<CellSurfaceType> surfaces,
    required List<RingTier> tiers,
  }) {
    final candidates = <GridPosition>[];
    for (var z = 1; z < size - 1; z++) {
      for (var x = 1; x < size - 1; x++) {
        if (surfaces[z * size + x] != CellSurfaceType.passage) {
          continue;
        }
        final pos = GridPosition(x, z);
        if (_countOpenNeighbors(pos, size, surfaces) == 1) {
          candidates.add(pos);
        }
      }
    }

    candidates.shuffle(random);
    final pruneTarget = ((1.0 - deadEndDensity) * candidates.length).round();
    var pruned = 0;

    for (final deadEnd in candidates) {
      if (pruned >= pruneTarget) {
        break;
      }
      if (_countOpenNeighbors(deadEnd, size, surfaces) != 1) {
        continue;
      }
      final currentTier = tiers[deadEnd.z * size + deadEnd.x];

      for (final dir in CardinalDirection.values) {
        final wallPos = deadEnd.step(dir, 1);
        final beyondPos = deadEnd.step(dir, 2);
        if (beyondPos.x <= 0 ||
            beyondPos.x >= size - 1 ||
            beyondPos.z <= 0 ||
            beyondPos.z >= size - 1) {
          continue;
        }
        final wallIdx = wallPos.z * size + wallPos.x;
        final beyondIdx = beyondPos.z * size + beyondPos.x;
        if (surfaces[wallIdx] == CellSurfaceType.wall &&
            surfaces[beyondIdx] == CellSurfaceType.passage &&
            tiers[beyondIdx] == currentTier) {
          surfaces[wallIdx] = CellSurfaceType.passage;
          pruned++;
          break;
        }
      }
    }
  }

  /// Размещает 4 симметричных угловых спавна с вертикальными шахтами
  /// и подпольной линией синхронного сброса поршней.
  void _placeSymmetricCornerSpawns({
    required int size,
    required int wallHeight,
    required List<CellSurfaceType> surfaces,
    required List<RingTier> tiers,
    required List<PoiMarker> pois,
    required List<bool> redstoneFlags,
  }) {
    final corners = <GridPosition>[
      const GridPosition(1, 1),
      GridPosition(size - 2, 1),
      GridPosition(1, size - 2),
      GridPosition(size - 2, size - 2),
    ];

    for (var i = 0; i < corners.length; i++) {
      final corner = corners[i];
      final idx = corner.z * size + corner.x;
      surfaces[idx] = CellSurfaceType.spawnShaft;
      tiers[idx] = RingTier.tier1;
      pois[idx] = CornerSpawnPoi(
        spawnIndex: i + 1,
        shaftHeight: wallHeight + 1,
      );
      redstoneFlags[idx] = true;

      // Гарантируем, что у стартовой шахты есть открытый выход во внешнее кольцо.
      final inwardX = corner.x == 1 ? 2 : size - 3;
      final inwardZ = corner.z == 1 ? 2 : size - 3;
      if (surfaces[corner.z * size + inwardX] != CellSurfaceType.passage &&
          surfaces[inwardZ * size + corner.x] != CellSurfaceType.passage) {
        surfaces[corner.z * size + inwardX] = CellSurfaceType.passage;
      }
    }

    // Прокладываем периметральную подпольную редстоун-шину (Y=0) вдоль внешнего кольца
    // для синхронного сброса всех 4 стартовых поршней.
    for (var i = 1; i < size - 1; i++) {
      redstoneFlags[1 * size + i] = true;
      redstoneFlags[(size - 2) * size + i] = true;
      redstoneFlags[i * size + 1] = true;
      redstoneFlags[i * size + (size - 2)] = true;
    }
  }

  /// Пробивает межкольевые ворота с математическим смещением на 90°–180°
  /// относительно предыдущего перехода, исключая прямой путь к центру.
  List<RingGateTransition> _carveShiftedRingGates({
    required int size,
    required GridPosition center,
    required List<RingBoundarySpec> ringBoundaries,
    required ArenaEntryMode arenaEntryMode,
    required math.Random random,
    required List<CellSurfaceType> surfaces,
    required List<RingTier> tiers,
    required List<PoiMarker> pois,
    required List<bool> redstoneFlags,
  }) {
    final transitions = <RingGateTransition>[];

    // Базовый опорный угол первого внешнего ориентира (0°, 90°, 180° или 270°).
    var previousAngle = (random.nextInt(4) * 90.0 + 45.0) % 360.0;

    for (var i = 0; i < ringBoundaries.length - 1; i++) {
      final outerSpec = ringBoundaries[i];
      final innerSpec = ringBoundaries[i + 1];
      final barrierRadius = outerSpec.innerRadius;

      // Целевое угловое смещение строго в интервале [115°, 175°] ⊂ [90°, 180°].
      final sign = random.nextBool() ? 1.0 : -1.0;
      final desiredDelta = 115.0 + random.nextDouble() * 60.0;
      final targetAngle = (previousAngle + sign * desiredDelta + 360.0) % 360.0;

      // Собираем кандидатов на барьерной стене радиуса barrierRadius
      // (не на самых углах квадрата, чтобы с обеих сторон барьера были прямые клетки).
      final candidates = <({
        GridPosition gatePos,
        GridPosition outerNeighbor,
        GridPosition innerNeighbor,
        CardinalDirection inwardDir,
        double angleDeg,
        double deltaFromPrev,
      })>[];

      for (var z = center.z - barrierRadius;
          z <= center.z + barrierRadius;
          z++) {
        for (var x = center.x - barrierRadius;
            x <= center.x + barrierRadius;
            x++) {
          final pos = GridPosition(x, z);
          if (pos.chebyshevDistanceTo(center) != barrierRadius) {
            continue;
          }

          final dx = x - center.x;
          final dz = z - center.z;
          // Исключаем угловые вершины барьерного квадрата и четные координаты,
          // чтобы ворота попадали на коридорные линии.
          if (dx.abs() == barrierRadius && dz.abs() == barrierRadius) {
            continue;
          }
          if ((dx.abs() == barrierRadius && z.isEven) ||
              (dz.abs() == barrierRadius && x.isEven)) {
            continue;
          }

          final CardinalDirection inwardDir;
          if (dz == -barrierRadius) {
            inwardDir = CardinalDirection.south;
          } else if (dz == barrierRadius) {
            inwardDir = CardinalDirection.north;
          } else if (dx == -barrierRadius) {
            inwardDir = CardinalDirection.east;
          } else {
            inwardDir = CardinalDirection.west;
          }

          final outerNeighbor = pos.step(inwardDir.opposite, 1);
          final innerNeighbor = pos.step(inwardDir, 1);

          final angle = _polarAngleDegrees(pos, center);
          final delta = shortestAngularDistanceDegrees(angle, previousAngle);

          if (delta >= 90.0 && delta <= 180.0) {
            candidates.add((
              gatePos: pos,
              outerNeighbor: outerNeighbor,
              innerNeighbor: innerNeighbor,
              inwardDir: inwardDir,
              angleDeg: angle,
              deltaFromPrev: delta,
            ));
          }
        }
      }

      // Сортируем кандидатов по близости к целевому углу и наличию проходов с обеих сторон.
      candidates.sort((a, b) {
        final aOuterOpen =
            surfaces[a.outerNeighbor.z * size + a.outerNeighbor.x].isWalkable
                ? 0.0
                : 25.0;
        final bOuterOpen =
            surfaces[b.outerNeighbor.z * size + b.outerNeighbor.x].isWalkable
                ? 0.0
                : 25.0;
        final aScore =
            shortestAngularDistanceDegrees(a.angleDeg, targetAngle) +
                aOuterOpen;
        final bScore =
            shortestAngularDistanceDegrees(b.angleDeg, targetAngle) +
                bOuterOpen;
        return aScore.compareTo(bScore);
      });

      final chosen = candidates.first;
      final gateIdx = chosen.gatePos.z * size + chosen.gatePos.x;
      final outerIdx = chosen.outerNeighbor.z * size + chosen.outerNeighbor.x;
      final innerIdx = chosen.innerNeighbor.z * size + chosen.innerNeighbor.x;

      surfaces[gateIdx] = CellSurfaceType.passage;
      if (!surfaces[outerIdx].isWalkable) {
        surfaces[outerIdx] = CellSurfaceType.passage;
      }
      if (!surfaces[innerIdx].isWalkable) {
        surfaces[innerIdx] = innerSpec.tier == RingTier.centralArena
            ? CellSurfaceType.arenaFloor
            : CellSurfaceType.passage;
      }

      if (innerSpec.tier == RingTier.centralArena) {
        pois[gateIdx] = ArenaEntryPoi(
          mode: arenaEntryMode,
          entryDirection: chosen.inwardDir,
          angleDegrees: chosen.angleDeg,
        );
        if (arenaEntryMode == ArenaEntryMode.oneWayIronDoor) {
          redstoneFlags[outerIdx] = true;
          redstoneFlags[gateIdx] = true;
        }
      } else {
        pois[gateIdx] = RingGatePoi(
          fromTier: outerSpec.tier,
          toTier: innerSpec.tier,
          angleDegrees: chosen.angleDeg,
        );
      }

      transitions.add(
        RingGateTransition(
          fromTier: outerSpec.tier,
          toTier: innerSpec.tier,
          gatePosition: chosen.gatePos,
          barrierRadius: barrierRadius,
          angleDegrees: chosen.angleDeg,
          angularOffsetFromPrevious: chosen.deltaFromPrev,
        ),
      );

      previousAngle = chosen.angleDeg;
    }

    return transitions;
  }

  /// Настраивает центральный пьедестал 3×3 с главным призом и редстоун-разводкой к салютам.
  void _setupCentralArenaPedestal({
    required int size,
    required GridPosition center,
    required List<PoiMarker> pois,
    required List<bool> redstoneFlags,
  }) {
    final centerIdx = center.z * size + center.x;
    pois[centerIdx] = const ArenaPedestalPoi(
      chestFacing: CardinalDirection.south,
    );

    // Крестообразная и угловая подпольная редстоун-разводка от центрального
    // сундука-ловушки к 4 угловым раздатчикам фейерверков на пьедестале 3×3.
    for (var dz = -1; dz <= 1; dz++) {
      for (var dx = -1; dx <= 1; dx++) {
        redstoneFlags[(center.z + dz) * size + (center.x + dx)] = true;
      }
    }
  }

  /// Выявляет тупики (клетки прохода с ровно 1 открытым соседом) и размещает:
  /// - Сундуки с лутом (обычные и ловушки) СТРОГО в тупиках с привязкой тира к кольцу;
  /// - Нажимные плиты + раздатчики в коридорах Тира 2 и Тира 3;
  /// - Спавнеры опасных мобов во внутреннем кольце (Тир 3).
  List<bool> _populateDeadEndChestsAndTraps({
    required int size,
    required double trapPercentage,
    required math.Random random,
    required List<CellSurfaceType> surfaces,
    required List<RingTier> tiers,
    required List<PoiMarker> pois,
    required List<bool> redstoneFlags,
  }) {
    final deadEndFlags = List<bool>.filled(size * size, false);
    final deadEndsByTier = <RingTier, List<({GridPosition pos, CardinalDirection exitDir})>>{
      RingTier.tier1: [],
      RingTier.tier2: [],
      RingTier.tier3: [],
    };

    for (var z = 1; z < size - 1; z++) {
      for (var x = 1; x < size - 1; x++) {
        final idx = z * size + x;
        if (surfaces[idx] != CellSurfaceType.passage) {
          continue;
        }
        if (pois[idx] is! NoPoi) {
          continue;
        }

        final pos = GridPosition(x, z);
        CardinalDirection? singleExit;
        var openCount = 0;

        for (final dir in CardinalDirection.values) {
          final neighbor = pos.step(dir);
          if (surfaces[neighbor.z * size + neighbor.x].isWalkable) {
            openCount++;
            singleExit = dir;
          }
        }

        if (openCount == 1 && singleExit != null) {
          deadEndFlags[idx] = true;
          final tier = tiers[idx];
          deadEndsByTier[tier]?.add((pos: pos, exitDir: singleExit));
        }
      }
    }

    // 1. Размещаем головоломки «Запертая дверь ↔ Скрытый рычаг в тупике».
    _placeDoorAndLeverPuzzles(
      size: size,
      random: random,
      surfaces: surfaces,
      tiers: tiers,
      pois: pois,
      redstoneFlags: redstoneFlags,
      deadEndsByTier: deadEndsByTier,
    );

    // 2. Размещаем сундуки с лутом ИСКЛЮЧИТЕЛЬНО в тупиках (dead-ends),
    // привязывая тир лута к глубине кольца (Tier 1, Tier 2, Tier 3).
    for (final entry in deadEndsByTier.entries) {
      final tier = entry.key;
      final tierDeadEnds = entry.value..shuffle(random);
      if (tierDeadEnds.isEmpty) {
        continue;
      }

      // В каждом тире минимум 1 сундук, плюс до 75% всех тупиков тира.
      final targetChestCount = math.max(
        1,
        (tierDeadEnds.length * 0.65).round(),
      );

      for (var i = 0; i < tierDeadEnds.length && i < targetChestCount; i++) {
        final deadEnd = tierDeadEnds[i];
        final idx = deadEnd.pos.z * size + deadEnd.pos.x;

        // Доля сундуков-ловушек растет с глубиной кольца и настройкой trapPercentage.
        final tierTrapBoost = switch (tier) {
          RingTier.tier1 => 0.5,
          RingTier.tier2 => 1.0,
          RingTier.tier3 => 1.25,
          RingTier.centralArena => 1.0,
        };
        final isTrapped =
            random.nextDouble() < (trapPercentage * tierTrapBoost).clamp(0.0, 0.9);

        pois[idx] = LootChestPoi(
          lootTier: tier,
          isTrappedChest: isTrapped,
          facing: deadEnd.exitDir,
        );

        if (isTrapped) {
          redstoneFlags[idx] = true;
          final backWall = deadEnd.pos.step(deadEnd.exitDir.opposite);
          if (backWall.x >= 0 &&
              backWall.x < size &&
              backWall.z >= 0 &&
              backWall.z < size) {
            redstoneFlags[backWall.z * size + backWall.x] = true;
          }
        }
      }
    }

    // 2. Размещаем ловушки (нажимные плиты + редстоун под полом к раздатчикам в стенах)
    // и спавнеры опасных мобов во внутреннем кольце (Тир 3).
    final corridorCandidates = <GridPosition>[];
    for (var z = 2; z < size - 2; z++) {
      for (var x = 2; x < size - 2; x++) {
        final idx = z * size + x;
        if (surfaces[idx] != CellSurfaceType.passage ||
            deadEndFlags[idx] ||
            pois[idx] is! NoPoi) {
          continue;
        }
        final tier = tiers[idx];
        if (tier == RingTier.tier2 || tier == RingTier.tier3) {
          corridorCandidates.add(GridPosition(x, z));
        }
      }
    }

    corridorCandidates.shuffle(random);
    final maxMechanismCount =
        (corridorCandidates.length * (trapPercentage * 0.28)).round();
    var placedMechanisms = 0;

    const mobTypes = <(String, String)>[
      ('minecraft:wither_skeleton', 'Визер-скелет'),
      ('minecraft:skeleton', 'Скелет-снайпер'),
      ('minecraft:zombie', 'Бронированный зомби'),
      ('minecraft:cave_spider', 'Пещерный паук'),
    ];

    for (final pos in corridorCandidates) {
      if (placedMechanisms >= maxMechanismCount) {
        break;
      }
      final idx = pos.z * size + pos.x;
      final tier = tiers[idx];

      // Проверяем, не стоит ли уже ловушка на соседней клетке.
      var adjacentHasPoi = false;
      CardinalDirection? solidWallDir;
      for (final dir in CardinalDirection.values) {
        final neighbor = pos.step(dir);
        final nIdx = neighbor.z * size + neighbor.x;
        if (pois[nIdx] is! NoPoi) {
          adjacentHasPoi = true;
          break;
        }
        if (surfaces[nIdx] == CellSurfaceType.wall) {
          solidWallDir = dir;
        }
      }
      if (adjacentHasPoi || solidWallDir == null) {
        continue;
      }

      if (tier == RingTier.tier3 && placedMechanisms % 3 == 0) {
        // Во внутреннем кольце (Тир 3) размещаем спавнеры опасных мобов.
        final mob = mobTypes[placedMechanisms % mobTypes.length];
        pois[idx] = MobSpawnerPoi(
          entityId: mob.$1,
          entityNameRu: mob.$2,
        );
        placedMechanisms++;
      } else {
        // Нажимная плита с подпольной редстоун-линией к раздатчику стрел/фейерверков.
        final kind = (tier == RingTier.tier3 && placedMechanisms.isEven)
            ? TrapKind.fireworkDispenser
            : TrapKind.arrowDispenser;
        pois[idx] = TrapMechanismPoi(
          kind: kind,
          dispenserFacing: solidWallDir.opposite,
          wallDirection: solidWallDir,
        );
        redstoneFlags[idx] = true;
        final wallPos = pos.step(solidWallDir);
        redstoneFlags[wallPos.z * size + wallPos.x] = true;
        placedMechanisms++;
      }
    }

    return deadEndFlags;
  }

  /// Размещает головоломки «Запертая железная дверь ↔ Скрытый рычаг в тупике».
  void _placeDoorAndLeverPuzzles({
    required int size,
    required math.Random random,
    required List<CellSurfaceType> surfaces,
    required List<RingTier> tiers,
    required List<PoiMarker> pois,
    required List<bool> redstoneFlags,
    required Map<RingTier, List<({GridPosition pos, CardinalDirection exitDir})>>
        deadEndsByTier,
  }) {
    final corridorDoorCandidates =
        <({GridPosition pos, CardinalDirection facing, RingTier tier})>[];

    for (var z = 2; z < size - 2; z++) {
      for (var x = 2; x < size - 2; x++) {
        final idx = z * size + x;
        if (surfaces[idx] != CellSurfaceType.passage || pois[idx] is! NoPoi) {
          continue;
        }
        final tier = tiers[idx];
        if (tier != RingTier.tier2 && tier != RingTier.tier3) {
          continue;
        }

        final northOpen = surfaces[(z - 1) * size + x].isWalkable;
        final southOpen = surfaces[(z + 1) * size + x].isWalkable;
        final eastOpen = surfaces[z * size + (x + 1)].isWalkable;
        final westOpen = surfaces[z * size + (x - 1)].isWalkable;

        if (northOpen && southOpen && !eastOpen && !westOpen) {
          corridorDoorCandidates.add((
            pos: GridPosition(x, z),
            facing: CardinalDirection.north,
            tier: tier,
          ));
        } else if (eastOpen && westOpen && !northOpen && !southOpen) {
          corridorDoorCandidates.add((
            pos: GridPosition(x, z),
            facing: CardinalDirection.east,
            tier: tier,
          ));
        }
      }
    }

    if (corridorDoorCandidates.isEmpty) return;
    corridorDoorCandidates.shuffle(random);

    final puzzleNames = size >= 49 ? ['A', 'B'] : ['A'];
    var puzzleIndex = 0;

    for (final candidate in corridorDoorCandidates) {
      if (puzzleIndex >= puzzleNames.length) break;
      final puzzleId = puzzleNames[puzzleIndex];

      final searchTiers = candidate.tier == RingTier.tier3
          ? [RingTier.tier2, RingTier.tier3, RingTier.tier1]
          : [RingTier.tier1, RingTier.tier2];

      ({GridPosition pos, CardinalDirection exitDir})? chosenDeadEnd;
      for (final sTier in searchTiers) {
        final deadEnds = deadEndsByTier[sTier];
        if (deadEnds != null && deadEnds.isNotEmpty) {
          for (var i = 0; i < deadEnds.length; i++) {
            final de = deadEnds[i];
            if (de.pos.manhattanDistanceTo(candidate.pos) >= 5 &&
                pois[de.pos.z * size + de.pos.x] is NoPoi) {
              chosenDeadEnd = deadEnds.removeAt(i);
              break;
            }
          }
          if (chosenDeadEnd != null) break;
        }
      }

      if (chosenDeadEnd != null) {
        final doorPos = candidate.pos;
        final leverPos = chosenDeadEnd.pos;

        pois[doorPos.z * size + doorPos.x] = PuzzleDoorPoi(
          puzzleId: puzzleId,
          facing: candidate.facing,
          leverPosition: leverPos,
        );
        redstoneFlags[doorPos.z * size + doorPos.x] = true;

        pois[leverPos.z * size + leverPos.x] = PuzzleLeverPoi(
          puzzleId: puzzleId,
          wallFacing: chosenDeadEnd.exitDir.opposite,
          doorPosition: doorPos,
        );
        redstoneFlags[leverPos.z * size + leverPos.x] = true;

        puzzleIndex++;
      }
    }
  }

  int _countOpenNeighbors(
    GridPosition pos,
    int size,
    List<CellSurfaceType> surfaces,
  ) {
    var count = 0;
    for (final dir in CardinalDirection.values) {
      final n = pos.step(dir);
      if (n.x >= 0 &&
          n.x < size &&
          n.z >= 0 &&
          n.z < size &&
          surfaces[n.z * size + n.x].isWalkable) {
        count++;
      }
    }
    return count;
  }

  /// Вычисляет полярный угол клетки относительно центра в градусах $[0, 360)$.
  double _polarAngleDegrees(GridPosition pos, GridPosition center) {
    final rad = math.atan2(pos.z - center.z, pos.x - center.x);
    final deg = rad * 180.0 / math.pi;
    return (deg + 360.0) % 360.0;
  }

  /// Вычисляет кратчайшее угловое расстояние на окружности между двумя углами в градусах $[0, 180]$.
  static double shortestAngularDistanceDegrees(double a, double b) {
    final diff = (a - b).abs() % 360.0;
    return 180.0 - (diff - 180.0).abs();
  }
}

