# Entity Storage Performance TODOs

## Array-of-Structures vs Structure-of-Arrays Analysis

The current entity storage in `src/hex/hex_game.zig` uses archetype-based storage which is generally good for cache performance. However, there are some potential AoS patterns that could be improved:

### Current Architecture (Good)
```zig
// Using archetype storage from lib/game/storage - already SoA-like
const PlayerStorage = storage.PlayerStorage(MAX_ENTITIES_PER_ARCHETYPE);
const UnitStorage = storage.UnitStorage(MAX_ENTITIES_PER_ARCHETYPE, Unit);
const ProjectileStorage = storage.ProjectileStorage(MAX_ENTITIES_PER_ARCHETYPE, HexProjectile);
```

### Potential Improvements

#### TODO: Analyze hot paths for SoA optimization
- **Movement updates**: Position/velocity updates happen frequently
- **Collision detection**: Position/radius checks are hot paths  
- **Rendering**: Position/visual data access patterns
- **AI behavior**: Position/health queries for decision making

#### TODO: Consider specialized SoA layouts for hot systems
```zig
// Example: Pure SoA for position updates (if profiling shows benefit)
const MovementSoA = struct {
    positions: [MAX_ENTITIES]Vec2,
    velocities: [MAX_ENTITIES]Vec2,
    active_mask: [MAX_ENTITIES]bool,
    count: usize,
};
```

#### TODO: Profile current archetype performance
- Use `zig build -Doptimize=ReleaseFast` for realistic measurements
- Focus on entity update loops in hot zones (100+ entities)
- Compare cache miss rates between current archetype and pure SoA approaches

#### TODO: Benchmark specific access patterns
- Sequential position updates (movement)
- Random position queries (collision detection)
- Component iteration patterns (rendering)

### Decision Criteria
- Only convert to pure SoA if profiling shows >10% performance improvement
- Consider maintenance cost vs performance gain
- Keep archetype storage for complex component combinations
- Use pure SoA only for simple, frequently accessed data

### Implementation Notes
- Current archetype storage is already cache-friendly for most use cases
- Focus optimization on provably hot paths with measurements
- Maintain compatibility with existing entity queries and iteration patterns

---
*Created by antipattern cleanup - Zig prefers explicit performance measurement over premature optimization*