const std = @import("std");
const component_registry = @import("component_registry.zig");
const world_mod = @import("world.zig");

const ComponentRegistry = component_registry.ComponentRegistry;
const World = world_mod.World;
const Game = world_mod.Game;

/// System access patterns for dependency tracking
pub const SystemAccess = struct {
    read_components: []const ComponentRegistry.ComponentType,
    write_components: []const ComponentRegistry.ComponentType,
    archetype_access: []const ArchetypeAccess,

    pub const ArchetypeAccess = struct {
        archetype: component_registry.ArchetypeRegistry.ArchetypeType,
        access_type: AccessType,
    };

    pub const AccessType = enum {
        read_only,
        read_write,
        create_destroy, // Can create/destroy entities in this archetype
    };
};

/// System function signature for world-local systems
pub const WorldSystemFn = *const fn (world: *World, dt: f32) anyerror!void;

/// System function signature for game-global systems
pub const GameSystemFn = *const fn (game: *Game, dt: f32) anyerror!void;

/// System information and metadata
pub const SystemInfo = struct {
    name: []const u8,
    system_fn: SystemFunction,
    access: SystemAccess,
    schedule_group: ScheduleGroup,
    enabled: bool,

    pub const SystemFunction = union(enum) {
        world_local: WorldSystemFn,
        game_global: GameSystemFn,
    };

    pub const ScheduleGroup = enum {
        input,       // Input processing systems
        movement,    // Movement and physics systems
        combat,      // Combat and collision systems
        effects,     // Effect processing and updates
        rendering,   // Rendering and visual systems
        cleanup,     // Cleanup and maintenance systems
    };
};

/// System registry for managing game systems
pub const SystemRegistry = struct {
    systems: std.ArrayList(SystemInfo),
    execution_order: std.ArrayList(usize), // Indices into systems array
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SystemRegistry {
        return .{
            .systems = std.ArrayList(SystemInfo).init(allocator),
            .execution_order = std.ArrayList(usize).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SystemRegistry) void {
        self.systems.deinit();
        self.execution_order.deinit();
    }

    /// Register a system with the registry
    pub fn registerSystem(self: *SystemRegistry, system_info: SystemInfo) !void {
        const index = self.systems.items.len;
        try self.systems.append(system_info);
        try self.execution_order.append(index);
        
        // Sort execution order by schedule group
        self.sortExecutionOrder();
    }

    /// Enable or disable a system
    pub fn setSystemEnabled(self: *SystemRegistry, system_name: []const u8, enabled: bool) void {
        for (self.systems.items) |*system| {
            if (std.mem.eql(u8, system.name, system_name)) {
                system.enabled = enabled;
                break;
            }
        }
    }

    /// Execute all enabled world-local systems on a world
    pub fn executeWorldSystems(self: *SystemRegistry, world: *World, dt: f32) !void {
        for (self.execution_order.items) |system_index| {
            const system = &self.systems.items[system_index];
            if (!system.enabled) continue;

            switch (system.system_fn) {
                .world_local => |system_fn| {
                    try system_fn(world, dt);
                },
                .game_global => {
                    // Skip game-global systems for world execution
                },
            }
        }
    }

    /// Execute all enabled game systems (both world-local and game-global)
    pub fn executeGameSystems(self: *SystemRegistry, game: *Game, dt: f32) !void {
        for (self.execution_order.items) |system_index| {
            const system = &self.systems.items[system_index];
            if (!system.enabled) continue;

            switch (system.system_fn) {
                .game_global => |system_fn| {
                    try system_fn(game, dt);
                },
                .world_local => {
                    // Execute world-local system on current zone's world
                    const current_zone = game.getCurrentZone();
                    try system.system_fn.world_local(&current_zone.world, dt);
                },
            }
        }
    }

    /// Sort execution order by schedule group priority
    fn sortExecutionOrder(self: *SystemRegistry) void {
        const Context = struct {
            systems: []const SystemInfo,

            pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
                const a_group = ctx.systems[a_index].schedule_group;
                const b_group = ctx.systems[b_index].schedule_group;
                return @intFromEnum(a_group) < @intFromEnum(b_group);
            }
        };

        std.mem.sort(usize, self.execution_order.items, Context{ .systems = self.systems.items }, Context.lessThan);
    }

    /// Get system by name
    pub fn getSystem(self: *SystemRegistry, system_name: []const u8) ?*SystemInfo {
        for (self.systems.items) |*system| {
            if (std.mem.eql(u8, system.name, system_name)) {
                return system;
            }
        }
        return null;
    }

    /// Check for conflicting system access patterns
    pub fn validateSystemAccess(self: *SystemRegistry) !void {
        _ = self; // TODO: Implement access pattern validation
        // This would check for read/write conflicts between systems
        // and ensure proper scheduling order
    }
};

