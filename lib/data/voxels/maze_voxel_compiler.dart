import 'dart:typed_data';

import '../../domain/core/result.dart';
import '../../domain/entities/maze_cell.dart';
import '../../domain/entities/maze_enums.dart';
import '../../domain/entities/maze_grid.dart';
import '../../domain/entities/poi_marker.dart';
import '../../domain/entities/voxel_volume.dart';
import '../../domain/repositories/i_voxel_compiler.dart';

/// Компилятор 2D-карты лабиринта [MazeGrid] в полноценный 3D-воксельный объем [VoxelVolume].
///
/// Формирует послойную геометрию постройки:
/// * $Y = 0$: Подпольный фундамент и редстоун-трассы (`minecraft:redstone_wire`).
/// * $Y = 1$: Блоки пола по тирам колец и центральной арены.
/// * $Y = 2 \dots H+1$: Стены, барьеры, сундуки, нажимные плиты, раздатчики, спавнеры и двери.
/// * $Y = H+2 \dots H+4$: Оголовки стартовых вертикальных шахт с поршнями синхронного сброса.
final class MazeVoxelCompiler implements IVoxelCompiler {
  const MazeVoxelCompiler();

  @override
  Result<VoxelVolume> compile(MazeGrid grid) {
    try {
      final config = grid.config;
      final paletteSpec = config.palette;
      final width = grid.size;
      final length = grid.size;
      // Общая высота включает подпольный слой (1) + пол (1) + высоту стен (3..4) + запас под шахты сброса (3).
      final wallTopY = 1 + config.wallHeight;
      final totalHeight = wallTopY + 4;

      final paletteList = <String>[];
      final paletteLookup = <String, int>{};

      int registerBlockState(String blockState) {
        final normalized = blockState.toLowerCase();
        final existing = paletteLookup[normalized];
        if (existing != null) {
          return existing;
        }
        final newIndex = paletteList.length;
        paletteList.add(normalized);
        paletteLookup[normalized] = newIndex;
        return newIndex;
      }

      // Индекс 0 всегда резервируем за воздухом (`minecraft:air`) по стандарту Sponge Schematic.
      final airIdx = registerBlockState('minecraft:air');
      final subfloorIdx = registerBlockState(
        paletteSpec.subfloorFoundationBlock,
      );
      final redstoneWireIdx = registerBlockState(
        'minecraft:redstone_wire[east=side,north=side,power=0,south=side,west=side]',
      );
      final floorT1Idx = registerBlockState(paletteSpec.floorBlockTier1);
      final floorT2Idx = registerBlockState(paletteSpec.floorBlockTier2);
      final floorT3Idx = registerBlockState(paletteSpec.floorBlockTier3);
      final arenaFloorIdx = registerBlockState(paletteSpec.arenaFloorBlock);
      final pedestalIdx = registerBlockState(paletteSpec.pedestalBlock);
      final primaryWallIdx = registerBlockState(paletteSpec.primaryWallBlock);
      final barrierWallIdx = registerBlockState(paletteSpec.ringBarrierBlock);
      final wallTrimIdx = registerBlockState(paletteSpec.wallTrimBlock);
      final pressurePlateIdx = registerBlockState(
        'minecraft:stone_pressure_plate[powered=false]',
      );
      final spawnerIdx = registerBlockState('minecraft:spawner');
      final glassShaftIdx = registerBlockState('minecraft:tinted_glass');
      final stickyPistonIdx = registerBlockState(
        'minecraft:sticky_piston[extended=true,facing=down]',
      );
      final redstoneBlockIdx = registerBlockState('minecraft:redstone_block');
      final seaLanternIdx = registerBlockState('minecraft:sea_lantern');

      final blockIndices = Uint16List(width * totalHeight * length);
      if (airIdx != 0) {
        blockIndices.fillRange(0, blockIndices.length, airIdx);
      }

      void setVoxel(int x, int y, int z, int paletteIdx) {
        if (x < 0 ||
            x >= width ||
            y < 0 ||
            y >= totalHeight ||
            z < 0 ||
            z >= length) {
          return;
        }
        final linear = (y * length + z) * width + x;
        blockIndices[linear] = paletteIdx;
      }

      final blockEntities = <VoxelBlockEntity>[];

      // 1. Базовая расстановка фундамента (Y=0), пола (Y=1) и стен (Y=2..wallTopY).
      for (var z = 0; z < length; z++) {
        for (var x = 0; x < width; x++) {
          final cell = grid.cellAt(x, z);

          // Слой Y=0: фундамент или подпольный редстоун-канал.
          setVoxel(
            x,
            0,
            z,
            cell.hasSubfloorRedstone ? redstoneWireIdx : subfloorIdx,
          );

          // Слой Y=1: пол в зависимости от зоны/тира.
          final floorIdx = switch (cell.surfaceType) {
            CellSurfaceType.pedestal => pedestalIdx,
            CellSurfaceType.arenaFloor ||
            CellSurfaceType.arenaWall =>
              arenaFloorIdx,
            _ => switch (cell.ringTier) {
                RingTier.tier1 => floorT1Idx,
                RingTier.tier2 => floorT2Idx,
                RingTier.tier3 => floorT3Idx,
                RingTier.centralArena => arenaFloorIdx,
              },
          };
          setVoxel(x, 1, z, floorIdx);

          // Слои стен Y=2..wallTopY.
          if (cell.surfaceType == CellSurfaceType.wall) {
            for (var y = 2; y < wallTopY; y++) {
              setVoxel(x, y, z, primaryWallIdx);
            }
            setVoxel(x, wallTopY, z, wallTrimIdx);
          } else if (cell.surfaceType == CellSurfaceType.ringBarrierWall ||
              cell.surfaceType == CellSurfaceType.arenaWall) {
            for (var y = 2; y <= wallTopY; y++) {
              setVoxel(x, y, z, barrierWallIdx);
            }
          } else if (cell.surfaceType == CellSurfaceType.pedestal) {
            // Возвышение пьедестала 3×3 в центре арены на уровне Y=2.
            setVoxel(x, 2, z, pedestalIdx);
          }
        }
      }

      // 2. Размещение специфичных конструкций POI, контейнеров, дверей и ловушек.
      for (var z = 0; z < length; z++) {
        for (var x = 0; x < width; x++) {
          final cell = grid.cellAt(x, z);
          final poi = cell.poi;

          switch (poi) {
            case NoPoi():
              break;

            case CornerSpawnPoi(:final spawnIndex):
              _compileCornerSpawnShaft(
                x: x,
                z: z,
                wallTopY: wallTopY,
                spawnIndex: spawnIndex,
                glassShaftIdx: glassShaftIdx,
                stickyPistonIdx: stickyPistonIdx,
                redstoneBlockIdx: redstoneBlockIdx,
                seaLanternIdx: seaLanternIdx,
                setVoxel: setVoxel,
              );

            case LootChestPoi(
                :final lootTier,
                :final isTrappedChest,
                :final facing,
              ):
              final chestBlockName = isTrappedChest
                  ? 'minecraft:trapped_chest'
                  : 'minecraft:chest';
              final chestStateIdx = registerBlockState(
                '$chestBlockName[facing=${facing.minecraftName},type=single,waterlogged=false]',
              );
              setVoxel(x, 2, z, chestStateIdx);

              blockEntities.add(
                ContainerBlockEntity(
                  position: VoxelPosition(x, 2, z),
                  blockEntityId: chestBlockName,
                  customName:
                      'Сундук ${lootTier.shortLabel}${isTrappedChest ? " (Ловушка)" : ""}',
                  items: _buildTierLootItems(lootTier, isTrappedChest),
                ),
              );

              // Если это сундук-ловушка, монтируем скрытый раздатчик в стену позади сундука.
              if (isTrappedChest) {
                final backPos = cell.position.step(facing.opposite);
                if (grid.isInBounds(backPos.x, backPos.z)) {
                  final dispIdx = registerBlockState(
                    'minecraft:dispenser[facing=${facing.minecraftName},triggered=false]',
                  );
                  setVoxel(backPos.x, 3, backPos.z, dispIdx);
                  blockEntities.add(
                    ContainerBlockEntity(
                      position: VoxelPosition(backPos.x, 3, backPos.z),
                      blockEntityId: 'minecraft:dispenser',
                      customName: 'Засада сундука-ловушки',
                      items: const <ContainerSlotItem>[
                        ContainerSlotItem(
                          slot: 4,
                          itemId: 'minecraft:tipped_arrow',
                          count: 32,
                          customSnbtTag:
                              '{Potion:"minecraft:strong_harming"}',
                        ),
                      ],
                    ),
                  );
                }
              }

            case TrapMechanismPoi(
                :final kind,
                :final dispenserFacing,
                :final wallDirection,
              ):
              // Нажимная плита на полу коридора (Y=2).
              setVoxel(x, 2, z, pressurePlateIdx);
              setVoxel(x, 0, z, redstoneWireIdx);

              // Встраиваем раздатчик в прилегающую стену на высоте Y=2.
              final wallPos = cell.position.step(wallDirection);
              if (grid.isInBounds(wallPos.x, wallPos.z)) {
                setVoxel(wallPos.x, 0, wallPos.z, redstoneWireIdx);
                final dispIdx = registerBlockState(
                  'minecraft:dispenser[facing=${dispenserFacing.minecraftName},triggered=false]',
                );
                setVoxel(wallPos.x, 2, wallPos.z, dispIdx);

                final payloadItem = kind == TrapKind.fireworkDispenser
                    ? const ContainerSlotItem(
                        slot: 4,
                        itemId: 'minecraft:firework_rocket',
                        count: 32,
                        customSnbtTag:
                            '{Fireworks:{Flight:1b,Explosions:[{Type:1b,Colors:[I;11743532,15435844]}]}}',
                      )
                    : const ContainerSlotItem(
                        slot: 4,
                        itemId: 'minecraft:arrow',
                        count: 64,
                      );

                blockEntities.add(
                  ContainerBlockEntity(
                    position: VoxelPosition(wallPos.x, 2, wallPos.z),
                    blockEntityId: 'minecraft:dispenser',
                    customName: kind.title,
                    items: <ContainerSlotItem>[payloadItem],
                  ),
                );
              }

            case MobSpawnerPoi(:final entityId):
              setVoxel(x, 2, z, spawnerIdx);
              blockEntities.add(
                SpawnerBlockEntity(
                  position: VoxelPosition(x, 2, z),
                  entityId: entityId,
                ),
              );

            case RingGatePoi():
              // Открытая арка высотой 3 блока в капитальной кольцевой стене.
              setVoxel(x, 2, z, airIdx);
              setVoxel(x, 3, z, airIdx);
              setVoxel(x, 4, z, airIdx);

            case ArenaEntryPoi(:final mode, :final entryDirection):
              _compileOneWayArenaEntry(
                x: x,
                z: z,
                mode: mode,
                entryDirection: entryDirection,
                airIdx: airIdx,
                barrierWallIdx: barrierWallIdx,
                pressurePlateIdx: pressurePlateIdx,
                registerBlockState: registerBlockState,
                setVoxel: setVoxel,
              );

            case ArenaPedestalPoi(:final chestFacing):
              _compileCentralArenaPedestal(
                centerX: x,
                centerZ: z,
                chestFacing: chestFacing,
                seaLanternIdx: seaLanternIdx,
                redstoneWireIdx: redstoneWireIdx,
                registerBlockState: registerBlockState,
                setVoxel: setVoxel,
                blockEntities: blockEntities,
              );

            case PuzzleDoorPoi(:final facing):
              final lowerDoorIdx = registerBlockState(
                'minecraft:iron_door[facing=${facing.minecraftName},half=lower,hinge=left,open=false,powered=false]',
              );
              final upperDoorIdx = registerBlockState(
                'minecraft:iron_door[facing=${facing.minecraftName},half=upper,hinge=left,open=false,powered=false]',
              );
              setVoxel(x, 2, z, lowerDoorIdx);
              setVoxel(x, 3, z, upperDoorIdx);
              setVoxel(x, 0, z, redstoneWireIdx);

            case PuzzleLeverPoi(:final wallFacing):
              final leverIdx = registerBlockState(
                'minecraft:lever[face=wall,facing=${wallFacing.minecraftName},powered=false]',
              );
              setVoxel(x, 2, z, leverIdx);
              setVoxel(x, 0, z, redstoneWireIdx);
          }
        }
      }

      return Result.success(
        VoxelVolume(
          width: width,
          height: totalHeight,
          length: length,
          palette: paletteList,
          paletteLookup: paletteLookup,
          blockIndices: blockIndices,
          blockEntities: blockEntities,
        ),
      );
    } catch (e) {
      return Result.failure(
        DomainError(
          code: 'VOXEL_COMPILATION_FAILED',
          message: 'Не удалось скомпилировать 3D-воксельный объем лабиринта.',
          details: e.toString(),
        ),
      );
    }
  }

