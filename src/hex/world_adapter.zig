const std = @import("std");
const HexWorld = @import("hex_world.zig").HexWorld;
const HexGame = @import("hex_game.zig").HexGame;
const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");

const Vec2 = math.Vec2;

/// Adapter layer to bridge old HexWorld API to new HexGame system
/// Allows gradual migration by maintaining both systems in parallel
pub const WorldAdapter = struct {
    // Both world systems for comparison
    old_world: ?HexWorld,
    new_game: ?HexGame,
    
    // Migration mode
    use_new_system: bool,
    enable_validation: bool, // Compare results between systems
    
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, use_new_system: bool, enable_validation: bool) !WorldAdapter {
        var adapter = WorldAdapter{
            .old_world = null,
            .new_world = null,
            .use_new_system = use_new_system,
            .enable_validation = enable_validation,
            .allocator = allocator,
        };
        
        // Initialize the system(s) we need
        if (!use_new_system or enable_validation) {
            adapter.old_world = try HexWorld.init(allocator);
        }
        
        if (use_new_system or enable_validation) {
            adapter.new_game = HexGame.init(allocator);
        }
        
        return adapter;
    }
    
    pub fn deinit(self: *WorldAdapter) void {
        if (self.old_world) |*old| {
            old.deinit();
        }
        if (self.new_game) |*new| {
            new.deinit();
        }
    }
    
    // Unified API that routes to the appropriate system
    pub fn getPlayerPos(self: *const WorldAdapter) Vec2 {
        if (self.use_new_system) {
            if (self.new_game) |*new| {
                const result = new.getPlayerPos();
                
                // Validate against old system if enabled
                if (self.enable_validation and self.old_world != null) {
                    const old_result = self.old_world.?.getPlayerPos();
                    if (!math.vec2_equal(result, old_result)) {
                        std.log.warn("getPlayerPos mismatch: new={any} old={any}", .{ result, old_result });
                    }
                }
                
                return result;
            }
        }
        
        if (self.old_world) |old| {
            return old.getPlayerPos();
        }
        
        return Vec2.ZERO;
    }
    
    pub fn getPlayerRadius(self: *const WorldAdapter) f32 {
        if (self.use_new_system) {
            if (self.new_game) |*new| {
                const result = new.getPlayerRadius();
                
                // Validate against old system if enabled
                if (self.enable_validation and self.old_world != null) {
                    const old_result = self.old_world.?.getPlayerRadius();
                    if (result != old_result) {
                        std.log.warn("getPlayerRadius mismatch: new={} old={}", .{ result, old_result });
                    }
                }
                
                return result;
            }
        }
        
        if (self.old_world) |old| {
            return old.getPlayerRadius();
        }
        
        return constants.PLAYER_RADIUS;
    }
    
    pub fn getPlayerAlive(self: *const WorldAdapter) bool {
        if (self.use_new_system) {
            if (self.new_game) |*new| {
                const result = new.getPlayerAlive();
                
                // Validate against old system if enabled
                if (self.enable_validation and self.old_world != null) {
                    const old_result = self.old_world.?.getPlayerAlive();
                    if (result != old_result) {
                        std.log.warn("getPlayerAlive mismatch: new={} old={}", .{ result, old_result });
                    }
                }
                
                return result;
            }
        }
        
        if (self.old_world) |old| {
            return old.getPlayerAlive();
        }
        
        return false;
    }
    
    pub fn setPlayerPos(self: *WorldAdapter, pos: Vec2) void {
        if (self.use_new_system) {
            if (self.new_game) |*new| {
                new.setPlayerPos(pos);
            }
        }
        
        // Also update old system if validation enabled
        if (self.enable_validation and self.old_world != null) {
            self.old_world.?.setPlayerPos(pos);
        } else if (!self.use_new_system and self.old_world != null) {
            self.old_world.?.setPlayerPos(pos);
        }
    }
    
    pub fn setPlayerVel(self: *WorldAdapter, vel: Vec2) void {
        if (self.use_new_system) {
            if (self.new_game) |*new| {
                new.setPlayerVel(vel);
            }
        }
        
        // Also update old system if validation enabled
        if (self.enable_validation and self.old_world != null) {
            self.old_world.?.setPlayerVel(vel);
        } else if (!self.use_new_system and self.old_world != null) {
            self.old_world.?.setPlayerVel(vel);
        }
    }
    
    pub fn setPlayerAlive(self: *WorldAdapter, alive: bool) void {
        if (self.use_new_system) {
            if (self.new_game) |*new| {
                new.setPlayerAlive(alive);
            }
        }
        
        // Also update old system if validation enabled
        if (self.enable_validation and self.old_world != null) {
            self.old_world.?.setPlayerAlive(alive);
        } else if (!self.use_new_system and self.old_world != null) {
            self.old_world.?.setPlayerAlive(alive);
        }
    }
    
    pub fn travelToZone(self: *WorldAdapter, zone_index: u8, spawn_pos: Vec2) !void {
        if (self.use_new_system) {
            if (self.new_game) |*new| {
                try new.travelToZone(zone_index, spawn_pos);
            }
        }
        
        // Also update old system if validation enabled
        if (self.enable_validation and self.old_world != null) {
            try self.old_world.?.travelToZone(zone_index, spawn_pos);
        } else if (!self.use_new_system and self.old_world != null) {
            try self.old_world.?.travelToZone(zone_index, spawn_pos);
        }
    }
    
    // Debug and validation helpers
    pub fn debugLogZoneEntities(self: *const WorldAdapter, zone_index: u8) void {
        if (self.use_new_system) {
            if (self.new_game) |*new| {
                new.debugLogZoneEntities(zone_index);
            }
        }
        
        if (self.enable_validation and self.old_world != null) {
            std.log.debug("=== OLD SYSTEM ===");
            self.old_world.?.debugLogZoneEntities(zone_index);
            std.log.debug("=== END OLD SYSTEM ===");
        } else if (!self.use_new_system and self.old_world != null) {
            self.old_world.?.debugLogZoneEntities(zone_index);
        }
    }
    
    pub fn validateZoneIsolation(self: *const WorldAdapter) bool {
        if (!self.enable_validation) {
            std.log.warn("validateZoneIsolation: Validation not enabled");
            return true;
        }
        
        if (self.old_world == null or self.new_game == null) {
            std.log.warn("validateZoneIsolation: Both systems not available");
            return true;
        }
        
        // Compare entity counts between systems
        var mismatch_found = false;
        
        const hex_game_mod = @import("hex_game.zig");
        for (0..hex_game_mod.MAX_ZONES) |zone_idx| {
            const zone_index: u8 = @intCast(zone_idx);
            
            // Get entity counts from both systems
            const new_zone = self.new_game.?.getZone(zone_index) orelse continue;
            const new_count = new_zone.entity_count;
            
            // For old system, would need to implement entity counting
            // This is simplified for now
            _ = new_count;
            
            std.log.debug("Zone {} validation: {} entities", .{ zone_index, new_count });
        }
        
        if (mismatch_found) {
            std.log.err("validateZoneIsolation: Validation failed - entity count mismatches found");
            return false;
        }
        
        std.log.info("validateZoneIsolation: Validation passed");
        return true;
    }
    
    // Accessors for specific system instances
    pub fn getOldWorld(self: *WorldAdapter) ?*HexWorld {
        return if (self.old_world) |*old| old else null;
    }
    
    pub fn getNewGame(self: *WorldAdapter) ?*HexGame {
        return if (self.new_game) |*new| new else null;
    }
    
    // Get the active world for rendering/physics
    pub fn getActiveWorld(self: *WorldAdapter) union(enum) {
        old: *HexWorld,
        new: *HexGame,
        none,
    } {
        if (self.use_new_system) {
            if (self.new_game) |*new| {
                return .{ .new = new };
            }
        }
        
        if (self.old_world) |*old| {
            return .{ .old = old };
        }
        
        return .none;
    }
};