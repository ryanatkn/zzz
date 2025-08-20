const std = @import("std");
const kernel = @import("../../kernel/mod.zig");
const parser = @import("parser.zig");
const registry = @import("registry.zig");
const executor = @import("executor.zig");
const BasicWriter = @import("../output/basic_writer.zig").BasicWriter;

const Parser = parser.Parser;
const Registry = registry.Registry;
const Executor = executor.Executor;
const CommandContext = registry.CommandContext;

/// Command pipeline capability - coordinates command parsing, registration, and execution
pub const Pipeline = struct {

    allocator: std.mem.Allocator,
    parser_capability: ?*Parser = null,
    registry_capability: ?*Registry = null,
    executor_capability: ?*Executor = null,
    writer_capability: ?*BasicWriter = null,
    event_bus: ?*kernel.EventBus = null,

    const Self = @This();

    /// Factory method for creating pipeline capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const pipeline = try allocator.create(Self);
        pipeline.* = Self{
            .allocator = allocator,
        };
        return pipeline;
    }

    /// Factory method for destroying pipeline capability
    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    /// Get dependencies (parser, registry, executor, writer)
    pub fn getDependencies(self: *const Self) []const []const u8 {
        _ = self;
        return &[_][]const u8{ "command_parser", "command_registry", "process_executor", "basic_writer" };
    }

    pub fn initialize(self: *Self, dependencies: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        self.event_bus = event_bus;

        // Find all dependencies using type-safe casting
        for (dependencies) |dep| {
            if (dep.cast(Parser)) |pars| {
                self.parser_capability = pars;
            } else if (dep.cast(Registry)) |reg| {
                self.registry_capability = reg;
            } else if (dep.cast(Executor)) |exec| {
                self.executor_capability = exec;
            } else if (dep.cast(BasicWriter)) |writer| {
                self.writer_capability = writer;
            }
        }

        // Verify all dependencies are available
        if (self.parser_capability == null or
            self.registry_capability == null or
            self.executor_capability == null or
            self.writer_capability == null)
        {
            return error.MissingDependency;
        }

        // Subscribe to command_execute events to handle user input
        try event_bus.subscribe(.command_execute, handleCommandExecuteEvent, self);
    }

    pub fn deinit(self: *Self) void {
        // Unsubscribe from events first
        if (self.event_bus) |bus| {
            bus.unsubscribe(.command_execute, handleCommandExecuteEvent, self);
        }

        self.event_bus = null;
        self.parser_capability = null;
        self.registry_capability = null;
        self.executor_capability = null;
        self.writer_capability = null;
    }

    pub fn isActive(self: *const Self) bool {
        return self.event_bus != null and
            self.parser_capability != null and
            self.registry_capability != null and
            self.executor_capability != null and
            self.writer_capability != null;
    }

    /// Execute a command line through the complete pipeline
    pub fn executeCommand(self: *Self, command_line: []const u8) !void {
        if (!self.isActive()) {
            return error.NotInitialized;
        }

        const trimmed = std.mem.trim(u8, command_line, " \t\n");
        if (trimmed.len == 0) {
            return;
        }

        // Get capability implementations - type-safe direct access
        const parser_impl = self.parser_capability.?;
        const registry_impl = self.registry_capability.?;
        const executor_impl = self.executor_capability.?;

        // Parse command line
        var parse_result = parser_impl.parse(trimmed) catch |err| {
            const error_msg = std.fmt.allocPrint(self.allocator, "Parse error: {s}\n", .{@errorName(err)}) catch "Parse error\n";
            defer if (std.mem.startsWith(u8, error_msg, "Parse error:")) self.allocator.free(error_msg);
            try self.writeOutput(error_msg);
            return;
        };
        defer parse_result.deinit();

        // Create command context
        var command_context = CommandContext{
            .allocator = self.allocator,
            .event_bus = self.event_bus.?,
            .write_fn = writeToOutput,
            .write_context = self,
        };

        // Try built-in commands first
        const handled_builtin = registry_impl.execute(&command_context, parse_result.command, parse_result.args) catch |err| {
            const error_msg = std.fmt.allocPrint(self.allocator, "Error: Failed to execute command '{s}' - {s}\n", .{ parse_result.command, @errorName(err) }) catch {
                try self.writeOutput("Error: Command execution failed\n");
                return;
            };
            defer self.allocator.free(error_msg);
            try self.writeOutput(error_msg);
            return;
        };

        if (handled_builtin) {
            // Built-in command was executed successfully
            return;
        }

        // Execute as external process
        self.executeExternalCommand(parse_result.command, parse_result.args, executor_impl) catch |err| {
            const error_msg = std.fmt.allocPrint(self.allocator, "Error: Failed to execute external command '{s}' - {s}\n", .{ parse_result.command, @errorName(err) }) catch {
                try self.writeOutput("Error: External command execution failed\n");
                return;
            };
            defer self.allocator.free(error_msg);
            try self.writeOutput(error_msg);
        };
    }

    /// Execute external command via process executor
    fn executeExternalCommand(self: *Self, command: []const u8, args: []const []const u8, executor_impl: *Executor) !void {
        var result = executor_impl.execute(command, args) catch |err| switch (err) {
            error.FileNotFound => {
                const error_msg = std.fmt.allocPrint(self.allocator, "{s}: command not found\n", .{command}) catch "command not found\n";
                defer if (std.mem.startsWith(u8, error_msg, command)) self.allocator.free(error_msg); // Only free if allocation succeeded
                try self.writeOutput(error_msg);
                return;
            },
            else => return err,
        };
        defer result.deinit();

        // Output stdout
        if (result.stdout.len > 0) {
            try self.writeOutput(result.stdout);
        }

        // Output stderr
        if (result.stderr.len > 0) {
            try self.writeOutput(result.stderr);
        }

        // If command failed, show exit code
        if (result.exit_code != 0) {
            const exit_msg = std.fmt.allocPrint(self.allocator, "Command exited with code {d}\n", .{result.exit_code}) catch "Command failed\n";
            defer if (!std.mem.eql(u8, exit_msg, "Command failed\n")) self.allocator.free(exit_msg); // Only free if allocation succeeded
            try self.writeOutput(exit_msg);
        }
    }

    /// Internal write output function used by command context
    fn writeToOutput(context: *anyopaque, text: []const u8) !void {
        const self: *Pipeline = @ptrCast(@alignCast(context));
        try self.writeOutput(text);
    }

    /// Write output directly to BasicWriter
    fn writeOutput(self: *Self, text: []const u8) !void {
        if (self.writer_capability) |writer| {
            try writer.write(text);
        } else {
            // Fallback to stdout if no writer available
            const stdout = std.io.getStdOut().writer();
            try stdout.writeAll(text);
        }
    }

    /// Validate command line syntax before execution
    pub fn validateCommand(self: *Self, command_line: []const u8) !void {
        if (!self.isActive()) {
            return error.NotInitialized;
        }

        // Use the parser capability to validate the command line
        const parser_impl = self.parser_capability.?;

        // Parse to validate syntax - this will catch quote errors
        var parse_result = parser_impl.parse(command_line) catch |err| {
            return err; // Return the parsing error directly
        };
        defer parse_result.deinit();

        // If parsing succeeds, the command line is valid
    }

    /// Get list of available commands
    pub fn getAvailableCommands(self: *Self) ![][]const u8 {
        if (!self.isActive()) {
            return error.NotInitialized;
        }

        const registry_impl = self.registry_capability.?;
        return registry_impl.getCommandNames(self.allocator);
    }

    /// Check if a command exists (built-in)
    pub fn hasCommand(self: *Self, command_name: []const u8) bool {
        if (!self.isActive()) {
            return false;
        }

        // Use the registry capability to check if command exists
        const registry_impl = self.registry_capability.?;
        return registry_impl.hasCommand(command_name);
    }

    /// Get current working directory from executor
    pub fn getCurrentDirectory(self: *Self) ?[]const u8 {
        if (!self.isActive()) {
            return null;
        }

        const executor_impl = self.executor_capability.?;
        return executor_impl.getCurrentDirectory();
    }

    /// Change working directory via executor
    pub fn changeDirectory(self: *Self, path: []const u8) !void {
        if (!self.isActive()) {
            return error.NotInitialized;
        }

        const executor_impl = self.executor_capability.?;
        try executor_impl.changeDirectory(path);
    }
};

