const std = @import("std");
const Vec2 = @import("../../math/mod.zig").Vec2;

/// Configuration for return home behavior
pub const ReturnHomeConfig = struct {
    /// Distance at which unit is considered "at home" (squared for performance)
    home_tolerance_sq: f32,
    /// Speed when returning home
    return_speed: f32,

    pub fn init(home_tolerance: f32, return_speed: f32) ReturnHomeConfig {
        return .{
            .home_tolerance_sq = home_tolerance * home_tolerance,
            .return_speed = return_speed,
        };
    }
};

/// Result of return home behavior
pub const ReturnHomeResult = struct {
    /// Velocity to apply to the unit
    velocity: Vec2,
    /// Whether the unit is at home
    at_home: bool,
    /// Distance to home (squared)
    distance_to_home_sq: f32,
};

/// Calculate velocity for returning home
pub fn calculateReturnHomeVelocity(
    current_pos: Vec2,
    home_pos: Vec2,
    config: ReturnHomeConfig,
) ReturnHomeResult {
    const to_home = home_pos.sub(current_pos);
    const dist_sq = to_home.lengthSquared();

    // Check if already at home
    if (dist_sq <= config.home_tolerance_sq) {
        return ReturnHomeResult{
            .velocity = Vec2.ZERO,
            .at_home = true,
            .distance_to_home_sq = dist_sq,
        };
    }

    // Calculate return velocity
    const direction = to_home.normalize();
    const velocity = direction.scale(config.return_speed);

    return ReturnHomeResult{
        .velocity = velocity,
        .at_home = false,
        .distance_to_home_sq = dist_sq,
    };
}

/// Simple return home behavior (convenience function)
pub fn simpleReturnHome(
    current_pos: Vec2,
    home_pos: Vec2,
    home_tolerance: f32,
    return_speed: f32,
) Vec2 {
    const config = ReturnHomeConfig.init(home_tolerance, return_speed);
    const result = calculateReturnHomeVelocity(current_pos, home_pos, config);
    return result.velocity;
}

/// Check if a unit is at home
pub fn isAtHome(current_pos: Vec2, home_pos: Vec2, tolerance: f32) bool {
    const to_home = home_pos.sub(current_pos);
    const dist_sq = to_home.lengthSquared();
    const tolerance_sq = tolerance * tolerance;
    return dist_sq <= tolerance_sq;
}

/// Get distance to home
pub fn getDistanceToHome(current_pos: Vec2, home_pos: Vec2) f32 {
    const to_home = home_pos.sub(current_pos);
    return to_home.length();
}

/// Get squared distance to home (more efficient)
pub fn getDistanceToHomeSquared(current_pos: Vec2, home_pos: Vec2) f32 {
    const to_home = home_pos.sub(current_pos);
    return to_home.lengthSquared();
}

/// State machine for patrolling behavior (returning home via waypoints)
pub const PatrolState = struct {
    /// List of waypoint positions
    waypoints: []const Vec2,
    /// Current waypoint index
    current_waypoint: usize = 0,
    /// Whether currently moving to next waypoint
    moving_to_waypoint: bool = false,

    pub fn init(waypoints: []const Vec2) PatrolState {
        return .{
            .waypoints = waypoints,
            .current_waypoint = 0,
            .moving_to_waypoint = waypoints.len > 0,
        };
    }

    /// Get current target position
    pub fn getCurrentTarget(self: *const PatrolState) ?Vec2 {
        if (self.waypoints.len == 0) return null;
        return self.waypoints[self.current_waypoint];
    }

    /// Move to next waypoint
    pub fn nextWaypoint(self: *PatrolState) void {
        if (self.waypoints.len == 0) return;
        self.current_waypoint = (self.current_waypoint + 1) % self.waypoints.len;
    }

    /// Check if reached current waypoint and advance if so
    pub fn updateWaypoint(self: *PatrolState, current_pos: Vec2, tolerance: f32) bool {
        if (self.waypoints.len == 0) return false;

        const target = self.getCurrentTarget().?;
        if (isAtHome(current_pos, target, tolerance)) {
            self.nextWaypoint();
            return true; // Reached waypoint
        }
        return false; // Still moving
    }
};

/// Patrol behavior that cycles through waypoints
pub fn calculatePatrolVelocity(
    current_pos: Vec2,
    patrol_state: *PatrolState,
    config: ReturnHomeConfig,
) ReturnHomeResult {
    const target = patrol_state.getCurrentTarget();
    if (target == null) {
        return ReturnHomeResult{
            .velocity = Vec2.ZERO,
            .at_home = true,
            .distance_to_home_sq = 0,
        };
    }

    return calculateReturnHomeVelocity(current_pos, target.?, config);
}

test "return home behavior" {
    const config = ReturnHomeConfig.init(10.0, 50.0);
    const current_pos = Vec2{ .x = 100, .y = 100 };
    const home_pos = Vec2{ .x = 0, .y = 0 };

    // Test returning home
    var result = calculateReturnHomeVelocity(current_pos, home_pos, config);
    try std.testing.expect(!result.at_home);
    try std.testing.expect(result.velocity.x < 0); // Should move toward home
    try std.testing.expect(result.velocity.y < 0);

    // Test at home
    const close_pos = Vec2{ .x = 5, .y = 5 };
    result = calculateReturnHomeVelocity(close_pos, home_pos, config);
    try std.testing.expect(result.at_home);
    try std.testing.expect(result.velocity.x == 0.0 and result.velocity.y == 0.0);
}

test "patrol behavior" {
    const waypoints = [_]Vec2{
        Vec2{ .x = 0, .y = 0 },
        Vec2{ .x = 100, .y = 0 },
        Vec2{ .x = 100, .y = 100 },
        Vec2{ .x = 0, .y = 100 },
    };

    var patrol = PatrolState.init(&waypoints);

    // Test getting first waypoint
    const target = patrol.getCurrentTarget();
    try std.testing.expect(target != null);
    try std.testing.expect(target.?.x == 0.0 and target.?.y == 0.0);

    // Test advancing waypoint
    patrol.nextWaypoint();
    const target2 = patrol.getCurrentTarget();
    try std.testing.expect(target2 != null);
    try std.testing.expect(target2.?.x == 100.0 and target2.?.y == 0.0);
}

test "utility functions" {
    const pos1 = Vec2{ .x = 0, .y = 0 };
    const pos2 = Vec2{ .x = 3, .y = 4 }; // Distance = 5

    // Test distance calculation
    const dist = getDistanceToHome(pos2, pos1);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), dist, 0.001);

    // Test squared distance
    const dist_sq = getDistanceToHomeSquared(pos2, pos1);
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), dist_sq, 0.001);

    // Test at home check
    try std.testing.expect(!isAtHome(pos2, pos1, 4.0));
    try std.testing.expect(isAtHome(pos2, pos1, 6.0));
}
