const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Command function signature for registered commands
pub const CommandFn = *const fn (context: *CommandContext, args: []const []const u8) anyerror!void;

/// Command execution context provided to command functions
pub const CommandContext = struct {
    allocator: std.mem.Allocator,
    event_bus: *kernel.EventBus,
    write_fn: *const fn (context: *anyopaque, text: []const u8) anyerror!void,
    write_context: *anyopaque,

    /// Write output to terminal
    pub fn writeOutput(self: *CommandContext, text: []const u8) !void {
        try self.write_fn(self.write_context, text);
    }
};

/// Command definition
pub const Command = struct {
    name: []const u8,
    description: []const u8,
    usage: []const u8,
    func: CommandFn,
};

/// Command registry capability - manages command registration and lookup
pub const Registry = struct {
    pub const name = "command_registry";
    pub const capability_type = "commands";

    allocator: std.mem.Allocator,
    commands: std.StringHashMap(Command),
    event_bus: ?*kernel.EventBus = null,

    const Self = @This();

    /// Factory method for creating registry capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const registry = try allocator.create(Self);
        registry.* = Self{
            .allocator = allocator,
            .commands = std.StringHashMap(Command).init(allocator),
        };
        return registry;
    }

    /// Factory method for destroying registry capability
    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        // Clean up resources first
        self.deinit();
        // Then free the memory
        allocator.destroy(self);
    }

    /// ICapability interface implementation
    pub fn getName(self: *const Self) []const u8 {
        _ = self;
        return name;
    }

    pub fn getType(self: *const Self) []const u8 {
        _ = self;
        return capability_type;
    }

    pub fn getDependencies(self: *const Self) []const []const u8 {
        _ = self;
        return &[_][]const u8{}; // No dependencies
    }

    pub fn initialize(self: *Self, dependencies: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        _ = dependencies;
        self.event_bus = event_bus;
    }

    pub fn deinit(self: *Self) void {
        // Free the commands HashMap when called by registry
        self.commands.deinit();
        self.event_bus = null;
    }

    pub fn isActive(self: *const Self) bool {
        return self.event_bus != null;
    }

    /// Register a command
    pub fn register(self: *Self, command: Command) !void {
        try self.commands.put(command.name, command);

        // Emit command registration event
        if (self.event_bus) |bus| {
            const event = kernel.Event.init(.state_change, .{
                .state_change = .{
                    .component = .registry,
                    .state = .{ .registry = .{ .command_count = self.commands.count() } },
                },
            });
            try bus.emit(event);
        }
    }

    /// Unregister a command
    pub fn unregister(self: *Self, command_name: []const u8) bool {
        const removed = self.commands.remove(command_name);

        // Emit command removal event
        if (removed and self.event_bus != null) {
            const event = kernel.Event.init(.state_change, .{
                .state_change = .{
                    .component = .registry,
                    .state = .{ .registry = .{ .command_count = self.commands.count() } },
                },
            });
            self.event_bus.?.emit(event) catch {};
        }

        return removed;
    }

    /// Get a command by name
    pub fn getCommand(self: *const Self, command_name: []const u8) ?Command {
        return self.commands.get(command_name);
    }

    /// Check if a command exists
    pub fn hasCommand(self: *const Self, command_name: []const u8) bool {
        return self.commands.contains(command_name);
    }

    /// Get all registered command names
    pub fn getCommandNames(self: *const Self, allocator: std.mem.Allocator) ![][]const u8 {
        var names = std.ArrayList([]const u8).init(allocator);
        errdefer names.deinit();

        var iterator = self.commands.iterator();
        while (iterator.next()) |entry| {
            try names.append(entry.key_ptr.*);
        }

        return try names.toOwnedSlice();
    }

    /// Get iterator over all commands
    pub fn commandIterator(self: *const Self) std.StringHashMap(Command).Iterator {
        return self.commands.iterator();
    }

    /// Get command count
    pub fn getCommandCount(self: *const Self) usize {
        return self.commands.count();
    }

    /// Execute a command if it exists in the registry
    pub fn execute(self: *Self, context: *CommandContext, command_name: []const u8, args: []const []const u8) !bool {
        if (self.getCommand(command_name)) |command| {
            try command.func(context, args);

            // Emit command execution event
            if (self.event_bus) |bus| {
                const event = kernel.Event.init(.state_change, .{
                    .state_change = .{
                        .component = .registry,
                        .state = .{ .registry = .{ .command_count = self.commands.count() } },
                    },
                });
                try bus.emit(event);
            }

            return true;
        }
        return false;
    }

    /// Clear all registered commands
    pub fn clear(self: *Self) void {
        self.commands.clearRetainingCapacity();

        // Emit clear event
        if (self.event_bus) |bus| {
            const event = kernel.Event.init(.state_change, .{
                .state_change = .{
                    .component = .registry,
                    .state = .{ .registry = .{ .command_count = 0 } },
                },
            });
            bus.emit(event) catch {};
        }
    }
};

