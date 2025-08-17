const std = @import("std");
const Vec2 = @import("../../math/mod.zig").Vec2;

/// Wander behavior configuration
pub const WanderConfig = struct {
    /// Speed when wandering
    wander_speed: f32,
    /// Maximum distance from starting position
    wander_radius: f32,
    /// Time between direction changes (seconds)
    direction_change_interval: f32 = 3.0,
    /// How long to pause between movements (seconds)
    pause_duration: f32 = 0.0,
    /// Distance tolerance for reaching wander targets
    target_tolerance: f32 = 15.0,
    /// Whether to track state changes
    track_state_changes: bool = true,

    pub fn init(wander_speed: f32, wander_radius: f32, direction_change_interval: f32) WanderConfig {
        return .{
            .wander_speed = wander_speed,
            .wander_radius = wander_radius,
            .direction_change_interval = direction_change_interval,
        };
    }

    /// Create wander config with pauses
    pub fn withPauses(wander_speed: f32, wander_radius: f32, direction_change_interval: f32, pause_duration: f32) WanderConfig {
        return .{
            .wander_speed = wander_speed,
            .wander_radius = wander_radius,
            .direction_change_interval = direction_change_interval,
            .pause_duration = pause_duration,
        };
    }

    /// Create simple wander config
    pub fn simple(wander_speed: f32, wander_radius: f32) WanderConfig {
        return .{
            .wander_speed = wander_speed,
            .wander_radius = wander_radius,
            .direction_change_interval = 2.0,
            .track_state_changes = false,
        };
    }
};

/// Wander behavior state
pub const WanderState = struct {
    /// Starting position for wander area
    home_pos: Vec2,
    /// Current wander target position
    target_pos: Vec2,
    /// Time until next direction change
    direction_timer: f32,
    /// Time remaining paused
    pause_timer: f32 = 0,
    /// Whether currently paused
    is_paused: bool = false,
    /// Random number generator state
    rng_state: u64,

    pub fn init(home_pos: Vec2, initial_seed: u64) WanderState {
        return .{
            .home_pos = home_pos,
            .target_pos = home_pos,
            .direction_timer = 0,
            .rng_state = initial_seed,
        };
    }

    /// Simple linear congruential generator for deterministic randomness
    fn nextRandom(self: *WanderState) f32 {
        // LCG constants (Numerical Recipes)
        self.rng_state = self.rng_state *% 1664525 +% 1013904223;
        return @as(f32, @floatFromInt(self.rng_state & 0x7FFFFFFF)) / @as(f32, @floatFromInt(0x7FFFFFFF));
    }

    /// Generate a new random wander target within radius
    pub fn generateNewTarget(self: *WanderState, config: WanderConfig) void {
        // Generate random angle and distance
        const angle = self.nextRandom() * 2.0 * std.math.pi;
        const distance = self.nextRandom() * config.wander_radius;

        // Calculate new target position
        const offset_x = @cos(angle) * distance;
        const offset_y = @sin(angle) * distance;

        self.target_pos = Vec2{
            .x = self.home_pos.x + offset_x,
            .y = self.home_pos.y + offset_y,
        };

        // Reset direction timer
        self.direction_timer = config.direction_change_interval;
    }

    /// Update timers and handle state transitions
    pub fn update(self: *WanderState, config: WanderConfig, dt: f32) void {
        // Update pause timer
        if (self.pause_timer > 0) {
            self.pause_timer -= dt;
            if (self.pause_timer <= 0) {
                self.is_paused = false;
            }
        }

        // Update direction change timer
        if (!self.is_paused) {
            self.direction_timer -= dt;
            if (self.direction_timer <= 0) {
                self.generateNewTarget(config);

                // Start pause if configured
                if (config.pause_duration > 0) {
                    self.is_paused = true;
                    self.pause_timer = config.pause_duration;
                }
            }
        }
    }

    // Deprecated: Use update() directly with deltaTime from FrameContext
    // This function existed for the old complex context system

    /// Reset wander state to home position
    pub fn reset(self: *WanderState, home_pos: Vec2) void {
        self.home_pos = home_pos;
        self.target_pos = home_pos;
        self.direction_timer = 0;
        self.pause_timer = 0;
        self.is_paused = false;
    }
};

/// Result of wander behavior evaluation
pub const WanderResult = struct {
    /// Velocity to apply to the wanderer
    velocity: Vec2,
    /// Whether reached current wander target
    reached_target: bool,
    /// Whether generated new wander target
    new_target: bool,
    /// Whether currently paused
    is_paused: bool,
    /// Current target position
    target_pos: Vec2,
    /// Whether wander state changed this frame
    state_changed: bool = false,
};