/// Event handler for command_execute events from LineBuffer
fn handleCommandExecuteEvent(event: kernel.Event, context: ?*anyopaque) !void {
    if (context == null) return;

    const pipeline = @as(*Pipeline, @ptrCast(@alignCast(context.?)));

    switch (event.data) {
        .command_execute => |cmd_data| {
            // Execute the command through the pipeline
            try pipeline.executeCommand(cmd_data.command);
        },
        else => {}, // Ignore other event types
    }
}

// Tests
test "Pipeline capability initialization" {
    const allocator = std.testing.allocator;
    var pipeline = try Pipeline.create(allocator);
    defer pipeline.destroy(allocator);

    // Test that capability can be created and has correct properties
    try std.testing.expect(pipeline.getDependencies().len == 4);
    try std.testing.expect(!pipeline.isActive());
    
    // Test that all dependency pointers start as null
    try std.testing.expect(pipeline.parser_capability == null);
    try std.testing.expect(pipeline.registry_capability == null);
    try std.testing.expect(pipeline.executor_capability == null);
    try std.testing.expect(pipeline.writer_capability == null);
    
    // Test that allocator is properly set
    try std.testing.expect(pipeline.allocator.ptr == allocator.ptr);
}

test "Pipeline dependency validation" {
    const allocator = std.testing.allocator;
    var pipeline = try Pipeline.create(allocator);
    defer pipeline.destroy(allocator);

    var event_bus = kernel.EventBus.init(allocator);

    // Test with empty dependencies (should fail)
    try std.testing.expectError(error.MissingDependency, pipeline.initialize(&[_]kernel.TypeSafeCapability{}, &event_bus));
}

test "Pipeline command validation" {
    const allocator = std.testing.allocator;
    var pipeline = try Pipeline.create(allocator);
    defer pipeline.destroy(allocator);

    // Test validation without initialization (should fail)
    try std.testing.expectError(error.NotInitialized, pipeline.validateCommand("echo hello"));
}
