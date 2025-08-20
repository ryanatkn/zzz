const std = @import("std");
const kernel = @import("../../kernel/mod.zig");
const registry = @import("registry.zig");
const loggers = @import("../../../debug/loggers.zig");

const Registry = registry.Registry;
const Command = registry.Command;
const CommandContext = registry.CommandContext;

/// Built-in commands capability - provides essential terminal commands
pub const Builtin = struct {
    pub const name = "builtin_commands";
    pub const capability_type = "commands";

    allocator: std.mem.Allocator,
    registry_capability: ?*Registry = null,
    event_bus: ?*kernel.EventBus = null,

    const Self = @This();

    /// Factory method for creating builtin capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const builtin = try allocator.create(Self);
        builtin.* = Self{
            .allocator = allocator,
        };
        return builtin;
    }

    /// Factory method for destroying builtin capability
    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
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
        return &[_][]const u8{"command_registry"};
    }

    pub fn initialize(self: *Self, dependencies: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        self.event_bus = event_bus;

        // Find registry dependency using type-safe casting
        for (dependencies) |dep| {
            const dep_name = dep.getName();
            if (std.mem.eql(u8, dep_name, "command_registry")) {
                self.registry_capability = dep.cast(Registry) orelse return error.InvalidCapabilityType;
                break;
            }
        }

        if (self.registry_capability == null) {
            return error.MissingDependency;
        }

        // Register all built-in commands
        try self.registerBuiltinCommands();
    }

    pub fn deinit(self: *Self) void {
        self.event_bus = null;
        self.registry_capability = null;
    }

    pub fn isActive(self: *const Self) bool {
        return self.event_bus != null and self.registry_capability != null;
    }

    /// Register all built-in commands with the registry
    fn registerBuiltinCommands(self: *Self) !void {
        const registry_impl = self.registry_capability.?;

        const builtins = [_]Command{
            .{ .name = "help", .description = "Show available commands", .usage = "help [command]", .func = cmdHelp },
            .{ .name = "clear", .description = "Clear the terminal screen", .usage = "clear", .func = cmdClear },
            .{ .name = "cd", .description = "Change directory", .usage = "cd [directory]", .func = cmdCd },
            .{ .name = "pwd", .description = "Print working directory", .usage = "pwd", .func = cmdPwd },
            .{ .name = "ls", .description = "List directory contents", .usage = "ls [directory]", .func = cmdLs },
            .{ .name = "cat", .description = "Display file contents", .usage = "cat <file>", .func = cmdCat },
            .{ .name = "echo", .description = "Display a line of text", .usage = "echo <text>", .func = cmdEcho },
            .{ .name = "env", .description = "Display environment variables", .usage = "env", .func = cmdEnv },
            .{ .name = "export", .description = "Set environment variable", .usage = "export VAR=value", .func = cmdExport },
            .{ .name = "history", .description = "Show command history", .usage = "history", .func = cmdHistory },
            .{ .name = "exit", .description = "Exit the terminal", .usage = "exit", .func = cmdExit },
        };

        for (builtins) |command| {
            try registry_impl.register(command);
        }
    }
};

// Built-in command implementations

fn cmdHelp(context: *CommandContext, args: []const []const u8) !void {
    // Get registry from context (would need to be added to context)
    // For now, show basic help
    if (args.len == 0) {
        try context.writeOutput("Available commands:\n\n");
        try context.writeOutput("  help         - Show available commands\n");
        try context.writeOutput("  clear        - Clear the terminal screen\n");
        try context.writeOutput("  cd           - Change directory\n");
        try context.writeOutput("  pwd          - Print working directory\n");
        try context.writeOutput("  ls           - List directory contents\n");
        try context.writeOutput("  cat          - Display file contents\n");
        try context.writeOutput("  echo         - Display a line of text\n");
        try context.writeOutput("  env          - Display environment variables\n");
        try context.writeOutput("  export       - Set environment variable\n");
        try context.writeOutput("  history      - Show command history\n");
        try context.writeOutput("  exit         - Exit the terminal\n");
        try context.writeOutput("\nType 'help <command>' for detailed usage.\n");
    } else {
        const command_name = args[0];
        try context.writeOutput("Help for specific commands not yet implemented.\n");
        try context.writeOutput(std.fmt.allocPrint(context.allocator, "Command: {s}\n", .{command_name}) catch "");
    }
}

fn cmdClear(context: *CommandContext, args: []const []const u8) !void {
    _ = args;
    // ANSI clear screen and move cursor to top
    try context.writeOutput("\x1b[2J\x1b[H");
}

