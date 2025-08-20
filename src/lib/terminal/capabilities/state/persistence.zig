const std = @import("std");
const kernel = @import("../../kernel/mod.zig");
const History = @import("history.zig").History;

/// Persistence capability - saves and restores terminal state across sessions
pub const Persistence = struct {
    pub const name = "persistence";
    pub const capability_type = "state";
    pub const dependencies = &[_][]const u8{"history"};

    active: bool = false,
    initialized: bool = false,

    // Event bus for subscribing to shutdown events
    event_bus: ?*kernel.EventBus = null,
    allocator: std.mem.Allocator,

    // File paths
    history_file_path: []u8,
    session_file_path: []u8,

    // Configuration
    auto_save: bool = true,
    auto_load: bool = true,
    max_history_lines: usize = 1000,

    // Cached references to capabilities
    history_capability: ?*History = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Get home directory or use current directory
        const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch ".";
        defer if (!std.mem.eql(u8, home_dir, ".")) allocator.free(home_dir);

        // Create file paths
        const history_path = try std.fmt.allocPrint(allocator, "{s}/.terminal_history", .{home_dir});
        const session_path = try std.fmt.allocPrint(allocator, "{s}/.terminal_session", .{home_dir});

        return Self{
            .active = false,
            .initialized = false,
            .event_bus = null,
            .allocator = allocator,
            .history_file_path = history_path,
            .session_file_path = session_path,
        };
    }

    /// Create a new persistence capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = try Self.init(allocator);
        return self;
    }

    /// Destroy persistence capability
    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        self.deinit();
        allocator.destroy(self);
    }

    /// Get capability name
    pub fn getName(self: *Self) []const u8 {
        _ = self;
        return name;
    }

    /// Get capability type
    pub fn getType(self: *Self) []const u8 {
        _ = self;
        return capability_type;
    }

    /// Get required dependencies
    pub fn getDependencies(self: *Self) []const []const u8 {
        _ = self;
        return dependencies;
    }

    /// Check if capability is active
    pub fn isActive(self: *Self) bool {
        return self.active;
    }

    /// Initialize capability with dependencies
    pub fn initialize(self: *Self, deps: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        self.event_bus = event_bus;

        // Find history capability in dependencies using type-safe casting
        for (deps) |dep| {
            const dep_name = dep.getName();
            if (std.mem.eql(u8, dep_name, "history")) {
                self.history_capability = dep.cast(History) orelse return error.InvalidCapabilityType;
                break;
            }
        }

        // Subscribe to capability removed events to detect shutdown
        try event_bus.subscribe(.capability_removed, shutdownCallback, self);

        // Auto-load history if enabled
        if (self.auto_load) {
            self.loadHistory() catch |err| {
                // Log error but don't fail initialization
                std.log.warn("Failed to load history: {}", .{err});
            };
        }

        self.initialized = true;
        self.active = true;
    }

    /// Cleanup capability resources
    pub fn deinit(self: *Self) void {
        // Auto-save on shutdown if enabled
        if (self.auto_save and self.active) {
            self.saveHistory() catch |err| {
                std.log.warn("Failed to save history: {}", .{err});
            };
        }

        // Unsubscribe from events
        if (self.event_bus) |bus| {
            bus.unsubscribe(.capability_removed, shutdownCallback, self);
        }

        self.allocator.free(self.history_file_path);
        self.allocator.free(self.session_file_path);

        self.active = false;
        self.initialized = false;
        self.event_bus = null;
    }

    /// Save command history to file
    pub fn saveHistory(self: *Self) !void {
        if (self.history_capability == null) return;

        const file = try std.fs.createFileAbsolute(self.history_file_path, .{});
        defer file.close();

        const writer = file.writer();

        // Write header
        try writer.print("# Terminal History - Saved {d}\n", .{std.time.milliTimestamp()});

        // Get history from capability (would need method in History capability)
        // For now, we'll write a placeholder
        try writer.writeAll("# History entries would be written here\n");

        // In real implementation, would iterate through history buffer:
        // const history = @fieldParentPtr(History, "base", self.history_capability.?);
        // var i: usize = 0;
        // while (i < history.getCount()) : (i += 1) {
        //     if (history.command_history.get(i)) |cmd| {
        //         try writer.print("{s}\n", .{cmd});
        //     }
        // }
    }

    /// Load command history from file
    pub fn loadHistory(self: *Self) !void {
        if (self.history_capability == null) return;

        const file = std.fs.openFileAbsolute(self.history_file_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // No history file yet, that's okay
                return;
            }
            return err;
        };
        defer file.close();

        const reader = file.reader();
        var buf: [4096]u8 = undefined;

        while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            // Skip comments and empty lines
            if (line.len == 0 or line[0] == '#') continue;

            // Would add to history capability here
            // const history = @fieldParentPtr(History, "base", self.history_capability.?);
            // try history.addCommand(line);
        }
    }

    /// Save session state (working directory, environment, etc.)
    pub fn saveSession(self: *Self, session_name: ?[]const u8) !void {
        const session = session_name orelse "default";

        const session_file = if (std.mem.eql(u8, session, "default"))
            self.session_file_path
        else blk: {
            const path = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ self.session_file_path, session });
            break :blk path;
        };
        defer if (!std.mem.eql(u8, session, "default")) self.allocator.free(session_file);

        const file = try std.fs.createFileAbsolute(session_file, .{});
        defer file.close();

        const writer = file.writer();

        // Write session data in simple key=value format
        try writer.print("timestamp={d}\n", .{std.time.milliTimestamp()});

        // Save working directory
        var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
        const cwd = try std.process.getCwd(&cwd_buf);
        try writer.print("working_directory={s}\n", .{cwd});

        // Could save more state here:
        // - Environment variables
        // - Terminal dimensions
        // - Scrollback position
        // - etc.
    }

    /// Load session state
    pub fn loadSession(self: *Self, session_name: ?[]const u8) !void {
        const session = session_name orelse "default";

        const session_file = if (std.mem.eql(u8, session, "default"))
            self.session_file_path
        else blk: {
            const path = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ self.session_file_path, session });
            break :blk path;
        };
        defer if (!std.mem.eql(u8, session, "default")) self.allocator.free(session_file);

        const file = std.fs.openFileAbsolute(session_file, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // No session file yet
                return;
            }
            return err;
        };
        defer file.close();

        const reader = file.reader();
        var buf: [4096]u8 = undefined;

        while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            // Parse key=value pairs
            if (std.mem.indexOf(u8, line, "=")) |eq_pos| {
                const key = line[0..eq_pos];
                const value = line[eq_pos + 1 ..];

                if (std.mem.eql(u8, key, "working_directory")) {
                    // Change to saved directory
                    std.process.changeCurDir(value) catch |err| {
                        std.log.warn("Failed to restore working directory: {}", .{err});
                    };
                }
                // Handle other keys as needed
            }
        }
    }

    /// List available sessions
    pub fn listSessions(self: *Self, allocator: std.mem.Allocator) ![][]u8 {
        var sessions = std.ArrayList([]u8).init(allocator);

        // Always include default session
        try sessions.append(try allocator.dupe(u8, "default"));

        // Look for other session files
        const dir_path = std.fs.path.dirname(self.session_file_path) orelse ".";
        const base_name = std.fs.path.basename(self.session_file_path);

        var dir = try std.fs.openDirAbsolute(dir_path, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;

            // Check if file starts with our session file base name
            if (std.mem.startsWith(u8, entry.name, base_name) and
                entry.name.len > base_name.len and
                entry.name[base_name.len] == '.')
            {
                const session_name = entry.name[base_name.len + 1 ..];
                try sessions.append(try allocator.dupe(u8, session_name));
            }
        }

        return try sessions.toOwnedSlice();
    }

    /// Delete a session
    pub fn deleteSession(self: *Self, session_name: []const u8) !void {
        if (std.mem.eql(u8, session_name, "default")) {
            // Delete default session file
            std.fs.deleteFileAbsolute(self.session_file_path) catch |err| {
                if (err != error.FileNotFound) return err;
            };
        } else {
            const session_file = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ self.session_file_path, session_name });
            defer self.allocator.free(session_file);

            std.fs.deleteFileAbsolute(session_file) catch |err| {
                if (err != error.FileNotFound) return err;
            };
        }
    }
};

