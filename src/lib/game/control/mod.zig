/// AI control system for game input injection
pub const direct_input = @import("direct_input.zig");

// Convenience re-exports
pub const DirectInputBuffer = direct_input.DirectInputBuffer;
pub const InputCommand = direct_input.DirectInputBuffer.InputCommand;
pub const MappedInput = direct_input.MappedInput;
pub const applyCommand = direct_input.applyCommand;
pub const processCommands = direct_input.processCommands;