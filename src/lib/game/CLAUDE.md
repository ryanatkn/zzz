# Game Systems Library - AI Assistant Guide

> ⚠️ AI slop code and docs, is unstable and full of lies

This directory contains both experimental ECS architecture and production utilities for game development.

## ⚠️ IMPORTANT: Actual Usage Status

**See [COMPARISON.md](./COMPARISON.md) for detailed analysis of what's actually used vs experimental.**

### Production Components (Actually Used by hex)
✅ **AI Control** (`control/`) - Lock-free input injection system  
✅ **Behaviors** (`behaviors/`) - Simple chase/return utilities  
✅ **Cooldowns** (`cooldowns.zig`) - Spell/ability cooldown management  
✅ **State Management** (`state/`) - Save/load system  
✅ **Bullet Pool** (`projectiles/`) - Recharge-based projectile pool  
✅ **Events** (`events/`) - Pub/sub event system  

### Experimental Architecture (Mostly Unused)
⚠️ **ECS Core** (`ecs.zig`) - Complex dual architecture  
⚠️ **World/Zone/Game** - Multi-layer abstraction  
⚠️ **Archetype Storage** - Metaprogramming-based storage  
⚠️ **Component Registry** - Dynamic component system  
⚠️ **Entity Allocator** - Generation-tracked IDs  
⚠️ **System Registry** - Modular update pipeline  

## Quick Reference for hex Development

The hex game implements its own simplified architecture with fixed arrays. When working on hex:

### What to Import from lib/game
```zig
// Utility systems that work well
const ai_control = @import("../lib/game/control/mod.zig");
const behaviors = @import("../lib/game/behaviors/mod.zig");
const cooldowns = @import("../lib/game/cooldowns.zig");
const BulletPool = @import("../lib/game/projectiles/bullet_pool.zig").BulletPool;
const game_systems = @import("../lib/game/mod.zig"); // For StateManager
```

### What NOT to Use
```zig
// hex has its own simpler versions
// ❌ Don't use World, Zone, Game classes
// ❌ Don't use ArchetypeStorage
// ❌ Don't use ComponentRegistry
// ❌ Don't use complex EntityId with generations
```

## Directory Structure

```
game/
├── control/          # ✅ PRODUCTION - AI control system
├── behaviors/        # ✅ PRODUCTION - AI behaviors (chase, return)
├── state/           # ✅ PRODUCTION - Save/load management
├── events/          # ✅ PRODUCTION - Event system
├── projectiles/     # ✅ PRODUCTION - Bullet pool
├── cooldowns.zig    # ✅ PRODUCTION - Cooldown management
│
├── ecs.zig          # ⚠️ EXPERIMENTAL - Dual architecture
├── world.zig        # ⚠️ EXPERIMENTAL - Archetype world
├── zone.zig         # ⚠️ EXPERIMENTAL - Zone management
├── game.zig         # ⚠️ EXPERIMENTAL - Multi-zone game
├── archetype_*.zig  # ⚠️ EXPERIMENTAL - Storage systems
└── components.zig   # ⚠️ MIXED - Some used, some not
```

## Understanding the Two Architectures

### 1. Complex ECS (lib/game) - Experimental
```zig
// Rich but unused architecture
Game → Zone[] → World → ArchetypeStorage
- Generation-tracked entity IDs
- Dynamic archetype storage
- System registry pipeline
- Cross-zone entity tracking
```

### 2. Simple Arrays (hex) - Production
```zig
// What's actually used
HexGame → zones[7] → Direct Storage Arrays
- Simple u32 entity IDs
- Fixed-size arrays
- Direct function calls
- No abstraction layers
```

## Production Components Guide

### AI Control System
```zig
// Lock-free memory-mapped input
const ai = try ai_control.MappedInput.init(".ai_commands");
ai.processCommands(&input_state);
// ~50ns per command, zero allocations
```

### Behavior Utilities
```zig
// Simple, effective AI behaviors
const velocity = behaviors.simpleChase(
    transform.pos, target_pos, is_alive,
    aggro_range, min_distance, speed, aggro_mult
);
```

### Cooldown Management
```zig
// Reusable cooldown tracking
var cooldowns = Cooldowns.init();
cooldowns.startCooldown("spell_blink", 3.0);
if (cooldowns.isReady("spell_blink")) {
    // Cast spell
}
```

### State Management
```zig
// Save/load with caching
const manager = StateManager(SaveData, Events).init(allocator, "game", "save");
try manager.save();
const data = try manager.load();
```

## When to Use Which System

### Use hex's Simple Approach When:
- Building a game with known scope
- Performance is critical
- Simplicity is valued
- Fixed entity types

### Consider lib/game Complex System When:
- Building a framework/engine
- Need dynamic entity composition
- Complex entity relationships
- System modularity required

## Known Issues & Inconsistencies

1. **EntityId Mismatch**: hex uses both `ecs.EntityId` and its own `EntityId`
2. **Component Confusion**: Mixed usage of lib/game and hex components
3. **Partial Integration**: Only utilities used, not core architecture

## Future Direction

The experimental ECS architecture may be removed or moved to a separate experimental branch. The production utilities (AI control, behaviors, cooldowns, state management) will remain as they provide real value to game implementations.

## For New Development

1. **For new games**: Copy hex's simple approach, import lib/game utilities
2. **For engine work**: Consider if complex ECS is actually needed
3. **For utilities**: Add to production components, not experimental

## Testing

```bash
# Test production components
zig test src/lib/game/control/test_ai_control.zig
zig test src/lib/game/state/test_state_manager.zig

# hex game (actual usage)
zig build run
```

## Related Documentation

- [COMPARISON.md](./COMPARISON.md) - Detailed lib/game vs hex analysis
- [Architecture Overview](../../../docs/architecture.md) - Engine architecture
- [Hex Game](../../hex/CLAUDE.md) - Actual game implementation