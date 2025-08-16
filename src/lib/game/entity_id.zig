/// entity_id.zig - Simple Entity ID Generation
/// 
/// This is the CLEAR PRIMITIVE version of entity ID management.
/// Unlike the complex EntityAllocator with generation tracking and recycling,
/// this uses a simple monotonic counter that just increments.
/// 
/// Benefits:
/// - Dead simple to understand and debug
/// - No allocations or complex state
/// - Predictable IDs for testing
/// - Zero overhead
///
/// Trade-offs:
/// - No ID recycling (but with u32, you get 4 billion IDs)
/// - No generation checking (but simpler systems don't need it)

const std = @import("std");

/// Simple entity ID system without complex generation tracking
/// Just a monotonically increasing counter - clear and efficient

pub const EntityId = u32;
pub const INVALID_ENTITY: EntityId = 0;

/// Simple entity ID generator - no complex generation tracking
pub const EntityIdGenerator = struct {
    next_id: EntityId = 1,
    
    pub fn init() EntityIdGenerator {
        return .{ .next_id = 1 };
    }
    
    pub fn allocate(self: *EntityIdGenerator) EntityId {
        const id = self.next_id;
        self.next_id += 1;
        return id;
    }
    
    pub fn reset(self: *EntityIdGenerator) void {
        self.next_id = 1;
    }
    
    pub fn isValid(id: EntityId) bool {
        return id != INVALID_ENTITY;
    }
};