const std = @import("std");
const EntityId = @import("entity.zig").EntityId;
const World = @import("world.zig").World;
const Zone = @import("zone.zig").Zone;
const components = @import("components.zig");
const archetype_storage = @import("archetype_storage.zig");

/// Transfer entity between zones
pub const EntityTransfer = struct {
    /// Get archetype of an entity from any zone
    pub fn getEntityArchetype(world: *const World, entity: EntityId) ?World.ArchetypeType {
        // Check each archetype storage
        if (world.players.hasEntity(entity)) return .player;
        if (world.units.hasEntity(entity)) return .unit;
        if (world.projectiles.hasEntity(entity)) return .projectile;
        if (world.obstacles.hasEntity(entity)) return .obstacle;
        if (world.lifestones.hasEntity(entity)) return .lifestone;
        if (world.portals.hasEntity(entity)) return .portal;
        return null;
    }

    /// Transfer player entity between zones
    pub fn transferPlayer(source_zone: *Zone, dest_zone: *Zone, entity: EntityId) !EntityId {
        const source_world = &source_zone.world;
        const dest_world = &dest_zone.world;
        
        std.log.info("transferPlayer: Transferring player entity {any}", .{entity});
        
        // Extract all components from source
        std.log.info("transferPlayer: Extracting transform component", .{});
        const transform = source_world.players.getComponent(entity, .transform) orelse {
            std.log.err("transferPlayer: Missing transform component", .{});
            return error.MissingComponent;
        };
        std.log.info("transferPlayer: Extracting health component", .{});
        const health = source_world.players.getComponent(entity, .health) orelse {
            std.log.err("transferPlayer: Missing health component", .{});
            return error.MissingComponent;
        };
        std.log.info("transferPlayer: Extracting movement component", .{});
        const movement = source_world.players.getComponent(entity, .movement) orelse {
            std.log.err("transferPlayer: Missing movement component", .{});
            return error.MissingComponent;
        };
        std.log.info("transferPlayer: Extracting visual component", .{});
        const visual = source_world.players.getComponent(entity, .visual) orelse {
            std.log.err("transferPlayer: Missing visual component", .{});
            return error.MissingComponent;
        };
        std.log.info("transferPlayer: Extracting player_input component", .{});
        const player_input = source_world.players.getComponent(entity, .player_input) orelse {
            std.log.err("transferPlayer: Missing player_input component", .{});
            return error.MissingComponent;
        };
        std.log.info("transferPlayer: Extracting combat component", .{});
        const combat = source_world.players.getComponent(entity, .combat) orelse {
            std.log.err("transferPlayer: Missing combat component", .{});
            return error.MissingComponent;
        };
        
        // Check for optional components
        std.log.info("transferPlayer: Extracting optional effects component", .{});
        const effects = source_world.players.getComponent(entity, .effects);
        
        std.log.info("transferPlayer: All components extracted, creating new player in destination zone", .{});
        // Create new player in destination zone with same components
        const new_entity = dest_world.createPlayer(
            transform.pos,
            transform.radius,
            health.max,
            player_input.controller_id
        ) catch |err| {
            std.log.err("transferPlayer: Failed to create player in destination zone: {}", .{err});
            return err;
        };
        std.log.info("transferPlayer: Created new player entity {any}", .{new_entity});
        
        // Copy remaining component data
        std.log.info("transferPlayer: Copying component data", .{});
        if (dest_world.players.getComponentMut(new_entity, .health)) |new_health| {
            new_health.current = health.current;
        }
        if (dest_world.players.getComponentMut(new_entity, .movement)) |new_movement| {
            new_movement.* = movement.*;
        }
        if (dest_world.players.getComponentMut(new_entity, .visual)) |new_visual| {
            new_visual.* = visual.*;
        }
        if (dest_world.players.getComponentMut(new_entity, .combat)) |new_combat| {
            new_combat.* = combat.*;
        }
        
        // Copy optional components
        if (effects) |eff| {
            std.log.info("transferPlayer: Copying effects component", .{});
            dest_world.players.addOptionalComponent(new_entity, .effects, eff.*) catch |err| {
                std.log.err("transferPlayer: Failed to add effects component: {}", .{err});
            };
        }
        
        // Destroy original entity
        std.log.info("transferPlayer: Component copying complete, destroying original entity", .{});
        source_world.destroyEntity(entity) catch |err| {
            std.log.err("transferPlayer: Failed to destroy original entity: {}", .{err});
            // Continue anyway - entity is duplicated but at least transfer worked
        };
        
        std.log.info("transferPlayer: Player transferred from entity {any} to entity {any}", .{ entity, new_entity });
        return new_entity;
    }

    /// Transfer unit entity between zones
    pub fn transferUnit(source_zone: *Zone, dest_zone: *Zone, entity: EntityId) !EntityId {
        const source_world = &source_zone.world;
        const dest_world = &dest_zone.world;
        
        // Extract components
        const transform = source_world.units.getComponent(entity, .transform) orelse return error.MissingComponent;
        const health = source_world.units.getComponent(entity, .health) orelse return error.MissingComponent;
        const movement = source_world.units.getComponent(entity, .movement) orelse return error.MissingComponent;
        const visual = source_world.units.getComponent(entity, .visual) orelse return error.MissingComponent;
        const unit = source_world.units.getComponent(entity, .unit) orelse return error.MissingComponent;
        const combat = source_world.units.getComponent(entity, .combat) orelse return error.MissingComponent;
        // Note: awakeable is not part of unit archetype, skip it
        const effects = source_world.units.getComponent(entity, .effects);
        
        // Create new unit with health
        const new_entity = try dest_world.createUnit(transform.pos, transform.radius, health.max);
        
        // Copy component data
        if (dest_world.units.getComponentMut(new_entity, .health)) |new_health| {
            new_health.current = health.current;
        }
        if (dest_world.units.getComponentMut(new_entity, .movement)) |new_movement| {
            new_movement.* = movement.*;
        }
        if (dest_world.units.getComponentMut(new_entity, .visual)) |new_visual| {
            new_visual.* = visual.*;
        }
        if (dest_world.units.getComponentMut(new_entity, .unit)) |new_unit| {
            new_unit.* = unit.*;
        }
        if (dest_world.units.getComponentMut(new_entity, .combat)) |new_combat| {
            new_combat.* = combat.*;
        }
        
        // Copy optional components
        if (effects) |eff| {
            try dest_world.units.addOptionalComponent(new_entity, .effects, eff.*);
        }
        
        // Destroy original
        try source_world.destroyEntity(entity);
        
        return new_entity;
    }

    /// Transfer any entity between zones based on its archetype
    pub fn transferEntity(source_zone: *Zone, dest_zone: *Zone, entity: EntityId) !EntityId {
        const archetype = getEntityArchetype(&source_zone.world, entity) orelse return error.EntityNotFound;
        
        return switch (archetype) {
            .player => try transferPlayer(source_zone, dest_zone, entity),
            .unit => try transferUnit(source_zone, dest_zone, entity),
            .projectile => return error.ProjectilesCannotTransfer, // Projectiles shouldn't transfer zones
            .obstacle => return error.ObstaclesCannotTransfer, // Obstacles are zone-specific
            .lifestone => return error.LifestonesCannotTransfer, // Lifestones are zone-specific
            .portal => return error.PortalsCannotTransfer, // Portals are zone-specific
        };
    }
};