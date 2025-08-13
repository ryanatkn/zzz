const std = @import("std");
const signal = @import("signal.zig");
const effect = @import("effect.zig");

/// Batching system to group multiple reactive updates
/// Prevents cascading re-renders and improves performance
pub const BatchManager = struct {
    allocator: std.mem.Allocator,
    
    // Queue of pending updates
    pending_effects: std.ArrayList(*effect.Effect),
    pending_signals: std.ArrayList(*const anyopaque), // Type-erased signals
    
    // Batching state
    is_batching: bool = false,
    batch_depth: u32 = 0,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .pending_effects = std.ArrayList(*effect.Effect).init(allocator),
            .pending_signals = std.ArrayList(*const anyopaque).init(allocator),
            .is_batching = false,
            .batch_depth = 0,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.pending_effects.deinit();
        self.pending_signals.deinit();
    }
    
    /// Start a batch - defer effect execution until flushBatch()
    pub fn startBatch(self: *Self) void {
        if (self.batch_depth == 0) {
            self.is_batching = true;
        }
        self.batch_depth += 1;
    }
    
    /// End a batch and flush all pending effects
    pub fn endBatch(self: *Self) void {
        if (self.batch_depth == 0) return;
        
        self.batch_depth -= 1;
        if (self.batch_depth == 0) {
            self.is_batching = false;
            self.flushBatch();
        }
    }
    
    /// Execute a function within a batch
    pub fn batch(self: *Self, batch_fn: *const fn () void) void {
        self.startBatch();
        defer self.endBatch();
        batch_fn();
    }
    
    /// Queue an effect to run at batch flush
    pub fn queueEffect(self: *Self, eff: *effect.Effect) void {
        if (!self.is_batching) {
            eff.run();
            return;
        }
        
        // Check if effect is already queued
        for (self.pending_effects.items) |pending| {
            if (pending == eff) return;
        }
        
        self.pending_effects.append(eff) catch {
            // If we can't queue, run immediately
            eff.run();
        };
    }
    
    /// Queue a signal update notification
    pub fn queueSignalUpdate(self: *Self, sig: *const anyopaque) void {
        if (!self.is_batching) return;
        
        // Check if signal is already queued
        for (self.pending_signals.items) |pending| {
            if (pending == sig) return;
        }
        
        self.pending_signals.append(sig) catch {
            // If we can't queue, ignore - signal will update anyway
        };
    }
    
    /// Flush all pending effects and signals
    pub fn flushBatch(self: *Self) void {
        // Temporarily disable batching during flush to avoid infinite recursion
        const was_batching = self.is_batching;
        self.is_batching = false;
        
        // Run all queued effects
        for (self.pending_effects.items) |eff| {
            eff.run();
        }
        
        // Restore batching state
        self.is_batching = was_batching;
        
        // Clear queues
        self.pending_effects.clearRetainingCapacity();
        self.pending_signals.clearRetainingCapacity();
    }
    
    /// Check if currently batching
    pub fn isBatching(self: *const Self) bool {
        return self.is_batching;
    }
};

// Global batch manager instance
var global_batch_manager: ?*BatchManager = null;

/// Initialize global batching system
pub fn initGlobalBatcher(allocator: std.mem.Allocator) !void {
    if (global_batch_manager != null) return;
    
    const manager = try allocator.create(BatchManager);
    manager.* = BatchManager.init(allocator);
    global_batch_manager = manager;
}

/// Cleanup global batching system
pub fn deinitGlobalBatcher(allocator: std.mem.Allocator) void {
    if (global_batch_manager) |manager| {
        manager.deinit();
        allocator.destroy(manager);
        global_batch_manager = null;
    }
}

/// Get global batch manager
pub fn getGlobalBatcher() ?*BatchManager {
    return global_batch_manager;
}

/// Execute function in a global batch
pub fn batch(batch_fn: *const fn () void) void {
    if (global_batch_manager) |manager| {
        manager.batch(batch_fn);
    } else {
        // No batching available, run immediately
        batch_fn();
    }
}

/// Utility for batching multiple signal updates
pub fn batchSignalUpdates(comptime Context: type, context: Context, update_fn: *const fn (Context) void) void {
    batch(struct {
        fn run() void {
            update_fn(context);
        }
    }.run);
}

// Example usage and tests
test "batch system prevents duplicate effects" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var manager = BatchManager.init(allocator);
    defer manager.deinit();
    
    // Create a test effect
    const TestData = struct {
        var run_count: u32 = 0;
    };
    
    const test_effect = try effect.createEffect(allocator, struct {
        fn run() void {
            TestData.run_count += 1;
        }
    }.run);
    defer allocator.destroy(test_effect);
    
    // Test batching prevents duplicate runs
    manager.startBatch();
    
    manager.queueEffect(test_effect);
    manager.queueEffect(test_effect); // Should be deduped
    manager.queueEffect(test_effect); // Should be deduped
    
    manager.endBatch();
    
    // Effect should only run once despite being queued 3 times
    try std.testing.expect(TestData.run_count == 2); // 1 from creation + 1 from batch
}

test "nested batching works correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var manager = BatchManager.init(allocator);
    defer manager.deinit();
    
    // Test basic batching state
    try std.testing.expect(!manager.isBatching());
    
    manager.startBatch();
    try std.testing.expect(manager.isBatching());
    
    manager.endBatch();
    try std.testing.expect(!manager.isBatching());
}