  /// Строит вертикальную шахту спавна игрока с удерживающим липким поршнем вверху.
  void _compileCornerSpawnShaft({
    required int x,
    required int z,
    required int wallTopY,
    required int spawnIndex,
    required int glassShaftIdx,
    required int stickyPistonIdx,
    required int redstoneBlockIdx,
    required int seaLanternIdx,
    required void Function(int x, int y, int z, int idx) setVoxel,
  }) {
    setVoxel(x, 1, z, seaLanternIdx);
    // Ограждаем верхнюю часть шахты тонированным стеклом и ставим поршень сброса.
    for (final dir in CardinalDirection.values) {
      setVoxel(x + dir.dx, wallTopY + 1, z + dir.dz, glassShaftIdx);
      setVoxel(x + dir.dx, wallTopY + 2, z + dir.dz, glassShaftIdx);
    }
    setVoxel(x, wallTopY + 2, z, stickyPistonIdx);
    setVoxel(x, wallTopY + 3, z, redstoneBlockIdx);
  }

  /// Строит односторонний вход в центральную арену:
  /// - либо железная дверь с нажимной плитой ТОЛЬКО со стороны коридора;
  /// - либо перепад высоты в 2 блока (уступ, с которого игрок спрыгивает в арену).
  void _compileOneWayArenaEntry({
    required int x,
    required int z,
    required ArenaEntryMode mode,
    required CardinalDirection entryDirection,
    required int airIdx,
    required int barrierWallIdx,
    required int pressurePlateIdx,
    required int Function(String state) registerBlockState,
    required void Function(int x, int y, int z, int idx) setVoxel,
  }) {
    if (mode == ArenaEntryMode.oneWayIronDoor) {
      final lowerDoorIdx = registerBlockState(
        'minecraft:iron_door[facing=${entryDirection.minecraftName},half=lower,hinge=left,open=false,powered=false]',
      );
      final upperDoorIdx = registerBlockState(
        'minecraft:iron_door[facing=${entryDirection.minecraftName},half=upper,hinge=left,open=false,powered=false]',
      );
      setVoxel(x, 2, z, lowerDoorIdx);
      setVoxel(x, 3, z, upperDoorIdx);

      // Нажимная плита ставится ТОЛЬКО снаружи (со стороны коридора Тира 3),
      // чтобы изнутри арены дверь невозможно было открыть.
      final outerPos = GridPosition(x, z).step(entryDirection.opposite);
      setVoxel(outerPos.x, 2, outerPos.z, pressurePlateIdx);
    } else {
      // Перепад высоты в 2 блока: порог на высоте Y=2 и Y=3 закрыт блоками барьера,
      // а проход открыт на высоте Y=4 и Y=5 (спрыгивание на 2 блока вниз в арену).
      setVoxel(x, 2, z, barrierWallIdx);
      setVoxel(x, 3, z, barrierWallIdx);
      setVoxel(x, 4, z, airIdx);
      setVoxel(x, 5, z, airIdx);
    }
  }

