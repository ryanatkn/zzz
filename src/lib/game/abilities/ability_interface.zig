const std = @import("std");
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;

/// Generic ability casting interface
/// Games implement specific abilities using these patterns
pub const AbilityCastInterface = struct {
    /// Standard ability cast result
    pub const CastResult = enum {
        Success,
        OnCooldown,
        InvalidTarget,
        InsufficientResources,
        OutOfRange,
        Blocked,
    };

    /// Standard ability target types
    pub const TargetType = enum {
        None, // No target required
        Position, // Target a world position
        Entity, // Target a specific entity
        Self, // Self-cast only
        Area, // Area of effect around position
    };

    /// Generic ability cast context
    pub const CastContext = struct {
        caster_pos: Vec2,
        target_pos: ?Vec2,
        target_entity: ?u32, // EntityId type varies by game
        is_self_cast: bool,

        pub fn init(caster_pos: Vec2) CastContext {
            return .{
                .caster_pos = caster_pos,
                .target_pos = null,
                .target_entity = null,
                .is_self_cast = false,
            };
        }

        pub fn withTargetPos(self: CastContext, target_pos: Vec2) CastContext {
            var ctx = self;
            ctx.target_pos = target_pos;
            return ctx;
        }

        pub fn withSelfCast(self: CastContext) CastContext {
            var ctx = self;
            ctx.is_self_cast = true;
            ctx.target_pos = self.caster_pos;
            return ctx;
        }
    };
};

/// Generic area of effect patterns
pub const AoEPatterns = struct {
    /// Check if position is within circular area
    pub fn isInCircle(center: Vec2, pos: Vec2, radius: f32) bool {
        const dist_sq = center.distanceSquared(pos);
        return dist_sq <= radius * radius;
    }

    /// Check if position is within rectangular area
    pub fn isInRect(center: Vec2, pos: Vec2, width: f32, height: f32) bool {
        const half_w = width * 0.5;
        const half_h = height * 0.5;
        const dx = @abs(pos.x - center.x);
        const dy = @abs(pos.y - center.y);
        return dx <= half_w and dy <= half_h;
    }

    /// Get all positions within circular area (for grid-based games)
    pub fn getCirclePositions(allocator: std.mem.Allocator, center: Vec2, radius: f32, grid_size: f32) !std.ArrayList(Vec2) {
        var positions = std.ArrayList(Vec2).init(allocator);

        const steps = @as(i32, @intFromFloat(@ceil(radius * 2.0 / grid_size)));
        const half_steps = steps / 2;

        var y: i32 = -half_steps;
        while (y <= half_steps) : (y += 1) {
            var x: i32 = -half_steps;
            while (x <= half_steps) : (x += 1) {
                const pos = Vec2{
                    .x = center.x + @as(f32, @floatFromInt(x)) * grid_size,
                    .y = center.y + @as(f32, @floatFromInt(y)) * grid_size,
                };

                if (isInCircle(center, pos, radius)) {
                    try positions.append(pos);
                }
            }
        }

        return positions;
    }
};
