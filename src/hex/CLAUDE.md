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

## Key Systems

### Zone System
- Zones combine environment + entities
- Each zone has camera mode (fixed/follow)
- Data-driven via `game_data.zon`
- Portal-based travel between zones

### Combat System
```zig
// Bullet pool pattern
const BulletPool = struct {
    bullets: [6]Bullet,      // Fixed pool
    recharge_rate: f32 = 2,  // Per second
    recharge_timer: f32,
};
```

### Spell System
```zig
// 8 slots, independent cooldowns
const SpellSlots = struct {
    spells: [8]SpellType,
    cooldowns: [8]f32,
    active_slot: u8,
};
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