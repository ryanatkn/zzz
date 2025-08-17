const std = @import("std");
const Vec2 = @import("../../math/mod.zig").Vec2;

/// Guard behavior configuration
pub const GuardConfig = struct {
    /// Position to guard
    guard_pos: Vec2,
    /// Maximum distance from guard position before returning
    max_guard_distance: f32,
    /// Detection range for threats
    threat_detection_range: f32,
    /// Speed when returning to guard position
    return_speed: f32,
    /// Speed when intercepting threats
    intercept_speed: f32,
    /// Minimum distance to maintain from threats when intercepting
    intercept_distance: f32 = 30.0,
    /// How long to pursue threats before returning to guard (seconds)
    pursuit_duration: f32 = 5.0,
    /// Distance tolerance for being "at guard position"
    position_tolerance: f32 = 10.0,
    /// Whether to use timer-based pursuit
    use_pursuit_timer: bool = true,
    /// Whether to track state changes
    track_state_changes: bool = true,
    
    pub fn init(
        guard_pos: Vec2,
        max_guard_distance: f32,
        threat_detection_range: f32,
        return_speed: f32,
        intercept_speed: f32,
        pursuit_duration: f32,
    ) GuardConfig {
        return .{
            .guard_pos = guard_pos,
            .max_guard_distance = max_guard_distance,
            .threat_detection_range = threat_detection_range,
            .return_speed = return_speed,
            .intercept_speed = intercept_speed,
            .pursuit_duration = pursuit_duration,
        };
    }
    
    /// Create a simple guard config without pursuit timers
    pub fn simple(
        guard_pos: Vec2,
        max_guard_distance: f32,
        threat_detection_range: f32,
        return_speed: f32,
    ) GuardConfig {
        return .{
            .guard_pos = guard_pos,
            .max_guard_distance = max_guard_distance,
            .threat_detection_range = threat_detection_range,
            .return_speed = return_speed,
            .intercept_speed = return_speed,
            .pursuit_duration = 0,
            .use_pursuit_timer = false,
            .track_state_changes = false,
        };
    }
};

/// Guard behavior state
pub const GuardState = struct {
    /// Current behavior mode
    mode: GuardMode = .at_post,
    /// Position of current threat (if any)
    threat_pos: Vec2 = Vec2.ZERO,
    /// Time remaining in pursuit mode
    pursuit_timer: f32 = 0,
    
    pub const GuardMode = enum {
        at_post,       // At guard position, watching
        returning,     // Returning to guard position
        intercepting,  // Moving to intercept threat
        pursuing,      // Actively pursuing threat
    };
    
    pub fn init() GuardState {
        return .{};
    }
    
    /// Reset to guard post
    pub fn reset(self: *GuardState) void {
        self.mode = .at_post;
        self.threat_pos = Vec2.ZERO;
        self.pursuit_timer = 0;
    }
    
    /// Start intercepting a threat
    pub fn startIntercept(self: *GuardState, threat_pos: Vec2, pursuit_duration: f32) void {
        self.mode = .intercepting;
        self.threat_pos = threat_pos;
        self.pursuit_timer = pursuit_duration;
    }
    
    /// Update pursuit timer
    pub fn update(self: *GuardState, dt: f32, use_timer: bool) void {
        if (use_timer and self.pursuit_timer > 0) {
            self.pursuit_timer -= dt;
            if (self.pursuit_timer <= 0 and self.mode == .pursuing) {
                self.mode = .returning;
            }
        }
    }
};

/// Result of guard behavior evaluation
pub const GuardResult = struct {
    /// Velocity to apply to the guard
    velocity: Vec2,
    /// Current guard mode
    mode: GuardState.GuardMode,
    /// Whether detected a new threat
    detected_threat: bool,
    /// Whether lost threat and returning to post
    lost_threat: bool,
    /// Whether returned to guard position
    returned_to_post: bool,
    /// Whether guard state changed this frame
    state_changed: bool = false,
};

