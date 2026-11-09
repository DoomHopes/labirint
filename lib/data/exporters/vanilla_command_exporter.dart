import '../../domain/core/result.dart';
import '../../domain/entities/maze_grid.dart';
import '../../domain/entities/voxel_volume.dart';
import '../../domain/repositories/i_maze_exporter.dart';

/// Экспортер лабиринта в ванильный командный скрипт (`.mcfunction`) и цепочку `SignalBlock`.
///
/// Включает:
/// 1. Оптимизированную пакетную застройку (`/fill` с RLE-объединением рядов) для возведения
///    постройки на ванильном сервере без WorldEdit/FAWE;
/// 2. Точечную установку контейнеров (`/setblock`) с заполненным NBT-инвентарем тирового лута,
///    раздатчиков со стрелами/фейерверками и спавнеров мобов;
/// 3. Редстоун-инициализацию синхронного сброса 4 стартовых поршней с балансировкой задержки
///    повторителями и финального пьедестала с салютом победы;
/// 4. Генерацию структуры `SignalBlock` (импульсная рельсовая/редстоун-шина самосборки рядов).
final class VanillaCommandExporter implements ICommandScriptExporter {
  const VanillaCommandExporter();

  @override
  Result<CommandScriptArtifact> exportCommands({
    required MazeGrid grid,
    required VoxelVolume volume,
  }) {
    try {
      final buffer = StringBuffer();
      var commandCount = 0;

      void emit(String cmd) {
        buffer.writeln(cmd);
        commandCount++;
      }

      final size = grid.size;
      final wallTopY = 1 + grid.config.wallHeight;
      final center = grid.center;

      buffer.writeln(
        '# ============================================================================',
      );
      buffer.writeln(
        '# ПРОЦЕДУРНЫЙ РАДИАЛЬНО-КОНЦЕНТРИЧЕСКИЙ PvP-ЛАБИРИНТ MINECRAFT',
      );
      buffer.writeln(
        '# Габариты: ${size}x$size | Высота стен: ${grid.config.wallHeight} | Сид: ${grid.config.seed}',
      );
      buffer.writeln(
        '# Алгоритм: ${grid.config.algorithm.title} | Палитра: ${grid.config.palette.name}',
      );
      buffer.writeln(
        '# ============================================================================',
      );
      buffer.writeln();

      // Этап 1: Очистка строительного объема и укладка фундамента/пола.
      buffer.writeln('# [1/5] Очистка строительного объема и базовый фундамент');
      emit(
        'fill ~0 ~0 ~0 ~${size - 1} ~${volume.height - 1} ~${size - 1} minecraft:air',
      );
      emit(
        'fill ~0 ~0 ~0 ~${size - 1} ~0 ~${size - 1} ${grid.config.palette.subfloorFoundationBlock.toLowerCase()}',
      );
      emit(
        'fill ~0 ~1 ~0 ~${size - 1} ~1 ~${size - 1} ${grid.config.palette.floorBlockTier1.toLowerCase()}',
      );

      // Этап 2: RLE-оптимизированная укладка подпольного редстоуна (Y=0), пола зон (Y=1) и стен.
      buffer.writeln();
      buffer.writeln(
        '# [2/5] Пакетная расстановка концентрических стен, барьеров и редстоун-каналов (/fill RLE)',
      );

      for (var y = 0; y <= wallTopY; y++) {
        for (var z = 0; z < size; z++) {
          var x = 0;
          while (x < size) {
            final state = volume.blockStateAt(x, y, z);
            // Пропускаем воздух и уже залитые базовые блоки фундамента/пола Т1.
            final isDefaultLayerBlock = (y == 0 &&
                    state ==
                        grid.config.palette.subfloorFoundationBlock
                            .toLowerCase()) ||
                (y == 1 &&
                    state ==
                        grid.config.palette.floorBlockTier1.toLowerCase());
            if (state == 'minecraft:air' ||
                isDefaultLayerBlock ||
                _isTileEntityBlock(state)) {
              x++;
              continue;
            }

            var runEndX = x;
            while (runEndX + 1 < size &&
                volume.blockStateAt(runEndX + 1, y, z) == state &&
                !_isTileEntityBlock(volume.blockStateAt(runEndX + 1, y, z))) {
              runEndX++;
            }

            if (runEndX > x) {
              emit('fill ~$x ~$y ~$z ~$runEndX ~$y ~$z $state');
            } else {
              emit('setblock ~$x ~$y ~$z $state');
            }
            x = runEndX + 1;
          }
        }
      }

      // Этап 3: Установка TileEntities (сундуки с тировым лутом, раздатчики, спавнеры).
      buffer.writeln();
      buffer.writeln(
        '# [3/5] Размещение контейнеров с тировым лутом, раздатчиков ловушек и спавнеров мобов',
      );
      for (final entity in volume.blockEntities) {
        final pos = entity.position;
        final blockState = volume.blockStateAt(pos.x, pos.y, pos.z);
        final snbt = _buildEntitySnbt(entity);
        emit('setblock ~${pos.x} ~${pos.y} ~${pos.z} $blockState$snbt replace');
      }

      // Этап 4: Редстоун-инициализация синхронного сброса стартовых шахт и финала арены.
      buffer.writeln();
      buffer.writeln(
        '# [4/5] Редстоун-инициализация: линия синхронного сброса 4 угловых шахт и пьедестал победы',
      );
      final dropY = wallTopY + 2;
      final wireY = wallTopY + 3;
      final corners = <(int, int)>[
        (1, 1),
        (size - 2, 1),
        (1, size - 2),
        (size - 2, size - 2),
      ];

      // Верхняя кольцевая редстоун-шина синхронного старта с повторителями каждые 14 блоков.
      emit(
        'fill ~1 ~$wireY ~1 ~${size - 2} ~$wireY ~1 minecraft:polished_deepslate',
      );
      emit(
        'fill ~1 ~$wireY ~${size - 2} ~${size - 2} ~$wireY ~${size - 2} minecraft:polished_deepslate',
      );
      emit(
        'fill ~1 ~$wireY ~1 ~1 ~$wireY ~${size - 2} minecraft:polished_deepslate',
      );
      emit(
        'fill ~${size - 2} ~$wireY ~1 ~${size - 2} ~$wireY ~${size - 2} minecraft:polished_deepslate',
      );

      for (var i = 2; i < size - 2; i++) {
        final isRepeaterSlot = i % 14 == 0;
        final topBlockN = isRepeaterSlot
            ? 'minecraft:repeater[delay=1,facing=east]'
            : 'minecraft:redstone_wire';
        final topBlockS = isRepeaterSlot
            ? 'minecraft:repeater[delay=1,facing=east]'
            : 'minecraft:redstone_wire';
        emit('setblock ~$i ~${wireY + 1} ~1 $topBlockN');
        emit('setblock ~$i ~${wireY + 1} ~${size - 2} $topBlockS');
      }

      for (final (cx, cz) in corners) {
        emit(
          'setblock ~$cx ~$dropY ~$cz minecraft:sticky_piston[facing=down,extended=true]',
        );
        emit('setblock ~$cx ~${dropY - 1} ~$cz minecraft:tinted_glass');
        emit(
          'setblock ~$cx ~${wireY + 1} ~$cz minecraft:redstone_torch[lit=true]',
        );
      }

      // Центральный рубильник старта на командной вышке и финальный контур фейерверков.
      emit(
        'setblock ~1 ~${wireY + 2} ~1 minecraft:lever[face=floor,facing=south,powered=true]',
      );
      emit(
        'setblock ~${center.x} ~1 ~${center.z} minecraft:redstone_lamp[lit=false]',
      );

      // Этап 5: Блок-инициализатор SignalBlock (самоходная импульсная цепочка расстановки рядов).
      buffer.writeln();
      buffer.writeln(
        '# [5/5] Инициализация SignalBlock-шины (импульсная активация рядов без сторонних плагинов)',
      );
      final signalBootstrap = _buildSignalBlockBootstrap(
        size: size,
        centerX: center.x,
        centerZ: center.z,
        wallTopY: wallTopY,
      );
      buffer.writeln(signalBootstrap);

      final fileName =
          'build_pvp_maze_${size}x${size}_seed_${grid.config.seed}.mcfunction';

      return Result.success(
        CommandScriptArtifact(
          fileName: fileName,
          summaryRu:
              'Скрипт постройки ($fileName): $commandCount команд (/fill RLE + /setblock NBT + синхронный Redstone старт)',
          mcFunctionContent: buffer.toString(),
          signalBlockBootstrapCommand: signalBootstrap,
          commandCount: commandCount,
        ),
      );
    } catch (e) {
      return Result.failure(
        DomainError(
          code: 'COMMAND_EXPORT_ERROR',
          message: 'Ошибка при генерации командного скрипта постройки.',
          details: e.toString(),
        ),
      );
    }
  }

