// Terminal module - Clean separation between terminal engine and UI rendering
//
// This module provides the core terminal functionality independent of any UI rendering system.
// The terminal engine handles command execution, process management, ANSI parsing, and state management,
// while UI components (like src/lib/ui/terminal.zig) handle the actual rendering and user interaction.

const std = @import("std");
const loggers = @import("../debug/loggers.zig");

pub const core = @import("core.zig");
pub const ansi = @import("ansi.zig");
pub const output_capture = @import("output_capture.zig");
pub const process_control = @import("process_control.zig");

// Export kernel and presets for micro-kernel terminal
pub const kernel = @import("kernel/mod.zig");
pub const presets = struct {
    pub const MinimalTerminal = @import("presets/minimal.zig").MinimalTerminal;
    pub const StandardTerminal = @import("presets/standard.zig").StandardTerminal;
    pub const CommandTerminal = @import("presets/command.zig").CommandTerminal;
};

// Export builder system for fluent API construction
pub const builders = @import("builders/mod.zig");

// Export command capabilities
pub const capabilities = struct {
    pub const commands = struct {
        pub const Parser = @import("capabilities/commands/parser.zig").Parser;
        pub const Registry = @import("capabilities/commands/registry.zig").Registry;
        pub const Executor = @import("capabilities/commands/executor.zig").Executor;
        pub const Builtin = @import("capabilities/commands/builtin.zig").Builtin;
        pub const Pipeline = @import("capabilities/commands/pipeline.zig").Pipeline;
    };

    pub const output = struct {
        pub const AnsiWriter = @import("capabilities/output/ansi_writer.zig").AnsiWriter;
    };
};

// Re-export main types for convenience
pub const Terminal = core.Terminal;
// Legacy compatibility exports (use capabilities.commands directly for new code)
pub const ProcessExecutor = capabilities.commands.Executor;
pub const ProcessResult = @import("capabilities/commands/executor.zig").ProcessResult;
pub const CommandRegistry = capabilities.commands.Registry;
pub const CommandContext = @import("capabilities/commands/registry.zig").CommandContext;
pub const CommandFn = @import("capabilities/commands/registry.zig").CommandFn;
pub const Command = @import("capabilities/commands/registry.zig").Command;
pub const AnsiParser = ansi.AnsiParser;
pub const AnsiColor = ansi.AnsiColor;
pub const TextAttributes = ansi.TextAttributes;
pub const Style = ansi.Style;
pub const parseAnsiText = ansi.parseAnsiText;
pub const hasAnsiSequences = ansi.hasAnsiSequences;
pub const OutputCapture = output_capture.OutputCapture;
pub const ProcessControl = process_control.ProcessControl;
pub const SignalHandler = process_control.SignalHandler;

// Re-export core types
pub const Line = core.Line;
pub const Cursor = core.Cursor;
pub const Key = core.Key;
pub const RingBuffer = core.RingBuffer;
pub const CommandExecutorFn = core.CommandExecutorFn;
pub const VisibleLinesIterator = core.VisibleLinesIterator;