/// Common system implementations for the game
pub const GameSystems = struct {
    /// Movement system - updates entity positions based on velocity
    pub fn movementSystem(world: *World, dt: f32) !void {
        // Update player movement
        var player_iter = world.players.entityIterator();
        while (player_iter.next()) |entity| {
            if (world.players.getComponent(entity, .transform)) |transform| {
                transform.pos.x += transform.vel.x * dt;
                transform.pos.y += transform.vel.y * dt;
            }
        }

        // Update unit movement
        var unit_iter = world.units.entityIterator();
        while (unit_iter.next()) |entity| {
            if (world.units.getComponent(entity, .transform)) |transform| {
                transform.pos.x += transform.vel.x * dt;
                transform.pos.y += transform.vel.y * dt;
            }
        }

        // Update projectile movement
        var projectile_iter = world.projectiles.entityIterator();
        while (projectile_iter.next()) |entity| {
            if (world.projectiles.getComponent(entity, .transform)) |transform| {
                transform.pos.x += transform.vel.x * dt;
                transform.pos.y += transform.vel.y * dt;
            }
        }
    }

    /// Projectile lifetime system - removes expired projectiles
    pub fn projectileLifetimeSystem(world: *World, dt: f32) !void {
        var projectiles_to_destroy = std.ArrayList(world_mod.EntityId).init(world.allocator);
        defer projectiles_to_destroy.deinit();

        var projectile_iter = world.projectiles.entityIterator();
        while (projectile_iter.next()) |entity| {
            if (world.projectiles.getComponent(entity, .projectile)) |projectile| {
                if (!projectile.update(dt)) {
                    try projectiles_to_destroy.append(entity);
                }
            }
        }

        // Destroy expired projectiles
        for (projectiles_to_destroy.items) |entity| {
            try world.destroyEntity(entity);
        }
    }

    /// Effect update system - updates temporary effects on entities
    pub fn effectUpdateSystem(world: *World, dt: f32) !void {
        // Update effects on players
        var player_iter = world.players.entityIterator();
        while (player_iter.next()) |entity| {
            if (world.players.getComponent(entity, .effects)) |effects| {
                effects.update(dt);
            }
        }

        // Update effects on units
        var unit_iter = world.units.entityIterator();
        while (unit_iter.next()) |entity| {
            if (world.units.getComponent(entity, .effects)) |effects| {
                effects.update(dt);
            }
        }
    }

    /// Collision system - handles projectile-unit collisions
    pub fn collisionSystem(world: *World, dt: f32) !void {
        _ = dt; // dt not used in collision detection

        var projectiles_to_destroy = std.ArrayList(world_mod.EntityId).init(world.allocator);
        defer projectiles_to_destroy.deinit();

        // Check projectile-unit collisions
        var projectile_iter = world.projectiles.entityIterator();
        while (projectile_iter.next()) |projectile_entity| {
            const projectile_transform = world.projectiles.getComponent(projectile_entity, .transform) orelse continue;
            const projectile_combat = world.projectiles.getComponent(projectile_entity, .combat) orelse continue;

            var unit_iter = world.units.entityIterator();
            while (unit_iter.next()) |unit_entity| {
                const unit_transform = world.units.getComponent(unit_entity, .transform) orelse continue;
                const unit_health = world.units.getComponent(unit_entity, .health) orelse continue;

                if (!unit_health.alive) continue;

                // Check circle-circle collision
                const to_unit = .{
                    .x = unit_transform.pos.x - projectile_transform.pos.x,
                    .y = unit_transform.pos.y - projectile_transform.pos.y,
                };
                const distance_sq = to_unit.x * to_unit.x + to_unit.y * to_unit.y;
                const radius_sum = projectile_transform.radius + unit_transform.radius;

                if (distance_sq < radius_sum * radius_sum) {
                    // Collision detected - damage the unit
                    unit_health.damage(projectile_combat.damage);

                    // Update visual if unit died
                    if (!unit_health.alive) {
                        if (world.units.getComponent(unit_entity, .visual)) |visual| {
                            visual.color = .{ .r = 128, .g = 128, .b = 128, .a = 255 }; // Gray for dead
                        }
                    }

                    // Mark projectile for destruction
                    try projectiles_to_destroy.append(projectile_entity);
                    break; // This projectile hit something, stop checking other units
                }
            }
        }

        // Destroy projectiles that hit something
        for (projectiles_to_destroy.items) |entity| {
            try world.destroyEntity(entity);
        }
    }

    /// Game-global projectile cleanup system
    pub fn globalProjectileCleanupSystem(game: *Game, dt: f32) !void {
        _ = dt; // dt not used in this system

        // This system can operate across all zones
        // For example, cleaning up projectiles that are too far from any player
        for (game.zones.items) |*zone| {
            var projectiles_to_destroy = std.ArrayList(world_mod.EntityId).init(game.allocator);
            defer projectiles_to_destroy.deinit();

            var projectile_iter = zone.world.projectiles.entityIterator();
            while (projectile_iter.next()) |entity| {
                if (zone.world.projectiles.getComponent(entity, .transform)) |transform| {
                    // Remove projectiles that are very far from origin (off-screen)
                    const distance_from_origin = transform.pos.x * transform.pos.x + transform.pos.y * transform.pos.y;
                    if (distance_from_origin > 2000000) { // ~1414 units from origin
                        try projectiles_to_destroy.append(entity);
                    }
                }
            }

            for (projectiles_to_destroy.items) |entity| {
                try zone.destroyEntity(entity);
            }
        }
    }
};

