const std = @import("std");
const Vec2 = @import("../../math/mod.zig").Vec2;

/// Flee behavior configuration
pub const FleeConfig = struct {
    /// Distance at which to start fleeing
    danger_range: f32,
    /// Distance to maintain when fleeing
    safe_distance: f32,
    /// Speed when fleeing
    flee_speed: f32,
    /// How long to flee after leaving danger zone (seconds)
    flee_duration: f32 = 2.0,
    /// Whether to use timer-based flee continuation
    use_flee_timer: bool = true,
    /// Whether to track state changes
    track_state_changes: bool = true,

    pub fn init(danger_range: f32, safe_distance: f32, flee_speed: f32, flee_duration: f32) FleeConfig {
        return .{
            .danger_range = danger_range,
            .safe_distance = safe_distance,
            .flee_speed = flee_speed,
            .flee_duration = flee_duration,
        };
    }

    /// Create a simple flee config without timers
    pub fn simple(danger_range: f32, safe_distance: f32, flee_speed: f32) FleeConfig {
        return .{
            .danger_range = danger_range,
            .safe_distance = safe_distance,
            .flee_speed = flee_speed,
            .flee_duration = 0,
            .use_flee_timer = false,
            .track_state_changes = false,
        };
    }
};

/// Flee behavior state
pub const FleeState = struct {
    /// Whether currently fleeing
    is_fleeing: bool = false,
    /// Position to flee from
    threat_pos: Vec2 = Vec2.ZERO,
    /// Time remaining in flee mode (seconds)
    flee_timer: f32 = 0,

    pub fn init() FleeState {
        return .{};
    }

    /// Reset to idle state
    pub fn reset(self: *FleeState) void {
        self.is_fleeing = false;
        self.threat_pos = Vec2.ZERO;
        self.flee_timer = 0;
    }

    /// Start fleeing from a threat
    pub fn startFlee(self: *FleeState, threat_pos: Vec2, duration: f32) void {
        self.is_fleeing = true;
        self.threat_pos = threat_pos;
        self.flee_timer = duration;
    }

    /// Update flee timer and state
    pub fn update(self: *FleeState, dt: f32, use_timer: bool) void {
        if (use_timer and self.flee_timer > 0) {
            self.flee_timer -= dt;
            if (self.flee_timer <= 0) {
                self.is_fleeing = false;
            }
        }
    }

    // Timer management for flee duration
};

/// Result of flee behavior evaluation
pub const FleeResult = struct {
    /// Velocity to apply to the fleer
    velocity: Vec2,
    /// Whether started fleeing from a new threat
    started_fleeing: bool,
    /// Whether stopped fleeing (reached safety)
    stopped_fleeing: bool,
    /// Whether currently fleeing
    is_fleeing: bool,
    /// Whether flee state changed this frame
    state_changed: bool = false,
};

/// Evaluate flee behavior for a unit
pub fn evaluateFlee(
    unit_pos: Vec2,
    threat_pos: Vec2,
    threat_active: bool,
    state: *FleeState,
    config: FleeConfig,
    speed_multiplier: f32,
    dt: f32,
) FleeResult {
    var result = FleeResult{
        .velocity = Vec2.ZERO,
        .started_fleeing = false,
        .stopped_fleeing = false,
        .is_fleeing = false,
        .state_changed = false,
    };

    const old_flee_state = state.is_fleeing;

    // Update flee timer if enabled
    state.update(dt, config.use_flee_timer);

    // If threat is not active, stop fleeing
    if (!threat_active) {
        if (state.is_fleeing) {
            result.stopped_fleeing = true;
            if (config.track_state_changes) result.state_changed = true;
        }
        state.reset();
        return result;
    }

    const to_threat = threat_pos.sub(unit_pos);
    const dist_sq = to_threat.lengthSquared();
    const danger_sq = config.danger_range * config.danger_range;
    const safe_sq = config.safe_distance * config.safe_distance;

    // Check if we should start fleeing
    if (!state.is_fleeing and dist_sq <= danger_sq) {
        state.startFlee(threat_pos, config.flee_duration);
        result.started_fleeing = true;
        if (config.track_state_changes) result.state_changed = true;
    }

    // If currently fleeing
    if (state.is_fleeing) {
        // Update threat position
        state.threat_pos = threat_pos;

        // Calculate flee velocity if not far enough
        if (dist_sq < safe_sq) {
            const direction = to_threat.normalize().scale(-1.0); // Flee away from threat
            result.velocity = direction.scale(config.flee_speed * speed_multiplier);
            result.is_fleeing = true;
        } else {
            // Reached safe distance - stop fleeing
            state.is_fleeing = false;
            result.stopped_fleeing = true;
            if (config.track_state_changes) result.state_changed = true;
            result.is_fleeing = false;
        }
    }

    // Check if state changed
    if (config.track_state_changes and old_flee_state != state.is_fleeing) {
        result.state_changed = true;
    }

    return result;
}

