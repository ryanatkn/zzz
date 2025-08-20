const std = @import("std");
const terminal_builder = @import("terminal_builder.zig");
const validation = @import("validation.zig");
const TerminalBuilder = terminal_builder.TerminalBuilder;
const BuiltTerminal = terminal_builder.BuiltTerminal;
const PresetType = terminal_builder.PresetType;
const CapabilityType = terminal_builder.CapabilityType;

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
            .withCapability(.keyboard_input) // Required by readline_input
            .withCapability(.basic_writer) // Required by ansi_writer
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
        // Build terminal first
        var builder = TerminalBuilder.init(allocator);
        defer builder.deinit();

        const terminal = try builder
            .withPreset(preset)
            .build();

        // Get capabilities from the terminal for validation
        const capabilities = getPresetCapabilities(preset);

        // Run validation
        var validator = validation.ValidationSystem.init(allocator);
        defer validator.deinit();

        var validation_result = validator.validateCapabilities(capabilities) catch |err| {
            std.log.warn("Validation failed: {}", .{err});
            const warnings: []const []const u8 = &[_][]const u8{};
            return .{ .terminal = terminal, .warnings = warnings };
        };
        defer validation_result.deinit();

        // Convert validation warnings to string array
        var warning_list = std.ArrayList([]const u8).init(allocator);
        defer warning_list.deinit();

        for (validation_result.warnings.items) |warning| {
            const warning_msg = try std.fmt.allocPrint(allocator, "Warning: {} capability: {s}", .{ @tagName(warning.warning_type), warning.message });
            try warning_list.append(warning_msg);
        }

        const warnings = try warning_list.toOwnedSlice();
        return .{ .terminal = terminal, .warnings = warnings };
    }

    /// Get capabilities for a preset type (helper for validation)
    fn getPresetCapabilities(preset: PresetType) []const CapabilityType {
        return switch (preset) {
            .minimal => &[_]CapabilityType{ .keyboard_input, .basic_writer, .line_buffer, .cursor },
            .standard => &[_]CapabilityType{ .keyboard_input, .basic_writer, .line_buffer, .cursor, .history, .screen_buffer, .scrollback, .persistence },
            .command => &[_]CapabilityType{ .keyboard_input, .basic_writer, .ansi_writer, .line_buffer, .cursor, .history, .screen_buffer, .scrollback, .persistence, .parser, .registry, .executor, .builtin, .pipeline },
        };
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
            .withCapability(.readline_input) // Advanced input with line editing
            .withCapability(.ansi_writer) // Color/formatting support
            .withCapability(.history) // Command history
            .withCapability(.cursor) // Cursor management
            .withCapability(.line_buffer) // Current line buffer
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
