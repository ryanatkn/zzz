const std = @import("std");

const hex_game_mod = @import("hex_game.zig");
const faction_integration = @import("faction_integration.zig");
const Vec2 = @import("../lib/math/mod.zig").Vec2;
const Color = @import("../lib/core/colors.zig").Color;
const components = @import("../lib/game/components/mod.zig");

const HexGame = hex_game_mod.HexGame;
const EntityId = hex_game_mod.EntityId;
const Health = hex_game_mod.Health;
const Transform = hex_game_mod.Transform;
const Visual = hex_game_mod.Visual;
const Movement = hex_game_mod.Movement;

/// Generic entity queries to replace player-specific methods
/// These work with any entity in the current zone
/// Get position of any entity (replaces getPlayerPos)
pub fn getEntityPos(world: *const HexGame, entity_id: EntityId) ?Vec2 {
    const zone = world.getCurrentZoneConst();

    // Check player storage first
    if (zone.players.getComponent(entity_id, .transform)) |transform| {
        return transform.pos;
    }

    // Check unit storage
    if (zone.units.getComponent(entity_id, .transform)) |transform| {
        return transform.pos;
    }

    return null;
}

/// Set position of any entity (replaces setPlayerPos)
pub fn setEntityPos(world: *HexGame, entity_id: EntityId, pos: Vec2) void {
    const zone = world.getCurrentZone();

    // Try player storage first
    if (zone.players.getComponentMut(entity_id, .transform)) |transform| {
        transform.pos = pos;
        return;
    }

    // Try unit storage
    if (zone.units.getComponentMut(entity_id, .transform)) |transform| {
        transform.pos = pos;
    }
}

/// Get velocity of any entity (replaces getPlayerVelConst)
pub fn getEntityVelocity(world: *const HexGame, entity_id: EntityId) Vec2 {
    const zone = world.getCurrentZoneConst();

    // Check player storage first (velocity stored in transform for players too)
    if (zone.players.getComponent(entity_id, .transform)) |transform| {
        return transform.vel;
    }

    // Check unit storage (has velocity in Transform)
    if (zone.units.getComponent(entity_id, .transform)) |transform| {
        return transform.vel;
    }

    return Vec2.ZERO;
}

/// Set velocity of any entity (replaces setPlayerVel)
pub fn setEntityVelocity(world: *HexGame, entity_id: EntityId, vel: Vec2) void {
    const zone = world.getCurrentZone();

    // Try player storage first (velocity stored in transform for players too)
    if (zone.players.getComponentMut(entity_id, .transform)) |transform| {
        transform.vel = vel;
        return;
    }

    // Try unit storage (has velocity in Transform)
    if (zone.units.getComponentMut(entity_id, .transform)) |transform| {
        transform.vel = vel;
    }
}

/// Check if entity is alive (replaces getPlayerAlive)
pub fn isEntityAlive(world: *const HexGame, entity_id: EntityId) bool {
    const zone = world.getCurrentZoneConst();

    // Check player storage
    if (zone.players.getComponent(entity_id, .health)) |health| {
        return health.alive;
    }

    // Check unit storage
    if (zone.units.getComponent(entity_id, .health)) |health| {
        return health.alive;
    }

    return false;
}

/// Set entity alive state (replaces setPlayerAlive)
pub fn setEntityAlive(world: *HexGame, entity_id: EntityId, alive: bool) void {
    const zone = world.getCurrentZone();

    // Try player storage first
    if (zone.players.getComponentMut(entity_id, .health)) |health| {
        health.alive = alive;
        return;
    }

    // Try unit storage
    if (zone.units.getComponentMut(entity_id, .health)) |health| {
        health.alive = alive;
    }
}

/// Get entity radius (replaces getPlayerRadius)
pub fn getEntityRadius(world: *const HexGame, entity_id: EntityId) ?f32 {
    const zone = world.getCurrentZoneConst();

    // Check player storage
    if (zone.players.getComponent(entity_id, .transform)) |transform| {
        return transform.radius;
    }

    // Check unit storage
    if (zone.units.getComponent(entity_id, .transform)) |transform| {
        return transform.radius;
    }

    return null;
}

