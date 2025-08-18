const math = @import("../../math/mod.zig");
pub const Vec2 = math.Vec2;

/// Transform - universal positioning component
/// Dense storage - almost all entities have this
pub const Transform = extern struct {
    pos: Vec2,
    vel: Vec2,
    radius: f32,
    _padding: f32 = 0, // For alignment

    pub fn init(pos: Vec2, radius: f32) Transform {
        return .{
            .pos = pos,
            .vel = Vec2.ZERO,
            .radius = radius,
        };
    }
};