fn cmdCd(context: *CommandContext, args: []const []const u8) !void {
    const target_dir = if (args.len > 0) args[0] else (std.posix.getenv("HOME") orelse "/");

    // Change directory using std.fs
    var dir = std.fs.cwd().openDir(target_dir, .{}) catch |err| {
        const error_msg = switch (err) {
            error.FileNotFound => "Directory not found",
            error.NotDir => "Not a directory",
            error.AccessDenied => "Access denied",
            else => "Failed to change directory",
        };
        try context.writeOutput(std.fmt.allocPrint(context.allocator, "cd: {s}: {s}\n", .{ target_dir, error_msg }) catch "");
        return;
    };
    defer dir.close();

    // Note: In a real implementation, we'd update the executor's working directory
    // For now, just acknowledge the command
    try context.writeOutput(std.fmt.allocPrint(context.allocator, "Changed to directory: {s}\n", .{target_dir}) catch "");
}

fn cmdPwd(context: *CommandContext, args: []const []const u8) !void {
    _ = args;

    // Get current working directory
    const cwd = std.fs.cwd().realpathAlloc(context.allocator, ".") catch |err| switch (err) {
        error.AccessDenied => try context.allocator.dupe(u8, "/"),
        else => try context.allocator.dupe(u8, "."),
    };
    defer context.allocator.free(cwd);

    try context.writeOutput(std.fmt.allocPrint(context.allocator, "{s}\n", .{cwd}) catch "");
}

fn cmdLs(context: *CommandContext, args: []const []const u8) !void {
    const target_dir = if (args.len > 0) args[0] else ".";

    var dir = std.fs.cwd().openDir(target_dir, .{ .iterate = true }) catch |err| {
        const error_msg = switch (err) {
            error.FileNotFound => "Directory not found",
            error.NotDir => "Not a directory",
            error.AccessDenied => "Access denied",
            else => "Failed to open directory",
        };
        try context.writeOutput(std.fmt.allocPrint(context.allocator, "ls: {s}: {s}\n", .{ target_dir, error_msg }) catch "");
        return;
    };
    defer dir.close();

    var iterator = dir.iterate();

    // Collect entries and sort them
    var entries = std.ArrayList(std.fs.Dir.Entry).init(context.allocator);
    defer entries.deinit();

    while (iterator.next() catch null) |entry| {
        try entries.append(entry);
    }

    // Sort entries alphabetically
    std.sort.block(std.fs.Dir.Entry, entries.items, {}, struct {
        fn lessThan(ctx: void, a: std.fs.Dir.Entry, b: std.fs.Dir.Entry) bool {
            _ = ctx;
            return std.mem.order(u8, a.name, b.name) == .lt;
        }
    }.lessThan);

    // Display entries
    for (entries.items) |entry| {
        const prefix = switch (entry.kind) {
            .directory => "d",
            .file => "-",
            .sym_link => "l",
            else => "?",
        };

        try context.writeOutput(std.fmt.allocPrint(context.allocator, "{s} {s}\n", .{ prefix, entry.name }) catch "");
    }
}

fn cmdCat(context: *CommandContext, args: []const []const u8) !void {
    if (args.len == 0) {
        try context.writeOutput("cat: missing file argument\nUsage: cat <file>\n");
        return;
    }

    const filename = args[0];
    const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
        const error_msg = switch (err) {
            error.FileNotFound => "File not found",
            error.IsDir => "Is a directory",
            error.AccessDenied => "Access denied",
            else => "Failed to open file",
        };
        try context.writeOutput(std.fmt.allocPrint(context.allocator, "cat: {s}: {s}\n", .{ filename, error_msg }) catch "");
        return;
    };
    defer file.close();

    const contents = file.readToEndAlloc(context.allocator, 1024 * 1024) catch |err| {
        const error_msg = switch (err) {
            error.OutOfMemory => "File too large",
            else => "Failed to read file",
        };
        try context.writeOutput(std.fmt.allocPrint(context.allocator, "cat: {s}: {s}\n", .{ filename, error_msg }) catch "");
        return;
    };
    defer context.allocator.free(contents);

    try context.writeOutput(contents);
}

fn cmdEcho(context: *CommandContext, args: []const []const u8) !void {
    const ui_log = loggers.getUILog();
    ui_log.debug("terminal_echo", "cmdEcho called with {d} args", .{args.len});
    for (args, 0..) |arg, i| {
        ui_log.debug("terminal_echo", "arg[{d}] = '{s}'", .{ i, arg });
    }

    if (args.len == 0) {
        ui_log.debug("terminal_echo", "No args, calling writeOutput('\\n')", .{});
        try context.writeOutput("\n");
        return;
    }

    ui_log.debug("terminal_echo", "Processing {d} args", .{args.len});
    for (args, 0..) |arg, i| {
        if (i > 0) {
            ui_log.debug("terminal_echo", "Writing space", .{});
            try context.writeOutput(" ");
        }
        ui_log.debug("terminal_echo", "Writing arg '{s}'", .{arg});
        try context.writeOutput(arg);
    }
    ui_log.debug("terminal_echo", "Writing final newline", .{});
    try context.writeOutput("\n");
}

