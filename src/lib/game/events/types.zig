const std = @import("std");
const math = @import("../../math/mod.zig");
const Vec2 = math.Vec2;

/// Common game event types that can be extended with custom events
pub fn GameEvents(comptime CustomEvents: type) type {
    return union(enum) {
        // Entity events
        entity_spawned: struct { id: usize, pos: Vec2, entity_type: []const u8 },
        entity_killed: struct { id: usize, pos: Vec2, killer_id: ?usize },
        entity_damaged: struct { id: usize, damage: f32, source_id: ?usize },
        
        // Movement and collision events
        entity_moved: struct { id: usize, from: Vec2, to: Vec2 },
        collision_detected: struct { entity1_id: usize, entity2_id: usize },
        
        // Zone/level events
        zone_entered: struct { zone_id: usize, from_zone: ?usize },
        zone_exited: struct { zone_id: usize, to_zone: ?usize },
        zone_cleared: struct { zone_id: usize },
        
        // Checkpoint/save events
        checkpoint_reached: struct { checkpoint_id: usize, pos: Vec2 },
        checkpoint_activated: struct { checkpoint_id: usize },
        
        // Save/load events
        game_saving: struct { slot: usize },
        game_saved: struct { slot: usize, success: bool },
        game_loading: struct { slot: usize },
        game_loaded: struct { slot: usize, success: bool },
        
        // Achievement/progress events
        achievement_unlocked: struct { achievement_id: []const u8 },
        progress_updated: struct { category: []const u8, current: f32, total: f32 },
        
        // Custom game-specific events
        custom: CustomEvents,
    };
}

/// Helper to create a simple event callback signature
pub fn EventCallback(comptime EventType: type) type {
    return *const fn (event: EventType, ctx: ?*anyopaque) void;
}