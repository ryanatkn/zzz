const std = @import("std");
const entity_mod = @import("entity.zig");
const storage_mod = @import("storage.zig");
const components = @import("components.zig");
const colors = @import("../core/colors.zig");

const EntityId = entity_mod.EntityId;
const EntityAllocator = entity_mod.EntityAllocator;
const DenseStorage = storage_mod.DenseStorage;
const SparseStorage = storage_mod.SparseStorage;

/// Per-zone storage with perfect cache locality for zone iteration
pub const ZoneStorage = struct {
    // Dense component storage (most entities have these)
    transforms: DenseStorage(components.Transform),
    healths: DenseStorage(components.Health),
    movements: DenseStorage(components.Movement),
    visuals: DenseStorage(components.Visual),

    // Sparse component storage (few entities have these)
    units: SparseStorage(components.Unit),
    combats: SparseStorage(components.Combat),
    effects: SparseStorage(components.Effects),
    terrains: SparseStorage(components.Terrain),
    awakeables: SparseStorage(components.Awakeable),
    interactables: SparseStorage(components.Interactable),
    projectiles: SparseStorage(components.Projectile),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_entities_per_zone: usize) !ZoneStorage {
        return .{
            .transforms = try DenseStorage(components.Transform).init(allocator, max_entities_per_zone),
            .healths = try DenseStorage(components.Health).init(allocator, max_entities_per_zone),
            .movements = try DenseStorage(components.Movement).init(allocator, max_entities_per_zone),
            .visuals = try DenseStorage(components.Visual).init(allocator, max_entities_per_zone),
            .units = SparseStorage(components.Unit).init(allocator),
            .combats = SparseStorage(components.Combat).init(allocator),
            .effects = SparseStorage(components.Effects).init(allocator),
            .terrains = SparseStorage(components.Terrain).init(allocator),
            .awakeables = SparseStorage(components.Awakeable).init(allocator),
            .interactables = SparseStorage(components.Interactable).init(allocator),
            .projectiles = SparseStorage(components.Projectile).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ZoneStorage) void {
        self.transforms.deinit();
        self.healths.deinit();
        self.movements.deinit();
        self.visuals.deinit();
        self.units.deinit();
        self.combats.deinit();
        self.effects.deinit();
        self.terrains.deinit();
        self.awakeables.deinit();
        self.interactables.deinit();
        self.projectiles.deinit();
    }

    /// Remove entity from all storages in this zone
    pub fn removeEntity(self: *ZoneStorage, id: EntityId) void {
        _ = self.transforms.remove(id);
        _ = self.healths.remove(id);
        _ = self.movements.remove(id);
        _ = self.visuals.remove(id);
        _ = self.units.remove(id);
        _ = self.combats.remove(id);
        _ = self.effects.remove(id);
        _ = self.terrains.remove(id);
        _ = self.awakeables.remove(id);
        _ = self.interactables.remove(id);
        _ = self.projectiles.remove(id);
    }

    /// Check if entity exists in any storage in this zone
    pub fn hasEntity(self: *const ZoneStorage, id: EntityId) bool {
        return self.transforms.has(id) or
            self.healths.has(id) or
            self.movements.has(id) or
            self.visuals.has(id) or
            self.units.has(id) or
            self.combats.has(id) or
            self.effects.has(id) or
            self.terrains.has(id) or
            self.awakeables.has(id) or
            self.interactables.has(id) or
            self.projectiles.has(id);
    }
};

