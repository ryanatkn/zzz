// Entity Mapping - Stable ID system for unit pointer-to-ID mapping
// Converts unit pointers to stable u32 IDs for behavior composer storage

const std = @import("std");
const Unit = @import("../hex_game.zig").Unit;

/// Entity ID counter for behavior composer mapping
var next_entity_id: u32 = 1;
var entity_id_map: std.HashMap(usize, u32, std.hash_map.AutoContext(usize), std.hash_map.default_max_load_percentage) = undefined;

/// Initialize entity ID mapping system
pub fn initEntityIDMapping(allocator: std.mem.Allocator) void {
    entity_id_map = std.HashMap(usize, u32, std.hash_map.AutoContext(usize), std.hash_map.default_max_load_percentage).init(allocator);
}

/// Cleanup entity ID mapping system
pub fn deinitEntityIDMapping() void {
    entity_id_map.deinit();
}

/// Get or assign a stable entity ID for a unit pointer
pub fn getEntityID(unit_ptr: *Unit) u32 {
    const ptr_value = @intFromPtr(unit_ptr);
    
    const result = entity_id_map.getOrPut(ptr_value) catch {
        // Fallback: use a simple hash of the pointer
        return @truncate(std.hash_map.hashString(std.mem.asBytes(&ptr_value)));
    };
    
    if (!result.found_existing) {
        result.value_ptr.* = next_entity_id;
        next_entity_id += 1;
    }
    
    return result.value_ptr.*;
}