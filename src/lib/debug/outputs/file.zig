const std = @import("std");

/// File output backend with session tracking and error handling
pub fn File(comptime config: FileConfig) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        file: ?std.fs.File,
        path: []const u8,
        mutex: std.Thread.Mutex,
        session_started: bool,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .file = null,
                .path = config.path,
                .mutex = std.Thread.Mutex{},
                .session_started = false,
            };
        }

        pub fn deinit(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.file) |file| {
                file.close();
                self.file = null;
            }
        }

        /// Write a log message to file
        pub fn write(self: *Self, level: std.log.Level, message: []const u8) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            self.ensureFile();

            if (self.file) |file| {
                self.writeSessionStart();

                const timestamp = std.time.timestamp();
                const level_str = switch (level) {
                    .debug => "DEBUG",
                    .info => "INFO",
                    .warn => "WARN",
                    .err => "ERROR",
                };

                const log_entry = std.fmt.allocPrint(self.allocator, "[{}] {s}: {s}\n", .{ timestamp, level_str, message }) catch return;
                defer self.allocator.free(log_entry);

                _ = file.writeAll(log_entry) catch {
                    // If writing fails, close file and continue
                    file.close();
                    self.file = null;
                };
            }
        }

        /// Ensure log file is open and ready
        fn ensureFile(self: *Self) void {
            if (self.file != null) return;

            self.file = std.fs.cwd().createFile(self.path, .{ .truncate = false }) catch {
                // Silently fail - continue without file logging
                return;
            };

            // Seek to end for append mode
            _ = self.file.?.seekFromEnd(0) catch {
                self.file.?.close();
                self.file = null;
                return;
            };
        }

        /// Write session start marker once per session
        fn writeSessionStart(self: *Self) void {
            if (self.session_started) return;

            if (self.file) |file| {
                const timestamp = std.time.timestamp();
                const session_marker = std.fmt.allocPrint(self.allocator, "\n=== Game Session Started: {} ===\n", .{timestamp}) catch return;
                defer self.allocator.free(session_marker);

                _ = file.writeAll(session_marker) catch {
                    file.close();
                    self.file = null;
                    return;
                };

                self.session_started = true;
            }
        }
    };
}

/// Configuration for file output
pub const FileConfig = struct {
    path: []const u8,
};