/// Evaluate guard behavior for a unit
pub fn evaluateGuard(
    unit_pos: Vec2,
    threat_pos: ?Vec2,
    threat_active: bool,
    state: *GuardState,
    config: GuardConfig,
    speed_multiplier: f32,
    dt: f32,
) GuardResult {
    var result = GuardResult{
        .velocity = Vec2.ZERO,
        .mode = state.mode,
        .detected_threat = false,
        .lost_threat = false,
        .returned_to_post = false,
        .state_changed = false,
    };
    
    const old_mode = state.mode;
    
    // Update pursuit timer
    state.update(dt, config.use_pursuit_timer);
    
    const to_guard_pos = config.guard_pos.sub(unit_pos);
    const guard_dist_sq = to_guard_pos.lengthSquared();
    const max_guard_sq = config.max_guard_distance * config.max_guard_distance;
    const pos_tolerance_sq = config.position_tolerance * config.position_tolerance;
    
    // If no active threat, return to guard position
    if (!threat_active or threat_pos == null) {
        if (state.mode == .intercepting or state.mode == .pursuing) {
            state.mode = .returning;
            result.lost_threat = true;
            if (config.track_state_changes) result.state_changed = true;
        }
    }
    
    // Handle behavior based on current mode
    switch (state.mode) {
        .at_post => {
            // Check for threats to intercept
            if (threat_active and threat_pos != null) {
                const threat_pos_val = threat_pos.?;
                const to_threat = threat_pos_val.sub(unit_pos);
                const threat_dist_sq = to_threat.lengthSquared();
                const detection_sq = config.threat_detection_range * config.threat_detection_range;
                
                if (threat_dist_sq <= detection_sq) {
                    state.startIntercept(threat_pos_val, config.pursuit_duration);
                    result.detected_threat = true;
                    if (config.track_state_changes) result.state_changed = true;
                }
            }
            
            // If too far from guard position, return
            if (guard_dist_sq > pos_tolerance_sq) {
                state.mode = .returning;
                if (config.track_state_changes) result.state_changed = true;
            }
        },
        
        .returning => {
            // Move back to guard position
            if (guard_dist_sq > pos_tolerance_sq) {
                const direction = to_guard_pos.normalize();
                result.velocity = direction.scale(config.return_speed * speed_multiplier);
            } else {
                // Reached guard position
                state.mode = .at_post;
                result.returned_to_post = true;
                if (config.track_state_changes) result.state_changed = true;
            }
            
            // Check for new threats while returning
            if (threat_active and threat_pos != null) {
                const threat_pos_val = threat_pos.?;
                const to_threat = threat_pos_val.sub(unit_pos);
                const threat_dist_sq = to_threat.lengthSquared();
                const detection_sq = config.threat_detection_range * config.threat_detection_range;
                
                if (threat_dist_sq <= detection_sq) {
                    state.startIntercept(threat_pos_val, config.pursuit_duration);
                    result.detected_threat = true;
                    if (config.track_state_changes) result.state_changed = true;
                }
            }
        },
        
        .intercepting => {
            if (threat_pos) |threat_pos_val| {
                state.threat_pos = threat_pos_val;
                
                const to_threat = threat_pos_val.sub(unit_pos);
                const threat_dist_sq = to_threat.lengthSquared();
                const intercept_sq = config.intercept_distance * config.intercept_distance;
                
                // Move toward threat if not close enough
                if (threat_dist_sq > intercept_sq) {
                    const direction = to_threat.normalize();
                    result.velocity = direction.scale(config.intercept_speed * speed_multiplier);
                } else {
                    // Close enough, start pursuing
                    state.mode = .pursuing;
                    if (config.track_state_changes) result.state_changed = true;
                }
                
                // If threat is too far from guard area, give up
                const threat_to_guard = config.guard_pos.sub(threat_pos_val);
                const threat_guard_sq = threat_to_guard.lengthSquared();
                if (threat_guard_sq > max_guard_sq) {
                    state.mode = .returning;
                    result.lost_threat = true;
                    if (config.track_state_changes) result.state_changed = true;
                }
            } else {
                // Lost threat
                state.mode = .returning;
                result.lost_threat = true;
                if (config.track_state_changes) result.state_changed = true;
            }
        },
        
        .pursuing => {
            if (threat_pos) |threat_pos_val| {
                state.threat_pos = threat_pos_val;
                
                const to_threat = threat_pos_val.sub(unit_pos);
                const threat_dist_sq = to_threat.lengthSquared();
                const intercept_sq = config.intercept_distance * config.intercept_distance;
                
                // Maintain distance from threat
                if (threat_dist_sq > intercept_sq) {
                    const direction = to_threat.normalize();
                    result.velocity = direction.scale(config.intercept_speed * speed_multiplier);
                }
                
                // If threat is too far from guard area, give up
                const threat_to_guard = config.guard_pos.sub(threat_pos_val);
                const threat_guard_sq = threat_to_guard.lengthSquared();
                if (threat_guard_sq > max_guard_sq) {
                    state.mode = .returning;
                    result.lost_threat = true;
                    if (config.track_state_changes) result.state_changed = true;
                }
            } else {
                // Lost threat
                state.mode = .returning;
                result.lost_threat = true;
                if (config.track_state_changes) result.state_changed = true;
            }
        },
    }
    
    result.mode = state.mode;
    
    // Check if mode changed
    if (config.track_state_changes and old_mode != state.mode) {
        result.state_changed = true;
    }
    
    return result;
}

