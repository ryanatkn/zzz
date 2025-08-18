# Hex Behaviors System

**Architecture**: Clean modular composition with hex-specific profiles  
**Performance**: 6-7ms frame times, optimized squared distance calculations  
**Design**: Engine provides primitives, game composes behaviors, caller controls visuals

## Module Structure

```
src/hex/behaviors/
├── mod.zig              # Public API - import from here
├── context.zig          # UnitUpdateContext for clean parameter passing
├── composer.zig         # BehaviorComposer state container  
├── profiles.zig         # 4 behavior profile configurations
├── evaluators.zig       # Profile evaluation logic + visual helpers
└── integration.zig      # Main update coordination and pure functions
```

## Usage

### Modern API (Recommended)
```zig
const behaviors = @import("behaviors/mod.zig");

// Initialize system
behaviors.initBehaviorSystem(allocator);
defer behaviors.deinitBehaviorSystem();

// Create update context
const context = behaviors.UnitUpdateContext.init(
    unit, transform, visual, player_pos, player_alive, frame_ctx
);

// Option 1: Full update including visuals
behaviors.updateUnit(context);

// Option 2: Separate evaluation and application (for custom visuals)
const result = behaviors.evaluateUnitBehavior(context);
behaviors.applyBehaviorResult(context, result);
// Custom visual handling here...
```

### Legacy API (Backward Compatible)
```zig
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

## Architecture Improvements

### ✅ **Removed Circular Dependencies**
- BehaviorProfile moved entirely to hex game (no more lib/game dependency)
- Engine provides primitives, games define specific profiles

### ✅ **Clean Interface**
- UnitUpdateContext replaces 7-parameter functions
- Pure evaluation functions for testing and custom logic
- Caller controls visual updates vs automatic application

### ✅ **Direct Entity IDs** 
- Entity ID stored directly in unit (no complex pointer mapping)
- Eliminated entity_mapping.zig entirely
- Simpler, faster ID access

### ✅ **Decoupled Visuals**
- Behavior system returns state, doesn't force visual changes
- `evaluateUnitBehavior()` for pure logic
- `applyBehaviorResult()` for controlled application
- Helper methods for color mapping when needed

### ✅ **Performance Optimizations**
- Squared distance calculations (avoid expensive sqrt)
- Fixed home_tolerance_sq usage confusion
- Direct field access vs complex mapping

## Benefits

- **Clean Separation**: Engine primitives vs game-specific profiles
- **Flexible Updates**: Pure functions + controllable side effects
- **Better Performance**: Direct IDs, squared distances, fewer allocations
- **Extensible**: Easy to add new profiles, behaviors, or visual systems
- **Testable**: Pure evaluation functions for unit testing

The system now follows proper dependency flow: engine provides tools, game composes behaviors, caller controls presentation.