  /// Строит пьедестал главного приза в центре арены с финальным сундуком-ловушкой
  /// и 4 угловыми раздатчиками фейерверков победы.
  void _compileCentralArenaPedestal({
    required int centerX,
    required int centerZ,
    required CardinalDirection chestFacing,
    required int seaLanternIdx,
    required int redstoneWireIdx,
    required int Function(String state) registerBlockState,
    required void Function(int x, int y, int z, int idx) setVoxel,
    required List<VoxelBlockEntity> blockEntities,
  }) {
    // Центральная тумба пьедестала (Y=2 — морской фонарь, Y=3 — сундук-ловушка).
    setVoxel(centerX, 2, centerZ, seaLanternIdx);
    final prizeChestIdx = registerBlockState(
      'minecraft:trapped_chest[facing=${chestFacing.minecraftName},type=single,waterlogged=false]',
    );
    setVoxel(centerX, 3, centerZ, prizeChestIdx);

    blockEntities.add(
      ContainerBlockEntity(
        position: VoxelPosition(centerX, 3, centerZ),
        blockEntityId: 'minecraft:trapped_chest',
        customName: 'Главный Приз Чемпиона Лабиринта',
        items: const <ContainerSlotItem>[
          ContainerSlotItem(
            slot: 13,
            itemId: 'minecraft:netherite_sword',
            count: 1,
          ),
          ContainerSlotItem(
            slot: 11,
            itemId: 'minecraft:enchanted_golden_apple',
            count: 4,
          ),
          ContainerSlotItem(
            slot: 15,
            itemId: 'minecraft:totem_of_undying',
            count: 2,
          ),
          ContainerSlotItem(
            slot: 4,
            itemId: 'minecraft:nether_star',
            count: 1,
          ),
          ContainerSlotItem(
            slot: 22,
            itemId: 'minecraft:diamond_block',
            count: 16,
          ),
        ],
      ),
    );

    // 4 вертикальных раздатчика фейерверков победы по углам пьедестала 3×3
    // и редстоун-линии от центрального сундука-ловушки.
    final upwardDispenserIdx = registerBlockState(
      'minecraft:dispenser[facing=up,triggered=false]',
    );

    for (final dir in CardinalDirection.values) {
      setVoxel(centerX + dir.dx, 2, centerZ + dir.dz, redstoneWireIdx);
    }

    const offsets = <(int, int)>[(-1, -1), (1, -1), (-1, 1), (1, 1)];
    for (var i = 0; i < offsets.length; i++) {
      final ox = centerX + offsets[i].$1;
      final oz = centerZ + offsets[i].$2;
      setVoxel(ox, 2, oz, upwardDispenserIdx);
      blockEntities.add(
        ContainerBlockEntity(
          position: VoxelPosition(ox, 2, oz),
          blockEntityId: 'minecraft:dispenser',
          customName: 'Салют Победы #${i + 1}',
          items: const <ContainerSlotItem>[
            ContainerSlotItem(
              slot: 4,
              itemId: 'minecraft:firework_rocket',
              count: 64,
              customSnbtTag:
                  '{Fireworks:{Flight:2b,Explosions:[{Type:2b,Flicker:1b,Trail:1b,Colors:[I;16766720,65280],FadeColors:[I;16777215]}]}}',
            ),
          ],
        ),
      );
    }
  }

