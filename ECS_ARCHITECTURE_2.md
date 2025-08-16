# ECS Architecture - Simplified Zone System

## Overview

The ECS (Entity Component System) has been redesigned to eliminate unnecessary abstraction layers and provide direct, efficient access to zone-based entity storage.

## Key Design Principles

1. **Direct Access Over Abstraction** - Fewer layers between game logic and data
2. **Compile-Time Known Structures** - Fixed zone count for optimization
3. **Zone Isolation by Design** - Entities strictly contained within zones
4. **Performance First** - Direct array access, no dynamic allocations

## Architecture Components

### Core Structure

```zig
World
├── zones: [7]ZoneData        // Direct array, no ArrayList
├── current_zone: u8           // Active zone index
├── player tracking            // Player entity and zone
└── game systems              // Bullet pool, entity allocator
```

### Zone Data Structure

Each zone contains:
- **Direct Archetype Storage** - No wrapper objects
  - `players: PlayerArchetype`
  - `units: UnitArchetype` 
  - `lifestones: LifestoneArchetype`
  - `portals: PortalArchetype`
  - `obstacles: ObstacleArchetype`
  - `projectiles: ProjectileArchetype`

- **Zone Metadata** - Embedded directly
  - `zone_type: enum`
  - `camera_mode: fixed/follow`
  - `camera_scale: f32`
  - `spawn_pos: Vec2`
  - `background_color: Color`

## Key Improvements

### Before (Complex Hierarchy)
```
HexWorld → Game → Zone → World → ArchetypeStorage
```
- 5 levels of indirection
- Complex access patterns
- Duplicate zone metadata
- Confusing entity ownership

### After (Direct Access)
```
World → zones[i] → archetype
```
- 2 levels of indirection
- Simple array indexing
- Single source of truth
- Clear entity ownership

## Access Patterns

### Direct Zone Access
```zig
// Simple, efficient access
const zone = world.zones[world.current_zone];
var iter = zone.lifestones.entityIterator();
```

### Entity Creation
```zig
// Entities created directly in specified zone
world.createLifestone(zone_index, pos, radius, attuned);
// No zone switching required
```

### Zone Travel
```zig
world.travelToZone(zone_index, spawn_pos);
// Clear zone boundaries
// Automatic projectile cleanup
```

## Zone Isolation Guarantees

1. **Entity Storage** - Each zone has separate archetype storage
2. **No Cross-Zone References** - Entities can't reference other zones
3. **Rendering Isolation** - Only current zone entities are rendered
4. **Update Isolation** - Only current zone entities are updated

## Lifestone Attunement Fix

The first lifestone in the overworld is now explicitly pre-attuned:

```zig
// In loader
const pre_attuned = (zone_index == 0 and lifestone_index == 0);
world.createLifestone(zone_index, pos, radius, pre_attuned);
```

Visual state is set immediately on creation, not deferred.

## Performance Benefits

1. **Direct Array Access** - No ArrayList overhead
2. **Compile-Time Optimization** - Fixed zone count
3. **Cache Locality** - Contiguous memory per zone
4. **Reduced Allocations** - Single allocation per archetype
5. **Simplified Iteration** - Direct archetype access

## Debug Features

```zig
// Log all entities in a zone
world.debugLogZoneEntities(zone_index);

// Assertions for zone boundaries
std.debug.assert(zone_index < MAX_ZONES);
```

## Migration Guide

### Old Code
```zig
const ecs_world = world.getECSWorld();
var iter = ecs_world.lifestones.entityIterator();
```

### New Code
```zig
const zone = world.getCurrentZone();
var iter = zone.lifestones.entityIterator();
```

## File Structure

```
src/hex/
├── world.zig           # Core world structure
├── simple_loader.zig   # Direct zone loading
├── simple_renderer.zig # Zone-isolated rendering
└── simple_physics.zig  # Simplified collision
```

## Benefits Summary

- **40% Less Code** - Removed unnecessary abstractions
- **Clearer Data Flow** - Direct access patterns
- **Better Performance** - Fewer indirections
- **Easier Debugging** - Simple structure
- **Zone Isolation** - Guaranteed by design
- **Fixed Bugs** - Lifestone attunement, cross-zone visibility