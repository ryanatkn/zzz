const math = @import("../../math/mod.zig");
pub const Vec2 = math.Vec2;

const EntityId = u32;

/// Unit - core gameplay entity component
/// Sparse storage - only actual units have this
pub const Unit = struct {
    pub const UnitType = enum {
        player,
        enemy,
        friendly,
        neutral,
    };

    pub const BehaviorState = enum {
        idle,
        chasing,
        attacking,
        fleeing,
        patrolling,
    };

    unit_type: UnitType,
    aggro_range: f32,
    aggro_factor: f32,
    home_pos: Vec2,
    behavior_state: BehaviorState,
    target: ?EntityId,

    pub fn init(unit_type: UnitType, home_pos: Vec2) Unit {
        return .{
            .unit_type = unit_type,
            .aggro_range = switch (unit_type) {
                .enemy => 150.0,
                .friendly => 100.0,
                else => 0.0,
            },
            .aggro_factor = 1.0,
            .home_pos = home_pos,
            .behavior_state = .idle,
            .target = null,
        };
    }
};