  /// Формирует список предметов сундука в соответствии с тиром кольца (Tier 1, 2, 3).
  List<ContainerSlotItem> _buildTierLootItems(
    RingTier tier,
    bool isTrapped,
  ) {
    return switch (tier) {
      RingTier.tier1 => <ContainerSlotItem>[
          const ContainerSlotItem(
            slot: 0,
            itemId: 'minecraft:stone_sword',
            count: 1,
          ),
          const ContainerSlotItem(
            slot: 1,
            itemId: 'minecraft:leather_chestplate',
            count: 1,
          ),
          const ContainerSlotItem(
            slot: 2,
            itemId: 'minecraft:cooked_beef',
            count: 8,
          ),
          const ContainerSlotItem(
            slot: 3,
            itemId: 'minecraft:shield',
            count: 1,
          ),
          if (isTrapped)
            const ContainerSlotItem(
              slot: 8,
              itemId: 'minecraft:golden_apple',
              count: 1,
            ),
        ],
      RingTier.tier2 => <ContainerSlotItem>[
          const ContainerSlotItem(
            slot: 0,
            itemId: 'minecraft:iron_sword',
            count: 1,
          ),
          const ContainerSlotItem(
            slot: 1,
            itemId: 'minecraft:iron_chestplate',
            count: 1,
          ),
          const ContainerSlotItem(
            slot: 2,
            itemId: 'minecraft:bow',
            count: 1,
          ),
          const ContainerSlotItem(
            slot: 3,
            itemId: 'minecraft:arrow',
            count: 24,
          ),
          const ContainerSlotItem(
            slot: 4,
            itemId: 'minecraft:golden_apple',
            count: 2,
          ),
        ],
      RingTier.tier3 || RingTier.centralArena => <ContainerSlotItem>[
          const ContainerSlotItem(
            slot: 0,
            itemId: 'minecraft:diamond_sword',
            count: 1,
          ),
          const ContainerSlotItem(
            slot: 1,
            itemId: 'minecraft:diamond_chestplate',
            count: 1,
          ),
          const ContainerSlotItem(
            slot: 2,
            itemId: 'minecraft:ender_pearl',
            count: 4,
          ),
          const ContainerSlotItem(
            slot: 3,
            itemId: 'minecraft:golden_apple',
            count: 4,
          ),
          const ContainerSlotItem(
            slot: 4,
            itemId: 'minecraft:Crossbow',
            count: 1,
          ),
        ],
    };
  }
}

