// Extended Unit Component - Hex-specific unit with behavior profile
// Extends the generic lib/game Unit with hex-specific fields

const Unit = @import("../lib/game/components/unit.zig").Unit;
const BehaviorProfile = @import("behavior_profile.zig").BehaviorProfile;
const Vec2 = @import("../lib/math/mod.zig").Vec2;

/// Hex-specific unit extension with behavior profile and aggro
pub const HexUnit = struct {
    // Base unit component
    base: Unit,
    
    // Hex-specific behavior fields
    behavior_profile: BehaviorProfile,
    aggro_range: f32,
    aggro_factor: f32,
    entity_id: u32,

    pub fn init(unit_type: Unit.UnitType, home_pos: Vec2, behavior_profile: BehaviorProfile, entity_id: u32) HexUnit {
        return .{
            .base = Unit.init(unit_type, home_pos),
            .behavior_profile = behavior_profile,
            .aggro_range = switch (unit_type) {
                .enemy => 150.0,
                .friendly => 100.0,
                else => 0.0,
            },
            .aggro_factor = 1.0,
            .entity_id = entity_id,
        };
    }

    // Convenience accessors for base unit fields
    pub fn unitType(self: *const HexUnit) Unit.UnitType {
        return self.base.unit_type;
    }

    pub fn homePos(self: *const HexUnit) Vec2 {
        return self.base.home_pos;
    }

    pub fn target(self: *const HexUnit) ?u32 {
        return self.base.target;
    }

    pub fn setTarget(self: *HexUnit, target_id: ?u32) void {
        self.base.target = target_id;
    }
};