// Extended Unit Component - Hex-specific unit with disposition
// Extends the generic lib/game Unit with hex-specific fields

const Unit = @import("../lib/game/components/unit.zig").Unit;
const Disposition = @import("disposition.zig").Disposition;
const Vec2 = @import("../lib/math/mod.zig").Vec2;
const constants = @import("constants.zig");
const EnergyLevel = constants.EnergyLevel;

/// Configuration for creating a HexUnit
pub const UnitConfig = struct {
    unit_type: Unit.UnitType,
    home_pos: Vec2,
    disposition: Disposition,
    entity_id: u32,
    speed: f32 = constants.UNIT_SPEED, // Default speed for regular units
    energy: EnergyLevel = .normal, // Default energy level
};

/// Hex-specific unit extension with disposition and aggro
pub const HexUnit = struct {
    // Base unit component
    base: Unit,

    // Hex-specific disposition fields (temperament/personality)
    disposition: Disposition,
    aggro_range: f32, // world space detection range (meters)
    aggro_factor: f32,
    entity_id: u32,
    energy_level: EnergyLevel,
    move_speed: f32, // Movement speed in meters/second

    pub fn init(config: UnitConfig) HexUnit {
        return .{
            .base = Unit.init(config.unit_type, config.home_pos),
            .disposition = config.disposition,
            .aggro_range = switch (config.unit_type) {
                .enemy => 12.5, // 12.5m detection range (was 150px)
                .friendly => 8.33, // 8.33m detection range (was 100px)
                .neutral => 10.0, // 10.0m detection range (was 120px)
                .player => 0.0, // Player doesn't need aggro detection
            },
            .aggro_factor = 1.0,
            .entity_id = config.entity_id,
            .energy_level = config.energy,
            .move_speed = config.speed,
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
