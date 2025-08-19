/// Entity capabilities define what an entity can do in the game world
/// This separates what entities CAN do from their current state
pub const Capabilities = struct {
    // Movement capabilities
    can_move: bool = true,
    move_speed: f32 = 100.0,

    // Control capabilities
    can_be_controlled: bool = false, // Can player/AI control this entity?

    // Combat capabilities
    can_attack: bool = false,
    attack_damage: f32 = 10.0,
    can_be_damaged: bool = true,

    // Interaction capabilities
    can_interact: bool = false, // Can be talked to, traded with, etc.

    /// Create capabilities with sensible defaults
    pub fn init() Capabilities {
        return .{};
    }

    /// Create capabilities for a player entity
    pub fn initPlayer(move_speed: f32, damage: f32) Capabilities {
        return .{
            .can_move = true,
            .move_speed = move_speed,
            .can_be_controlled = true,
            .can_attack = true,
            .attack_damage = damage,
            .can_be_damaged = true,
            .can_interact = true,
        };
    }

    /// Create capabilities for a hostile unit
    pub fn initHostileUnit(move_speed: f32, damage: f32) Capabilities {
        return .{
            .can_move = true,
            .move_speed = move_speed,
            .can_be_controlled = true,
            .can_attack = true,
            .attack_damage = damage,
            .can_be_damaged = true,
            .can_interact = false,
        };
    }

    /// Create capabilities for a friendly unit
    pub fn initFriendlyUnit(move_speed: f32) Capabilities {
        return .{
            .can_move = true,
            .move_speed = move_speed,
            .can_be_controlled = true,
            .can_attack = false, // Friendly units don't attack
            .attack_damage = 0.0,
            .can_be_damaged = true,
            .can_interact = true,
        };
    }

    /// Create capabilities for a neutral/passive entity
    pub fn initNeutral(move_speed: f32) Capabilities {
        return .{
            .can_move = true,
            .move_speed = move_speed,
            .can_be_controlled = true,
            .can_attack = false,
            .attack_damage = 0.0,
            .can_be_damaged = true,
            .can_interact = true,
        };
    }

    /// Create capabilities for a static/immobile entity
    pub fn initStatic() Capabilities {
        return .{
            .can_move = false,
            .move_speed = 0.0,
            .can_be_controlled = false,
            .can_attack = false,
            .attack_damage = 0.0,
            .can_be_damaged = false,
            .can_interact = true,
        };
    }
};
