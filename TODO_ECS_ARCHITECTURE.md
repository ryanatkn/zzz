# ECS Architecture Implementation

## Status: ✅ ECS Migration Complete with Effect Stacking

### Completed Tasks
1. ✅ **Core ECS entity system with generational IDs** - Safe ID recycling with generation tracking
2. ✅ **Dense and sparse storage abstractions** - Cache-efficient SOA layout for components
3. ✅ **Base component types in lib/game** - Transform, Health, Movement, Visual, Unit, Combat, Effects
4. ✅ **World container** - Central entity/component management
5. ✅ **Camera memory corruption fix** - Heap-allocated game_renderer/game_state
6. ✅ **Specialized bullet pool** - High-performance projectile management
7. ✅ **Integration example** - HexWorld showing migration path
8. ✅ **Player ECS migration** - Player entity using pure ECS components
9. ✅ **Unit ECS migration** - All units spawned as ECS entities
10. ✅ **Combat system integration** - Bullet-unit collision with ECS components
11. ✅ **Effect stacking system** - Spell effects using ECS Effects component
12. ✅ **Aggro modifier system** - ECS-based aggro calculation with proper stacking

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
- `Effects`: Stacked modifiers with duration and different stack behaviors (replace/add/multiply)

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
3. **Phase 3**: Migrate entities incrementally (✅ Complete)
   - ✅ Player using pure ECS components
   - ✅ Units converted to ECS form
   - ✅ Bullets as ECS entities with pool optimization
   - ✅ Spell effects using ECS Effects component
4. **Phase 4**: Complete ECS migration
   - ✅ Effect stacking system implemented
   - ✅ Aggro modifiers via ECS Effects
   - [ ] Migrate obstacles and lifestones to full ECS
   - [ ] Update save/load system for ECS world state

### TODO: Remaining Steps

- [x] ~~Migrate Player entity to full ECS~~ ✅ Complete
- [x] ~~Convert Unit spawning to use ECS~~ ✅ Complete  
- [x] ~~Implement effect stacking for spells~~ ✅ Complete
- [ ] Add visual indicators for active effects on entities
- [ ] Migrate obstacles and lifestones to full ECS
- [ ] Update save/load system to work with ECS world state
- [ ] Create query builder API for efficient multi-component queries
- [ ] Profile and optimize hot paths
- [ ] Add debug visualization for entities

### Usage Example

```zig
// Create world
var world = try HexWorld.init(allocator);
defer world.deinit();

// Create entities with ECS components
const player = try world.createPlayer(Vec2.new(100, 100));
const enemy = try world.createUnit(Vec2.new(200, 200), 15.0, 100.0, .enemy);

// Fire bullet as ECS entity
const bullet = world.fireBullet(player_pos, target_pos, player, 150.0, 300.0, 4.0);

// Apply spell effects using ECS Effects component
const lull_modifier = Effects.Modifier{
    .type = .aggro_mult,
    .value = 0.3,  // 30% aggro
    .duration = 12.0,
    .stack_type = .replace,
    .source = player,
};
try world.world.effects.get(enemy).?.addModifier(lull_modifier);

// Update systems with ECS queries
updateUnitsECS(&game_state, dt);
world.updateProjectiles(dt);
```

## Benefits Achieved

1. **Memory Safety**: No more undefined globals, proper lifecycle management
2. **Performance**: Cache-friendly SOA layout, specialized pools for high-frequency objects
3. **Effect Stacking**: Proper spell modifier system with different stack behaviors
4. **Combat System**: One-hit kills with ECS bullet-unit collision detection
5. **Flexibility**: Easy to add new components and behaviors
6. **Maintainability**: Clean separation of data and logic
7. **Scalability**: Supports thousands of entities efficiently

### Current Game Features Using ECS

- **Player Entity**: Pure ECS components (Transform, Health, Visual, PlayerInput)
- **Unit Entities**: AI, health, combat using ECS components
- **Projectile Entities**: Bullets as ECS entities with collision detection
- **Effect System**: Lull spell applies aggro modifiers via ECS Effects component
- **Combat Balance**: 150 damage bullets for one-hit kills, gray corpses remain visible

The ECS migration is largely complete with a working effect stacking system, maintaining the game's procedural, performance-focused philosophy.