  bool _isTileEntityBlock(String state) {
    return state.startsWith('minecraft:chest') ||
        state.startsWith('minecraft:trapped_chest') ||
        state.startsWith('minecraft:dispenser') ||
        state.startsWith('minecraft:spawner');
  }

  String _buildEntitySnbt(VoxelBlockEntity entity) {
    switch (entity) {
      case ContainerBlockEntity(:final customName, :final items):
        final itemStrings = items.map((item) {
          if (item.customSnbtTag != null) {
            return '{Slot:${item.slot}b,id:"${item.itemId.toLowerCase()}",Count:${item.count}b,tag:${item.customSnbtTag}}';
          }
          return '{Slot:${item.slot}b,id:"${item.itemId.toLowerCase()}",Count:${item.count}b}';
        }).join(',');
        return '{CustomName:\'{"text":"$customName"}\',Items:[$itemStrings]}';

      case SpawnerBlockEntity(
          :final entityId,
          :final spawnCount,
          :final spawnRange,
          :final minSpawnDelay,
          :final maxSpawnDelay,
          :final requiredPlayerRange,
        ):
        return '{SpawnCount:${spawnCount}s,SpawnRange:${spawnRange}s,'
            'MinSpawnDelay:${minSpawnDelay}s,MaxSpawnDelay:${maxSpawnDelay}s,'
            'RequiredPlayerRange:${requiredPlayerRange}s,'
            'SpawnData:{entity:{id:"$entityId"}}}';
    }
  }

  String _buildSignalBlockBootstrap({
    required int size,
    required int centerX,
    required int centerZ,
    required int wallTopY,
  }) {
    return '''
# SignalBlock Bootstrap: импульсная редстоун-рельса поочередной активации рядов Z=0..${size - 1}
fill ~-3 ~0 ~0 ~-2 ~0 ~${size - 1} minecraft:Smooth_stone
fill ~-3 ~1 ~0 ~-3 ~1 ~${size - 1} minecraft:powered_rail[shape=north_south,powered=false]
setblock ~-3 ~1 ~0 minecraft:repeater[facing=south,delay=2]
setblock ~-2 ~1 ~0 minecraft:observer[facing=east]
# Активация синхронного сброса всех 4 угловых шахт и фейерверка центральной арены:
setblock ~1 ~${wallTopY + 4} ~1 minecraft:redstone_block''';
  }
}

