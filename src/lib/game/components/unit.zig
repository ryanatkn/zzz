const math = @import("../../math/mod.zig");
pub const Vec2 = math.Vec2;

const EntityId = u32;

/// Generic Unit component - games define their own UnitType enum
/// Example: const MyUnit = Unit(MyUnitType);
pub fn Unit(comptime UnitType: type) type {
    return struct {
        const Self = @This();

        unit_type: UnitType,
        home_pos: Vec2,
        target: ?EntityId,

        pub fn init(unit_type: UnitType, home_pos: Vec2) Self {
            return .{
                .unit_type = unit_type,
                .home_pos = home_pos,
                .target = null,
            };
        }
    };
}

// Generic Unit component is ready for use by games
// Games should create their own Unit instances with game-specific UnitType enums
// Example: const MyUnit = Unit(MyUnitType);
