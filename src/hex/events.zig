const math = @import("../lib/math/mod.zig");
const Vec2 = math.Vec2;
const game_systems = @import("../lib/game/game.zig");

/// Hex-specific game events
pub const HexCustomEvents = union(enum) {
    // Lifestone events
    lifestone_attuned: struct { zone: usize, index: usize, pos: Vec2 },
    all_lifestones_attuned: struct { total_count: usize },

    // Portal events
    portal_entered: struct { from_zone: usize, to_zone: usize, portal_index: usize },

    // Spell events
    spell_cast: struct { spell_id: usize, target_pos: Vec2, caster_pos: Vec2 },
    spell_cooldown_expired: struct { spell_id: usize },

    // Combat events
    bullet_fired: struct { pos: Vec2, direction: Vec2 },
    bullet_hit_unit: struct { unit_id: usize, damage: f32 },
    player_respawned: struct { pos: Vec2, zone: usize },

    // Zone events
    zone_units_cleared: struct { zone: usize },
    zone_fully_explored: struct { zone: usize },
};

/// Complete event type for Hex game
pub const HexEvents = game_systems.GameEvents(HexCustomEvents);

/// Helper function to create a lifestone attuned event
pub fn lifestoneAttuned(zone: usize, index: usize, pos: Vec2) HexEvents {
    return HexEvents{
        .custom = .{
            .lifestone_attuned = .{
                .zone = zone,
                .index = index,
                .pos = pos,
            },
        },
    };
}

/// Helper function to create an all lifestones attuned event
pub fn allLifestonesAttuned(total_count: usize) HexEvents {
    return HexEvents{
        .custom = .{
            .all_lifestones_attuned = .{
                .total_count = total_count,
            },
        },
    };
}

/// Helper function to create a portal entered event
pub fn portalEntered(from_zone: usize, to_zone: usize, portal_index: usize) HexEvents {
    return HexEvents{
        .custom = .{
            .portal_entered = .{
                .from_zone = from_zone,
                .to_zone = to_zone,
                .portal_index = portal_index,
            },
        },
    };
}

/// Helper function to create a player respawned event
pub fn playerRespawned(pos: Vec2, zone: usize) HexEvents {
    return HexEvents{
        .custom = .{
            .player_respawned = .{
                .pos = pos,
                .zone = zone,
            },
        },
    };
}
