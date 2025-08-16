const std = @import("std");
const Vec2 = @import("../../math/mod.zig").Vec2;

/// Generic chase behavior configuration
pub const ChaseConfig = struct {
    /// Maximum distance to detect targets (squared for performance)
    detection_range_sq: f32,
    /// Minimum distance to maintain from target (squared)
    min_distance_sq: f32,
    /// Speed when chasing
    chase_speed: f32,
    /// How long to continue chasing after losing target (seconds)
    chase_duration: f32,
    /// Maximum distance to lose target completely (squared)
    lose_range_sq: f32,
    
    pub fn init(detection_range: f32, min_distance: f32, chase_speed: f32, chase_duration: f32, lose_range: f32) ChaseConfig {
        return .{
            .detection_range_sq = detection_range * detection_range,
            .min_distance_sq = min_distance * min_distance,
            .chase_speed = chase_speed,
            .chase_duration = chase_duration,
            .lose_range_sq = lose_range * lose_range,
        };
    }
};

/// Chase behavior state
pub const ChaseState = struct {
    /// Current target position (if any)
    target_pos: ?Vec2 = null,
    /// Time remaining in chase mode (seconds)
    chase_timer: f32 = 0,
    /// Whether currently in active chase
    is_chasing: bool = false,
    
    pub fn init() ChaseState {
        return .{};
    }
    
    /// Reset to idle state
    pub fn reset(self: *ChaseState) void {
        self.target_pos = null;
        self.chase_timer = 0;
        self.is_chasing = false;
    }
    
    /// Update chase timer
    pub fn update(self: *ChaseState, dt: f32) void {
        if (self.chase_timer > 0) {
            self.chase_timer -= dt;
            if (self.chase_timer <= 0) {
                self.reset();
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
    };
    
    // Update chase timer
    state.update(dt);
    
    // If target is not alive, abandon chase
    if (!target_alive) {
        if (state.is_chasing) {
            result.lost_target = true;
        }
        state.reset();
        return result;
    }
    
    const to_target = target_pos.sub(chaser_pos);
    const dist_sq = to_target.lengthSquared();
    
    // Apply aggro multiplier to detection range
    const effective_detection_sq = config.detection_range_sq * aggro_multiplier * aggro_multiplier;
    const effective_lose_sq = config.lose_range_sq * aggro_multiplier * aggro_multiplier;
    
    // Check for new target detection
    if (!state.is_chasing and dist_sq <= effective_detection_sq) {
        state.is_chasing = true;
        state.target_pos = target_pos;
        state.chase_timer = config.chase_duration;
        result.detected_target = true;
    }
    
    // If currently chasing
    if (state.is_chasing) {
        // Check if target is now too far away (lose aggro)
        if (dist_sq > effective_lose_sq) {
            result.lost_target = true;
            state.reset();
            return result;
        }
        
        // Update target position
        state.target_pos = target_pos;
        
        // Calculate chase velocity if not too close
        if (dist_sq > config.min_distance_sq) {
            const direction = to_target.normalize();
            result.velocity = direction.scale(config.chase_speed);
        }
        
        result.is_chasing = true;
    }
    
    return result;
}

/// Simplified chase behavior for basic AI
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
    const config = ChaseConfig.init(100.0, 20.0, 150.0, 3.0, 200.0);
    
    const chaser_pos = Vec2{ .x = 0, .y = 0 };
    const target_pos = Vec2{ .x = 50, .y = 0 }; // Within detection range
    
    // Test initial detection
    var result = evaluateChase(chaser_pos, target_pos, true, &state, config, 1.0, 0.1);
    try std.testing.expect(result.detected_target);
    try std.testing.expect(result.is_chasing);
    try std.testing.expect(result.velocity.x > 0); // Should move toward target
    
    // Test losing target when too far
    const far_target = Vec2{ .x = 300, .y = 0 }; // Beyond lose range
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