fn cmdEnv(context: *CommandContext, args: []const []const u8) !void {
    _ = args;

    // Get all environment variables
    var env_map = try std.process.getEnvMap(context.allocator);
    defer env_map.deinit();
    var env_iter = env_map.iterator();

    // Collect and sort environment variables
    var env_vars = std.ArrayList(struct { key: []const u8, value: []const u8 }).init(context.allocator);
    defer env_vars.deinit();

    while (env_iter.next()) |entry| {
        try env_vars.append(.{ .key = entry.key_ptr.*, .value = entry.value_ptr.* });
    }

    std.sort.block(@TypeOf(env_vars.items[0]), env_vars.items, {}, struct {
        fn lessThan(ctx: void, a: @TypeOf(env_vars.items[0]), b: @TypeOf(env_vars.items[0])) bool {
            _ = ctx;
            return std.mem.order(u8, a.key, b.key) == .lt;
        }
    }.lessThan);

    for (env_vars.items) |env_var| {
        try context.writeOutput(std.fmt.allocPrint(context.allocator, "{s}={s}\n", .{ env_var.key, env_var.value }) catch "");
    }
}

fn cmdExport(context: *CommandContext, args: []const []const u8) !void {
    if (args.len == 0) {
        try context.writeOutput("export: missing variable assignment\nUsage: export VAR=value\n");
        return;
    }

    const assignment = args[0];
    if (std.mem.indexOf(u8, assignment, "=")) |eq_pos| {
        const var_name = assignment[0..eq_pos];
        const var_value = assignment[eq_pos + 1 ..];

        // Note: In a real implementation, we'd set the environment variable in the executor
        try context.writeOutput(std.fmt.allocPrint(context.allocator, "Exported {s}={s}\n", .{ var_name, var_value }) catch "");
    } else {
        try context.writeOutput("export: invalid format\nUsage: export VAR=value\n");
    }
}

fn cmdHistory(context: *CommandContext, args: []const []const u8) !void {
    _ = args;
    try context.writeOutput("Command history feature not yet implemented.\n");
}

fn cmdExit(context: *CommandContext, args: []const []const u8) !void {
    _ = args;
    try context.writeOutput("Exiting terminal...\n");
    // Note: In a real implementation, this would trigger terminal shutdown
}

// Tests
test "Builtin capability initialization" {
    const allocator = std.testing.allocator;
    var builtin = try Builtin.create(allocator);
    defer builtin.destroy(allocator);

    try std.testing.expectEqualStrings("builtin_commands", builtin.getName());
    try std.testing.expectEqualStrings("commands", builtin.getType());
    try std.testing.expect(builtin.getDependencies().len == 1);
    try std.testing.expectEqualStrings("command_registry", builtin.getDependencies()[0]);
}

test "Builtin echo command" {
    const allocator = std.testing.allocator;

    // Mock context
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    const mockWrite = struct {
        fn write(context: *anyopaque, text: []const u8) !void {
            const out = @as(*std.ArrayList(u8), @ptrCast(@alignCast(context)));
            try out.appendSlice(text);
        }
    }.write;

    var mock_bus = kernel.EventBus.init(allocator);

    var context = CommandContext{
        .allocator = allocator,
        .event_bus = &mock_bus,
        .write_fn = mockWrite,
        .write_context = &output,
    };

    try cmdEcho(&context, &[_][]const u8{ "hello", "world" });
    try std.testing.expectEqualStrings("hello world\n", output.items);
}

test "Builtin clear command" {
    const allocator = std.testing.allocator;

    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    const mockWrite = struct {
        fn write(context: *anyopaque, text: []const u8) !void {
            const out = @as(*std.ArrayList(u8), @ptrCast(@alignCast(context)));
            try out.appendSlice(text);
        }
    }.write;

    var mock_bus = kernel.EventBus.init(allocator);

    var context = CommandContext{
        .allocator = allocator,
        .event_bus = &mock_bus,
        .write_fn = mockWrite,
        .write_context = &output,
    };

    try cmdClear(&context, &[_][]const u8{});
    try std.testing.expectEqualStrings("\x1b[2J\x1b[H", output.items);
}
