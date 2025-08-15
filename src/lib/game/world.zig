const std = @import("std");
const entity_mod = @import("entity.zig");
const storage_mod = @import("storage.zig");
const components = @import("components.zig");
const colors = @import("../core/colors.zig");

const EntityId = entity_mod.EntityId;
const EntityAllocator = entity_mod.EntityAllocator;
const DenseStorage = storage_mod.DenseStorage;
const SparseStorage = storage_mod.SparseStorage;

/// World container for ECS - manages entities and components
pub const World = struct {
    // Entity management
    entities: EntityAllocator,

    // Dense component storage (most entities have these)
    transforms: DenseStorage(components.Transform),
    healths: DenseStorage(components.Health),
    movements: DenseStorage(components.Movement),
    visuals: DenseStorage(components.Visual),

    // Sparse component storage (few entities have these)
    units: SparseStorage(components.Unit),
    combats: SparseStorage(components.Combat),
    effects: SparseStorage(components.Effects),
    player_inputs: SparseStorage(components.PlayerInput),
    projectiles: SparseStorage(components.Projectile),
    terrains: SparseStorage(components.Terrain),
    awakeables: SparseStorage(components.Awakeable),
    interactables: SparseStorage(components.Interactable),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_entities: usize) !World {
        return .{
            .entities = try EntityAllocator.init(allocator, max_entities),
            .transforms = try DenseStorage(components.Transform).init(allocator, max_entities),
            .healths = try DenseStorage(components.Health).init(allocator, max_entities),
            .movements = try DenseStorage(components.Movement).init(allocator, max_entities),
            .visuals = try DenseStorage(components.Visual).init(allocator, max_entities),
            .units = SparseStorage(components.Unit).init(allocator),
            .combats = SparseStorage(components.Combat).init(allocator),
            .effects = SparseStorage(components.Effects).init(allocator),
            .player_inputs = SparseStorage(components.PlayerInput).init(allocator),
            .projectiles = SparseStorage(components.Projectile).init(allocator),
            .terrains = SparseStorage(components.Terrain).init(allocator),
            .awakeables = SparseStorage(components.Awakeable).init(allocator),
            .interactables = SparseStorage(components.Interactable).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *World) void {
        self.entities.deinit();
        self.transforms.deinit();
        self.healths.deinit();
        self.movements.deinit();
        self.visuals.deinit();
        self.units.deinit();
        self.combats.deinit();
        self.effects.deinit();
        self.player_inputs.deinit();
        self.projectiles.deinit();
        self.terrains.deinit();
        self.awakeables.deinit();
        self.interactables.deinit();
    }

    /// Create a new entity
    pub fn createEntity(self: *World) !EntityId {
        return try self.entities.create();
    }

    /// Destroy an entity and all its components
    pub fn destroyEntity(self: *World, id: EntityId) !void {
        // Remove from all component storages
        _ = self.transforms.remove(id);
        _ = self.healths.remove(id);
        _ = self.movements.remove(id);
        _ = self.visuals.remove(id);
        _ = self.units.remove(id);
        _ = self.combats.remove(id);
        _ = self.effects.remove(id);
        _ = self.player_inputs.remove(id);
        _ = self.projectiles.remove(id);
        _ = self.terrains.remove(id);
        _ = self.awakeables.remove(id);
        _ = self.interactables.remove(id);

        // Mark entity as destroyed
        try self.entities.destroy(id);
    }

    /// Check if an entity is alive
    pub fn isAlive(self: *World, id: EntityId) bool {
        return self.entities.isAlive(id);
    }

    /// Helper to create a basic unit entity
    pub fn createUnit(
        self: *World,
        pos: components.Vec2,
        radius: f32,
        health: f32,
        unit_type: components.Unit.UnitType,
    ) !EntityId {
        const id = try self.createEntity();
        errdefer self.destroyEntity(id) catch {};

        try self.transforms.add(id, components.Transform.init(pos, radius));
        try self.healths.add(id, components.Health.init(health));
        try self.movements.add(id, components.Movement.init(100));
        try self.visuals.add(id, components.Visual.init(.{ .r = 1, .g = 1, .b = 1, .a = 1 }));
        try self.units.add(id, components.Unit.init(unit_type, pos));

        return id;
    }

    /// Helper to create a player entity
    pub fn createPlayer(
        self: *World,
        pos: components.Vec2,
        radius: f32,
        health: f32,
        controller_id: u8,
    ) !EntityId {
        const id = try self.createEntity();
        errdefer self.destroyEntity(id) catch {};

        try self.transforms.add(id, components.Transform.init(pos, radius));
        try self.healths.add(id, components.Health.init(health));
        try self.movements.add(id, components.Movement.init(200)); // Default player speed
        try self.visuals.add(id, components.Visual.init(.{ .r = 51, .g = 178, .b = 255, .a = 255 })); // Blue player
        try self.player_inputs.add(id, components.PlayerInput.init(controller_id));
        try self.combats.add(id, components.Combat.init(25, 2.0)); // 25 damage, 2 attacks/sec

        return id;
    }

    /// Helper to create a projectile entity
    pub fn createProjectile(
        self: *World,
        pos: components.Vec2,
        vel: components.Vec2,
        radius: f32,
        owner: EntityId,
        damage: f32,
        lifetime: f32,
    ) !EntityId {
        const id = try self.createEntity();
        errdefer self.destroyEntity(id) catch {};

        try self.transforms.add(id, components.Transform{
            .pos = pos,
            .vel = vel,
            .radius = radius,
        });
        try self.visuals.add(id, components.Visual.init(.{ .r = 255, .g = 255, .b = 0, .a = 255 })); // Yellow projectile
        try self.projectiles.add(id, components.Projectile.init(owner, lifetime));
        try self.combats.add(id, components.Combat.init(damage, 0)); // Projectiles don't attack repeatedly

        // Make projectiles deflectable by default
        try self.interactables.add(id, components.Interactable.init(.deflectable));

        return id;
    }

    /// Helper to find the player entity
    pub fn getPlayer(self: *World) ?EntityId {
        var iter = self.player_inputs.iterator();
        while (iter.next()) |entry| {
            if (self.isAlive(entry.key_ptr.*)) {
                return entry.key_ptr.*;
            }
        }
        return null;
    }

    /// Helper to create an obstacle/terrain entity
    pub fn createObstacle(
        self: *World,
        pos: components.Vec2,
        size: components.Vec2,
        is_deadly: bool,
    ) !EntityId {
        const id = try self.createEntity();
        errdefer self.destroyEntity(id) catch {};

        // Create rectangular obstacle using width/height as radius for collision detection
        const radius = @max(size.x, size.y) / 2.0; // Use larger dimension for collision
        try self.transforms.add(id, components.Transform.init(pos, radius));

        // Create visual component
        const color = if (is_deadly)
            colors.Color{ .r = 200, .g = 0, .b = 0, .a = 255 } // Red for deadly
        else
            colors.Color{ .r = 100, .g = 100, .b = 100, .a = 255 }; // Gray for blocking
        try self.visuals.add(id, components.Visual.init(color));

        // Create terrain component with size information
        const terrain_type = if (is_deadly) components.Terrain.TerrainType.pit else components.Terrain.TerrainType.wall;
        try self.terrains.add(id, components.Terrain.init(terrain_type, size));

        return id;
    }

    /// Helper to create a lifestone entity
    pub fn createLifestone(
        self: *World,
        pos: components.Vec2,
        radius: f32,
        attuned: bool,
    ) !EntityId {
        const id = try self.createEntity();
        errdefer self.destroyEntity(id) catch {};

        try self.transforms.add(id, components.Transform.init(pos, radius));

        // Create visual component with proper lifestone color
        const color = if (attuned)
            colors.Color{ .r = 0, .g = 255, .b = 255, .a = 255 } // Cyan for attuned
        else
            colors.Color{ .r = 128, .g = 128, .b = 255, .a = 255 }; // Light blue for unattuned
        try self.visuals.add(id, components.Visual.init(color));

        // Create terrain component as altar type
        // Lifestones are circular, so create square size from radius
        const lifestone_size = components.Vec2{ .x = radius * 2.0, .y = radius * 2.0 };
        try self.terrains.add(id, components.Terrain.init(components.Terrain.TerrainType.altar, lifestone_size));

        // Add interactable component for attunement
        var interactable = components.Interactable.init(components.Interactable.InteractionType.transformable);
        interactable.attuned = attuned;
        try self.interactables.add(id, interactable);

        return id;
    }

    /// Helper to create a portal entity
    pub fn createPortal(
        self: *World,
        pos: components.Vec2,
        radius: f32,
        destination_zone: u8,
    ) !EntityId {
        const id = try self.createEntity();
        errdefer self.destroyEntity(id) catch {};

        try self.transforms.add(id, components.Transform.init(pos, radius));

        // Create visual component with portal color (purple/magenta)
        const color = colors.Color{ .r = 255, .g = 0, .b = 255, .a = 255 }; // Magenta
        try self.visuals.add(id, components.Visual.init(color));

        // Create terrain component as door type (portals are like doors)
        // Portals are circular, so create square size from radius
        const portal_size = components.Vec2{ .x = radius * 2.0, .y = radius * 2.0 };
        try self.terrains.add(id, components.Terrain.init(components.Terrain.TerrainType.door, portal_size));

        // Add interactable component for travel with destination
        try self.interactables.add(id, components.Interactable.initPortal(destination_zone));

        return id;
    }

    /// Query entities with specific components
    pub fn query2(
        self: *World,
        comptime C1: type,
        comptime C2: type,
    ) Query2(C1, C2) {
        return Query2(C1, C2).init(self);
    }

    /// Query helper for two components
    pub fn Query2(comptime C1: type, comptime C2: type) type {
        const Storage1Type = if (C1 == components.Transform or C1 == components.Health or C1 == components.Movement or C1 == components.Visual)
            *DenseStorage(C1)
        else
            *SparseStorage(C1);

        const Storage2Type = if (C2 == components.Transform or C2 == components.Health or C2 == components.Movement or C2 == components.Visual)
            *DenseStorage(C2)
        else
            *SparseStorage(C2);

        return struct {
            world: *World,
            storage1: Storage1Type,
            storage2: Storage2Type,

            const Self = @This();

            pub fn init(world: *World) Self {
                const storage1 = comptime blk: {
                    if (C1 == components.Transform) break :blk &world.transforms;
                    if (C1 == components.Health) break :blk &world.healths;
                    if (C1 == components.Movement) break :blk &world.movements;
                    if (C1 == components.Visual) break :blk &world.visuals;
                    if (C1 == components.Unit) break :blk &world.units;
                    if (C1 == components.Combat) break :blk &world.combats;
                    if (C1 == components.Effects) break :blk &world.effects;
                    if (C1 == components.PlayerInput) break :blk &world.player_inputs;
                    if (C1 == components.Projectile) break :blk &world.projectiles;
                    if (C1 == components.Terrain) break :blk &world.terrains;
                    if (C1 == components.Awakeable) break :blk &world.awakeables;
                    if (C1 == components.Interactable) break :blk &world.interactables;
                    @compileError("Unknown component type");
                };

                const storage2 = comptime blk: {
                    if (C2 == components.Transform) break :blk &world.transforms;
                    if (C2 == components.Health) break :blk &world.healths;
                    if (C2 == components.Movement) break :blk &world.movements;
                    if (C2 == components.Visual) break :blk &world.visuals;
                    if (C2 == components.Unit) break :blk &world.units;
                    if (C2 == components.Combat) break :blk &world.combats;
                    if (C2 == components.Effects) break :blk &world.effects;
                    if (C2 == components.PlayerInput) break :blk &world.player_inputs;
                    if (C2 == components.Projectile) break :blk &world.projectiles;
                    if (C2 == components.Terrain) break :blk &world.terrains;
                    if (C2 == components.Awakeable) break :blk &world.awakeables;
                    if (C2 == components.Interactable) break :blk &world.interactables;
                    @compileError("Unknown component type");
                };

                return .{
                    .world = world,
                    .storage1 = storage1,
                    .storage2 = storage2,
                };
            }

            pub const Result = struct {
                entity: EntityId,
                c1: *C1,
                c2: *C2,
            };

            // TODO: Implement proper iterator
            // For now, simple callback-based iteration
            pub fn forEach(self: Self, callback: fn (Result) void) void {
                // Iterate over the smaller storage for efficiency
                // This is a simplified implementation
                var iter = self.storage1.iterator();
                while (iter.next()) |entry| {
                    if (self.storage2.get(entry.entity)) |c2| {
                        callback(.{
                            .entity = entry.entity,
                            .c1 = entry.component,
                            .c2 = c2,
                        });
                    }
                }
            }
        };
    }
};

test "World basic operations" {
    var world = try World.init(std.testing.allocator, 100);
    defer world.deinit();

    const e1 = try world.createEntity();
    try std.testing.expect(world.isAlive(e1));

    try world.transforms.add(e1, components.Transform.init(.{ .x = 0, .y = 0 }, 10));
    try world.healths.add(e1, components.Health.init(100));

    try world.destroyEntity(e1);
    try std.testing.expect(!world.isAlive(e1));
}

test "World createUnit helper" {
    var world = try World.init(std.testing.allocator, 100);
    defer world.deinit();

    const unit = try world.createUnit(
        .{ .x = 100, .y = 200 },
        16,
        100,
        .enemy,
    );

    try std.testing.expect(world.transforms.has(unit));
    try std.testing.expect(world.healths.has(unit));
    try std.testing.expect(world.units.has(unit));
}
