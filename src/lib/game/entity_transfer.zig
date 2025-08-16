const std = @import("std");
const EntityId = @import("entity.zig").EntityId;
const World = @import("world.zig").World;
const Zone = @import("zone.zig").Zone;
const components = @import("components.zig");
const archetype_storage = @import("archetype_storage.zig");

/// Data needed to transfer an entity between zones (stateless)
pub const TransferData = struct {
    archetype: World.ArchetypeType,
    
    // Core components (always present)
    transform: components.Transform,
    visual: components.Visual,
    
    // Components by archetype
    health: ?components.Health = null,
    movement: ?components.Movement = null,
    player_input: ?components.PlayerInput = null,
    combat: ?components.Combat = null,
    unit: ?components.Unit = null,
    projectile: ?components.Projectile = null,
    terrain: ?components.Terrain = null,
    interactable: ?components.Interactable = null,
    effects: ?components.Effects = null,
    
    // Metadata
    is_player: bool = false,
};

/// Result of a transfer operation
pub const TransferResult = struct {
    old_entity: EntityId,
    new_entity: EntityId,
    zone_id: u8,
};

/// Transfer entity between zones
pub const EntityTransfer = struct {
    /// Extract transfer data from an entity (for stateless transfer)
    pub fn extractTransferData(zone: *const Zone, entity: EntityId) !TransferData {
        const world = &zone.world;
        
        // Determine archetype
        const archetype = getEntityArchetype(world, entity) orelse return error.EntityNotFound;
        
        var data = TransferData{
            .archetype = archetype,
            .transform = undefined,
            .visual = undefined,
        };
        
        // Extract components based on archetype
        switch (archetype) {
            .player => {
                const transform_ptr = world.players.getComponent(entity, .transform) orelse return error.MissingComponent;
                const visual_ptr = world.players.getComponent(entity, .visual) orelse return error.MissingComponent;
                data.transform = transform_ptr.*;
                data.visual = visual_ptr.*;
                if (world.players.getComponent(entity, .health)) |h| data.health = h.*;
                if (world.players.getComponent(entity, .movement)) |m| data.movement = m.*;
                if (world.players.getComponent(entity, .player_input)) |p| data.player_input = p.*;
                if (world.players.getComponent(entity, .combat)) |c| data.combat = c.*;
                if (world.players.getComponent(entity, .effects)) |e| data.effects = e.*;
                data.is_player = true;
            },
            .unit => {
                const transform_ptr = world.units.getComponent(entity, .transform) orelse return error.MissingComponent;
                const visual_ptr = world.units.getComponent(entity, .visual) orelse return error.MissingComponent;
                data.transform = transform_ptr.*;
                data.visual = visual_ptr.*;
                if (world.units.getComponent(entity, .health)) |h| data.health = h.*;
                if (world.units.getComponent(entity, .movement)) |m| data.movement = m.*;
                if (world.units.getComponent(entity, .unit)) |u| data.unit = u.*;
                if (world.units.getComponent(entity, .combat)) |c| data.combat = c.*;
                if (world.units.getComponent(entity, .effects)) |e| data.effects = e.*;
            },
            else => {
                // For now, other archetypes not supported for transfer
                return error.UnsupportedArchetype;
            }
        }
        
        return data;
    }
    
    /// Stateless transfer - create entity in destination from transfer data
    pub fn createFromTransferData(dest_zone: *Zone, data: TransferData) !EntityId {
        const world = &dest_zone.world;
        
        switch (data.archetype) {
            .player => {
                const player_input = data.player_input orelse return error.MissingComponent;
                const health = data.health orelse return error.MissingComponent;
                
                const new_entity = try world.createPlayer(
                    data.transform.pos,
                    data.transform.radius,
                    health.max,
                    player_input.controller_id
                );
                
                // Update components with transferred data
                if (world.players.getComponentMut(new_entity, .transform)) |transform| {
                    transform.vel = data.transform.vel;
                }
                if (world.players.getComponentMut(new_entity, .health)) |h| {
                    h.current = health.current;
                    h.alive = health.alive;
                }
                if (data.movement) |movement| {
                    if (world.players.getComponentMut(new_entity, .movement)) |m| {
                        m.* = movement;
                    }
                }
                if (world.players.getComponentMut(new_entity, .visual)) |v| {
                    v.* = data.visual;
                }
                if (data.combat) |combat| {
                    if (world.players.getComponentMut(new_entity, .combat)) |c| {
                        c.* = combat;
                    }
                }
                if (data.effects) |effects| {
                    try world.players.addOptionalComponent(new_entity, .effects, effects);
                }
                
                return new_entity;
            },
            .unit => {
                const health = data.health orelse return error.MissingComponent;
                
                const new_entity = try world.createUnit(
                    data.transform.pos,
                    data.transform.radius,
                    health.max
                );
                
                // Update components
                if (world.units.getComponentMut(new_entity, .transform)) |transform| {
                    transform.vel = data.transform.vel;
                }
                if (world.units.getComponentMut(new_entity, .health)) |h| {
                    h.current = health.current;
                    h.alive = health.alive;
                }
                if (data.unit) |unit| {
                    if (world.units.getComponentMut(new_entity, .unit)) |u| {
                        u.* = unit;
                    }
                }
                if (world.units.getComponentMut(new_entity, .visual)) |v| {
                    v.* = data.visual;
                }
                if (data.combat) |combat| {
                    if (world.units.getComponentMut(new_entity, .combat)) |c| {
                        c.* = combat;
                    }
                }
                if (data.effects) |effects| {
                    try world.units.addOptionalComponent(new_entity, .effects, effects);
                }
                
                return new_entity;
            },
            else => return error.UnsupportedArchetype,
        }
    }
    
    /// Perform a stateless entity transfer
    pub fn transferStateless(
        source_zone: *Zone,
        dest_zone: *Zone, 
        entity: EntityId,
        dest_zone_id: u8
    ) !TransferResult {
        // Extract data from source
        const data = try extractTransferData(source_zone, entity);
        
        // Create in destination
        const new_entity = try createFromTransferData(dest_zone, data);
        
        // Destroy in source
        try source_zone.world.destroyEntity(entity);
        
        return TransferResult{
            .old_entity = entity,
            .new_entity = new_entity,
            .zone_id = dest_zone_id,
        };
    }
    
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
};