/// Simple guard behavior (stateless)
pub fn simpleGuard(
    unit_pos: Vec2,
    guard_pos: Vec2,
    threat_pos: ?Vec2,
    threat_active: bool,
    max_guard_distance: f32,
    threat_detection_range: f32,
    guard_speed: f32,
    speed_multiplier: f32,
) Vec2 {
    const to_guard = guard_pos.sub(unit_pos);
    const guard_dist_sq = to_guard.lengthSquared();
    const max_guard_sq = max_guard_distance * max_guard_distance;
    
    // If threat is active and within detection range, intercept
    if (threat_active and threat_pos != null) {
        const threat_pos_val = threat_pos.?;
        const to_threat = threat_pos_val.sub(unit_pos);
        const threat_dist_sq = to_threat.lengthSquared();
        const detection_sq = threat_detection_range * threat_detection_range;
        
        // Check if threat is in guard area
        const threat_to_guard = guard_pos.sub(threat_pos_val);
        const threat_guard_sq = threat_to_guard.lengthSquared();
        
        if (threat_dist_sq <= detection_sq and threat_guard_sq <= max_guard_sq) {
            const direction = to_threat.normalize();
            return direction.scale(guard_speed * speed_multiplier);
        }
    }
    
    // Otherwise return to guard position
    const tolerance_sq = 10.0 * 10.0; // Default tolerance
    if (guard_dist_sq > tolerance_sq) {
        const direction = to_guard.normalize();
        return direction.scale(guard_speed * speed_multiplier);
    }
    
    return Vec2.ZERO;
}

test "guard behavior basic functionality" {
    const guard_pos = Vec2{ .x = 100, .y = 100 };
    var state = GuardState.init();
    const config = GuardConfig.init(guard_pos, 150.0, 80.0, 100.0, 150.0, 3.0);
    
    const unit_pos = Vec2{ .x = 100, .y = 100 }; // At guard position
    const threat_pos = Vec2{ .x = 120, .y = 100 }; // Nearby threat
    
    // Test threat detection
    var result = evaluateGuard(unit_pos, threat_pos, true, &state, config, 1.0, 0.1);
    try std.testing.expect(result.detected_threat);
    try std.testing.expect(result.mode == .intercepting);
    
    // Test returning to post when threat gone
    result = evaluateGuard(unit_pos, null, false, &state, config, 1.0, 0.1);
    try std.testing.expect(result.lost_threat);
    try std.testing.expect(result.mode == .returning);
}

test "simple guard functionality" {
    const guard_pos = Vec2{ .x = 100, .y = 100 };
    const unit_pos = Vec2{ .x = 80, .y = 100 }; // Away from guard position
    const threat_pos = Vec2{ .x = 120, .y = 100 }; // Threat near guard area
    
    // Test intercepting threat
    var velocity = simpleGuard(unit_pos, guard_pos, threat_pos, true, 150.0, 80.0, 100.0, 1.0);
    try std.testing.expect(velocity.x > 0); // Moving toward threat
    
    // Test returning to guard position when no threat
    velocity = simpleGuard(unit_pos, guard_pos, null, false, 150.0, 80.0, 100.0, 1.0);
    try std.testing.expect(velocity.x > 0); // Moving toward guard position
}