/// Zone-segmented world with per-zone SOA storage for optimal cache locality
pub const ZonedWorld = struct {
    // Per-zone storage - perfect cache locality for zone iteration
    zones: [7]ZoneStorage,
    current_zone: usize,

    // Global entity allocation (shared across zones)
    entities: EntityAllocator,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_entities: usize) !ZonedWorld {
        // Divide entity capacity across zones (with some overlap for flexibility)
        const entities_per_zone = max_entities / 4; // Allow entities to concentrate in some zones

        var zoned_world = ZonedWorld{
            .zones = undefined,
            .current_zone = 0,
            .entities = try EntityAllocator.init(allocator, max_entities),
            .allocator = allocator,
        };

        // Initialize all zone storages
        for (&zoned_world.zones) |*zone| {
            zone.* = try ZoneStorage.init(allocator, entities_per_zone);
        }

        return zoned_world;
    }

    pub fn deinit(self: *ZonedWorld) void {
        for (&self.zones) |*zone| {
            zone.deinit();
        }
        self.entities.deinit();
    }

    /// Switch to a different zone (hot path - just change index)
    pub fn setCurrentZone(self: *ZonedWorld, zone_index: usize) void {
        if (zone_index < self.zones.len) {
            self.current_zone = zone_index;
        }
    }

    /// Get current zone's storage (hot path)
    pub fn getCurrentZone(self: *ZonedWorld) *ZoneStorage {
        return &self.zones[self.current_zone];
    }

    /// Get current zone's storage (const version)
    pub fn getCurrentZoneConst(self: *const ZonedWorld) *const ZoneStorage {
        return &self.zones[self.current_zone];
    }

    /// Get specific zone's storage
    pub fn getZone(self: *ZonedWorld, zone_index: usize) *ZoneStorage {
        return &self.zones[zone_index];
    }

    /// Get specific zone's storage (const)
    pub fn getZoneConst(self: *const ZonedWorld, zone_index: usize) *const ZoneStorage {
        return &self.zones[zone_index];
    }

    /// Create a new entity in current zone
    pub fn createEntity(self: *ZonedWorld) !EntityId {
        return try self.entities.create();
    }

    /// Destroy an entity (removes from its zone and deallocates)
    pub fn destroyEntity(self: *ZonedWorld, id: EntityId) !void {
        // Find which zone contains this entity and remove it
        for (&self.zones) |*zone| {
            if (zone.hasEntity(id)) {
                zone.removeEntity(id);
                break;
            }
        }

        // Mark entity as destroyed in allocator
        try self.entities.destroy(id);
    }

    /// Check if an entity is alive
    pub fn isAlive(self: *const ZonedWorld, id: EntityId) bool {
        return self.entities.isAlive(id);
    }

    /// Move entity from one zone to another (for zone travel)
    pub fn moveEntityToZone(self: *ZonedWorld, id: EntityId, target_zone: usize) !void {
        if (target_zone >= self.zones.len) return;

        // Find source zone
        var source_zone_index: ?usize = null;
        for (self.zones, 0..) |zone, i| {
            if (zone.hasEntity(id)) {
                source_zone_index = i;
                break;
            }
        }

        if (source_zone_index == null) return; // Entity not found
        const source_idx = source_zone_index.?;
        if (source_idx == target_zone) return; // Already in target zone

        const source_zone = &self.zones[source_idx];
        const target_zone_storage = &self.zones[target_zone];

        // Move all components from source to target zone
        // Transform
        if (source_zone.transforms.get(id)) |component| {
            const data = component.*;
            _ = source_zone.transforms.remove(id);
            try target_zone_storage.transforms.add(id, data);
        }

        // Health
        if (source_zone.healths.get(id)) |component| {
            const data = component.*;
            _ = source_zone.healths.remove(id);
            try target_zone_storage.healths.add(id, data);
        }

        // Movement
        if (source_zone.movements.get(id)) |component| {
            const data = component.*;
            _ = source_zone.movements.remove(id);
            try target_zone_storage.movements.add(id, data);
        }

        // Visual
        if (source_zone.visuals.get(id)) |component| {
            const data = component.*;
            _ = source_zone.visuals.remove(id);
            try target_zone_storage.visuals.add(id, data);
        }

        // Unit
        if (source_zone.units.get(id)) |component| {
            const data = component.*;
            _ = source_zone.units.remove(id);
            try target_zone_storage.units.add(id, data);
        }

        // Combat
        if (source_zone.combats.get(id)) |component| {
            const data = component.*;
            _ = source_zone.combats.remove(id);
            try target_zone_storage.combats.add(id, data);
        }

        // Effects
        if (source_zone.effects.get(id)) |component| {
            const data = component.*;
            _ = source_zone.effects.remove(id);
            try target_zone_storage.effects.add(id, data);
        }

        // Terrain
        if (source_zone.terrains.get(id)) |component| {
            const data = component.*;
            _ = source_zone.terrains.remove(id);
            try target_zone_storage.terrains.add(id, data);
        }

        // Awakeable
        if (source_zone.awakeables.get(id)) |component| {
            const data = component.*;
            _ = source_zone.awakeables.remove(id);
            try target_zone_storage.awakeables.add(id, data);
        }

        // Interactable
        if (source_zone.interactables.get(id)) |component| {
            const data = component.*;
            _ = source_zone.interactables.remove(id);
            try target_zone_storage.interactables.add(id, data);
        }

        // Projectile
        if (source_zone.projectiles.get(id)) |component| {
            const data = component.*;
            _ = source_zone.projectiles.remove(id);
            try target_zone_storage.projectiles.add(id, data);
        }
    }

    /// Helper to create a basic unit entity in current zone
    pub fn createUnit(
        self: *ZonedWorld,
        pos: components.Vec2,
        radius: f32,
    ) !EntityId {
        const id = try self.createEntity();
        errdefer self.destroyEntity(id) catch {};

        const zone = self.getCurrentZone();
        try zone.transforms.add(id, components.Transform.init(pos, radius));
        try zone.healths.add(id, components.Health.init(1.0)); // Simple 1-hit units
        try zone.visuals.add(id, components.Visual.init(.{ .r = 1, .g = 1, .b = 1, .a = 1 }));
        try zone.units.add(id, components.Unit.init(.enemy, pos)); // All units are enemies by default

        return id;
    }

    /// Helper to create a player entity in current zone
    pub fn createPlayer(
        self: *ZonedWorld,
        pos: components.Vec2,
        radius: f32,
        health: f32,
        controller_id: u8,
    ) !EntityId {
        const id = try self.createEntity();
        errdefer self.destroyEntity(id) catch {};

        const zone = self.getCurrentZone();
        try zone.transforms.add(id, components.Transform.init(pos, radius));
        try zone.healths.add(id, components.Health.init(health));
        try zone.movements.add(id, components.Movement.init(200)); // Default player speed
        try zone.visuals.add(id, components.Visual.init(.{ .r = 51, .g = 178, .b = 255, .a = 255 })); // Blue player
        try zone.combats.add(id, components.Combat.init(25, 2.0)); // 25 damage, 2 attacks/sec

        // Note: PlayerInput component can be added by calling code if needed
        _ = controller_id; // Controller ID handled by higher-level logic

        return id;
    }

    /// Helper to create a projectile entity in current zone
    pub fn createProjectile(
        self: *ZonedWorld,
        pos: components.Vec2,
        vel: components.Vec2,
        radius: f32,
        owner: EntityId,
        damage: f32,
        lifetime: f32,
    ) !EntityId {
        const id = try self.createEntity();
        errdefer self.destroyEntity(id) catch {};

        const zone = self.getCurrentZone();
        try zone.transforms.add(id, components.Transform{
            .pos = pos,
            .vel = vel,
            .radius = radius,
        });
        try zone.visuals.add(id, components.Visual.init(.{ .r = 255, .g = 255, .b = 0, .a = 255 })); // Yellow projectile
        try zone.projectiles.add(id, components.Projectile.init(owner, lifetime));
        try zone.combats.add(id, components.Combat.init(damage, 0)); // Projectiles don't attack repeatedly

        // Make projectiles deflectable by default
        try zone.interactables.add(id, components.Interactable.init(.deflectable));

        return id;
    }

    /// Helper to create an obstacle/terrain entity in current zone
    pub fn createObstacle(
        self: *ZonedWorld,
        pos: components.Vec2,
        size: components.Vec2,
        is_deadly: bool,
    ) !EntityId {
        const id = try self.createEntity();
        errdefer self.destroyEntity(id) catch {};

        const zone = self.getCurrentZone();

        // Create rectangular obstacle using width/height as radius for collision detection
        const radius = @max(size.x, size.y) / 2.0; // Use larger dimension for collision
        try zone.transforms.add(id, components.Transform.init(pos, radius));

        // Create visual component
        const color = if (is_deadly)
            colors.Color{ .r = 200, .g = 0, .b = 0, .a = 255 } // Red for deadly
        else
            colors.Color{ .r = 100, .g = 100, .b = 100, .a = 255 }; // Gray for blocking
        try zone.visuals.add(id, components.Visual.init(color));

        // Create terrain component with size information
        const terrain_type = if (is_deadly) components.Terrain.TerrainType.pit else components.Terrain.TerrainType.wall;
        try zone.terrains.add(id, components.Terrain.init(terrain_type, size));

        return id;
    }

    /// Helper to create a lifestone entity in current zone
    pub fn createLifestone(
        self: *ZonedWorld,
        pos: components.Vec2,
        radius: f32,
        attuned: bool,
    ) !EntityId {
        const id = try self.createEntity();
        errdefer self.destroyEntity(id) catch {};

        const zone = self.getCurrentZone();
        try zone.transforms.add(id, components.Transform.init(pos, radius));

        // Create visual component with proper lifestone color
        const color = if (attuned)
            colors.Color{ .r = 0, .g = 255, .b = 255, .a = 255 } // Cyan for attuned
        else
            colors.Color{ .r = 128, .g = 128, .b = 255, .a = 255 }; // Light blue for unattuned
        try zone.visuals.add(id, components.Visual.init(color));

        // Create terrain component as altar type
        // Lifestones are circular, so create square size from radius
        const lifestone_size = components.Vec2{ .x = radius * 2.0, .y = radius * 2.0 };
        try zone.terrains.add(id, components.Terrain.init(components.Terrain.TerrainType.altar, lifestone_size));

        // Add interactable component for attunement
        var interactable = components.Interactable.init(components.Interactable.InteractionType.transformable);
        interactable.attuned = attuned;
        try zone.interactables.add(id, interactable);

        return id;
    }

    /// Helper to create a portal entity in current zone
    pub fn createPortal(
        self: *ZonedWorld,
        pos: components.Vec2,
        radius: f32,
        destination_zone: u8,
    ) !EntityId {
        const id = try self.createEntity();
        errdefer self.destroyEntity(id) catch {};

        const zone = self.getCurrentZone();
        try zone.transforms.add(id, components.Transform.init(pos, radius));

        // Create visual component with portal color (purple/magenta)
        const color = colors.Color{ .r = 255, .g = 0, .b = 255, .a = 255 }; // Magenta
        try zone.visuals.add(id, components.Visual.init(color));

        // Create terrain component as door type (portals are like doors)
        // Portals are circular, so create square size from radius
        const portal_size = components.Vec2{ .x = radius * 2.0, .y = radius * 2.0 };
        try zone.terrains.add(id, components.Terrain.init(components.Terrain.TerrainType.door, portal_size));

        // Add interactable component for travel with destination
        try zone.interactables.add(id, components.Interactable.initPortal(destination_zone));

        return id;
    }
};

