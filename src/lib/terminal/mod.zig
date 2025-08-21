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
pub const engine = @import("engine.zig");

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

// Re-export terminal engine
pub const TerminalEngine = engine.TerminalEngine;

// Re-export core types
pub const Line = core.Line;
pub const Cursor = core.Cursor;
pub const Key = core.Key;
pub const RingBuffer = core.RingBuffer;
pub const CommandExecutorFn = core.CommandExecutorFn;
pub const VisibleLinesIterator = core.VisibleLinesIterator;
