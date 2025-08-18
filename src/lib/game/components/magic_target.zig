/// MagicTarget - defines how spells can target this entity
/// Sparse storage - only entities that can be targeted by magic have this
pub const MagicTarget = struct {
    pub const TargetType = enum {
        single, // Single entity target (click to target)
        self, // Self-cast only (ctrl+click)
        area, // Area effect (click for center, ctrl+click for self-centered)
        line, // Line/ray effect (drag from caster)
        cone, // Cone effect (drag direction)
    };

    targetable: bool = true,
    self_castable: bool = true,
    area_radius: f32 = 0, // 0 = single target, >0 = AoE radius
    target_type: TargetType = .single,
    requires_line_of_sight: bool = true,
    blocks_targeting: bool = false, // Can this entity block targeting of entities behind it?

    pub fn init(target_type: TargetType) MagicTarget {
        return .{
            .targetable = true,
            .self_castable = target_type == .self or target_type == .area,
            .area_radius = 0,
            .target_type = target_type,
            .requires_line_of_sight = true,
            .blocks_targeting = false,
        };
    }

    pub fn initArea(radius: f32) MagicTarget {
        return .{
            .targetable = true,
            .self_castable = true,
            .area_radius = radius,
            .target_type = .area,
            .requires_line_of_sight = false, // AoE doesn't need LOS to center
            .blocks_targeting = false,
        };
    }

    pub fn initSingleTarget() MagicTarget {
        return .{
            .targetable = true,
            .self_castable = false,
            .area_radius = 0,
            .target_type = .single,
            .requires_line_of_sight = true,
            .blocks_targeting = false,
        };
    }

    pub fn canBeTargeted(self: MagicTarget) bool {
        return self.targetable;
    }

    pub fn canSelfCast(self: MagicTarget) bool {
        return self.self_castable;
    }

    pub fn isAreaEffect(self: MagicTarget) bool {
        return self.area_radius > 0 or self.target_type == .area;
    }

    pub fn getEffectiveRadius(self: MagicTarget) f32 {
        return if (self.isAreaEffect()) self.area_radius else 0;
    }
};