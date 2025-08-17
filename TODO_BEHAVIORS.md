# ✅ COMPLETED: Fix Unit Behavior System to Use ZON Data

## Problem
Currently the behavior system assigns behaviors based on entity ID modulo (`entity_id % 5`) rather than using actual data from the ZON file. The ZON parser structure is also limited to only `position` and `radius` fields for units, making it impossible to specify behaviors declaratively.

## Goal
Make unit behaviors data-driven through the ZON file using proper enum syntax and sensible defaults.

## Implementation Plan

### 1. Update BehaviorProfile enum to include idle as default
```zig
pub const BehaviorProfile = enum {
    idle,        // Default - basic aggro when player in range
    aggressive,  // Chase-focused, minimal flee
    defensive,   // Flee-focused, guard home
    patrolling,  // Patrol routes, guard when threatened
    wandering,   // Wander randomly, flee when threatened
    guardian,    // Guard specific area, intercept threats
};
```

### 2. Refactor idle behavior with basic aggro characteristics
- Move current simple chase logic into idle behavior
- Idle units attack when player is in range but don't pursue far
- Return to home position when player leaves aggro range
- Add idle behavior configuration with appropriate priorities

### 3. Update ZON structure to use enum directly
**File: `src/hex/loader.zig`**
```zig
units: ?[]const struct {
    position: struct { x: f32, y: f32 },
    radius: f32,
    behavior: BehaviorProfile = .idle,  // Enum with default
}
```

### 4. Update game_data.zon with enum syntax
**File: `src/hex/game_data.zon`**
```zon
.units = .{
    .{ .position = .{ .x = 850.0, .y = 150.0 }, .radius = 8.0 }, // No behavior = .idle default
    .{ .position = .{ .x = 1350.0, .y = 300.0 }, .radius = 9.0, .behavior = .defensive },
    .{ .position = .{ .x = 350.0, .y = 350.0 }, .radius = 7.0, .behavior = .patrolling },
    .{ .position = .{ .x = 1550.0, .y = 450.0 }, .radius = 8.0, .behavior = .wandering },
    .{ .position = .{ .x = 200.0, .y = 600.0 }, .radius = 9.0, .behavior = .guardian },
    .{ .position = .{ .x = 1450.0, .y = 650.0 }, .radius = 8.0, .behavior = .aggressive },
    // Mix of behaviors throughout all zones...
}
```

### 5. Add idle behavior configuration
**File: `src/hex/behaviors.zig`**
```zig
/// Create idle behavior config (basic aggro, returns home)
pub fn idle(home_pos: Vec2, detection_range: f32, chase_speed: f32) UnitBehaviorConfig {
    var config = UnitBehaviorConfig.init(
        home_pos, 
        detection_range, 
        20.0, // min_distance
        chase_speed, 
        chase_speed * 0.5, // walk_speed
        1.5, // chase_duration (short)
        15.0, // home_tolerance
        1.05 // lose_tolerance (tight)
    );
    config.behavior_priorities.chase = .low;         // Will chase but not aggressively
    config.behavior_priorities.return_home = .normal; // Returns home when player leaves
    config.behavior_priorities.wander = .lowest;     // Minimal wandering
    return config;
}
```

### 6. Update Unit component to store behavior
**File: `src/hex/hex_game.zig`**
```zig
pub const Unit = struct {
    unit_type: UnitType,
    behavior_profile: BehaviorProfile = .idle,  // Default to idle
    aggro_range: f32,
    aggro_factor: f32,
    home_pos: Vec2,
    target: ?EntityId,
    
    // AI behavior state
    state: UnitState,
    target_pos: Vec2,
    chase_timer: f32,
    
    pub fn init(unit_type: UnitType, home_pos: Vec2, behavior: BehaviorProfile) Unit {
        return .{
            .unit_type = unit_type,
            .behavior_profile = behavior,  // Store behavior from ZON
            .aggro_range = if (unit_type == .enemy) 150.0 else 0.0,
            .aggro_factor = 1.0,
            .home_pos = home_pos,
            .target = null,
            .state = .returning_home,
            .target_pos = Vec2.ZERO,
            .chase_timer = 0,
        };
    }
}
```

### 7. Update createUnit to accept behavior parameter
**File: `src/hex/hex_game.zig`**
```zig
pub fn createUnit(self: *HexGame, zone_index: u8, pos: Vec2, radius: f32, behavior: BehaviorProfile) !EntityId {
    if (zone_index >= MAX_ZONES) return error.InvalidZone;
    
    const zone = &self.zones[zone_index];
    const entity = self.entity_allocator.create();
    
    const transform = Transform.init(pos, radius);
    const health = Health.init(50);
    const unit = Unit.init(.enemy, pos, behavior);  // Use provided behavior
    const visual = Visual.init(constants.COLOR_UNIT_DEFAULT);
    
    try zone.units.addEntity(entity, transform, health, unit, visual);
    zone.entity_count += 1;
    
    return entity;
}
```

