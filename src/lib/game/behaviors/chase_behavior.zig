const std = @import("std");
const Vec2 = @import("../../math/mod.zig").Vec2;

/// Comprehensive chase behavior configuration
pub const ChaseConfig = struct {
    /// Maximum distance to detect targets
    detection_range: f32,
    /// Minimum distance to maintain from target
    min_distance: f32,
    /// Speed when chasing
    chase_speed: f32,
    /// How long to continue chasing after losing target (seconds)
    chase_duration: f32,
    /// Multiplier for lose aggro range (e.g., 1.15 = 15% tolerance)
    lose_range_multiplier: f32 = 1.15,
    /// Whether to use timer-based chase continuation
    use_chase_timer: bool = true,
    /// Whether to track state changes for event handling
    track_state_changes: bool = true,
    
    pub fn init(detection_range: f32, min_distance: f32, chase_speed: f32, chase_duration: f32, lose_tolerance: f32) ChaseConfig {
        return .{
            .detection_range = detection_range,
            .min_distance = min_distance,
            .chase_speed = chase_speed,
            .chase_duration = chase_duration,
            .lose_range_multiplier = lose_tolerance,
        };
    }
    
    /// Create a simple chase config without timers or state tracking
    pub fn simple(detection_range: f32, min_distance: f32, chase_speed: f32) ChaseConfig {
        return .{
            .detection_range = detection_range,
            .min_distance = min_distance,
            .chase_speed = chase_speed,
            .chase_duration = 0,
            .lose_range_multiplier = 1.0,
            .use_chase_timer = false,
            .track_state_changes = false,
        };
    }
};

/// Chase behavior state
pub const ChaseState = struct {
    /// Whether currently in active chase
    is_chasing: bool = false,
    /// Current target position (tracked during chase)
    target_pos: Vec2 = Vec2.ZERO,
    /// Time remaining in chase mode (seconds)
    chase_timer: f32 = 0,
    
    pub fn init() ChaseState {
        return .{};
    }
    
    /// Reset to idle state
    pub fn reset(self: *ChaseState) void {
        self.is_chasing = false;
        self.target_pos = Vec2.ZERO;
        self.chase_timer = 0;
    }
    
    /// Start chasing a target
    pub fn startChase(self: *ChaseState, target_pos: Vec2, duration: f32) void {
        self.is_chasing = true;
        self.target_pos = target_pos;
        self.chase_timer = duration;
    }
    
    /// Update chase timer and state
    pub fn update(self: *ChaseState, dt: f32, use_timer: bool) void {
        if (use_timer and self.chase_timer > 0) {
            self.chase_timer -= dt;
            if (self.chase_timer <= 0) {
                self.is_chasing = false;
            }
        }
    }
};

/// Result of chase behavior evaluation
pub const ChaseResult = struct {
    /// Velocity to apply to the chaser
    velocity: Vec2,
    /// Whether the chaser detected a new target
    detected_target: bool,
    /// Whether the chaser lost its target
    lost_target: bool,
    /// Whether currently in chase mode
    is_chasing: bool,
    /// Whether chase state changed this frame (optional tracking)
    state_changed: bool = false,
};

/// Evaluate chase behavior for a unit
pub fn evaluateChase(
    chaser_pos: Vec2,
    target_pos: Vec2,
    target_alive: bool,
    state: *ChaseState,
    config: ChaseConfig,
    aggro_multiplier: f32,
    dt: f32,
) ChaseResult {
    var result = ChaseResult{
        .velocity = Vec2.ZERO,
        .detected_target = false,
        .lost_target = false,
        .is_chasing = false,
        .state_changed = false,
    };
    
    const old_chase_state = state.is_chasing;
    
    // Update chase timer if enabled
    state.update(dt, config.use_chase_timer);
    
    // If target is not alive, abandon chase
    if (!target_alive) {
        if (state.is_chasing) {
            result.lost_target = true;
            if (config.track_state_changes) result.state_changed = true;
        }
        state.reset();
        return result;
    }
    
    const to_target = target_pos.sub(chaser_pos);
    const dist_sq = to_target.lengthSquared();
    
    // Apply aggro multiplier to ranges
    const effective_detection_sq = (config.detection_range * aggro_multiplier) * (config.detection_range * aggro_multiplier);
    const effective_lose_sq = (config.detection_range * aggro_multiplier * config.lose_range_multiplier) * (config.detection_range * aggro_multiplier * config.lose_range_multiplier);
    
    // Check for new target detection
    if (!state.is_chasing and dist_sq <= effective_detection_sq) {
        state.startChase(target_pos, config.chase_duration);
        result.detected_target = true;
        if (config.track_state_changes) result.state_changed = true;
    }
    
    // If currently chasing
    if (state.is_chasing) {
        // Check if target is now too far away (lose aggro)
        if (dist_sq > effective_lose_sq) {
            result.lost_target = true;
            if (config.track_state_changes) result.state_changed = true;
            state.reset();
            return result;
        }
        
        // Update target position
        state.target_pos = target_pos;
        
        // Calculate chase velocity if not too close
        const min_dist_sq = config.min_distance * config.min_distance;
        if (dist_sq > min_dist_sq) {
            const direction = to_target.normalize();
            result.velocity = direction.scale(config.chase_speed);
        }
        
        result.is_chasing = true;
    }
    
    // Check if state changed
    if (config.track_state_changes and old_chase_state != state.is_chasing) {
        result.state_changed = true;
    }
    
    return result;
}

