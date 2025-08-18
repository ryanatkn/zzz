const math = @import("../../math/mod.zig");
pub const Vec2 = math.Vec2;

const EntityId = u32;

/// Unit - core gameplay entity component
/// Generic unit with basic properties - games add behavior specifics
pub const Unit = struct {
    pub const UnitType = enum {
        player,
        enemy,
        friendly,
        neutral,
    };

    unit_type: UnitType,
    home_pos: Vec2,
    target: ?EntityId,

    pub fn init(unit_type: UnitType, home_pos: Vec2) Unit {
        return .{
            .unit_type = unit_type,
            .home_pos = home_pos,
            .target = null,
        };
    }
};