### 8. Update loader to pass behavior from ZON
**File: `src/hex/loader.zig`**
```zig
// Load units as ECS entities
if (data.units) |units| {
    for (units) |unit_data| {
        // Create ECS unit entity with behavior from ZON data
        const unit_id = game.createUnit(
            @intCast(zone_index),
            Vec2{ .x = unit_data.position.x, .y = unit_data.position.y },
            unit_data.radius,
            unit_data.behavior,  // Pass enum directly, defaults to .idle
        ) catch |err| {
            loggers.getGameLog().err("unit_create_fail", "Failed to create unit entity: {}", .{err});
            continue;
        };

        _ = unit_id; // Unit created successfully
    }
}
```

### 9. Update behaviors.zig to use stored behavior
**File: `src/hex/behaviors.zig`**
```zig
/// Determine behavior profile from stored unit data (not entity ID)
fn determineBehaviorProfile(entity_id: u32, unit_comp: *const Unit) BehaviorProfile {
    _ = entity_id; // No longer needed - use stored behavior
    return unit_comp.behavior_profile; // Use stored value from ZON
}

/// Create behavior config based on profile (add idle case)
pub fn createBehaviorConfig(profile: BehaviorProfile, home_pos: Vec2) unit_behavior.UnitBehaviorConfig {
    return switch (profile) {
        .idle => idle(home_pos, constants.UNIT_DETECTION_RADIUS, constants.UNIT_CHASE_SPEED),
        .aggressive => unit_behavior.UnitBehaviorConfig.aggressive(
            home_pos,
            constants.UNIT_DETECTION_RADIUS,
            constants.UNIT_CHASE_SPEED,
        ),
        .defensive => unit_behavior.UnitBehaviorConfig.defensive(
            home_pos,
            constants.UNIT_DETECTION_RADIUS,
            constants.UNIT_CHASE_SPEED * 1.2,
        ),
        .patrolling => unit_behavior.UnitBehaviorConfig.patrolling(
            home_pos,
            constants.UNIT_DETECTION_RADIUS,
            constants.UNIT_WALK_SPEED,
        ),
        .wandering => /* existing wandering config */,
        .guardian => /* existing guardian config */,
    };
}
```

## Benefits

- **Type-safe**: Enums everywhere, no string parsing needed
- **Efficient**: Direct enum comparison at runtime, no conversion overhead
- **Readable**: `.patrolling` is clear and concise in ZON files
- **Sensible default**: Idle units have basic aggro but aren't overly aggressive
- **Data-driven**: Behaviors specified in ZON, not hardcoded by entity ID
- **Backwards compatible**: Old ZON files work with default `.idle` behavior

## Testing

1. Verify build compiles after each step
2. Test that units with no behavior field default to idle
3. Test that units with explicit behaviors work correctly
4. Verify each behavior type displays correct colors and AI patterns
5. Test in multiple zones to ensure variety works as expected

## Completion Criteria - ✅ ALL COMPLETED (August 17, 2025)

- [x] ZON structure updated to include behavior enum field
- [x] Unit component stores behavior profile from ZON
- [x] createUnit function accepts and uses behavior parameter
- [x] Loader passes behavior from ZON to createUnit
- [x] behaviors.zig uses stored behavior instead of entity ID modulo
- [x] Idle behavior configuration added with appropriate characteristics
- [x] game_data.zon updated with varied behaviors using enum syntax
- [x] All zones have interesting behavior variety
- [x] Build compiles and game runs with new behavior system
- [x] Visual verification that different behaviors display different colors/patterns

## Final Implementation Summary

**Successfully transformed the behavior system from hardcoded entity ID modulo to fully data-driven ZON configuration:**

1. **enum BehaviorProfile** added to hex_game.zig with idle as default
2. **ZON Structure** updated to support `.behavior = .aggressive` syntax
3. **Unit Component** stores behavior_profile field from ZON data
4. **createUnit Function** accepts behavior parameter and passes to Unit.init
5. **Loader** passes `unit_data.behavior` directly to createUnit
6. **behaviors.zig** uses stored `unit_comp.behavior_profile` instead of entity ID
7. **game_data.zon** updated with mix of explicit behaviors and defaults
8. **Testing** confirmed units default to idle when no behavior specified
9. **Visual Verification** game runs at 143 FPS with varied unit behaviors

**Key Benefits Achieved:**
- Type-safe enum values prevent typos
- Direct enum comparison for efficiency
- Readable `.patrolling` syntax in ZON files
- Sensible `.idle` default for backwards compatibility
- Fully data-driven, no hardcoded logic
- Zero breaking changes to existing zones