/// Simplified chase behavior for basic AI (stateless)
pub fn simpleChase(
    chaser_pos: Vec2,
    target_pos: Vec2,
    target_alive: bool,
    detection_range: f32,
    min_distance: f32,
    chase_speed: f32,
    aggro_multiplier: f32,
) Vec2 {
    if (!target_alive) return Vec2.ZERO;
    
    const to_target = target_pos.sub(chaser_pos);
    const dist_sq = to_target.lengthSquared();
    
    const effective_range_sq = (detection_range * aggro_multiplier) * (detection_range * aggro_multiplier);
    const min_dist_sq = min_distance * min_distance;
    
    // Check if in range and not too close
    if (dist_sq <= effective_range_sq and dist_sq > min_dist_sq) {
        const direction = to_target.normalize();
        return direction.scale(chase_speed);
    }
    
    return Vec2.ZERO;
}

test "chase behavior basic functionality" {
    var state = ChaseState.init();
    const config = ChaseConfig.init(100.0, 20.0, 150.0, 3.0, 1.15);
    
    const chaser_pos = Vec2{ .x = 0, .y = 0 };
    const target_pos = Vec2{ .x = 50, .y = 0 }; // Within detection range
    
    // Test initial detection
    var result = evaluateChase(chaser_pos, target_pos, true, &state, config, 1.0, 0.1);
    try std.testing.expect(result.detected_target);
    try std.testing.expect(result.is_chasing);
    try std.testing.expect(result.velocity.x > 0); // Should move toward target
    
    // Test losing target when too far (beyond lose range with tolerance)
    const far_target = Vec2{ .x = 120, .y = 0 }; // Beyond lose range (100 * 1.15 = 115)
    result = evaluateChase(chaser_pos, far_target, true, &state, config, 1.0, 0.1);
    try std.testing.expect(result.lost_target);
    try std.testing.expect(!result.is_chasing);
}


test "simple chase functionality" {
    const chaser_pos = Vec2{ .x = 0, .y = 0 };
    const target_pos = Vec2{ .x = 50, .y = 0 };
    
    // Test chase when in range
    var velocity = simpleChase(chaser_pos, target_pos, true, 100.0, 10.0, 150.0, 1.0);
    try std.testing.expect(velocity.x > 0);
    
    // Test no chase when target dead
    velocity = simpleChase(chaser_pos, target_pos, false, 100.0, 10.0, 150.0, 1.0);
    try std.testing.expect(velocity.x == 0.0 and velocity.y == 0.0);
    
    // Test no chase when out of range
    const far_target = Vec2{ .x = 200, .y = 0 };
    velocity = simpleChase(chaser_pos, far_target, true, 100.0, 10.0, 150.0, 1.0);
    try std.testing.expect(velocity.x == 0.0 and velocity.y == 0.0);
}

test "chase config variations" {
    // Test simple config (no timers)
    const simple_config = ChaseConfig.simple(100.0, 10.0, 150.0);
    try std.testing.expect(!simple_config.use_chase_timer);
    try std.testing.expect(!simple_config.track_state_changes);
    
    // Test full config
    const full_config = ChaseConfig.init(100.0, 10.0, 150.0, 3.0, 1.15);
    try std.testing.expect(full_config.use_chase_timer);
    try std.testing.expect(full_config.track_state_changes);
}