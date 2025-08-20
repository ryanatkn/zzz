const std = @import("std");
const terminal_builder = @import("terminal_builder.zig");
const TerminalBuilder = terminal_builder.TerminalBuilder;
const BuiltTerminal = terminal_builder.BuiltTerminal;
const PresetType = terminal_builder.PresetType;

/// Builder-based preset constructors for common terminal configurations
pub const BuilderPresets = struct {
    
    /// Create a minimal terminal using the builder pattern
    pub fn createMinimal(allocator: std.mem.Allocator) !BuiltTerminal {
        var builder = TerminalBuilder.init(allocator);
        defer builder.deinit();
        
        return try builder
            .withPreset(.minimal)
            .build();
    }
    
    /// Create a standard terminal using the builder pattern
    pub fn createStandard(allocator: std.mem.Allocator) !BuiltTerminal {
        var builder = TerminalBuilder.init(allocator);
        defer builder.deinit();
        
        return try builder
            .withPreset(.standard)
            .build();
    }
    
    /// Create a command terminal using the builder pattern
    pub fn createCommand(allocator: std.mem.Allocator) !BuiltTerminal {
        var builder = TerminalBuilder.init(allocator);
        defer builder.deinit();
        
        return try builder
            .withPreset(.command)
            .build();
    }
    
    /// Create a custom interactive terminal
    pub fn createInteractive(allocator: std.mem.Allocator) !BuiltTerminal {
        var builder = TerminalBuilder.init(allocator);
        defer builder.deinit();
        
        return try builder
            .withCapability(.keyboard_input)    // Required by readline_input
            .withCapability(.basic_writer)      // Required by ansi_writer
            .withCapability(.readline_input)
            .withCapability(.ansi_writer)
            .withCapability(.cursor)
            .withCapability(.line_buffer)
            .withCapability(.history)
            .withCapability(.screen_buffer)
            .withCapability(.scrollback)
            .build();
    }
    
    /// Create a high-throughput logging terminal
    pub fn createLogging(allocator: std.mem.Allocator) !BuiltTerminal {
        var builder = TerminalBuilder.init(allocator);
        defer builder.deinit();
        
        return try builder
            .withCapability(.keyboard_input)
            .withCapability(.buffered_output)
            .withCapability(.screen_buffer)
            .withCapability(.scrollback)
            .withCapability(.persistence)
            .build();
    }
    
    /// Create terminal from configuration file
    pub fn createFromConfig(allocator: std.mem.Allocator, config_path: []const u8) !BuiltTerminal {
        var builder = TerminalBuilder.init(allocator);
        defer builder.deinit();
        
        return try builder
            .withConfigFile(config_path)
            .build();
    }
    
    /// Create terminal with validation
    pub fn createValidated(allocator: std.mem.Allocator, preset: PresetType) !struct { terminal: BuiltTerminal, warnings: []const []const u8 } {
        // TODO: Implement validation integration
        var builder = TerminalBuilder.init(allocator);
        defer builder.deinit();
        
        const terminal = try builder
            .withPreset(preset)
            .build();
            
        // For now, return empty warnings
        const warnings: []const []const u8 = &[_][]const u8{};
        
        return .{ .terminal = terminal, .warnings = warnings };
    }
};

/// Example usage demonstrating builder patterns
pub const Examples = struct {
    
    /// Example: Basic terminal setup
    pub fn basicExample(allocator: std.mem.Allocator) !void {
        // Simple one-liner for common case
        var terminal = try BuilderPresets.createStandard(allocator);
        defer terminal.deinit();
        
        try terminal.write("Hello from builder-created terminal!\n");
    }
    
    /// Example: Custom capability combination
    pub fn customExample(allocator: std.mem.Allocator) !void {
        var builder = TerminalBuilder.init(allocator);
        defer builder.deinit();
        
        var terminal = try builder
            .withCapability(.readline_input)  // Advanced input with line editing
            .withCapability(.ansi_writer)     // Color/formatting support
            .withCapability(.history)         // Command history
            .withCapability(.cursor)          // Cursor management
            .withCapability(.line_buffer)     // Current line buffer
            .build();
        defer terminal.deinit();
        
        try terminal.write("Custom terminal with specific capabilities\n");
    }
    
    /// Example: Configuration-driven terminal
    pub fn configExample(allocator: std.mem.Allocator) !void {
        // Load from config file (when implemented)
        var terminal = try BuilderPresets.createFromConfig(allocator, "terminal.json");
        defer terminal.deinit();
        
        try terminal.write("Terminal created from configuration file\n");
    }
    
    /// Example: Validation and error handling
    pub fn validationExample(allocator: std.mem.Allocator) !void {
        const result = try BuilderPresets.createValidated(allocator, .command);
        var terminal = result.terminal;
        defer terminal.deinit();
        
        // Print any warnings
        for (result.warnings) |warning| {
            std.log.warn("Terminal validation: {s}", .{warning});
        }
        
        try terminal.write("Validated terminal ready\n");
    }
    
    /// Example: Error handling with builder
    pub fn errorHandlingExample(allocator: std.mem.Allocator) !void {
        var builder = TerminalBuilder.init(allocator);
        defer builder.deinit();
        
        const terminal = builder
            .withCapability(.keyboard_input)
            .withCapability(.basic_writer)
            .build() catch |err| switch (err) {
                error.NoCapabilities => {
                    std.log.err("No capabilities specified", .{});
                    return;
                },
                error.OutOfMemory => {
                    std.log.err("Out of memory creating terminal", .{});
                    return;
                },
                else => return err,
            };
        var term = terminal;
        defer term.deinit();
        
        try term.write("Terminal with error handling\n");
    }
};