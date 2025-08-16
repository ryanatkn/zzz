const std = @import("std");
const Vec2 = @import("../math/mod.zig").Vec2;

/// Generic lifecycle events for game entities
pub const LifecycleEvent = enum {
    spawn,
    death,
    respawn,
    destroy,
};

/// Respawn point information
pub const RespawnPoint = struct {
    position: Vec2,
    zone_id: ?u32 = null, // Optional zone identifier
    active: bool = true,
    priority: u32 = 0, // Higher priority = preferred respawn point
    name: []const u8 = "", // Optional name/identifier
    
    pub fn init(position: Vec2) RespawnPoint {
        return .{ .position = position };
    }
    
    pub fn initInZone(position: Vec2, zone_id: u32) RespawnPoint {
        return .{ .position = position, .zone_id = zone_id };
    }
};

/// Respawn manager handles multiple respawn points
pub const RespawnManager = struct {
    points: std.ArrayList(RespawnPoint),
    default_point: RespawnPoint,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, default_position: Vec2) RespawnManager {
        return .{
            .points = std.ArrayList(RespawnPoint).init(allocator),
            .default_point = RespawnPoint.init(default_position),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *RespawnManager) void {
        self.points.deinit();
    }
    
    /// Add a respawn point
    pub fn addRespawnPoint(self: *RespawnManager, point: RespawnPoint) !void {
        try self.points.append(point);
    }
    
    /// Remove a respawn point by index
    pub fn removeRespawnPoint(self: *RespawnManager, index: usize) void {
        if (index < self.points.items.len) {
            _ = self.points.swapRemove(index);
        }
    }
    
    /// Find the best respawn point (highest priority, then nearest)
    pub fn findBestRespawnPoint(self: *const RespawnManager, reference_pos: Vec2, zone_id: ?u32) RespawnPoint {
        if (self.points.items.len == 0) {
            return self.default_point;
        }
        
        var best_point: ?RespawnPoint = null;
        var best_priority: u32 = 0;
        var best_distance_sq: f32 = std.math.inf(f32);
        
        for (self.points.items) |point| {
            if (!point.active) continue;
            
            // Filter by zone if specified
            if (zone_id != null and point.zone_id != null and point.zone_id.? != zone_id.?) {
                continue;
            }
            
            // Check priority first
            if (point.priority > best_priority) {
                best_point = point;
                best_priority = point.priority;
                best_distance_sq = reference_pos.sub(point.position).lengthSquared();
            } else if (point.priority == best_priority) {
                // Same priority, check distance
                const distance_sq = reference_pos.sub(point.position).lengthSquared();
                if (distance_sq < best_distance_sq) {
                    best_point = point;
                    best_distance_sq = distance_sq;
                }
            }
        }
        
        return best_point orelse self.default_point;
    }
    
    /// Find nearest respawn point regardless of priority
    pub fn findNearestRespawnPoint(self: *const RespawnManager, reference_pos: Vec2, zone_id: ?u32) RespawnPoint {
        if (self.points.items.len == 0) {
            return self.default_point;
        }
        
        var nearest_point: ?RespawnPoint = null;
        var nearest_distance_sq: f32 = std.math.inf(f32);
        
        for (self.points.items) |point| {
            if (!point.active) continue;
            
            // Filter by zone if specified
            if (zone_id != null and point.zone_id != null and point.zone_id.? != zone_id.?) {
                continue;
            }
            
            const distance_sq = reference_pos.sub(point.position).lengthSquared();
            if (distance_sq < nearest_distance_sq) {
                nearest_point = point;
                nearest_distance_sq = distance_sq;
            }
        }
        
        return nearest_point orelse self.default_point;
    }
    
    /// Get all active respawn points in a zone
    pub fn getRespawnPointsInZone(self: *const RespawnManager, zone_id: u32, output: *std.ArrayList(RespawnPoint)) !void {
        output.clearRetainingCapacity();
        
        for (self.points.items) |point| {
            if (point.active and point.zone_id != null and point.zone_id.? == zone_id) {
                try output.append(point);
            }
        }
    }
    
    /// Activate/deactivate a respawn point by index
    pub fn setRespawnPointActive(self: *RespawnManager, index: usize, active: bool) void {
        if (index < self.points.items.len) {
            self.points.items[index].active = active;
        }
    }
    
    /// Clear all respawn points
    pub fn clearRespawnPoints(self: *RespawnManager) void {
        self.points.clearRetainingCapacity();
    }
};

/// Death/respawn state for an entity
pub const LifecycleState = struct {
    is_alive: bool = true,
    death_time: f32 = 0,
    respawn_delay: f32 = 0,
    respawn_timer: f32 = 0,
    can_respawn: bool = true,
    death_position: ?Vec2 = null,
    
    pub fn init() LifecycleState {
        return .{};
    }
    
    /// Mark entity as dead
    pub fn markDead(self: *LifecycleState, death_pos: Vec2, current_time: f32, respawn_delay: f32) void {
        self.is_alive = false;
        self.death_time = current_time;
        self.death_position = death_pos;
        self.respawn_delay = respawn_delay;
        self.respawn_timer = respawn_delay;
    }
    
    /// Mark entity as alive (respawned)
    pub fn markAlive(self: *LifecycleState) void {
        self.is_alive = true;
        self.death_position = null;
        self.respawn_timer = 0;
    }
    
    /// Update respawn timer
    pub fn update(self: *LifecycleState, delta_time: f32) void {
        if (!self.is_alive and self.respawn_timer > 0) {
            self.respawn_timer -= delta_time;
            if (self.respawn_timer < 0) {
                self.respawn_timer = 0;
            }
        }
    }
    
    /// Check if ready to respawn
    pub fn canRespawnNow(self: *const LifecycleState) bool {
        return !self.is_alive and self.can_respawn and self.respawn_timer <= 0;
    }
    
    /// Get respawn progress (0.0 = just died, 1.0 = ready to respawn)
    pub fn getRespawnProgress(self: *const LifecycleState) f32 {
        if (self.is_alive or self.respawn_delay <= 0) return 1.0;
        return 1.0 - (self.respawn_timer / self.respawn_delay);
    }
};

