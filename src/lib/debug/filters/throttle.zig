const std = @import("std");

/// Throttle filter to reduce log spam while preserving important information
/// Refactored from the original log_throttle.zig to fit the new architecture
pub const Throttle = struct {
    const Self = @This();
    
    const LogEntry = struct {
        key: []const u8,
        first_seen: i64,
        last_logged: i64,
        count: u32,
        last_value: ?[]const u8,
    };
    
    entries: std.AutoHashMap(u64, LogEntry),
    allocator: std.mem.Allocator,
    start_time: i64,
    
    // Mutable configuration (can be updated at runtime)
    summary_interval_ms: i64 = 30000, // Summary every 30 seconds
    first_time_delay_ms: i64 = 1000,  // Allow first occurrences for 1 second
    
    pub fn init(allocator: std.mem.Allocator) Self {
        const config = @import("../config.zig");
        return Self{
            .entries = std.AutoHashMap(u64, LogEntry).init(allocator),
            .allocator = allocator,
            .start_time = std.time.milliTimestamp(),
            // Initialize with config values (compile-time defaults)
            .summary_interval_ms = config.game_log.throttle_interval_ms,
            .first_time_delay_ms = config.game_log.first_time_delay_ms,
        };
    }
    
    pub fn deinit(self: *Self) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.key);
            if (entry.value_ptr.last_value) |val| {
                self.allocator.free(val);
            }
        }
        self.entries.deinit();
    }
    
    /// Check if a log message should be emitted or throttled
    pub fn shouldLog(self: *Self, _: std.log.Level, key: []const u8, value: []const u8) bool {
        const now = std.time.milliTimestamp();
        const key_hash = self.hashKey(key);
        
        const result = self.entries.getOrPut(key_hash) catch return true;
        
        if (!result.found_existing) {
            // First time seeing this key
            const age_ms = now - self.start_time;
            if (age_ms < self.first_time_delay_ms) {
                result.value_ptr.* = LogEntry{
                    .key = self.allocator.dupe(u8, key) catch return true,
                    .first_seen = now,
                    .last_logged = now,
                    .count = 1,
                    .last_value = self.allocator.dupe(u8, value) catch null,
                };
                return true;
            } else {
                // After startup, throttle new frequent events
                result.value_ptr.* = LogEntry{
                    .key = self.allocator.dupe(u8, key) catch return true,
                    .first_seen = now,
                    .last_logged = 0,
                    .count = 1,
                    .last_value = self.allocator.dupe(u8, value) catch null,
                };
                return false;
            }
        }
        
        const entry = result.value_ptr;
        entry.count += 1;
        
        // Check if value changed (always log changes)
        if (entry.last_value) |old_val| {
            if (!std.mem.eql(u8, old_val, value)) {
                self.allocator.free(old_val);
                entry.last_value = self.allocator.dupe(u8, value) catch null;
                entry.last_logged = now;
                return true;
            }
        } else {
            entry.last_value = self.allocator.dupe(u8, value) catch null;
            entry.last_logged = now;
            return true;
        }
        
        // Check if enough time has passed for a summary
        const time_since_last = now - entry.last_logged;
        if (time_since_last >= self.summary_interval_ms) {
            entry.last_logged = now;
            return true;
        }
        
        return false;
    }
    
    /// Hash a log key for consistent deduplication
    fn hashKey(_: Self, key: []const u8) u64 {
        return std.hash_map.hashString(key);
    }
    
    /// Get summary information for a throttled key
    pub fn getSummary(self: *Self, key: []const u8) ?struct { count: u32, age_ms: i64 } {
        const key_hash = self.hashKey(key);
        if (self.entries.get(key_hash)) |entry| {
            const now = std.time.milliTimestamp();
            return .{
                .count = entry.count,
                .age_ms = now - entry.first_seen,
            };
        }
        return null;
    }
    
    /// Clear all throttled entries
    pub fn reset(self: *Self) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.last_value) |val| {
                self.allocator.free(val);
            }
            self.allocator.free(entry.value_ptr.key);
        }
        self.entries.clearAndFree();
        self.start_time = std.time.milliTimestamp();
    }
};