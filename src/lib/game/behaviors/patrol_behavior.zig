const std = @import("std");
const Vec2 = @import("../../math/mod.zig").Vec2;

/// Patrol behavior configuration
pub const PatrolConfig = struct {
    /// Speed when patrolling
    patrol_speed: f32,
    /// Distance tolerance to consider waypoint reached
    waypoint_tolerance: f32 = 10.0,
    /// Whether to loop back to start after reaching end
    loop_patrol: bool = true,
    /// Whether to reverse direction at end instead of looping
    reverse_patrol: bool = false,
    /// Pause time at each waypoint (seconds)
    pause_duration: f32 = 0.0,
    /// Whether to track state changes
    track_state_changes: bool = true,

    pub fn init(patrol_speed: f32, waypoint_tolerance: f32, loop: bool) PatrolConfig {
        return .{
            .patrol_speed = patrol_speed,
            .waypoint_tolerance = waypoint_tolerance,
            .loop_patrol = loop,
        };
    }

    /// Create a patrol config with pauses at waypoints
    pub fn withPauses(patrol_speed: f32, waypoint_tolerance: f32, pause_duration: f32) PatrolConfig {
        return .{
            .patrol_speed = patrol_speed,
            .waypoint_tolerance = waypoint_tolerance,
            .pause_duration = pause_duration,
        };
    }

    /// Create a reversing patrol (ping-pong between waypoints)
    pub fn reversing(patrol_speed: f32, waypoint_tolerance: f32) PatrolConfig {
        return .{
            .patrol_speed = patrol_speed,
            .waypoint_tolerance = waypoint_tolerance,
            .loop_patrol = false,
            .reverse_patrol = true,
        };
    }
};

/// Patrol behavior state
pub const PatrolState = struct {
    /// Current waypoint index
    current_waypoint: u32 = 0,
    /// Whether moving forward through waypoints (or backward if reversing)
    forward_direction: bool = true,
    /// Time remaining paused at current waypoint
    pause_timer: f32 = 0,
    /// Whether currently at a waypoint (paused)
    at_waypoint: bool = false,
    /// Waypoint positions
    waypoints: []const Vec2,

    pub fn init(waypoints: []const Vec2) PatrolState {
        return .{
            .waypoints = waypoints,
        };
    }

    /// Reset to start of patrol
    pub fn reset(self: *PatrolState) void {
        self.current_waypoint = 0;
        self.forward_direction = true;
        self.pause_timer = 0;
        self.at_waypoint = false;
    }

    /// Get current target waypoint position
    pub fn getCurrentWaypoint(self: *const PatrolState) ?Vec2 {
        if (self.waypoints.len == 0) return null;
        if (self.current_waypoint >= self.waypoints.len) return null;
        return self.waypoints[self.current_waypoint];
    }

    /// Advance to next waypoint based on patrol config
    pub fn advanceWaypoint(self: *PatrolState, config: PatrolConfig) void {
        if (self.waypoints.len <= 1) return;

        if (config.reverse_patrol) {
            // Ping-pong patrol
            if (self.forward_direction) {
                self.current_waypoint += 1;
                if (self.current_waypoint >= self.waypoints.len - 1) {
                    self.current_waypoint = @as(u32, @intCast(self.waypoints.len)) - 1;
                    self.forward_direction = false;
                }
            } else {
                if (self.current_waypoint > 0) {
                    self.current_waypoint -= 1;
                }
                if (self.current_waypoint == 0) {
                    self.forward_direction = true;
                }
            }
        } else if (config.loop_patrol) {
            // Loop patrol
            self.current_waypoint = (self.current_waypoint + 1) % @as(u32, @intCast(self.waypoints.len));
        } else {
            // One-way patrol
            if (self.current_waypoint < self.waypoints.len - 1) {
                self.current_waypoint += 1;
            }
        }
    }

    /// Update pause timer
    pub fn update(self: *PatrolState, dt: f32) void {
        if (self.pause_timer > 0) {
            self.pause_timer -= dt;
            if (self.pause_timer <= 0) {
                self.at_waypoint = false;
            }
        }
    }
};

/// Result of patrol behavior evaluation
pub const PatrolResult = struct {
    /// Velocity to apply to the patroller
    velocity: Vec2,
    /// Whether reached a new waypoint
    reached_waypoint: bool,
    /// Whether completed full patrol route
    completed_patrol: bool,
    /// Whether currently paused at waypoint
    paused_at_waypoint: bool,
    /// Current waypoint index
    current_waypoint: u32,
    /// Whether patrol state changed this frame
    state_changed: bool = false,
};