// Simplified stateless API - use evaluateFlee() for full state tracking

/// Simplified flee behavior for basic AI (stateless)
pub fn simpleFlee(
    unit_pos: Vec2,
    threat_pos: Vec2,
    threat_active: bool,
    danger_range: f32,
    flee_speed: f32,
    speed_multiplier: f32,
) Vec2 {
    if (!threat_active) return Vec2.ZERO;

    const to_threat = threat_pos.sub(unit_pos);
    const dist_sq = to_threat.lengthSquared();
    const danger_sq = danger_range * danger_range;

    // Flee if within danger range
    if (dist_sq <= danger_sq) {
        const direction = to_threat.normalize().scale(-1.0); // Away from threat
        return direction.scale(flee_speed * speed_multiplier);
    }

    return Vec2.ZERO;
}

test "flee behavior basic functionality" {
    var state = FleeState.init();
    const config = FleeConfig.init(100.0, 150.0, 200.0, 2.0);

    const unit_pos = Vec2{ .x = 0, .y = 0 };
    const threat_pos = Vec2{ .x = 50, .y = 0 }; // Within danger range

    // Test initial flee detection
    var result = evaluateFlee(unit_pos, threat_pos, true, &state, config, 1.0, 0.1);
    try std.testing.expect(result.started_fleeing);
    try std.testing.expect(result.is_fleeing);
    try std.testing.expect(result.velocity.x < 0); // Should flee away from threat

    // Test stopping flee when threat gone
    result = evaluateFlee(unit_pos, threat_pos, false, &state, config, 1.0, 0.1);
    try std.testing.expect(result.stopped_fleeing);
    try std.testing.expect(!result.is_fleeing);
}

test "simple flee functionality" {
    const unit_pos = Vec2{ .x = 0, .y = 0 };
    const threat_pos = Vec2{ .x = 50, .y = 0 };

    // Test flee when in danger
    var velocity = simpleFlee(unit_pos, threat_pos, true, 100.0, 200.0, 1.0);
    try std.testing.expect(velocity.x < 0); // Should flee away

    // Test no flee when threat inactive
    velocity = simpleFlee(unit_pos, threat_pos, false, 100.0, 200.0, 1.0);
    try std.testing.expect(velocity.x == 0.0 and velocity.y == 0.0);

    // Test no flee when out of danger range
    const far_threat = Vec2{ .x = 200, .y = 0 };
    velocity = simpleFlee(unit_pos, far_threat, true, 100.0, 200.0, 1.0);
    try std.testing.expect(velocity.x == 0.0 and velocity.y == 0.0);
}

test "flee config variations" {
    // Test simple config (no timers)
    const simple_config = FleeConfig.simple(100.0, 150.0, 200.0);
    try std.testing.expect(!simple_config.use_flee_timer);
    try std.testing.expect(!simple_config.track_state_changes);

    // Test full config
    const full_config = FleeConfig.init(100.0, 150.0, 200.0, 2.0);
    try std.testing.expect(full_config.use_flee_timer);
    try std.testing.expect(full_config.track_state_changes);
}

test "flee stops at safe distance" {
    var state = FleeState.init();
    const config = FleeConfig.init(100.0, 150.0, 200.0, 0.0); // No timer
    
    // Unit at origin, threat nearby - start fleeing
    const unit_pos = Vec2{ .x = 0, .y = 0 };
    const threat_pos = Vec2{ .x = 50, .y = 0 };
    
    var result = evaluateFlee(unit_pos, threat_pos, true, &state, config, 1.0, 0.1);
    try std.testing.expect(result.started_fleeing);
    try std.testing.expect(result.is_fleeing);
    try std.testing.expect(result.velocity.x < 0); // Should flee away
    
    // Unit reaches safe distance (beyond 150 safe distance)
    const safe_pos = Vec2{ .x = -160, .y = 0 };
    result = evaluateFlee(safe_pos, threat_pos, true, &state, config, 1.0, 0.1);
    
    // Should stop fleeing when safe
    try std.testing.expect(result.stopped_fleeing);
    try std.testing.expect(!result.is_fleeing);
    try std.testing.expect(result.velocity.x == 0.0 and result.velocity.y == 0.0);
    
    // Verify state was reset
    try std.testing.expect(!state.is_fleeing);
}
