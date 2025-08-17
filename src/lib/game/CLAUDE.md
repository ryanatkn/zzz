# Game Library - Simplified Helpers

This directory contains simple, reusable game utilities. No complex ECS or over-engineered abstractions.

## What's Here

### Core Helpers
- `cooldowns.zig` - Simple cooldown timers for abilities
- `components.zig` - Basic component definitions (Transform, Health, Visual, etc.)
- `ecs.zig` - Minimal exports, just EntityId = u32

### Behaviors
- `behaviors/mod.zig` - AI behavior utilities
- `behaviors/chase_behavior.zig` - Simple chase logic
- `behaviors/return_home_behavior.zig` - Return to home position

### Control
- `control/mod.zig` - AI control system
- `control/direct_input.zig` - Memory-mapped input for external AI

### Projectiles
- `projectiles/bullet_pool.zig` - Rate-limited bullet pool system

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

## Usage

These are standalone utilities that can be imported as needed:

```zig
const cooldowns = @import("lib/game/cooldowns.zig");
const bullet_pool = @import("lib/game/projectiles/bullet_pool.zig");
```

The hex game defines its own components and uses these utilities for specific functionality.