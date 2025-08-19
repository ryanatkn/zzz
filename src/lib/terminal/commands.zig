const std = @import("std");
const process = @import("process.zig");
const loggers = @import("../debug/loggers.zig");

const ProcessExecutor = process.ProcessExecutor;

/// Command execution context
pub const CommandContext = struct {
    terminal: *anyopaque, // Terminal instance (opaque to avoid circular dependency)
    process_executor: *ProcessExecutor,
    command_registry: *CommandRegistry,
    allocator: std.mem.Allocator,
    output_writer: *const fn (context: *anyopaque, text: []const u8) anyerror!void,

    /// Write output to terminal
    pub fn writeOutput(self: *CommandContext, text: []const u8) !void {
        try self.output_writer(self.terminal, text);
    }
};

/// Command function signature
pub const CommandFn = *const fn (context: *CommandContext, args: []const []const u8) anyerror!void;

/// Built-in command entry
pub const Command = struct {
    name: []const u8,
    description: []const u8,
    usage: []const u8,
    func: CommandFn,
};

/// Built-in command registry
pub const CommandRegistry = struct {
    commands: std.StringHashMap(Command),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        var registry = Self{
            .commands = std.StringHashMap(Command).init(allocator),
            .allocator = allocator,
        };

        // Register built-in commands
        registry.registerBuiltins();

        return registry;
    }

    pub fn deinit(self: *Self) void {
        self.commands.deinit();
    }

    /// Register a command
    pub fn register(self: *Self, command: Command) !void {
        try self.commands.put(command.name, command);
    }

    /// Execute a command
    pub fn execute(self: *Self, context: *CommandContext, command_line: []const u8) !bool {
        // Parse command and arguments
        var args = std.ArrayList([]const u8).init(context.allocator);
        defer {
            for (args.items) |arg| {
                context.allocator.free(arg);
            }
            args.deinit();
        }

        try self.parseArgs(command_line, &args, context.allocator);

        if (args.items.len == 0) {
            return false;
        }

        const command_name = args.items[0];
        const command_args = if (args.items.len > 1) args.items[1..] else &[_][]const u8{};

        // Check if it's a built-in command
        if (self.commands.get(command_name)) |command| {
            try command.func(context, command_args);
            return true;
        }

        return false; // Not a built-in command
    }

    /// Get command by name
    pub fn getCommand(self: *const Self, name: []const u8) ?Command {
        return self.commands.get(name);
    }

    /// List all commands
    pub fn listCommands(self: *const Self) std.StringHashMap(Command).Iterator {
        return self.commands.iterator();
    }

    /// Register built-in commands
    fn registerBuiltins(self: *Self) void {
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
            self.commands.put(command.name, command) catch {};
        }
    }

    /// Parse command line into arguments
    fn parseArgs(self: *Self, command_line: []const u8, args: *std.ArrayList([]const u8), allocator: std.mem.Allocator) !void {
        _ = self;

        var i: usize = 0;
        var in_quotes = false;
        var quote_char: u8 = 0;
        var current_arg = std.ArrayList(u8).init(allocator);

        while (i < command_line.len) {
            const ch = command_line[i];

            switch (ch) {
                ' ', '\t' => {
                    if (in_quotes) {
                        try current_arg.append(ch);
                    } else if (current_arg.items.len > 0) {
                        try args.append(try current_arg.toOwnedSlice());
                        current_arg = std.ArrayList(u8).init(allocator);
                    }
                },
                '"', '\'' => {
                    if (in_quotes and ch == quote_char) {
                        in_quotes = false;
                        quote_char = 0;
                    } else if (!in_quotes) {
                        in_quotes = true;
                        quote_char = ch;
                    } else {
                        try current_arg.append(ch);
                    }
                },
                '\\' => {
                    if (i + 1 < command_line.len) {
                        i += 1;
                        try current_arg.append(command_line[i]);
                    } else {
                        try current_arg.append(ch);
                    }
                },
                else => {
                    try current_arg.append(ch);
                },
            }

            i += 1;
        }

        // Add final argument if any
        if (current_arg.items.len > 0) {
            try args.append(try current_arg.toOwnedSlice());
        } else {
            current_arg.deinit();
        }
    }
};

// Built-in command implementations

fn cmdHelp(context: *CommandContext, args: []const []const u8) !void {
    if (args.len == 0) {
        try context.writeOutput("Available commands:\n\n");

        var iter = context.command_registry.listCommands();
        while (iter.next()) |entry| {
            const command = entry.value_ptr;
            try context.writeOutput(std.fmt.allocPrint(context.allocator, "  {s:<12} - {s}\n", .{ command.name, command.description }) catch "");
        }

        try context.writeOutput("\nType 'help <command>' for detailed usage.\n");
    } else {
        const command_name = args[0];
        if (context.command_registry.getCommand(command_name)) |command| {
            try context.writeOutput(std.fmt.allocPrint(context.allocator, "{s} - {s}\n", .{ command.name, command.description }) catch "");
            try context.writeOutput(std.fmt.allocPrint(context.allocator, "Usage: {s}\n", .{command.usage}) catch "");
        } else {
            try context.writeOutput(std.fmt.allocPrint(context.allocator, "Unknown command: {s}\n", .{command_name}) catch "");
        }
    }
}

fn cmdClear(context: *CommandContext, args: []const []const u8) !void {
    _ = args;
    // Terminal clear will be handled by the terminal instance
    try context.writeOutput("\x1b[2J\x1b[H"); // ANSI clear screen and move cursor to top
}

fn cmdCd(context: *CommandContext, args: []const []const u8) !void {
    const target_dir = if (args.len > 0) args[0] else (std.posix.getenv("HOME") orelse "/");

    context.process_executor.changeDirectory(target_dir) catch |err| {
        const error_msg = switch (err) {
            error.DirectoryNotFound => "Directory not found",
            error.NotADirectory => "Not a directory",
            error.AccessDenied => "Access denied",
            else => "Failed to change directory",
        };
        try context.writeOutput(std.fmt.allocPrint(context.allocator, "cd: {s}: {s}\n", .{ target_dir, error_msg }) catch "");
        return;
    };
}

fn cmdPwd(context: *CommandContext, args: []const []const u8) !void {
    _ = args;
    const cwd = context.process_executor.getWorkingDirectory();
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
    if (args.len == 0) {
        try context.writeOutput("\n");
        return;
    }

    for (args, 0..) |arg, i| {
        if (i > 0) try context.writeOutput(" ");
        try context.writeOutput(arg);
    }
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

        try context.process_executor.setEnv(var_name, var_value);
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
}