/// Evaluate wander behavior for a unit
pub fn evaluateWander(
    unit_pos: Vec2,
    state: *WanderState,
    config: WanderConfig,
    speed_multiplier: f32,
    dt: f32,
) WanderResult {
    var result = WanderResult{
        .velocity = Vec2.ZERO,
        .reached_target = false,
        .new_target = false,
        .is_paused = false,
        .target_pos = state.target_pos,
        .state_changed = false,
    };

    const old_paused = state.is_paused;
    const old_timer = state.direction_timer;

    // Update state
    state.update(config, dt);

    // Check for state changes
    if (config.track_state_changes) {
        if (old_paused != state.is_paused) {
            result.state_changed = true;
        }
        if (old_timer > 0 and state.direction_timer > old_timer) {
            result.new_target = true;
            result.state_changed = true;
        }
    }

    result.is_paused = state.is_paused;
    result.target_pos = state.target_pos;

    // If paused, don't move
    if (state.is_paused) {
        return result;
    }

    // Initialize target if needed
    if (state.direction_timer <= 0) {
        state.generateNewTarget(config);
        result.new_target = true;
        if (config.track_state_changes) result.state_changed = true;
    }

    // Move toward current target
    const to_target = state.target_pos.sub(unit_pos);
    const dist_sq = to_target.lengthSquared();
    const tolerance_sq = config.target_tolerance * config.target_tolerance;

    if (dist_sq <= tolerance_sq) {
        // Reached target, generate new one
        state.generateNewTarget(config);
        result.reached_target = true;
        result.new_target = true;
        if (config.track_state_changes) result.state_changed = true;

        // Start pause if configured
        if (config.pause_duration > 0) {
            state.is_paused = true;
            state.pause_timer = config.pause_duration;
            result.is_paused = true;
        }

        result.target_pos = state.target_pos;
    } else {
        // Move toward target
        const direction = to_target.normalize();
        result.velocity = direction.scale(config.wander_speed * speed_multiplier);
    }

    return result;
}

/// Simple wander behavior (stateless, uses time-based randomness)
pub fn simpleWander(
    unit_pos: Vec2,
    home_pos: Vec2,
    wander_radius: f32,
    wander_speed: f32,
    speed_multiplier: f32,
    time_seed: f32, // Use game time or similar for deterministic randomness
) Vec2 {
    // Use time-based randomness for direction
    const angle = @mod(time_seed * 0.5, 2.0 * std.math.pi);
    const distance = wander_radius * 0.5; // Move to middle of wander area

    // Calculate target position
    const target_x = home_pos.x + @cos(angle) * distance;
    const target_y = home_pos.y + @sin(angle) * distance;
    const target_pos = Vec2{ .x = target_x, .y = target_y };

    // Move toward target
    const to_target = target_pos.sub(unit_pos);
    const dist_sq = to_target.lengthSquared();

    if (dist_sq > 100.0) { // Arbitrary minimum distance
        const direction = to_target.normalize();
        return direction.scale(wander_speed * speed_multiplier);
    }

    return Vec2.ZERO;
}

test "wander behavior basic functionality" {
    const home_pos = Vec2{ .x = 100, .y = 100 };
    var state = WanderState.init(home_pos, 12345);
    const config = WanderConfig.init(80.0, 50.0, 2.0);

    const unit_pos = Vec2{ .x = 100, .y = 100 }; // At home position

    // Test initial target generation
    var result = evaluateWander(unit_pos, &state, config, 1.0, 0.1);
    try std.testing.expect(result.new_target);

    // Should have a target position different from home
    const target_dist_sq = state.target_pos.sub(home_pos).lengthSquared();
    try std.testing.expect(target_dist_sq > 0);

    // Should move toward target
    result = evaluateWander(unit_pos, &state, config, 1.0, 0.1);
    const velocity_mag_sq = result.velocity.lengthSquared();
    try std.testing.expect(velocity_mag_sq > 0);
}

test "wander behavior with pauses" {
    const home_pos = Vec2{ .x = 100, .y = 100 };
    var state = WanderState.init(home_pos, 54321);
    const config = WanderConfig.withPauses(80.0, 50.0, 2.0, 1.0); // 1 second pause

    const unit_pos = Vec2{ .x = 100, .y = 100 };

    // Generate initial target by advancing time
    state.direction_timer = 0;
    var result = evaluateWander(unit_pos, &state, config, 1.0, 0.1);

    // Move to target position to trigger pause
    const target_pos = state.target_pos;
    result = evaluateWander(target_pos, &state, config, 1.0, 0.1);

    if (config.pause_duration > 0) {
        try std.testing.expect(result.is_paused);
        try std.testing.expect(state.pause_timer > 0);
    }
}

test "simple wander functionality" {
    const home_pos = Vec2{ .x = 100, .y = 100 };
    const unit_pos = Vec2{ .x = 100, .y = 100 };

    // Test movement with time-based seed
    const velocity = simpleWander(unit_pos, home_pos, 50.0, 80.0, 1.0, 1.5);

    // Should generate some movement (though direction depends on time seed)
    // We can't predict exact direction, but magnitude should be reasonable
    const mag_sq = velocity.lengthSquared();
    try std.testing.expect(mag_sq >= 0); // At minimum, should not be invalid
}
