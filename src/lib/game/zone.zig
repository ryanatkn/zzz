const std = @import("std");
const components = @import("components.zig");
const colors = @import("../core/colors.zig");
const World = @import("world.zig").World;
const EntityId = @import("entity.zig").EntityId;

pub const ZoneMetadata = struct {
    pub const ZoneType = enum {
        overworld,
        dungeon_fire,
        dungeon_ice,
        dungeon_storm,
        dungeon_nature,
        dungeon_shadow,
        dungeon_arcane,
    };

    pub const CameraMode = enum {
        fixed,
        follow,
    };

    zone_type: ZoneType,
    camera_mode: CameraMode,
    camera_scale: f32,
    spawn_pos: components.Vec2,
    background_color: colors.Color,
};

/// Lightweight zone that composes a World with metadata
pub const Zone = struct {
    id: u8,
    world: World,
    metadata: ZoneMetadata,

    pub const Config = struct {
        id: u8,
        metadata: ZoneMetadata,
        max_entities: usize,
    };

    pub fn init(allocator: std.mem.Allocator, config: Config) !Zone {
        return .{
            .id = config.id,
            .world = try World.init(allocator, config.max_entities),
            .metadata = config.metadata,
        };
    }

    pub fn deinit(self: *Zone) void {
        self.world.deinit();
    }

    // Delegate entity creation methods to world
    pub fn createPlayer(self: *Zone, pos: components.Vec2, radius: f32, health: f32, controller_id: u8) !EntityId {
        return self.world.createPlayer(pos, radius, health, controller_id);
    }

    pub fn createUnit(self: *Zone, pos: components.Vec2, radius: f32, health: f32) !EntityId {
        return self.world.createUnit(pos, radius, health);
    }

    pub fn createProjectile(self: *Zone, pos: components.Vec2, velocity: components.Vec2, radius: f32, damage: f32, owner: EntityId, lifetime: f32) !EntityId {
        return self.world.createProjectile(pos, velocity, radius, damage, owner, lifetime);
    }

    pub fn createObstacle(self: *Zone, pos: components.Vec2, size: components.Vec2, is_deadly: bool) !EntityId {
        return self.world.createObstacle(pos, size, is_deadly);
    }

    pub fn createLifestone(self: *Zone, pos: components.Vec2, radius: f32, attuned: bool) !EntityId {
        return self.world.createLifestone(pos, radius, attuned);
    }

    pub fn createPortal(self: *Zone, pos: components.Vec2, radius: f32, destination_zone: u8) !EntityId {
        return self.world.createPortal(pos, radius, destination_zone);
    }

    pub fn destroyEntity(self: *Zone, entity: EntityId) !void {
        return self.world.destroyEntity(entity);
    }

    pub fn isAlive(self: *Zone, entity: EntityId) bool {
        return self.world.isAlive(entity);
    }
};