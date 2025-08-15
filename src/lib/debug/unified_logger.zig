const std = @import("std");
const log_throttle = @import("log_throttle.zig");

/// Unified logging system that outputs to both console and file
/// Wraps the existing log_throttle system while adding file output capability
pub const UnifiedLogger = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    log_file: ?std.fs.File,
    log_file_path: []const u8,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, log_file_path: []const u8) Self {
        return Self{
            .allocator = allocator,
            .log_file = null,
            .log_file_path = log_file_path,
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.log_file) |file| {
            file.close();
            self.log_file = null;
        }
    }

    /// Initialize the log file, creating it if it doesn't exist
    fn ensureLogFile(self: *Self) void {
        if (self.log_file != null) return;

        self.log_file = std.fs.cwd().createFile(self.log_file_path, .{ .truncate = false }) catch |create_err| {
            // If we can't create the file, just continue with console-only logging
            std.log.warn("Failed to create log file '{s}': {}. Continuing with console-only logging.", .{ self.log_file_path, create_err });
            return;
        };

        // Seek to end for append mode
        _ = self.log_file.?.seekFromEnd(0) catch {
            // If seek fails, close and continue without file logging
            self.log_file.?.close();
            self.log_file = null;
            return;
        };

        // Write session start marker
        const timestamp = std.time.timestamp();
        const session_start = std.fmt.allocPrint(self.allocator, "\n=== Game Session Started: {} ===\n", .{timestamp}) catch return;
        defer self.allocator.free(session_start);

        _ = self.log_file.?.writeAll(session_start) catch {
            // If writing fails, close and continue without file logging
            self.log_file.?.close();
            self.log_file = null;
        };
    }

    /// Write a log message to the file (if available)
    fn writeToFile(self: *Self, level: []const u8, message: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.ensureLogFile();

        if (self.log_file) |file| {
            const timestamp = std.time.timestamp();
            const log_entry = std.fmt.allocPrint(self.allocator, "[{}] {s}: {s}\n", .{ timestamp, level, message }) catch return;
            defer self.allocator.free(log_entry);

            _ = file.writeAll(log_entry) catch {
                // If writing fails, close the file and continue with console-only
                file.close();
                self.log_file = null;
            };
        }
    }

    /// Log info message to both console and file
    pub fn info(self: *Self, comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
        // Format the message
        var buffer: [512]u8 = undefined;
        const message = std.fmt.bufPrint(&buffer, key ++ " " ++ fmt, args) catch "format error";

        // Output to console via log_throttle (preserves throttling behavior)
        log_throttle.logInfo(key, fmt, args);

        // Output to file (always, even if throttled from console)
        self.writeToFile("INFO", message);
    }

    /// Log debug message to both console and file
    pub fn debug(self: *Self, comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
        var buffer: [512]u8 = undefined;
        const message = std.fmt.bufPrint(&buffer, key ++ " " ++ fmt, args) catch "format error";

        log_throttle.logDebug(key, fmt, args);
        self.writeToFile("DEBUG", message);
    }

    /// Log error message to both console and file (errors are never throttled)
    pub fn err(self: *Self, comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
        var buffer: [512]u8 = undefined;
        const message = std.fmt.bufPrint(&buffer, key ++ " " ++ fmt, args) catch "format error";

        log_throttle.logError(key, fmt, args);
        self.writeToFile("ERROR", message);
    }

    /// Log warning message to both console and file
    pub fn warn(self: *Self, comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
        var buffer: [512]u8 = undefined;
        const message = std.fmt.bufPrint(&buffer, key ++ " " ++ fmt, args) catch "format error";

        // Use std.log.warn for console output (no throttling wrapper exists for warnings)
        std.log.warn(key ++ " " ++ fmt, args);
        self.writeToFile("WARN", message);
    }

    /// Direct logging without throttling (for critical messages)
    pub fn direct(self: *Self, level: std.log.Level, comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
        var buffer: [512]u8 = undefined;
        const message = std.fmt.bufPrint(&buffer, key ++ " " ++ fmt, args) catch "format error";

        // Output to console without throttling
        switch (level) {
            .info => std.log.info(key ++ " " ++ fmt, args),
            .debug => std.log.debug(key ++ " " ++ fmt, args),
            .err => std.log.err(key ++ " " ++ fmt, args),
            .warn => std.log.warn(key ++ " " ++ fmt, args),
        }

        // Output to file
        const level_str = switch (level) {
            .info => "INFO",
            .debug => "DEBUG", 
            .err => "ERROR",
            .warn => "WARN",
        };
        self.writeToFile(level_str, message);
    }
};

/// Global unified logger instance
var global_logger: ?*UnifiedLogger = null;

/// Initialize global unified logger
pub fn initGlobal(allocator: std.mem.Allocator, log_file_path: []const u8) !void {
    if (global_logger == null) {
        global_logger = try allocator.create(UnifiedLogger);
        global_logger.?.* = UnifiedLogger.init(allocator, log_file_path);
    }
}

/// Deinitialize global unified logger
pub fn deinitGlobal(allocator: std.mem.Allocator) void {
    if (global_logger) |logger| {
        logger.deinit();
        allocator.destroy(logger);
        global_logger = null;
    }
}

/// Convenience functions for global logger access
pub fn info(comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |logger| {
        logger.info(key, fmt, args);
    } else {
        // Fallback to log_throttle if unified logger not initialized
        log_throttle.logInfo(key, fmt, args);
    }
}

pub fn debug(comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |logger| {
        logger.debug(key, fmt, args);
    } else {
        log_throttle.logDebug(key, fmt, args);
    }
}

pub fn err(comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |logger| {
        logger.err(key, fmt, args);
    } else {
        log_throttle.logError(key, fmt, args);
    }
}

pub fn warn(comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |logger| {
        logger.warn(key, fmt, args);
    } else {
        std.log.warn(key ++ " " ++ fmt, args);
    }
}

pub fn direct(level: std.log.Level, comptime key: []const u8, comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |logger| {
        logger.direct(level, key, fmt, args);
    } else {
        // Fallback to std.log if unified logger not initialized
        switch (level) {
            .info => std.log.info(key ++ " " ++ fmt, args),
            .debug => std.log.debug(key ++ " " ++ fmt, args),
            .err => std.log.err(key ++ " " ++ fmt, args),
            .warn => std.log.warn(key ++ " " ++ fmt, args),
        }
    }
}

/// Print summary of throttled logs (delegates to log_throttle)
pub fn printGlobalSummary() void {
    log_throttle.printGlobalSummary();
}