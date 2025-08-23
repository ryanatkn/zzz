const std = @import("std");
const math = @import("../../math/mod.zig");
const camera_mod = @import("../camera/camera.zig");

const Vec2 = math.Vec2;
const Camera = camera_mod.Camera;

/// Generic targeting system for combat and interaction
/// Provides patterns for mouse-to-world conversion and target selection
pub const Targeting = struct {
    /// Convert screen coordinates to world coordinates using Camera
    pub fn screenToWorld(screen_pos: Vec2, camera: *const Camera) Vec2 {
        return camera.screenToWorldSafe(screen_pos);
    }

    /// Convert world coordinates to screen coordinates using Camera
    pub fn worldToScreen(world_pos: Vec2, camera: *const Camera) Vec2 {
        return camera.worldToScreen(world_pos);
    }

    /// Check if world position is visible on screen using Camera
    pub fn isPositionOnScreen(world_pos: Vec2, camera: *const Camera) bool {
        const screen_pos = camera.worldToScreen(world_pos);
        return screen_pos.x >= 0 and screen_pos.x <= camera.screen_width and
            screen_pos.y >= 0 and screen_pos.y <= camera.screen_height;
    }
};

/// Target selection and validation
pub const TargetSelection = struct {
    /// Target validation result
    pub const TargetResult = struct {
        valid: bool,
        target_pos: Vec2,
        distance: f32,
        error_reason: ?[]const u8 = null,

        pub fn ok(target_pos: Vec2, distance: f32) TargetResult {
            return .{ .valid = true, .target_pos = target_pos, .distance = distance };
        }

        pub fn invalid(target_pos: Vec2, reason: []const u8) TargetResult {
            return .{ .valid = false, .target_pos = target_pos, .distance = 0, .error_reason = reason };
        }
    };

    /// Range validation configuration
    pub const RangeConfig = struct {
        min_range: f32 = 0,
        max_range: f32 = std.math.inf(f32),
        check_line_of_sight: bool = false,

        pub fn withRange(min_range: f32, max_range: f32) RangeConfig {
            return .{ .min_range = min_range, .max_range = max_range };
        }

        pub fn withMaxRange(max_range: f32) RangeConfig {
            return .{ .max_range = max_range };
        }

        pub fn withLineOfSight() RangeConfig {
            return .{ .check_line_of_sight = true };
        }
    };

    /// Validate target based on range and other criteria
    pub fn validateTarget(shooter_pos: Vec2, target_pos: Vec2, config: RangeConfig) TargetResult {
        const distance = shooter_pos.distance(target_pos);

        // Check minimum range
        if (distance < config.min_range) {
            return TargetResult.invalid(target_pos, "Target too close");
        }

        // Check maximum range
        if (distance > config.max_range) {
            return TargetResult.invalid(target_pos, "Target out of range");
        }

        // Line of sight would require collision system integration
        if (config.check_line_of_sight) {
            // Games would implement this with their collision system
            // For now, just pass through
        }

        return TargetResult.ok(target_pos, distance);
    }

    /// Find closest valid target from a list of positions
    pub fn findClosestTarget(shooter_pos: Vec2, targets: []const Vec2, config: RangeConfig) ?TargetResult {
        var closest_target: ?TargetResult = null;
        var closest_distance: f32 = std.math.inf(f32);

        for (targets) |target_pos| {
            const result = validateTarget(shooter_pos, target_pos, config);
            if (result.valid and result.distance < closest_distance) {
                closest_distance = result.distance;
                closest_target = result;
            }
        }

        return closest_target;
    }
};

/// Area of effect targeting
pub const AoETargeting = struct {
    /// AoE shape types
    pub const AoEShape = enum {
        circle,
        rectangle,
        cone,
        line,
    };

    /// AoE configuration
    pub const AoEConfig = struct {
        center: Vec2,
        shape: AoEShape,
        radius: f32 = 0, // For circle
        width: f32 = 0, // For rectangle/line
        height: f32 = 0, // For rectangle
        angle: f32 = 0, // For cone (in radians)
        direction: Vec2 = Vec2.ZERO, // For cone/line

        pub fn circle(center: Vec2, radius: f32) AoEConfig {
            return .{ .center = center, .shape = .circle, .radius = radius };
        }

        pub fn rectangle(center: Vec2, width: f32, height: f32) AoEConfig {
            return .{ .center = center, .shape = .rectangle, .width = width, .height = height };
        }

        pub fn cone(center: Vec2, direction: Vec2, radius: f32, angle: f32) AoEConfig {
            return .{ .center = center, .shape = .cone, .radius = radius, .angle = angle, .direction = direction.normalize() };
        }

        pub fn line(start: Vec2, direction: Vec2, length: f32, width: f32) AoEConfig {
            return .{ .center = start, .shape = .line, .direction = direction.normalize(), .radius = length, .width = width };
        }
    };

    /// Check if a position is within the AoE
    pub fn isPositionInAoE(pos: Vec2, config: AoEConfig) bool {
        switch (config.shape) {
            .circle => {
                const distance = config.center.distance(pos);
                return distance <= config.radius;
            },
            .rectangle => {
                const diff = pos.sub(config.center);
                return @abs(diff.x) <= config.width / 2.0 and @abs(diff.y) <= config.height / 2.0;
            },
            .cone => {
                const to_target = pos.sub(config.center);
                const distance = to_target.magnitude();
                if (distance > config.radius) return false;

                const angle_to_target = std.math.atan2(to_target.y, to_target.x);
                const center_angle = std.math.atan2(config.direction.y, config.direction.x);
                var angle_diff = @abs(angle_to_target - center_angle);

                // Normalize angle difference to [0, π]
                if (angle_diff > std.math.pi) {
                    angle_diff = 2.0 * std.math.pi - angle_diff;
                }

                return angle_diff <= config.angle / 2.0;
            },
            .line => {
                // Distance from point to line segment
                const line_end = config.center.add(config.direction.scale(config.radius));
                const distance_to_line = pointToLineDistance(pos, config.center, line_end);
                return distance_to_line <= config.width / 2.0;
            },
        }
    }

    /// Calculate distance from point to line segment
    fn pointToLineDistance(point: Vec2, line_start: Vec2, line_end: Vec2) f32 {
        const line_vec = line_end.sub(line_start);
        const point_vec = point.sub(line_start);

        const line_length_sq = line_vec.magnitudeSquared();
        if (line_length_sq == 0) return point_vec.magnitude();

        const t = @max(0, @min(1, point_vec.dot(line_vec) / line_length_sq));
        const projection = line_start.add(line_vec.scale(t));

        return point.distance(projection);
    }
};