/// Lifecycle event callback type
pub const LifecycleCallback = fn (event: LifecycleEvent, entity_id: u32, position: Vec2) void;

/// Complete lifecycle manager
pub const LifecycleManager = struct {
    respawn_manager: RespawnManager,
    states: std.HashMap(u32, LifecycleState, std.hash_map.DefaultContext(u32), std.hash_map.default_max_load_percentage),
    callbacks: std.ArrayList(LifecycleCallback),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, default_respawn: Vec2) LifecycleManager {
        return .{
            .respawn_manager = RespawnManager.init(allocator, default_respawn),
            .states = std.HashMap(u32, LifecycleState, std.hash_map.DefaultContext(u32), std.hash_map.default_max_load_percentage).init(allocator),
            .callbacks = std.ArrayList(LifecycleCallback).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *LifecycleManager) void {
        self.respawn_manager.deinit();
        self.states.deinit();
        self.callbacks.deinit();
    }
    
    /// Register an entity for lifecycle management
    pub fn registerEntity(self: *LifecycleManager, entity_id: u32) !void {
        try self.states.put(entity_id, LifecycleState.init());
    }
    
    /// Unregister an entity
    pub fn unregisterEntity(self: *LifecycleManager, entity_id: u32) void {
        _ = self.states.remove(entity_id);
    }
    
    /// Add lifecycle callback
    pub fn addCallback(self: *LifecycleManager, callback: LifecycleCallback) !void {
        try self.callbacks.append(callback);
    }
    
    /// Trigger lifecycle event
    fn triggerEvent(self: *LifecycleManager, event: LifecycleEvent, entity_id: u32, position: Vec2) void {
        for (self.callbacks.items) |callback| {
            callback(event, entity_id, position);
        }
    }
    
    /// Kill an entity
    pub fn killEntity(self: *LifecycleManager, entity_id: u32, death_pos: Vec2, current_time: f32, respawn_delay: f32) void {
        if (self.states.getPtr(entity_id)) |state| {
            state.markDead(death_pos, current_time, respawn_delay);
            self.triggerEvent(.death, entity_id, death_pos);
        }
    }
    
    /// Respawn an entity at the best respawn point
    pub fn respawnEntity(self: *LifecycleManager, entity_id: u32, zone_id: ?u32) ?Vec2 {
        if (self.states.getPtr(entity_id)) |state| {
            if (state.canRespawnNow()) {
                const death_pos = state.death_position orelse Vec2{ .x = 0, .y = 0 };
                const respawn_point = self.respawn_manager.findBestRespawnPoint(death_pos, zone_id);
                
                state.markAlive();
                self.triggerEvent(.respawn, entity_id, respawn_point.position);
                return respawn_point.position;
            }
        }
        return null;
    }
    
    /// Update all entity lifecycle states
    pub fn update(self: *LifecycleManager, delta_time: f32) void {
        var iterator = self.states.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.update(delta_time);
        }
    }
    
    /// Check if entity is alive
    pub fn isEntityAlive(self: *const LifecycleManager, entity_id: u32) bool {
        if (self.states.get(entity_id)) |state| {
            return state.is_alive;
        }
        return false; // Unknown entities are considered dead
    }
    
    /// Get entity lifecycle state
    pub fn getEntityState(self: *const LifecycleManager, entity_id: u32) ?LifecycleState {
        return self.states.get(entity_id);
    }
};

test "respawn manager basic functionality" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var manager = RespawnManager.init(allocator, Vec2{ .x = 0, .y = 0 });
    defer manager.deinit();
    
    // Add some respawn points
    try manager.addRespawnPoint(RespawnPoint{ .position = Vec2{ .x = 100, .y = 100 }, .priority = 1 });
    try manager.addRespawnPoint(RespawnPoint{ .position = Vec2{ .x = 200, .y = 200 }, .priority = 2 });
    
    // Find best respawn point
    const best = manager.findBestRespawnPoint(Vec2{ .x = 50, .y = 50 }, null);
    try std.testing.expect(best.priority == 2); // Should pick highest priority
}

test "lifecycle state functionality" {
    var state = LifecycleState.init();
    
    // Initial state
    try std.testing.expect(state.is_alive);
    try std.testing.expect(!state.canRespawnNow());
    
    // Mark dead
    state.markDead(Vec2{ .x = 100, .y = 100 }, 0.0, 2.0);
    try std.testing.expect(!state.is_alive);
    try std.testing.expect(!state.canRespawnNow()); // Still in respawn delay
    
    // Update timer
    state.update(2.5);
    try std.testing.expect(state.canRespawnNow()); // Ready to respawn
    
    // Mark alive
    state.markAlive();
    try std.testing.expect(state.is_alive);
}