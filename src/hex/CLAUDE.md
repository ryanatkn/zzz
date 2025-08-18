# Hex Game - AI Assistant Guide

> ⚠️ AI slop code and docs, is unstable and full of lies

Reference implementation of a 2D action RPG using the Zzz engine. This is a complete, playable game demonstrating engine capabilities.

## Quick Reference

**Type:** Zone-based action RPG with procedural graphics
**Status:** Fully playable with combat, spells, and progression
**Entry:** `main.zig` - game loop and initialization

## Architecture Overview

The game uses a zone-based world system (NOT traditional ECS):
- **Zones** own entities and define environments
- **Direct function calls** instead of systems/components
- **Simple arrays** for entity storage
- **Travel metaphor** between zones via portals

**Separation Strategy:** Hex uses generic systems from `lib/game` for reusable functionality while implementing all hex-specific behavior locally. This keeps the game extremely customizable while benefiting from shared infrastructure.

## File Structure

```
hex/
├── main.zig           # Entry point and game loop
├── game.zig           # Core game state management
├── game_renderer.zig  # Rendering implementation
├── entities.zig       # Zone-based entity system
├── player.zig         # Player controller
├── combat.zig         # Bullet pool and combat
├── spells.zig         # 8-slot spell system
├── behaviors.zig      # Entity AI behaviors
├── physics.zig        # Collision detection
├── effects.zig        # Visual effects system
├── portals.zig        # Zone travel system
├── borders.zig        # World boundary rendering
├── hud.zig            # HUD and UI elements
├── controls.zig       # Input mapping
├── constants.zig      # Game configuration
├── loader.zig         # ZON data parser
└── game_data.zon      # Zone definitions
```

## Import Conventions

**Capability-Based Organization:** Imports are grouped by functionality to make dependencies clear and maintainable.

```zig
const std = @import("std");

// Core capabilities (math, types, time)
const math = @import("../lib/math/mod.zig");
const colors = @import("../lib/core/colors.zig");
const frame = @import("../lib/core/frame.zig");

// Platform capabilities (SDL, input)
const c = @import("../lib/platform/sdl.zig");
const input = @import("../lib/platform/input.zig");

// Rendering capabilities
const camera = @import("../lib/rendering/camera.zig");
const simple_gpu_renderer = @import("../lib/rendering/gpu.zig");

// Game system capabilities
const game_systems = @import("../lib/game/mod.zig");
const GameParticleSystem = @import("../lib/particles/game_particles.zig").GameParticleSystem;

// Debug capabilities
const loggers = @import("../lib/debug/loggers.zig");

// Hex game modules (local)
const hex_game_mod = @import("hex_game.zig");
const constants = @import("constants.zig");
const behaviors = @import("behaviors/mod.zig");

// Type aliases after imports
const Vec2 = math.Vec2;
const FrameContext = frame.FrameContext;
const HexGame = hex_game_mod.HexGame;
```

**Rules:**
- **Never inline imports** in function signatures or function bodies
- **Group by capability** not alphabetically - shows architecture dependencies
- **Use descriptive aliases** for commonly used types
- **Module-level only** - all imports at the top
- **Comment groups** to make structure clear

## Key Systems

### What Hex Implements (Game-Specific)
- **Zone System:** Environment + entity ownership, camera modes, portal travel
- **Specific Spells:** Lull (aggro reduction), Blink (teleport), future spells
- **Unit Behaviors:** Chase, patrol, flee, aggro mechanics
- **World Data:** Zone layouts, spawn points, obstacle placement
- **Game Constants:** Damage values, speeds, sizes, colors

### What Hex Uses from lib/game (Generic Systems)
- **Bullet Pool:** Rate-limited projectile management (`lib/game/projectiles/`)
- **Cooldowns:** Timer management for abilities (`lib/game/cooldowns.zig`)
- **AI Control:** External input injection (`lib/game/control/`)
- **Basic Components:** Transform, Health, Visual (`lib/game/components.zig`)
- **Future:** Save system, spell slots, respawn interface, input patterns

### Example Integration
```zig
// Hex uses generic bullet pool
const BulletPool = @import("../lib/game/projectiles/bullet_pool.zig").BulletPool;

// But implements hex-specific combat logic
pub fn fireBullet(game: *HexGame, target: Vec2, pool: *BulletPool) bool {
    // Hex-specific: player alive check, zone-based projectiles
    if (!game.getPlayerAlive()) return false;
    if (!pool.canFire()) return false;
    
    // Create hex-specific projectile entity...
}
```

## Common Modifications

### Adding a New Zone
1. Edit `game_data.zon` to define zone
2. Add portal connections
3. Set camera mode and spawn points
4. Test with `zig build run`

### Creating a New Spell
1. Add spell type to `spells.zig`
2. Implement cast logic
3. Add visual effects in `effects.zig`
4. Map to keyboard slot (1-4, Q, E, R, F)

### Adding Entity Behaviors
1. Create behavior in `behaviors.zig`
2. Add to entity update loop
3. Use existing patterns (chase, patrol, flee)
4. Test collision with `physics.zig`

### Modifying Combat
1. Adjust constants in `constants.zig`
2. Bullet pool size in `combat.zig`
3. Damage values in collision handling
4. Recharge rates and timers

## Performance Guidelines

When modifying game code:
- Keep entity counts reasonable (<1000 per zone)
- Use squared distances for comparisons
- Batch similar entities in rendering
- Pool effects and bullets
- Avoid allocations in update loops

## Game Data Format (ZON)

```zon
.{
    .zones = .{
        .overworld = .{
            .width = 1600,
            .height = 1200,
            .camera_mode = .fixed,
            .spawn_point = .{ .x = 800, .y = 600 },
            .units = &[_]Unit{ ... },
            .obstacles = &[_]Obstacle{ ... },
            .portals = &[_]Portal{ ... },
        },
    },
}
```

## Testing Checklist

- [ ] All zones load correctly
- [ ] Portals connect properly
- [ ] Combat feels responsive
- [ ] Spells have correct effects
- [ ] No memory leaks
- [ ] 60 FPS maintained
- [ ] Save/load works

## Controls Reference

**Movement:** WASD, Shift=walk, Ctrl+click=move to
**Combat:** Left-click=shoot, Right-click=cast
**Spells:** 1-4, Q, E, R, F to select
**System:** Space=pause, R=respawn, G=AI control
**Debug:** Backtick=HUD overlay

## AI Control Integration

The game supports external AI control:
```zig
// Enable with G key
if (game.ai_control) |*ai| {
    ai.processCommands(&input_state);
}
```

See `web/ai_control/` for controller implementation.

## Common Issues

**Performance drops:**
- Check entity counts per zone
- Profile with ReleaseFast build
- Reduce effect particle counts

**Collision bugs:**
- Verify shape definitions
- Check physics.zig calculations
- Test with debug rendering

**Zone transitions:**
- Ensure portal pairs match
- Check spawn point validity
- Verify zone exists in data

## Related Documentation

- [Game Design](../../docs/game-design.md) - Mechanics details
- [Entity System](../../docs/hex/ecs.mdz) - Architecture
- [GPU Patterns](../../docs/hex/gpu.mdz) - Rendering details