/// Evaluate patrol behavior for a unit
pub fn evaluatePatrol(
    unit_pos: Vec2,
    state: *PatrolState,
    config: PatrolConfig,
    speed_multiplier: f32,
    dt: f32,
) PatrolResult {
    var result = PatrolResult{
        .velocity = Vec2.ZERO,
        .reached_waypoint = false,
        .completed_patrol = false,
        .paused_at_waypoint = false,
        .current_waypoint = state.current_waypoint,
        .state_changed = false,
    };

    // Update pause timer
    state.update(dt);

    // If paused at waypoint, don't move
    if (state.at_waypoint and state.pause_timer > 0) {
        result.paused_at_waypoint = true;
        return result;
    }

    // Get current target waypoint
    const target_pos = state.getCurrentWaypoint() orelse {
        // No waypoints to patrol
        return result;
    };

    const to_target = target_pos.sub(unit_pos);
    const dist_sq = to_target.lengthSquared();
    const tolerance_sq = config.waypoint_tolerance * config.waypoint_tolerance;

    // Check if reached current waypoint
    if (dist_sq <= tolerance_sq) {
        _ = state.current_waypoint; // Track waypoint for potential future use

        // Start pause if configured
        if (config.pause_duration > 0) {
            state.at_waypoint = true;
            state.pause_timer = config.pause_duration;
            result.paused_at_waypoint = true;
        }

        // Advance to next waypoint
        state.advanceWaypoint(config);

        result.reached_waypoint = true;
        if (config.track_state_changes) result.state_changed = true;

        // Check if completed full patrol
        if (!config.loop_patrol and !config.reverse_patrol) {
            if (state.current_waypoint >= state.waypoints.len - 1) {
                result.completed_patrol = true;
            }
        }

        result.current_waypoint = state.current_waypoint;

        // If not paused, continue to next waypoint
        if (!state.at_waypoint) {
            const next_target = state.getCurrentWaypoint() orelse return result;
            const next_to_target = next_target.sub(unit_pos);
            const next_dist_sq = next_to_target.lengthSquared();

            if (next_dist_sq > tolerance_sq) {
                const direction = next_to_target.normalize();
                result.velocity = direction.scale(config.patrol_speed * speed_multiplier);
            }
        }
    } else {
        // Move toward current waypoint
        const direction = to_target.normalize();
        result.velocity = direction.scale(config.patrol_speed * speed_multiplier);
    }

    return result;
}

/// Simple patrol behavior (stateless, single back-and-forth between two points)
pub fn simplePatrol(
    unit_pos: Vec2,
    point_a: Vec2,
    point_b: Vec2,
    patrol_speed: f32,
    speed_multiplier: f32,
    tolerance: f32,
) Vec2 {
    const to_a = point_a.sub(unit_pos);
    const to_b = point_b.sub(unit_pos);

    const dist_a_sq = to_a.lengthSquared();
    const dist_b_sq = to_b.lengthSquared();
    const tolerance_sq = tolerance * tolerance;

    // Move toward whichever point is farther
    if (dist_a_sq > tolerance_sq and dist_b_sq > tolerance_sq) {
        // Not at either point, move to closer one
        if (dist_a_sq < dist_b_sq) {
            const direction = to_a.normalize();
            return direction.scale(patrol_speed * speed_multiplier);
        } else {
            const direction = to_b.normalize();
            return direction.scale(patrol_speed * speed_multiplier);
        }
    } else if (dist_a_sq <= tolerance_sq) {
        // At point A, move toward B
        if (dist_b_sq > tolerance_sq) {
            const direction = to_b.normalize();
            return direction.scale(patrol_speed * speed_multiplier);
        }
    } else if (dist_b_sq <= tolerance_sq) {
        // At point B, move toward A
        if (dist_a_sq > tolerance_sq) {
            const direction = to_a.normalize();
            return direction.scale(patrol_speed * speed_multiplier);
        }
    }

    return Vec2.ZERO;
}

test "patrol behavior basic functionality" {
    const waypoints = [_]Vec2{
        Vec2{ .x = 0, .y = 0 },
        Vec2{ .x = 100, .y = 0 },
        Vec2{ .x = 100, .y = 100 },
    };

    var state = PatrolState.init(&waypoints);
    const config = PatrolConfig.init(150.0, 10.0, true);

    const unit_pos = Vec2{ .x = 5, .y = 0 }; // Near first waypoint

    // Test reaching waypoint
    const result = evaluatePatrol(unit_pos, &state, config, 1.0, 0.1);
    try std.testing.expect(result.reached_waypoint);
    try std.testing.expect(state.current_waypoint == 1); // Advanced to next

    // Test movement toward next waypoint
    result = evaluatePatrol(unit_pos, &state, config, 1.0, 0.1);
    try std.testing.expect(result.velocity.x > 0); // Moving toward (100,0)
}

test "patrol behavior with pauses" {
    const waypoints = [_]Vec2{
        Vec2{ .x = 0, .y = 0 },
        Vec2{ .x = 100, .y = 0 },
    };

    var state = PatrolState.init(&waypoints);
    const config = PatrolConfig.withPauses(150.0, 10.0, 1.0); // 1 second pause

    const unit_pos = Vec2{ .x = 5, .y = 0 }; // Near first waypoint

    // Test reaching waypoint with pause
    const result = evaluatePatrol(unit_pos, &state, config, 1.0, 0.1);
    try std.testing.expect(result.reached_waypoint);
    try std.testing.expect(result.paused_at_waypoint);
    try std.testing.expect(state.pause_timer > 0);
}

test "simple patrol functionality" {
    const point_a = Vec2{ .x = 0, .y = 0 };
    const point_b = Vec2{ .x = 100, .y = 0 };
    const unit_pos = Vec2{ .x = 5, .y = 0 }; // Near point A

    // Should move toward point B (farther away)
    const velocity = simplePatrol(unit_pos, point_a, point_b, 150.0, 1.0, 10.0);
    try std.testing.expect(velocity.x > 0);
}
