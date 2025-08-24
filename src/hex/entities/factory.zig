const std = @import("std");

// Core capabilities
const math = @import("../../lib/math/mod.zig");
const colors = @import("../../lib/core/colors.zig");

// Game system capabilities
const components = @import("../../lib/game/components/mod.zig");

// Hex game modules
const constants = @import("../constants.zig");
const faction_presets = @import("../faction_presets.zig");
const faction_integration = @import("../faction_integration.zig");
const disposition = @import("../disposition.zig");
const unit_ext = @import("../unit_ext.zig");
const world_state_mod = @import("../world_state.zig");

// Debug capabilities
const loggers = @import("../../lib/debug/loggers.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const EntityId = u32;
const Unit = unit_ext.HexUnit;
const Disposition = disposition.Disposition;
const PlayerConfig = world_state_mod.PlayerConfig;

/// Entity creation methods extracted from hex_game.zig
pub const EntityFactory = struct {
    /// Create a lifestone entity in the specified zone
    pub fn createLifestone(hex_game: anytype, zone_index: usize, pos: Vec2, radius: f32, attuned: bool) !EntityId {
        if (zone_index >= world_state_mod.MAX_ZONES) return error.InvalidZone;

        const zone = hex_game.zone_manager.getZone(zone_index);
        const entity = hex_game.entity_allocator.create();

        // Determine color based on attunement
        const color = if (attuned)
            constants.COLOR_LIFESTONE_ATTUNED
        else
            constants.COLOR_LIFESTONE_UNATTUNED;

        // Create components directly
        const transform = components.Transform.init(pos, radius);
        const visual = components.Visual.init(color);
        // Use floor terrain type - lifestones are identified by component composition, not terrain type
        const terrain = components.Terrain.init(.floor, Vec2.init(radius * 2, radius * 2));
        // Lifestone is identified by having an Interactable component with attunement capability
        var interactable = components.Interactable.init(.deflectable);
        interactable.state = .normal;
        interactable.attuned = attuned; // This marks it as a lifestone checkpoint

        try zone.lifestones.addEntity(entity, transform, visual, terrain, interactable);
        zone.entity_count += 1;

        hex_game.logger.debug("lifestone_created", "Created lifestone in zone {} at {any}, attuned: {}", .{ zone_index, pos, attuned });

        return entity;
    }

    /// Create a unit entity in the specified zone
    pub fn createUnit(hex_game: anytype, zone_index: usize, pos: Vec2, radius: f32, unit_disposition: Disposition) !EntityId {
        if (zone_index >= world_state_mod.MAX_ZONES) return error.InvalidZone;

        const zone = hex_game.zone_manager.getZone(zone_index);
        const entity = hex_game.entity_allocator.create();

        // Create components directly
        const transform = components.Transform.init(pos, radius);
        const health = components.Health.init(50);
        const visual = components.Visual.init(constants.COLOR_UNIT_DEFAULT);
        const entity_id = hex_game.entity_allocator.create();
        // Create regular unit with default speed and energy
        const unit = Unit.init(.{
            .unit_type = .enemy,
            .home_pos = pos,
            .disposition = unit_disposition,
            .entity_id = entity_id,
            // speed and energy use defaults from UnitConfig
        });

        try zone.units.addEntity(entity, transform, health, unit, visual);
        zone.entity_count += 1;

        // Log faction system initialization for debugging
        const unit_factions = faction_presets.getUnitFactions(unit_disposition, .enemy);
        const unit_capabilities = faction_presets.getUnitCapabilities(unit_disposition);
        hex_game.logger.debug("unit_factions", "Unit created with disposition {s}, {} faction tags, attack capability: {}", .{ @tagName(unit_disposition), unit_factions.tags.count(), unit_capabilities.can_attack });

        return entity;
    }

    /// Create a terrain entity in the specified zone
    pub fn createTerrain(hex_game: anytype, zone_index: usize, pos: Vec2, size: Vec2, is_deadly: bool) !EntityId {
        if (zone_index >= world_state_mod.MAX_ZONES) return error.InvalidZone;

        const zone = hex_game.zone_manager.getZone(zone_index);
        const entity = hex_game.entity_allocator.create();

        const color = if (is_deadly) constants.COLOR_OBSTACLE_DEADLY else constants.COLOR_OBSTACLE_BLOCKING;

        // Use generic factory pattern for obstacle creation
        // Create components directly
        const radius = @max(size.x, size.y) / 2.0; // Convert size to radius
        const transform = components.Transform.init(pos, radius);
        const terrain_type: components.Terrain.TerrainType = if (is_deadly) .pit else .rock;
        const terrain = components.Terrain.init(terrain_type, size);
        const visual = components.Visual.init(color);

        try zone.terrain.addEntity(entity, transform, terrain, visual);
        zone.entity_count += 1;

        return entity;
    }

    /// Create a portal entity in the specified zone
    pub fn createPortal(hex_game: anytype, zone_index: usize, pos: Vec2, radius: f32, destination: usize) !EntityId {
        if (zone_index >= world_state_mod.MAX_ZONES) return error.InvalidZone;

        const zone = hex_game.zone_manager.getZone(zone_index);
        const entity = hex_game.entity_allocator.create();

        // Use generic factory pattern for portal creation
        // Create components directly
        const transform = components.Transform.init(pos, radius);
        const visual = components.Visual.init(constants.COLOR_PORTAL);
        const terrain = components.Terrain.init(.floor, Vec2.init(radius * 2, radius * 2));
        var interactable = components.Interactable.init(.deflectable);
        interactable.destination_zone = destination;

        try zone.portals.addEntity(entity, transform, visual, terrain, interactable);
        zone.entity_count += 1;

        return entity;
    }

    /// Create a player entity in the current zone
    pub fn createPlayer(hex_game: anytype, config: PlayerConfig) !EntityId {
        const zone = hex_game.getCurrentZone();
        const entity = hex_game.entity_allocator.create();

        // Create components for a player unit
        const transform = components.Transform.init(config.position, config.radius);
        const health = components.Health.init(100); // Player has more health than regular units
        const visual = components.Visual.init(constants.COLOR_PLAYER_ALIVE);

        // Create player unit using data-driven configuration
        const unit = Unit.init(.{
            .unit_type = .player,
            .home_pos = config.position,
            .disposition = config.disposition,
            .entity_id = entity,
            .speed = config.speed, // Speed from world data
            .energy = config.energy, // Energy level from world data
        });
        try zone.units.addEntity(entity, transform, health, unit, visual);
        zone.entity_count += 1;

        // Log faction system initialization for debugging
        const player_factions = faction_presets.getPlayerFactions();
        const player_capabilities = faction_presets.getPlayerCapabilities();
        hex_game.logger.debug("player_factions", "Player created with {} faction tags and attack capability: {}", .{ player_factions.tags.count(), player_capabilities.can_attack });

        // Controller system: possess the created player entity
        const possession_success = hex_game.primary_controller.possess(hex_game, entity);
        if (possession_success) {
            hex_game.logger.info("possession", "Controller 0 possessed entity {}", .{entity});
        }

        return entity;
    }

    /// Create a projectile entity in the specified zone
    pub fn createProjectile(hex_game: anytype, zone_index: usize, pos: Vec2, radius: f32, velocity: Vec2, lifetime: f32, shooter_id: EntityId) !EntityId {
        _ = radius; // Currently unused, kept for API compatibility
        if (zone_index >= world_state_mod.MAX_ZONES) return error.InvalidZone;

        const zone = hex_game.zone_manager.getZone(zone_index);
        const entity = hex_game.entity_allocator.create();

        // Create components directly
        var transform = components.Transform.init(pos, constants.PROJECTILE_RADIUS); // 20cm projectile radius (world space)
        transform.vel = velocity;
        const visual = components.Visual.init(.{ .r = 255, .g = 255, .b = 0, .a = 255 }); // Yellow projectile

        // Create hex-specific projectile with damage - use shooter_id as owner
        const projectile = world_state_mod.Projectile.init(shooter_id, lifetime, constants.PROJECTILE_DAMAGE);

        try zone.projectiles.addEntity(entity, transform, projectile, visual);
        zone.entity_count += 1;

        return entity;
    }
};
