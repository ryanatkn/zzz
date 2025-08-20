// Terminal Builder System - Fluent API for Terminal Construction
//
// This module provides a fluent builder API for constructing terminals with
// specific capability combinations. It simplifies the manual process of
// creating, registering, and initializing capabilities.
//
// Key Features:
// - Fluent API for intuitive terminal construction
// - Automatic capability dependency resolution
// - Configuration file support
// - Validation and compatibility checking
// - Pre-built presets for common use cases
//
// Example Usage:
//   var terminal = try TerminalBuilder.init(allocator)
//       .withPreset(.standard)
//       .withCapability(.mouse_input)
//       .build();
//   defer terminal.deinit();

const std = @import("std");

// Core builder components
pub const terminal_builder = @import("terminal_builder.zig");
pub const capability_loader = @import("capability_loader.zig");
pub const configuration = @import("configuration.zig");
pub const validation = @import("validation.zig");
pub const builder_presets = @import("builder_presets.zig");

// Main types
pub const TerminalBuilder = terminal_builder.TerminalBuilder;
pub const BuiltTerminal = terminal_builder.BuiltTerminal;
pub const CapabilityType = terminal_builder.CapabilityType;
pub const PresetType = terminal_builder.PresetType;

// Capability system
pub const CapabilityLoader = capability_loader.CapabilityLoader;
pub const CapabilityMetadata = capability_loader.CapabilityMetadata;

// Configuration system
pub const ConfigurationSystem = configuration.ConfigurationSystem;
pub const TerminalConfig = configuration.TerminalConfig;
pub const ConfigFormat = configuration.ConfigFormat;

// Validation system
pub const ValidationSystem = validation.ValidationSystem;
pub const ValidationResult = validation.ValidationResult;
pub const ValidationError = validation.ValidationError;
pub const ValidationWarning = validation.ValidationWarning;

// Presets
pub const BuilderPresets = builder_presets.BuilderPresets;

// Convenience functions for common use cases
/// Create a minimal terminal (keyboard + basic output)
pub fn createMinimal(allocator: std.mem.Allocator) !BuiltTerminal {
    return BuilderPresets.createMinimal(allocator);
}

/// Create a standard terminal (full featured)
pub fn createStandard(allocator: std.mem.Allocator) !BuiltTerminal {
    return BuilderPresets.createStandard(allocator);
}

/// Create a command terminal (with command execution)
pub fn createCommand(allocator: std.mem.Allocator) !BuiltTerminal {
    return BuilderPresets.createCommand(allocator);
}

/// Create a terminal from configuration file
pub fn createFromConfig(allocator: std.mem.Allocator, config_path: []const u8) !BuiltTerminal {
    return BuilderPresets.createFromConfig(allocator, config_path);
}

/// Validate a capability configuration
pub fn validateCapabilities(allocator: std.mem.Allocator, capabilities: []const CapabilityType) !ValidationResult {
    var validator = try ValidationSystem.init(allocator);
    defer validator.deinit();
    
    return validator.validateCapabilities(capabilities);
}

// Tests
pub const test_builders = @import("test_builders.zig");

// Version information
pub const VERSION = std.SemanticVersion{
    .major = 0,
    .minor = 1,
    .patch = 0,
};