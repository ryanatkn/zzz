# TODO: ECS Refactor - Hex Game Migration Status

## Overview

We have successfully implemented a new archetype-based ECS architecture and are in the process of migrating the hex game from the old flat storage system to the new system. The core ECS is complete and working, but integration with the hex game requires systematic API updates.

## Completed ✅

### Core ECS Architecture
- **✅ Component Registry**: Centralized component definitions with storage strategies (`component_registry.zig`)
- **✅ Archetype Storage**: Cache-optimized storage for entity archetypes (`archetype_storage.zig`)
- **✅ World System**: Pure ECS World with Zone composition (`world.zig`)
- **✅ System Registry**: Updated to use new World/Game types (`system_registry.zig`)
- **✅ Compilation Fixes**: Fixed Zig 0.14.1 compatibility issues (struct field definitions)

### Hex Game Integration (Partial)
- **✅ HexWorld API**: Updated type aliases and core methods (`hex_world.zig`)
- **✅ Game Renderer**: Updated storage access patterns (`game_renderer.zig`)
- **✅ Physics (Partial)**: Fixed lifestone collision detection (`physics.zig`)

## Current Architecture

### New ECS Structure
```zig
// Old flat storage (deprecated)
ZoneStorage { transforms: HashMap, healths: HashMap, ... }

// New archetype storage (current)
World {
    players: PlayerArchetype,    // Transform + Health + Movement + Visual + PlayerInput + Combat
    units: UnitArchetype,        // Transform + Health + Visual + Unit
    projectiles: ProjectileArchetype, // Transform + Visual + Projectile + Combat
    obstacles: ObstacleArchetype,     // Transform + Visual + Terrain
    lifestones: LifestoneArchetype,   // Transform + Visual + Terrain + Interactable
    portals: PortalArchetype,         // Transform + Visual + Terrain + Interactable
}
```

### API Migration Patterns
```zig
// OLD PATTERN
var iter = ecs_world.units.iterator();
while (iter.next()) |entry| {
    const entity_id = entry.key_ptr.*;
    if (ecs_world.transforms.get(entity_id)) |transform| { ... }
}

// NEW PATTERN
var iter = ecs_world.units.entityIterator();
while (iter.next()) |entity_id| {
    if (ecs_world.units.getComponent(entity_id, .transform)) |transform| { ... }
}
```

## In Progress 🚧

### Current Compilation Status
- **Total Errors**: 34 (down from original 28, showing integration complexity)
- **Core ECS**: ✅ Compiles successfully
- **Hex Game**: ⚠️ Integration in progress

### Active Issues

#### 1. Const Iterator Issues
```zig
// Error: expected mutable, found const
var obstacle_iter = ecs_world.obstacles.entityIterator();

// Fix: Cast away const for read-only operations
var obstacle_iter = @constCast(&ecs_world.obstacles).entityIterator();
```

#### 2. Component Access Migration
Many files still use old flat storage API:
- `ecs_world.transforms.get()` → `ecs_world.units.getComponent(entity, .transform)`
- `ecs_world.terrains.iterator()` → separate archetype iteration (obstacles, lifestones, portals)

#### 3. Type Compatibility
- `usize` zone IDs → `u32` zone IDs (requires `@intCast`)
- `ZoneStorage` return types → `World` return types

## Pending Tasks 📋

### High Priority
1. **Fix spells.zig iterator calls** - Likely has `units.iterator()` calls
2. **Complete game.zig migration** - Still has old API calls and component access patterns
3. **Fix loader.zig and portals.zig** - May have entity creation and iteration issues
4. **Resolve const iterator issues** - Apply `@constCast` pattern systematically

### Medium Priority
1. **Update remaining physics.zig patterns** - Check for more terrain iteration issues
2. **Validate spell system integration** - Ensure spell targeting works with new archetypes
3. **Test entity lifecycle** - Verify creation/destruction works across zones

### Low Priority
1. **Performance validation** - Ensure archetype storage provides expected performance benefits
2. **Memory usage analysis** - Compare memory footprint vs old system
3. **Documentation updates** - Update hex game docs to reflect new architecture

## Migration Strategy

### Systematic File-by-File Approach
1. **Search for old patterns**: `rg "\.iterator\(\)" src/hex/` 
2. **Identify storage access**: Look for `ecs_world.{component_name}.get()`
3. **Update iterators**: Replace with `entityIterator()` and remove `.key_ptr.*`
4. **Fix component access**: Use archetype-specific `getComponent()` calls
5. **Handle const issues**: Add `@constCast` for read-only operations

### Error Reduction Tracking
- **Target**: 0 compilation errors
- **Progress**: 28 → 34 errors (integration complexity expected)
- **Strategy**: Fix systematically by error type, not by file

## Technical Notes

### Archetype Benefits Realized
- **Cache Locality**: Components for same archetype stored together
- **Query Performance**: Iterate only relevant entities per archetype
- **Type Safety**: Compile-time guarantees about component combinations

### Compatibility Layer
`hex_world.zig` provides compatibility methods:
- `getECSWorld()` returns `*World` (was `*ZoneStorage`)
- `iterateObstaclesInCurrentZone()` returns proper iterator type
- Entity creation methods delegate to current zone's world

### Future Considerations
Once migration is complete:
1. **Remove legacy APIs** - Clean up compatibility methods
2. **Optimize archetype definitions** - Based on actual usage patterns
3. **Add missing archetypes** - If needed for future entities
4. **System integration** - Hook up system registry for automatic updates

## Next Steps

1. **Continue systematic migration** of remaining hex game files
2. **Test build incrementally** to track error reduction
3. **Validate gameplay** once compilation succeeds
4. **Performance testing** to confirm architectural benefits
5. **Documentation cleanup** once migration is complete

The core architecture is solid and the patterns are established. The remaining work is systematic application of the migration patterns to complete the hex game integration.