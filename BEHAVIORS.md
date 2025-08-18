# Hex Behaviors System

**Architecture**: Modular composition using lib/game behavior modules  
**Performance**: 6-7ms frame times, zero allocations in update loop  
**Design**: Engine provides modules, game composes behaviors via profiles

## Module Structure

```
src/hex/behaviors/
├── mod.zig              # Public API - import from here
├── composer.zig         # BehaviorComposer state container  
├── profiles.zig         # 4 behavior profiles with configs
├── evaluators.zig       # Profile evaluation logic
├── entity_mapping.zig   # Stable entity ID system
└── integration.zig      # Main update coordination
```

## Usage

```zig
const behaviors = @import("behaviors/mod.zig");

// Initialize system
behaviors.initBehaviorSystem(allocator);
defer behaviors.deinitBehaviorSystem();

// Update units
behaviors.updateUnitWithAggroMod(
    unit_comp, transform, visual,
    player_pos, player_alive, aggro_multiplier, frame_ctx
);
```

## Behavior Types

Active behaviors tracked per unit:
- `idle` - Stationary or returning home
- `chasing` - Pursuing player (hostile/friendly)
- `fleeing` - Escaping from player (fearful)
- `wandering` - Exploring near home (neutral/friendly)
- `returning_home` - Moving back to spawn point

## Behavior Profiles

- **Hostile** - Aggressive chasers (red units)
- **Fearful** - Flee from player, return home (orange units)  
- **Neutral** - Ignore player, wander near home (gray units)
- **Friendly** - Follow player gently, explore (green units)

## Architecture Benefits

- **Modular**: Each file has single responsibility
- **Extensible**: New profiles just add to profiles.zig
- **Testable**: Individual modules can be tested separately
- **Clean**: Removed unused behavior types, streamlined enums
- **Performance**: Zero behavioral changes, same frame times

The system demonstrates capability-based organization where the engine provides behavior primitives and the game composes them into meaningful AI profiles.