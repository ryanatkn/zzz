// Terminal module - Clean separation between terminal engine and UI rendering
//
// This module provides the core terminal functionality independent of any UI rendering system.
// The terminal engine handles command execution, process management, ANSI parsing, and state management,
// while UI components (like src/lib/ui/terminal.zig) handle the actual rendering and user interaction.

pub const core = @import("core.zig");
pub const process = @import("process.zig");
pub const commands = @import("commands.zig");
pub const ansi = @import("ansi.zig");
pub const output_capture = @import("output_capture.zig");
pub const process_control = @import("process_control.zig");

// Re-export main types for convenience
pub const Terminal = core.Terminal;
pub const ProcessExecutor = process.ProcessExecutor;
pub const ProcessResult = process.ProcessResult;
pub const CommandRegistry = commands.CommandRegistry;
pub const CommandContext = commands.CommandContext;
pub const CommandFn = commands.CommandFn;
pub const Command = commands.Command;
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
        const log = std.log.scoped(.terminal_execute);
        const trimmed = std.mem.trim(u8, command_line, " \t\n");
        log.info("Command received: '{s}' (length: {d})", .{ trimmed, trimmed.len });
        if (trimmed.len == 0) {
            log.info("Empty command, returning", .{});
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
        log.info("Checking built-in commands...", .{});
        const handled_builtin = self.command_registry.execute(&context, trimmed) catch |err| {
            log.err("Built-in command execution failed: {}", .{err});
            try self.terminal.write("Error executing command: ");
            try self.terminal.write(@errorName(err));
            try self.terminal.write("\n");
            return;
        };
        
        if (handled_builtin) {
            log.info("Built-in command executed successfully", .{});
            return; // Built-in command was executed
        }
        
        // Execute as external process
        log.info("No built-in command found, trying external process...", .{});
        self.executeExternalCommand(trimmed) catch |err| {
            log.err("External command execution failed: {}", .{err});
            try self.terminal.write("Error executing external command: ");
            try self.terminal.write(@errorName(err));
            try self.terminal.write("\n");
        };
    }
    
    /// Execute external command via process executor
    fn executeExternalCommand(self: *Self, command_line: []const u8) !void {
        // Use streaming execution for better responsiveness
        const result = self.process_executor.executeWithStreaming(command_line) catch |err| {
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
            const exit_msg = std.fmt.allocPrint(self.allocator, "Command exited with code {d}\n", .{result.exit_code}) catch return;
            defer self.allocator.free(exit_msg);
            try self.terminal.write(exit_msg);
        }
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
        const log = std.log.scoped(.terminal_engine_key);
        
        // Handle signal keys first (Ctrl+C, etc.)
        if (self.signal_handler.handleKeyInput(key)) {
            log.info("Signal key handled: {}", .{key});
            // Process any pending signals
            _ = self.signal_handler.processSignals(if (self.process_executor.isProcessRunning()) 
                &self.process_executor.current_process.? else null) catch |err| {
                std.log.err("Failed to process signal: {}", .{err});
            };
            return;
        }
        
        // Log regular keys (but not every single character to avoid spam)
        switch (key) {
            .enter => log.info("Processing ENTER key in engine", .{}),
            .backspace => log.info("Processing BACKSPACE key", .{}),
            .up_arrow => log.info("Processing UP ARROW key", .{}),
            .down_arrow => log.info("Processing DOWN ARROW key", .{}),
            else => {}, // Don't log every character
        }
        
        // Regular key handling
        try self.terminal.handleKey(key);
    }
    
    /// Update terminal state
    pub fn update(self: *Self, dt: f32) void {
        self.terminal.update(dt);
    }
    
    /// Get visible lines for rendering
    pub fn getVisibleContent(self: *const Self) struct { lines: []const Line, current: []const u8, cursor: Cursor } {
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
    const log = std.log.scoped(.terminal_callback);
    log.info("Callback triggered for command: '{s}'", .{command});
    const engine: *TerminalEngine = @ptrCast(@alignCast(context));
    try engine.executeCommand(command);
    log.info("Callback completed", .{});
}

/// Output streaming callback for real-time display
fn streamOutputCallback(context: *anyopaque, data: []const u8) !void {
    const engine: *TerminalEngine = @ptrCast(@alignCast(context));
    try engine.writeWithAnsiParsing(data);
}

const std = @import("std");