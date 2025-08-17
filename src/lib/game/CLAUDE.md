# Game Library - Reusable Game Systems

This directory contains reusable game systems and utilities designed to be extremely open-ended. The engine provides interfaces and patterns - games provide implementations.

## Core Architecture Principle

**Engine provides interfaces, games provide implementations.** This ensures games remain fully customizable while benefiting from shared infrastructure. No game-specific logic is hardcoded here.

## What's Here

### Core Helpers
- `cooldowns.zig` - Simple cooldown timers for abilities
- `components.zig` - Basic component definitions (Transform, Health, Visual, etc.)
- `ecs.zig` - Minimal exports, just EntityId = u32
- `mod.zig` - Main module exports

### Behaviors
- `behaviors/mod.zig` - AI behavior utilities
- `behaviors/chase_behavior.zig` - Simple chase logic
- `behaviors/return_home_behavior.zig` - Return to home position

### Control
- `control/mod.zig` - AI control system
- `control/direct_input.zig` - Memory-mapped input for external AI

### Projectiles
- `projectiles/bullet_pool.zig` - Rate-limited bullet pool system

### Persistence (Planned)
- `persistence/save_system.zig` - Generic save/load interfaces
- `persistence/statistics.zig` - Game statistics tracking patterns
- Games implement specific save data structures

### Abilities (Planned)
- `abilities/spell_slots.zig` - Generic spell slot management
- `abilities/ability_interface.zig` - Ability casting patterns
- Games implement specific spells and effects

### Systems (Planned)
- `systems/respawn.zig` - Respawn interface and checkpoint patterns
- `systems/damage.zig` - Damage calculation interfaces
- Games implement specific respawn logic and damage formulas

### Input (Planned)
- `input/input_patterns.zig` - Common input handling patterns
- `input/dead_player_handler.zig` - Input handling when player is dead
- `input/action_priority.zig` - Action priority system
- Games map specific keys to actions

## What Was Removed

We deleted the over-engineered ECS system including:
- Complex archetype storage with metaprogramming
- Dynamic component/system registries  
- Entity generation tracking and recycling
- Multi-layer Game→Zone→World abstractions
- Complex persistence and event systems
- State management with caching

## Design Philosophy

- **Simple is better** - Direct arrays and function calls
- **Performance first** - No unnecessary abstractions
- **Actually used** - Only keep what the game needs
- **No magic** - Clear, obvious code
- **Interfaces, not implementations** - Provide patterns games can customize
- **Open-ended by design** - Never hardcode game-specific logic

## Usage Examples

### Using Generic Systems in Your Game

```zig
// Import generic systems
const cooldowns = @import("lib/game/cooldowns.zig");
const bullet_pool = @import("lib/game/projectiles/bullet_pool.zig");
const spell_slots = @import("lib/game/abilities/spell_slots.zig");

// Your game provides the implementation
const MySpell = struct {
    slot: spell_slots.SpellSlot,
    // Game-specific spell data
    damage: f32,
    effect_type: MyEffectType,
};
```

### How Hex Game Uses These Systems

The hex game demonstrates proper usage:
- Uses `bullet_pool.zig` for combat system
- Uses `cooldowns.zig` for spell cooldowns
- Uses `control/` for AI integration
- Implements hex-specific logic (zones, portals, specific spells) in `src/hex/`

## Separation of Concerns

**What belongs in lib/game:**
- Generic interfaces and patterns
- Reusable data structures
- Common algorithms (pathfinding, collision patterns)
- Input handling patterns
- Save/load interfaces

**What stays in your game (e.g., src/hex):**
- Specific entity types and behaviors
- Game-specific constants and tuning
- Concrete implementations of spells/abilities
- World/level data and structure
- Game-specific rendering details