test "ZonedWorld basic operations" {
    var world = try ZonedWorld.init(std.testing.allocator, 1000);
    defer world.deinit();

    const e1 = try world.createEntity();
    try std.testing.expect(world.isAlive(e1));

    const zone = world.getCurrentZone();
    try zone.transforms.add(e1, components.Transform.init(.{ .x = 0, .y = 0 }, 10));
    try zone.healths.add(e1, components.Health.init(100));

    try world.destroyEntity(e1);
    try std.testing.expect(!world.isAlive(e1));
}

test "ZonedWorld entity movement between zones" {
    var world = try ZonedWorld.init(std.testing.allocator, 1000);
    defer world.deinit();

    // Create entity in zone 0
    world.setCurrentZone(0);
    const e1 = try world.createUnit(.{ .x = 100, .y = 100 }, 15);

    // Verify it exists in zone 0
    try std.testing.expect(world.getZone(0).hasEntity(e1));
    try std.testing.expect(!world.getZone(1).hasEntity(e1));

    // Move to zone 1
    try world.moveEntityToZone(e1, 1);

    // Verify it moved
    try std.testing.expect(!world.getZone(0).hasEntity(e1));
    try std.testing.expect(world.getZone(1).hasEntity(e1));

    // Verify components preserved
    try std.testing.expect(world.getZone(1).transforms.has(e1));
    try std.testing.expect(world.getZone(1).units.has(e1));
}