/// Callback for shutdown events
fn shutdownCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *Persistence = @ptrCast(@alignCast(context.?));

    switch (event.data) {
        .capability_removed => |data| {
            // If persistence capability is being removed, save state
            if (std.mem.eql(u8, data.name, "persistence")) {
                if (self.auto_save) {
                    try self.saveHistory();
                    try self.saveSession(null);
                }
            }
        },
        else => {},
    }
}

// Tests
test "Persistence capability initialization" {
    const allocator = std.testing.allocator;
    const persistence = try Persistence.init(allocator);
    defer {
        allocator.free(persistence.history_file_path);
        allocator.free(persistence.session_file_path);
    }

    try std.testing.expect(persistence.auto_save);
    try std.testing.expect(persistence.auto_load);
    try std.testing.expectEqual(@as(usize, 1000), persistence.max_history_lines);
}

test "Persistence session management" {
    const allocator = std.testing.allocator;
    var persistence = try Persistence.init(allocator);
    defer persistence.deinit();

    // Save and load default session
    try persistence.saveSession(null);
    try persistence.loadSession(null);

    // Save named session
    try persistence.saveSession("test_session");

    // List sessions
    const sessions = try persistence.listSessions(allocator);
    defer {
        for (sessions) |session| {
            allocator.free(session);
        }
        allocator.free(sessions);
    }

    // Should have at least default session
    try std.testing.expect(sessions.len >= 1);

    // Clean up test session
    try persistence.deleteSession("test_session");
}