/// Integrated terminal engine that combines all components
pub const TerminalEngine = struct {
    allocator: std.mem.Allocator,
    terminal: Terminal,
    process_executor: ProcessExecutor,
    command_registry: CommandRegistry,
    ansi_parser: AnsiParser,
    process_control: ProcessControl,
    signal_handler: SignalHandler,

    const Self = @This();

    /// Initialize terminal engine with all components
    pub fn init(allocator: std.mem.Allocator) !Self {
        var engine = Self{
            .allocator = allocator,
            .terminal = Terminal.init(allocator),
            .process_executor = try ProcessExecutor.init(allocator),
            .command_registry = CommandRegistry.init(allocator),
            .ansi_parser = AnsiParser.init(),
            .process_control = ProcessControl.init(allocator),
            .signal_handler = undefined, // Will be initialized after
        };

        // Initialize signal handler with reference to engine's process_control
        engine.signal_handler = SignalHandler.init(&engine.process_control);

        // Set up command execution callback
        engine.terminal.setCommandExecutor(executeCommandCallback, @ptrCast(&engine));

        // Set up output streaming callback
        engine.process_executor.setOutputCallback(streamOutputCallback, @ptrCast(&engine));

        return engine;
    }

    /// Cleanup terminal engine
    pub fn deinit(self: *Self) void {
        self.terminal.deinit();
        self.process_executor.deinit();
        self.command_registry.deinit();
        self.process_control.deinit();
    }

    /// Execute a command line
    pub fn executeCommand(self: *Self, command_line: []const u8) !void {
        const trimmed = std.mem.trim(u8, command_line, " \t\n");
        if (trimmed.len == 0) {
            return;
        }

        // Create command context
        var context = CommandContext{
            .terminal = @ptrCast(self), // Pass self as opaque terminal reference
            .process_executor = &self.process_executor,
            .command_registry = &self.command_registry,
            .allocator = self.allocator,
            .output_writer = writeToTerminal,
        };

        // Try built-in commands first
        const handled_builtin = self.command_registry.execute(&context, trimmed) catch |err| {
            const error_msg = std.fmt.allocPrint(self.allocator, "Error: Failed to execute command '{s}' - {s}\n", .{ trimmed, @errorName(err) }) catch {
                try self.terminal.write("Error: Command execution failed\n");
                return;
            };
            defer self.allocator.free(error_msg);
            try self.terminal.write(error_msg);
            return;
        };

        if (handled_builtin) {
            // Add a blank line after built-in command output
            try self.terminal.write("\n");
            return; // Built-in command was executed
        }

        // Execute as external process
        self.executeExternalCommand(trimmed) catch |err| {
            const error_msg = std.fmt.allocPrint(self.allocator, "Error: Failed to execute external command '{s}' - {s}\n", .{ trimmed, @errorName(err) }) catch {
                try self.terminal.write("Error: External command execution failed\n");
                return;
            };
            defer self.allocator.free(error_msg);
            try self.terminal.write(error_msg);
        };
    }

    /// Execute external command via process executor
    fn executeExternalCommand(self: *Self, command_line: []const u8) !void {

        // Try with absolute paths first for common commands
        var modified_command_line: ?[]u8 = null;
        defer if (modified_command_line) |cmd| self.allocator.free(cmd);

        var args = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (args.items) |arg| {
                self.allocator.free(arg);
            }
            args.deinit();
        }

        // Parse to get the command name
        try self.process_executor.parseCommandLine(command_line, &args);
        if (args.items.len > 0) {
            const command_name = args.items[0];

            // Try common absolute paths for basic commands
            const common_commands = [_]struct { name: []const u8, path: []const u8 }{
                .{ .name = "ls", .path = "/bin/ls" },
                .{ .name = "echo", .path = "/bin/echo" },
                .{ .name = "pwd", .path = "/bin/pwd" },
                .{ .name = "cat", .path = "/bin/cat" },
                .{ .name = "grep", .path = "/bin/grep" },
                .{ .name = "find", .path = "/bin/find" },
                .{ .name = "which", .path = "/bin/which" },
            };

            for (common_commands) |cmd| {
                if (std.mem.eql(u8, command_name, cmd.name)) {
                    // Check if absolute path exists
                    std.fs.cwd().access(cmd.path, .{}) catch {
                        break;
                    };

                    // Replace command with absolute path
                    modified_command_line = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ cmd.path, command_line[command_name.len..] });
                    break;
                }
            }
        }

        const final_command = modified_command_line orelse command_line;

        // Use streaming execution for better responsiveness
        const result = self.process_executor.executeWithStreaming(final_command) catch |err| {
            const error_msg = switch (err) {
                error.FileNotFound => "Command not found",
                error.AccessDenied => "Permission denied",
                else => @errorName(err),
            };
            try self.terminal.write(error_msg);
            try self.terminal.write("\n");
            return;
        };
        defer {
            self.allocator.free(result.stdout);
            self.allocator.free(result.stderr);
        }

        // Note: stdout and stderr are already written via streaming callback
        // This is just for any remaining data or final processing

        // Show exit code if non-zero
        if (result.exit_code != 0) {
            const exit_msg = std.fmt.allocPrint(self.allocator, "[Exit code: {d}]\n", .{result.exit_code}) catch return;
            defer self.allocator.free(exit_msg);
            try self.terminal.write(exit_msg);
        }

        // Add a blank line after command output for readability
        try self.terminal.write("\n");
    }

    /// Write text to terminal with ANSI parsing
    fn writeWithAnsiParsing(self: *Self, text: []const u8) !void {
        if (ansi.hasAnsiSequences(text)) {
            const parsed = ansi.parseAnsiText(self.allocator, text) catch {
                // Fallback to raw text if parsing fails
                try self.terminal.write(text);
                return;
            };
            defer {
                self.allocator.free(parsed.text);
                self.allocator.free(parsed.colors);
                self.allocator.free(parsed.attributes);
            }

            // For now, just write the text without styling
            // Full styling integration will be handled by the UI component
            try self.terminal.write(parsed.text);
        } else {
            try self.terminal.write(text);
        }
    }

    /// Handle keyboard input
    pub fn handleKey(self: *Self, key: Key) !void {
        const ui_log = loggers.getUILog();

        // Log all key inputs received by the engine
        switch (key) {
            .char => |ch| ui_log.info("terminal_engine_key", "Engine received character: '{c}' (ASCII {d})", .{ ch, ch }),
            .enter => ui_log.info("terminal_engine_key", "Engine received: ENTER", .{}),
            .backspace => ui_log.info("terminal_engine_key", "Engine received: BACKSPACE", .{}),
            .delete => ui_log.info("terminal_engine_key", "Engine received: DELETE", .{}),
            .tab => ui_log.info("terminal_engine_key", "Engine received: TAB", .{}),
            .up_arrow => ui_log.info("terminal_engine_key", "Engine received: UP_ARROW", .{}),
            .down_arrow => ui_log.info("terminal_engine_key", "Engine received: DOWN_ARROW", .{}),
            .left_arrow => ui_log.info("terminal_engine_key", "Engine received: LEFT_ARROW", .{}),
            .right_arrow => ui_log.info("terminal_engine_key", "Engine received: RIGHT_ARROW", .{}),
            .home => ui_log.info("terminal_engine_key", "Engine received: HOME", .{}),
            .end => ui_log.info("terminal_engine_key", "Engine received: END", .{}),
            .page_up => ui_log.info("terminal_engine_key", "Engine received: PAGE_UP", .{}),
            .page_down => ui_log.info("terminal_engine_key", "Engine received: PAGE_DOWN", .{}),
            .ctrl_c => ui_log.info("terminal_engine_key", "Engine received: CTRL_C", .{}),
            .ctrl_d => ui_log.info("terminal_engine_key", "Engine received: CTRL_D", .{}),
            .ctrl_l => ui_log.info("terminal_engine_key", "Engine received: CTRL_L", .{}),
            .ctrl_z => ui_log.info("terminal_engine_key", "Engine received: CTRL_Z", .{}),
            else => ui_log.info("terminal_engine_key", "Engine received: {}", .{key}),
        }

        // Handle signal keys first (Ctrl+C, etc.)
        if (self.signal_handler.handleKeyInput(key)) {
            ui_log.info("terminal_engine_key", "Signal key handled: {}", .{key});
            // Process any pending signals
            _ = self.signal_handler.processSignals(if (self.process_executor.isProcessRunning())
                &self.process_executor.current_process.?
            else
                null) catch |err| {
                const signal_log = loggers.getUILog();
                signal_log.err("terminal_signal", "Failed to process signal: {}", .{err});
            };
            return;
        }

        // Forward to terminal core for processing
        ui_log.info("terminal_engine_key", "Forwarding key to terminal core", .{});
        try self.terminal.handleKey(key);
        ui_log.info("terminal_engine_key", "Terminal core processing complete", .{});
    }

    /// Update terminal state
    pub fn update(self: *Self, dt: f32) void {
        self.terminal.update(dt);
    }

    /// Get visible lines for rendering
    pub fn getVisibleContent(self: *const Self) struct { lines: VisibleLinesIterator, current: []const u8, cursor: Cursor } {
        const visible = self.terminal.getVisibleLines();
        return .{
            .lines = visible.lines,
            .current = visible.current,
            .cursor = self.terminal.cursor,
        };
    }

    /// Clear terminal
    pub fn clear(self: *Self) void {
        self.terminal.clear();
    }

    /// Resize terminal
    pub fn resize(self: *Self, columns: usize, rows: usize) void {
        self.terminal.resize(columns, rows);
    }

    /// Get current working directory
    pub fn getWorkingDirectory(self: *const Self) []const u8 {
        return self.process_executor.getWorkingDirectory();
    }

    /// Check if process is running
    pub fn isProcessRunning(self: *const Self) bool {
        return self.process_executor.isProcessRunning();
    }
};

/// Output writer function for command context
fn writeToTerminal(terminal_ptr: *anyopaque, text: []const u8) !void {
    const engine: *TerminalEngine = @ptrCast(@alignCast(terminal_ptr));
    try engine.terminal.write(text);
}

/// Command execution callback for terminal core
fn executeCommandCallback(context: *anyopaque, command: []const u8) !void {
    const ui_log = loggers.getUILog();
    ui_log.info("terminal_callback", "Callback triggered for command: '{s}'", .{command});
    const engine: *TerminalEngine = @ptrCast(@alignCast(context));
    try engine.executeCommand(command);
    ui_log.info("terminal_callback", "Callback completed", .{});
}

/// Output streaming callback for real-time display
fn streamOutputCallback(context: *anyopaque, data: []const u8) !void {
    const engine: *TerminalEngine = @ptrCast(@alignCast(context));
    try engine.writeWithAnsiParsing(data);
}