/// Helper to create a default system registry with common game systems
pub fn createDefaultSystemRegistry(allocator: std.mem.Allocator) !SystemRegistry {
    var registry = SystemRegistry.init(allocator);

    // Register movement system
    try registry.registerSystem(.{
        .name = "movement",
        .system_fn = .{ .world_local = GameSystems.movementSystem },
        .access = .{
            .read_components = &.{},
            .write_components = &.{.transform},
            .archetype_access = &.{
                .{ .archetype = .player, .access_type = .read_write },
                .{ .archetype = .unit, .access_type = .read_write },
                .{ .archetype = .projectile, .access_type = .read_write },
            },
        },
        .schedule_group = .movement,
        .enabled = true,
    });

    // Register projectile lifetime system
    try registry.registerSystem(.{
        .name = "projectile_lifetime",
        .system_fn = .{ .world_local = GameSystems.projectileLifetimeSystem },
        .access = .{
            .read_components = &.{.projectile},
            .write_components = &.{.projectile},
            .archetype_access = &.{
                .{ .archetype = .projectile, .access_type = .create_destroy },
            },
        },
        .schedule_group = .combat,
        .enabled = true,
    });

    // Register effect update system
    try registry.registerSystem(.{
        .name = "effect_update",
        .system_fn = .{ .world_local = GameSystems.effectUpdateSystem },
        .access = .{
            .read_components = &.{},
            .write_components = &.{.effects},
            .archetype_access = &.{
                .{ .archetype = .player, .access_type = .read_write },
                .{ .archetype = .unit, .access_type = .read_write },
            },
        },
        .schedule_group = .effects,
        .enabled = true,
    });

    // Register collision system
    try registry.registerSystem(.{
        .name = "collision",
        .system_fn = .{ .world_local = GameSystems.collisionSystem },
        .access = .{
            .read_components = &.{.transform, .combat},
            .write_components = &.{.health, .visual},
            .archetype_access = &.{
                .{ .archetype = .projectile, .access_type = .create_destroy },
                .{ .archetype = .unit, .access_type = .read_write },
            },
        },
        .schedule_group = .combat,
        .enabled = true,
    });

    // Register global projectile cleanup system
    try registry.registerSystem(.{
        .name = "global_projectile_cleanup",
        .system_fn = .{ .game_global = GameSystems.globalProjectileCleanupSystem },
        .access = .{
            .read_components = &.{.transform},
            .write_components = &.{},
            .archetype_access = &.{
                .{ .archetype = .projectile, .access_type = .create_destroy },
            },
        },
        .schedule_group = .cleanup,
        .enabled = true,
    });

    return registry;
}

test "system registry basic operations" {
    const testing = std.testing;

    var registry = SystemRegistry.init(testing.allocator);
    defer registry.deinit();

    // Register a test system
    try registry.registerSystem(.{
        .name = "test_system",
        .system_fn = .{ .world_local = GameSystems.movementSystem },
        .access = .{
            .read_components = &.{},
            .write_components = &.{.transform},
            .archetype_access = &.{},
        },
        .schedule_group = .movement,
        .enabled = true,
    });

    try testing.expect(registry.systems.items.len == 1);
    try testing.expect(registry.getSystem("test_system") != null);
    try testing.expect(registry.getSystem("nonexistent") == null);

    // Test enable/disable
    registry.setSystemEnabled("test_system", false);
    try testing.expect(!registry.getSystem("test_system").?.enabled);
}

test "default system registry creation" {
    const testing = std.testing;

    var registry = try createDefaultSystemRegistry(testing.allocator);
    defer registry.deinit();

    try testing.expect(registry.systems.items.len > 0);
    try testing.expect(registry.getSystem("movement") != null);
    try testing.expect(registry.getSystem("collision") != null);
}