// Tests
test "Registry capability initialization" {
    const allocator = std.testing.allocator;
    var registry = try Registry.create(allocator);
    defer registry.destroy(allocator);

    try std.testing.expectEqualStrings("command_registry", registry.getName());
    try std.testing.expectEqualStrings("commands", registry.getType());
    try std.testing.expect(registry.getDependencies().len == 0);
    try std.testing.expect(registry.getCommandCount() == 0);
}

test "Registry command registration" {
    const allocator = std.testing.allocator;
    var registry = try Registry.create(allocator);
    defer registry.destroy(allocator);

    // Mock command function
    const mockCommand = struct {
        fn run(context: *CommandContext, args: []const []const u8) !void {
            _ = context;
            _ = args;
        }
    }.run;

    const command = Command{
        .name = "test",
        .description = "Test command",
        .usage = "test [args]",
        .func = mockCommand,
    };

    try registry.register(command);
    try std.testing.expect(registry.hasCommand("test"));
    try std.testing.expect(registry.getCommandCount() == 1);

    const retrieved = registry.getCommand("test").?;
    try std.testing.expectEqualStrings("test", retrieved.name);
    try std.testing.expectEqualStrings("Test command", retrieved.description);
}

test "Registry command removal" {
    const allocator = std.testing.allocator;
    var registry = try Registry.create(allocator);
    defer registry.destroy(allocator);

    // Mock command function
    const mockCommand = struct {
        fn run(context: *CommandContext, args: []const []const u8) !void {
            _ = context;
            _ = args;
        }
    }.run;

    const command = Command{
        .name = "test",
        .description = "Test command",
        .usage = "test [args]",
        .func = mockCommand,
    };

    try registry.register(command);
    try std.testing.expect(registry.hasCommand("test"));

    const removed = registry.unregister("test");
    try std.testing.expect(removed);
    try std.testing.expect(!registry.hasCommand("test"));
    try std.testing.expect(registry.getCommandCount() == 0);

    // Try removing non-existent command
    const not_removed = registry.unregister("nonexistent");
    try std.testing.expect(!not_removed);
}

test "Registry command names listing" {
    const allocator = std.testing.allocator;
    var registry = try Registry.create(allocator);
    defer registry.destroy(allocator);

    // Mock command function
    const mockCommand = struct {
        fn run(context: *CommandContext, args: []const []const u8) !void {
            _ = context;
            _ = args;
        }
    }.run;

    // Register multiple commands
    try registry.register(Command{
        .name = "cmd1",
        .description = "Command 1",
        .usage = "cmd1",
        .func = mockCommand,
    });

    try registry.register(Command{
        .name = "cmd2",
        .description = "Command 2",
        .usage = "cmd2",
        .func = mockCommand,
    });

    const names = try registry.getCommandNames(allocator);
    defer allocator.free(names);

    try std.testing.expect(names.len == 2);
    // Note: HashMap iteration order is not guaranteed, so we check for both commands
    var found_cmd1 = false;
    var found_cmd2 = false;
    for (names) |name| {
        if (std.mem.eql(u8, name, "cmd1")) found_cmd1 = true;
        if (std.mem.eql(u8, name, "cmd2")) found_cmd2 = true;
    }
    try std.testing.expect(found_cmd1 and found_cmd2);
}