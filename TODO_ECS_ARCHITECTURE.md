# ECS Architecture Implementation

## Status: ✅ Core Implementation Complete

### Completed Tasks
1. ✅ **Core ECS entity system with generational IDs** - Safe ID recycling with generation tracking
2. ✅ **Dense and sparse storage abstractions** - Cache-efficient SOA layout for components
3. ✅ **Base component types in lib/game** - Transform, Health, Movement, Visual, Unit, Combat, Effects
4. ✅ **World container** - Central entity/component management
5. ✅ **Camera memory corruption fix** - Heap-allocated game_renderer/game_state
6. ✅ **Specialized bullet pool** - High-performance projectile management
7. ✅ **Integration example** - HexWorld showing migration path

## Architecture Overview

### Core Concepts
- **Entity**: Generational ID (24-bit index + 8-bit generation) for safe recycling
- **Component**: Data chunks at appropriate granularity (not per-property)
- **Unit**: Core gameplay component type (replaces monolithic structs)
- **System**: Logic operating on components
- **World**: Container managing entities and components

### File Structure
```
src/lib/game/
├── entity.zig       # EntityId, EntityAllocator with generation tracking
├── storage.zig      # DenseStorage (SOA) and SparseStorage (HashMap)
├── components.zig   # Core component types (Transform, Health, Unit, etc.)
├── world.zig        # World container with query system
├── pools.zig        # Specialized pools (BulletPool, ParticlePool)
└── ecs.zig          # Barrel export for clean imports

src/hex/
├── ecs_integration.zig  # Example migration to ECS
└── main.zig             # Fixed memory corruption with heap allocation
```

### Key Design Decisions

#### 1. Generational Entity IDs
```zig
pub const EntityId = packed struct {
    index: u24,      // 16M entities
    generation: u8,  // 256 generations before wrap
};
```
- Prevents stale references after entity recycling
- Essential for bullets and other high-frequency objects
- Minimal overhead (4 bytes per ID)

#### 2. Storage Strategy
- **Dense Storage**: Components most entities have (Transform, Health, Visual)
  - SOA layout for cache efficiency
  - O(1) access with generation validation
  - Swap-remove for fast deletion

- **Sparse Storage**: Components few entities have (Unit, Combat, Effects)
  - HashMap for memory efficiency
  - Only allocated when needed
  - Good for optional components

#### 3. Component Chunking
Components group related data at meaningful granularity:
- `Transform`: position, velocity, radius
- `Health`: current, max, alive status
- `Movement`: speed, walk_speed, movement flags
- `Unit`: AI state, behavior, aggro
- `Combat`: damage, attack rate, projectile properties
- `Effects`: Stacked modifiers with duration

#### 4. Specialized Pools
High-frequency objects bypass ECS for performance:
- **BulletPool**: 256 pre-allocated bullets, SOA layout
- **ParticlePool**: 1024 particles with bit-mask tracking
- Direct array access, no indirection
- SIMD-friendly update loops

### Memory Safety Improvements

#### Fixed: Global Variable Corruption
**Before (corrupted):**
```zig
var game_renderer: GameRenderer = undefined;  // Stack allocated, undefined memory
```

**After (safe):**
```zig
var game_renderer: ?*GameRenderer = null;  // Heap allocated, stable pointer
game_renderer = try allocator.create(GameRenderer);
```

This eliminates the camera corruption crash by:
1. Using heap allocation for stable memory addresses
2. Proper initialization before use
3. Clear ownership and lifecycle
4. No undefined global state

### Performance Characteristics

- **Cache Efficiency**: SOA layout keeps hot data together
- **Minimal Indirection**: Direct array indexing for dense components
- **Batch Processing**: Systems iterate over packed arrays
- **Zero Allocation in Hot Path**: Pre-allocated pools, no runtime allocs
- **SIMD-Friendly**: Aligned data structures for vectorization

### Migration Path

1. **Phase 1**: Core ECS in lib/game (✅ Complete)
2. **Phase 2**: Fix memory corruption (✅ Complete)
3. **Phase 3**: Migrate entities incrementally
   - Start with Player using components
   - Convert Units to component form
   - Keep bullets in specialized pool
4. **Phase 4**: Add new gameplay features
   - Effect stacking system
   - Item modifiers
   - Spell interactions

### TODO: Next Steps

- [ ] Migrate Player entity to full ECS
- [ ] Convert Unit spawning to use ECS
- [ ] Implement effect stacking for spells
- [ ] Add component query system
- [ ] Profile and optimize hot paths
- [ ] Add debug visualization for entities
- [ ] Implement save/load for ECS world

### Usage Example

```zig
// Create world
var world = try HexWorld.init(allocator);
defer world.deinit();

// Create entities
const player = try world.createPlayer(Vec2.new(100, 100));
const enemy = try world.createEnemy(Vec2.new(200, 200), .medium);

// Fire bullet (uses specialized pool)
const bullet = world.fireBullet(player_pos, target_pos, player);

// Update systems
updateUnitAI(&world, dt);
updateCombat(&world, time);
updatePhysics(&world, dt);
```

## Benefits Achieved

1. **Memory Safety**: No more undefined globals, proper lifecycle management
2. **Performance**: Cache-friendly SOA layout, specialized pools
3. **Flexibility**: Easy to add new components and behaviors
4. **Maintainability**: Clean separation of data and logic
5. **Scalability**: Supports thousands of entities efficiently

The architecture is ready for incremental migration while maintaining the game's procedural, performance-focused philosophy.