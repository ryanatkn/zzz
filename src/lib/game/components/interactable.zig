const math = @import("../../math/mod.zig");
pub const Vec2 = math.Vec2;

// Import Unit for transform data
const unit_mod = @import("unit.zig");
pub const Unit = unit_mod.Unit;
const EntityId = u32;

/// Interactable - enables entity interactions (deflection, telekinesis, etc.)
/// Sparse storage - only interactive entities have this
pub const Interactable = struct {
    pub const InteractionType = enum {
        deflectable, // Can be deflected by spells/abilities
        telekinetic, // Can be moved by telekinesis
        transformable, // Can be polymorphed
        combinable, // Can merge with other entities
        splittable, // Can split into multiple entities
    };

    pub const InteractionState = enum {
        normal,
        being_deflected,
        being_moved,
        transforming,
        combining,
        splitting,
    };

    interaction_type: InteractionType,
    state: InteractionState,
    interaction_timer: f32,
    destination_zone: ?usize, // For portals - zone to travel to
    attuned: bool, // For lifestones - whether player is attuned to this lifestone
    interaction_data: union(enum) {
        deflect: struct {
            new_direction: Vec2,
            force: f32,
        },
        telekinesis: struct {
            target_pos: Vec2,
            controller: EntityId,
        },
        transform: struct {
            target_type: Unit.UnitType,
            progress: f32,
        },
        none: void,
    },

    pub fn init(interaction_type: InteractionType) Interactable {
        return .{
            .interaction_type = interaction_type,
            .state = .normal,
            .interaction_timer = 0,
            .destination_zone = null,
            .attuned = false,
            .interaction_data = .none,
        };
    }

    pub fn initPortal(destination: usize) Interactable {
        return .{
            .interaction_type = .telekinetic,
            .state = .normal,
            .interaction_timer = 0,
            .destination_zone = destination,
            .attuned = false,
            .interaction_data = .none,
        };
    }

    pub fn startDeflection(self: *Interactable, direction: Vec2, force: f32) void {
        if (self.interaction_type == .deflectable) {
            self.state = .being_deflected;
            self.interaction_timer = 0.5; // 0.5 second deflection
            self.interaction_data = .{ .deflect = .{ .new_direction = direction, .force = force } };
        }
    }

    pub fn update(self: *Interactable, dt: f32) void {
        if (self.state != .normal) {
            self.interaction_timer -= dt;
            if (self.interaction_timer <= 0) {
                self.state = .normal;
                self.interaction_data = .none;
            }
        }
    }
};