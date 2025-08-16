/// zone_storage.zig - Simple Array-Based Entity Storage
///
/// This is the CLEAR PRIMITIVE version of entity storage for a single zone.
/// Unlike the complex ArchetypeStorage with comptime metaprogramming and
/// dynamic field generation, this uses simple, explicit arrays for each entity type.
///
/// Benefits:
/// - Immediately understandable structure
/// - Direct array access with zero abstraction
/// - Predictable memory layout
/// - Easy to debug and profile
/// - No comptime complexity
///
/// Trade-offs:
/// - Less flexible (can't add new component types at runtime)
/// - Manual management of each entity type
/// - But that's actually clearer for most use cases!

const std = @import("std");
const entity_id = @import("entity_id.zig");
const components = @import("components.zig");

const EntityId = entity_id.EntityId;

/// Clear, simple storage for a single zone
/// No complex archetype system - just arrays of components
pub const ZoneStorage = struct {
    // Entity arrays - fixed size, no dynamic allocation
    players: []Player,
    units: []Unit,
    projectiles: []Projectile,
    obstacles: []Obstacle,
    lifestones: []Lifestone,
    portals: []Portal,
    
    // Entity counts
    player_count: usize = 0,
    unit_count: usize = 0,
    projectile_count: usize = 0,
    obstacle_count: usize = 0,
    lifestone_count: usize = 0,
    portal_count: usize = 0,
    
    // Memory allocator for cleanup
    allocator: std.mem.Allocator,
    
    // Component definitions - simple structs with data
    pub const Player = struct {
        id: EntityId,
        transform: components.Transform,
        health: components.Health,
        visual: components.Visual,
        input: components.PlayerInput,
    };
    
    pub const Unit = struct {
        id: EntityId,
        transform: components.Transform,
        health: components.Health,
        visual: components.Visual,
        unit: components.Unit,
        combat: components.Combat,
    };
    
    pub const Projectile = struct {
        id: EntityId,
        transform: components.Transform,
        visual: components.Visual,
        projectile: components.Projectile,
    };
    
    pub const Obstacle = struct {
        id: EntityId,
        transform: components.Transform,
        visual: components.Visual,
        terrain: components.Terrain,
    };
    
    pub const Lifestone = struct {
        id: EntityId,
        transform: components.Transform,
        visual: components.Visual,
        interactable: components.Interactable,
        awakeable: components.Awakeable,
    };
    
    pub const Portal = struct {
        id: EntityId,
        transform: components.Transform,
        visual: components.Visual,
        interactable: components.Interactable,
    };
    
    /// Initialize with fixed capacity
    pub fn init(allocator: std.mem.Allocator, capacity: usize) !ZoneStorage {
        // Allocate arrays with reasonable capacities
        const player_capacity = @min(10, capacity / 10);
        const unit_capacity = @min(100, capacity / 3);
        const projectile_capacity = @min(200, capacity / 3);
        const obstacle_capacity = @min(50, capacity / 10);
        const lifestone_capacity = @min(20, capacity / 10);
        const portal_capacity = @min(10, capacity / 10);
        
        return .{
            .players = try allocator.alloc(Player, player_capacity),
            .units = try allocator.alloc(Unit, unit_capacity),
            .projectiles = try allocator.alloc(Projectile, projectile_capacity),
            .obstacles = try allocator.alloc(Obstacle, obstacle_capacity),
            .lifestones = try allocator.alloc(Lifestone, lifestone_capacity),
            .portals = try allocator.alloc(Portal, portal_capacity),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *ZoneStorage) void {
        self.allocator.free(self.players);
        self.allocator.free(self.units);
        self.allocator.free(self.projectiles);
        self.allocator.free(self.obstacles);
        self.allocator.free(self.lifestones);
        self.allocator.free(self.portals);
    }
    
    /// Add a player entity
    pub fn addPlayer(self: *ZoneStorage, player: Player) !void {
        if (self.player_count >= self.players.len) {
            return error.CapacityExceeded;
        }
        self.players[self.player_count] = player;
        self.player_count += 1;
    }
    
    /// Add a unit entity
    pub fn addUnit(self: *ZoneStorage, unit: Unit) !void {
        if (self.unit_count >= self.units.len) {
            return error.CapacityExceeded;
        }
        self.units[self.unit_count] = unit;
        self.unit_count += 1;
    }
    
    /// Add a projectile entity
    pub fn addProjectile(self: *ZoneStorage, projectile: Projectile) !void {
        if (self.projectile_count >= self.projectiles.len) {
            return error.CapacityExceeded;
        }
        self.projectiles[self.projectile_count] = projectile;
        self.projectile_count += 1;
    }
    
    /// Remove projectile by index (swap-remove for efficiency)
    pub fn removeProjectile(self: *ZoneStorage, index: usize) void {
        if (index >= self.projectile_count) return;
        
        // Swap with last and decrement count
        self.projectiles[index] = self.projectiles[self.projectile_count - 1];
        self.projectile_count -= 1;
    }
    
    /// Get active players slice
    pub fn getPlayers(self: *const ZoneStorage) []const Player {
        return self.players[0..self.player_count];
    }
    
    /// Get active units slice
    pub fn getUnits(self: *const ZoneStorage) []const Unit {
        return self.units[0..self.unit_count];
    }
    
    /// Get active projectiles slice
    pub fn getProjectiles(self: *const ZoneStorage) []const Projectile {
        return self.projectiles[0..self.projectile_count];
    }
    
    /// Clear all entities in this zone
    pub fn clear(self: *ZoneStorage) void {
        self.player_count = 0;
        self.unit_count = 0;
        self.projectile_count = 0;
        self.obstacle_count = 0;
        self.lifestone_count = 0;
        self.portal_count = 0;
    }
    
    /// Get total entity count
    pub fn getTotalEntityCount(self: *const ZoneStorage) usize {
        return self.player_count + self.unit_count + self.projectile_count +
               self.obstacle_count + self.lifestone_count + self.portal_count;
    }
};