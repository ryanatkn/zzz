const std = @import("std");
const builtin = @import("builtin");

/// Logging throttle helper to reduce per-frame spam while preserving important information
pub const LogThrottle = struct {
    const Self = @This();

    const LogEntry = struct {
        key: []const u8,
        first_seen: i64,
        last_logged: i64,
        count: u32,
        last_value: ?[]const u8, // For change detection
    };

    entries: std.AutoHashMap(u64, LogEntry),
    allocator: std.mem.Allocator,
    start_time: i64,

    // Configuration
    summary_interval_ms: i64 = 30000, // Summary every 30 seconds (reduced spam)
    first_time_delay_ms: i64 = 1000, // Allow first occurrences for 1 second

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .entries = std.AutoHashMap(u64, LogEntry).init(allocator),
            .allocator = allocator,
            .start_time = std.time.milliTimestamp(),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            // Free duplicated key string
            self.allocator.free(entry.value_ptr.key);
            // Free duplicated value string if present
            if (entry.value_ptr.last_value) |val| {
                self.allocator.free(val);
            }
        }
        self.entries.deinit();
    }

    /// Hash a log key for consistent deduplication
    fn hashKey(key: []const u8) u64 {
        return std.hash_map.hashString(key);
    }

    /// Check if a log message should be emitted or throttled
    pub fn shouldLog(self: *Self, key: []const u8, value: ?[]const u8) bool {
        const now = std.time.milliTimestamp();
        const key_hash = hashKey(key);

        const result = self.entries.getOrPut(key_hash) catch return true; // On error, allow logging

        if (!result.found_existing) {
            // First time seeing this key - always log if we're in early startup
            const age_ms = now - self.start_time;
            if (age_ms < self.first_time_delay_ms) {
                result.value_ptr.* = LogEntry{
                    .key = self.allocator.dupe(u8, key) catch return true,
                    .first_seen = now,
                    .last_logged = now,
                    .count = 1,
                    .last_value = if (value) |v| self.allocator.dupe(u8, v) catch null else null,
                };
                return true;
            } else {
                // After startup, throttle new frequent events
                result.value_ptr.* = LogEntry{
                    .key = self.allocator.dupe(u8, key) catch return true,
                    .first_seen = now,
                    .last_logged = 0, // Haven't logged yet
                    .count = 1,
                    .last_value = if (value) |v| self.allocator.dupe(u8, v) catch null else null,
                };
                return false; // Throttle new events after startup
            }
        }

        const entry = result.value_ptr;
        entry.count += 1;

        // Check if value changed (always log changes)
        if (value) |new_val| {
            if (entry.last_value) |old_val| {
                if (!std.mem.eql(u8, old_val, new_val)) {
                    // Value changed - update and log
                    self.allocator.free(old_val);
                    entry.last_value = self.allocator.dupe(u8, new_val) catch null;
                    entry.last_logged = now;
                    return true;
                }
            } else {
                // First time we have a value for this key
                entry.last_value = self.allocator.dupe(u8, new_val) catch null;
                entry.last_logged = now;
                return true;
            }
        }

        // Check if enough time has passed for a summary
        const time_since_last = now - entry.last_logged;
        if (time_since_last >= self.summary_interval_ms) {
            entry.last_logged = now;
            return true;
        }

        return false;
    }

    /// Get summary information for a throttled key
    pub fn getSummary(self: *Self, key: []const u8) ?struct { count: u32, age_ms: i64 } {
        const key_hash = hashKey(key);
        if (self.entries.get(key_hash)) |entry| {
            const now = std.time.milliTimestamp();
            return .{
                .count = entry.count,
                .age_ms = now - entry.first_seen,
            };
        }
        return null;
    }

    /// Clear all throttled entries (useful for testing or reset)
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

    /// Print summary of all throttled logs (useful for debugging)
    pub fn printSummary(self: *Self) void {
        const now = std.time.milliTimestamp();
        std.log.info("=== LogThrottle Summary ===", .{});

        var iter = self.entries.iterator();
        var total_suppressed: u32 = 0;
        var active_keys: u32 = 0;

        while (iter.next()) |entry| {
            const age_ms = now - entry.value_ptr.first_seen;
            const suppressed = entry.value_ptr.count - 1; // -1 because first occurrence was logged

            if (suppressed > 0) {
                std.log.info("  {s}: {} occurrences, {} suppressed ({}ms ago)", .{ entry.value_ptr.key, entry.value_ptr.count, suppressed, age_ms });
                total_suppressed += suppressed;
            }
            active_keys += 1;
        }

        std.log.info("Total: {} keys tracked, {} logs suppressed", .{ active_keys, total_suppressed });
        std.log.info("==========================", .{});
    }
};

/// Global throttle instance for convenience
var global_throttle: ?*LogThrottle = null;

/// Initialize global logging throttle
pub fn initGlobal(allocator: std.mem.Allocator) !void {
    if (global_throttle == null) {
        global_throttle = try allocator.create(LogThrottle);
        global_throttle.?.* = LogThrottle.init(allocator);
    }
}

/// Deinitialize global logging throttle
pub fn deinitGlobal(allocator: std.mem.Allocator) void {
    if (global_throttle) |throttle| {
        throttle.deinit();
        allocator.destroy(throttle);
        global_throttle = null;
    }
}

/// Throttled logging macros for common use
pub fn logInfo(comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
    if (global_throttle) |throttle| {
        var buffer: [256]u8 = undefined;
        const message = std.fmt.bufPrint(&buffer, fmt, args) catch "format error";

        if (throttle.shouldLog(key, message)) {
            if (throttle.getSummary(key)) |summary| {
                if (summary.count > 1) {
                    std.log.info(key ++ " [+" ++ fmt ++ "] (x{} in {}ms)", args ++ .{ summary.count, summary.age_ms });
                } else {
                    std.log.info(key ++ " " ++ fmt, args);
                }
            } else {
                std.log.info(key ++ " " ++ fmt, args);
            }
        }
    } else {
        // Fallback to normal logging if throttle not initialized
        std.log.info(key ++ " " ++ fmt, args);
    }
}

pub fn logDebug(comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
    if (global_throttle) |throttle| {
        if (throttle.shouldLog(key, null)) {
            if (throttle.getSummary(key)) |summary| {
                if (summary.count > 1) {
                    std.log.debug(key ++ " [+" ++ fmt ++ "] (x{} in {}ms)", args ++ .{ summary.count, summary.age_ms });
                } else {
                    std.log.debug(key ++ " " ++ fmt, args);
                }
            } else {
                std.log.debug(key ++ " " ++ fmt, args);
            }
        }
    } else {
        // Fallback to normal logging
        std.log.debug(key ++ " " ++ fmt, args);
    }
}

/// Always log errors (no throttling for errors)
pub fn logError(comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
    std.log.err(key ++ " " ++ fmt, args);
}

/// Print throttle summary on demand
pub fn printGlobalSummary() void {
    if (global_throttle) |throttle| {
        throttle.printSummary();
    }
}