/// Set entity color (replaces setPlayerColor)
pub fn setEntityColor(world: *HexGame, entity_id: EntityId, color: Color) void {
    const zone = world.getCurrentZone();

    // Try player storage first
    if (zone.players.getComponentMut(entity_id, .visual)) |visual| {
        visual.color = color;
        return;
    }

    // Try unit storage
    if (zone.units.getComponentMut(entity_id, .visual)) |visual| {
        visual.color = color;
    }
}

/// Get entity health (new - more granular than alive check)
pub fn getEntityHealth(world: *const HexGame, entity_id: EntityId) ?*const Health {
    const zone = world.getCurrentZoneConst();

    // Check player storage
    if (zone.players.getComponent(entity_id, .health)) |health| {
        return health;
    }

    // Check unit storage
    if (zone.units.getComponent(entity_id, .health)) |health| {
        return health;
    }

    return null;
}

/// Get entity transform (new - access to full transform data)
pub fn getEntityTransform(world: *const HexGame, entity_id: EntityId) ?*const Transform {
    const zone = world.getCurrentZoneConst();

    // Check player storage
    if (zone.players.getComponent(entity_id, .transform)) |transform| {
        return transform;
    }

    // Check unit storage
    if (zone.units.getComponent(entity_id, .transform)) |transform| {
        return transform;
    }

    return null;
}

/// Get mutable entity transform (for updates)
pub fn getEntityTransformMutable(world: *HexGame, entity_id: EntityId) ?*Transform {
    const zone = world.getCurrentZone();

    // Check player storage
    if (zone.players.getComponent(entity_id, .transform)) |transform| {
        return transform;
    }

    // Check unit storage
    if (zone.units.getComponent(entity_id, .transform)) |transform| {
        return transform;
    }

    return null;
}

/// Find all controllable entities in current zone
pub fn findControllableEntities(world: *const HexGame, buffer: []EntityId) usize {
    const zone = world.getCurrentZoneConst();
    var count: usize = 0;

    // Check players (players are typically controllable)
    var player_iter = zone.players.entityIterator();
    while (player_iter.next()) |entity_id| {
        if (count >= buffer.len) break;

        if (faction_integration.canEntityBeControlled(world, entity_id)) {
            buffer[count] = entity_id;
            count += 1;
        }
    }

    // Check units that can be controlled (rare but supported)
    var unit_iter = zone.units.entityIterator();
    while (unit_iter.next()) |entity_id| {
        if (count >= buffer.len) break;

        if (faction_integration.canEntityBeControlled(world, entity_id)) {
            buffer[count] = entity_id;
            count += 1;
        }
    }

    return count;
}

/// Check if entity exists in current zone
pub fn entityExists(world: *const HexGame, entity_id: EntityId) bool {
    const zone = world.getCurrentZoneConst();

    return zone.players.containsEntity(entity_id) or zone.units.containsEntity(entity_id);
}

/// Get entity type (player vs unit)
pub const EntityType = enum {
    player,
    unit,
    unknown,
};

pub fn getEntityType(world: *const HexGame, entity_id: EntityId) EntityType {
    const zone = world.getCurrentZoneConst();

    if (zone.players.containsEntity(entity_id)) return .player;
    if (zone.units.containsEntity(entity_id)) return .unit;
    return .unknown;
}

/// Movement bounds helper for controlled entities
pub fn applyMovementBounds(world: *const HexGame, entity_id: EntityId, pos: Vec2) Vec2 {
    const zone = world.getCurrentZoneConst();
    var new_pos = pos;

    // Use screen bounds only in fixed camera mode (overworld)
    if (zone.camera_mode == .fixed) {
        const entity_radius = getEntityRadius(world, entity_id) orelse 20.0;
        const margin = entity_radius + 10.0; // PLAYER_BOUNDARY_MARGIN equivalent

        if (new_pos.x < margin) new_pos.x = margin;
        if (new_pos.y < margin) new_pos.y = margin;
        if (new_pos.x > 1600.0 - margin) new_pos.x = 1600.0 - margin; // SCREEN_WIDTH
        if (new_pos.y > 1200.0 - margin) new_pos.y = 1200.0 - margin; // SCREEN_HEIGHT
    }

    return new_pos;
}

/// Check if entity can move to a position (collision-aware)
pub fn canEntityMoveTo(world: *const HexGame, entity_id: EntityId, new_pos: Vec2) bool {
    // This will delegate to physics system
    // For now, placeholder implementation
    _ = world;
    _ = entity_id;
    _ = new_pos;
    return true; // TODO: Implement collision checking
}
