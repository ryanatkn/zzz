const std = @import("std");
const testing = std.testing;

const terminal_builder = @import("terminal_builder.zig");
const capability_loader = @import("capability_loader.zig");
const configuration = @import("configuration.zig");
const validation = @import("validation.zig");
const builder_presets = @import("builder_presets.zig");
const KeyboardInput = @import("../capabilities/input/keyboard.zig").KeyboardInput;
const BasicWriter = @import("../capabilities/output/basic_writer.zig").BasicWriter;

const TerminalBuilder = terminal_builder.TerminalBuilder;
const CapabilityType = terminal_builder.CapabilityType;
const PresetType = terminal_builder.PresetType;
const CapabilityLoader = capability_loader.CapabilityLoader;
const ConfigurationSystem = configuration.ConfigurationSystem;
const ValidationSystem = validation.ValidationSystem;
const BuilderPresets = builder_presets.BuilderPresets;

test "TerminalBuilder: Basic construction" {
    var builder = TerminalBuilder.init(testing.allocator);
    defer builder.deinit();
    
    // Builder should start empty
    try testing.expect(builder.capabilities.len == 0);
    try testing.expect(builder.error_state == null);
}

test "TerminalBuilder: Add single capability" {
    var builder = TerminalBuilder.init(testing.allocator);
    defer builder.deinit();
    
    _ = builder.withCapability(.keyboard_input);
    
    try testing.expect(builder.capabilities.len == 1);
    try testing.expect(builder.capabilities.slice()[0] == .keyboard_input);
    try testing.expect(builder.error_state == null);
}

test "TerminalBuilder: Add multiple capabilities" {
    var builder = TerminalBuilder.init(testing.allocator);
    defer builder.deinit();
    
    const caps = &[_]CapabilityType{ .keyboard_input, .basic_writer, .cursor };
    _ = builder.withCapabilities(caps);
    
    try testing.expect(builder.capabilities.len == 3);
    try testing.expect(builder.capabilities.slice()[0] == .keyboard_input);
    try testing.expect(builder.capabilities.slice()[1] == .basic_writer);
    try testing.expect(builder.capabilities.slice()[2] == .cursor);
    try testing.expect(builder.error_state == null);
}

test "TerminalBuilder: Preset loading" {
    var builder = TerminalBuilder.init(testing.allocator);
    defer builder.deinit();
    
    _ = builder.withPreset(.minimal);
    
    try testing.expect(builder.capabilities.len == 4); // minimal has 4 capabilities
    try testing.expect(builder.error_state == null);
    
    // Check that minimal preset includes required capabilities
    var has_keyboard = false;
    var has_writer = false;
    var has_line_buffer = false;
    var has_cursor = false;
    
    for (builder.capabilities.slice()) |cap| {
        switch (cap) {
            .keyboard_input => has_keyboard = true,
            .basic_writer => has_writer = true,
            .line_buffer => has_line_buffer = true,
            .cursor => has_cursor = true,
            else => {},
        }
    }
    
    try testing.expect(has_keyboard);
    try testing.expect(has_writer);
    try testing.expect(has_line_buffer);
    try testing.expect(has_cursor);
}

test "TerminalBuilder: Build minimal terminal" {
    var builder = TerminalBuilder.init(testing.allocator);
    defer builder.deinit();
    
    var terminal = try builder
        .withPreset(.minimal)
        .build();
    defer terminal.deinit();
    
    try testing.expect(terminal.capability_count == 4);
    
    // Test that we can get capabilities
    const keyboard = terminal.getCapability(KeyboardInput);
    const writer = terminal.getCapability(BasicWriter);
    
    try testing.expect(keyboard != null);
    try testing.expect(writer != null);
}

test "TerminalBuilder: Build fails with no capabilities" {
    var builder = TerminalBuilder.init(testing.allocator);
    defer builder.deinit();
    
    const result = builder.build();
    try testing.expectError(error.NoCapabilities, result);
}

test "CapabilityLoader: Initialize and get metadata" {
    var loader = try CapabilityLoader.init(testing.allocator);
    defer loader.deinit();
    
    const keyboard_meta = loader.getMetadata(.keyboard_input);
    try testing.expect(keyboard_meta != null);
    try testing.expect(std.mem.eql(u8, keyboard_meta.?.name, "Keyboard Input"));
    try testing.expect(keyboard_meta.?.category == .input);
}

test "CapabilityLoader: Get capabilities by category" {
    var loader = try CapabilityLoader.init(testing.allocator);
    defer loader.deinit();
    
    var input_capabilities = std.ArrayList(CapabilityType).init(testing.allocator);
    defer input_capabilities.deinit();
    
    try loader.getCapabilitiesByCategory(.input, &input_capabilities);
    
    try testing.expect(input_capabilities.items.len >= 1); // At least keyboard_input
    
    var found_keyboard = false;
    for (input_capabilities.items) |cap| {
        if (cap == .keyboard_input) {
            found_keyboard = true;
            break;
        }
    }
    try testing.expect(found_keyboard);
}

test "CapabilityLoader: Dependency resolution" {
    var loader = try CapabilityLoader.init(testing.allocator);
    defer loader.deinit();
    
    var resolved = std.ArrayList(CapabilityType).init(testing.allocator);
    defer resolved.deinit();
    
    const requested = &[_]CapabilityType{.readline_input};
    try loader.resolveDependencies(requested, &resolved);
    
    // readline_input should depend on keyboard_input, cursor, line_buffer
    try testing.expect(resolved.items.len >= 4); // Dependencies + the capability itself
    
    var found_keyboard = false;
    var found_cursor = false;
    var found_line_buffer = false;
    var found_readline = false;
    
    for (resolved.items) |cap| {
        switch (cap) {
            .keyboard_input => found_keyboard = true,
            .cursor => found_cursor = true,
            .line_buffer => found_line_buffer = true,
            .readline_input => found_readline = true,
            else => {},
        }
    }
    
    try testing.expect(found_keyboard);
    try testing.expect(found_cursor);
    try testing.expect(found_line_buffer);
    try testing.expect(found_readline);
}

test "ConfigurationSystem: Create default config" {
    var config_system = ConfigurationSystem.init(testing.allocator);
    var config = config_system.defaultConfig();
    defer config.deinit(testing.allocator);
    
    try testing.expect(config.preset != null);
    try testing.expect(config.preset.? == .standard);
}

test "ConfigurationSystem: Load from environment" {
    var config_system = ConfigurationSystem.init(testing.allocator);
    
    // Test with no environment variables set
    var config = try config_system.loadFromEnvironment();
    defer config.deinit(testing.allocator);
    
    // Should not fail, may or may not have preset depending on env
    try testing.expect(true); // Config loaded successfully
}

test "ConfigurationSystem: Merge configurations" {
    var config_system = ConfigurationSystem.init(testing.allocator);
    
    var config1 = configuration.TerminalConfig.init(testing.allocator);
    config1.preset = .minimal;
    defer config1.deinit(testing.allocator);
    
    var config2 = configuration.TerminalConfig.init(testing.allocator);
    config2.preset = .standard;
    defer config2.deinit(testing.allocator);
    
    const configs = &[_]configuration.TerminalConfig{ config1, config2 };
    var merged = try config_system.mergeConfigs(configs);
    defer merged.deinit(testing.allocator);
    
    // Later config should override
    try testing.expect(merged.preset.? == .standard);
}

test "ValidationSystem: Validate valid configuration" {
    var validation_system = try ValidationSystem.init(testing.allocator);
    defer validation_system.deinit();
    
    const capabilities = &[_]CapabilityType{ .keyboard_input, .basic_writer, .cursor, .line_buffer };
    var result = try validation_system.validateCapabilities(capabilities);
    defer result.deinit();
    
    try testing.expect(result.is_valid);
    try testing.expect(result.errors.len == 0);
}

test "ValidationSystem: Detect missing dependencies" {
    var validation_system = try ValidationSystem.init(testing.allocator);
    defer validation_system.deinit();
    
    // readline_input requires dependencies that are missing
    const capabilities = &[_]CapabilityType{.readline_input};
    var result = try validation_system.validateCapabilities(capabilities);
    defer result.deinit();
    
    try testing.expect(!result.is_valid);
    try testing.expect(result.errors.len > 0);
    
    // Should have missing dependency errors
    var found_missing_dep = false;
    for (result.errors.slice()) |error_info| {
        if (error_info.error_type == .missing_dependency) {
            found_missing_dep = true;
            break;
        }
    }
    try testing.expect(found_missing_dep);
}

test "ValidationSystem: Get recommendations for use case" {
    var validation_system = try ValidationSystem.init(testing.allocator);
    defer validation_system.deinit();
    
    var recommended = std.ArrayList(CapabilityType).init(testing.allocator);
    defer recommended.deinit();
    
    try validation_system.getRecommendedCapabilities(.minimal_terminal, &recommended);
    
    try testing.expect(recommended.items.len > 0);
    
    // Should include basic capabilities for minimal terminal
    var has_keyboard = false;
    var has_writer = false;
    for (recommended.items) |cap| {
        switch (cap) {
            .keyboard_input => has_keyboard = true,
            .basic_writer => has_writer = true,
            else => {},
        }
    }
    try testing.expect(has_keyboard);
    try testing.expect(has_writer);
}

test "BuilderPresets: Create minimal terminal" {
    var terminal = try BuilderPresets.createMinimal(testing.allocator);
    defer terminal.deinit();
    
    try testing.expect(terminal.capability_count >= 4);
    
    // Should be able to write to terminal
    try terminal.write("Test message");
}

test "BuilderPresets: Create standard terminal" {
    var terminal = try BuilderPresets.createStandard(testing.allocator);
    defer terminal.deinit();
    
    try testing.expect(terminal.capability_count >= 8); // Standard has more capabilities
    
    // Should be able to write to terminal
    try terminal.write("Test standard terminal");
}

test "BuilderPresets: Create command terminal" {
    var terminal = try BuilderPresets.createCommand(testing.allocator);
    defer terminal.deinit();
    
    try testing.expect(terminal.capability_count >= 10); // Command has most capabilities
    
    // Should be able to write to terminal
    try terminal.write("Test command terminal");
}

test "BuilderPresets: Create interactive terminal" {
    var terminal = try BuilderPresets.createInteractive(testing.allocator);
    defer terminal.deinit();
    
    try testing.expect(terminal.capability_count >= 7); // Interactive has specific capability set
    
    // Should be able to write to terminal
    try terminal.write("Test interactive terminal");
}

test "Builder integration: Full workflow" {
    // Test complete workflow: validation -> building -> usage
    var validation_system = try ValidationSystem.init(testing.allocator);
    defer validation_system.deinit();
    
    // Define desired capabilities
    const capabilities = &[_]CapabilityType{
        .keyboard_input,
        .basic_writer,
        .cursor,
        .line_buffer,
        .history,
    };
    
    // Validate the configuration
    var validation_result = try validation_system.validateCapabilities(capabilities);
    defer validation_result.deinit();
    
    try testing.expect(validation_result.is_valid);
    
    // Build terminal with validated capabilities
    var builder = TerminalBuilder.init(testing.allocator);
    defer builder.deinit();
    
    var terminal = try builder
        .withCapabilities(capabilities)
        .build();
    defer terminal.deinit();
    
    // Use the terminal
    try terminal.write("Integration test successful!");
    
    try testing.expect(terminal.capability_count == capabilities.len);
}

test "Builder fluent API: Method chaining" {
    var builder = TerminalBuilder.init(testing.allocator);
    defer builder.deinit();
    
    // Test method chaining syntax
    var terminal = try builder
        .withCapability(.keyboard_input)
        .withCapability(.basic_writer)
        .withCapability(.cursor)
        .withCapability(.line_buffer)
        .build();
    defer terminal.deinit();
    
    try testing.expect(terminal.capability_count == 4);
}

test "Builder error handling: Capacity exceeded" {
    var builder = TerminalBuilder.init(testing.allocator);
    defer builder.deinit();
    
    // Fill the builder beyond its capacity to trigger error state
    var i: u32 = 0;
    while (i < 35) : (i += 1) { // More than BoundedArray capacity of 32
        _ = builder.withCapability(.keyboard_input);
    }
    
    // Should have error state set
    try testing.expect(builder.error_state != null);
    try testing.expect(builder.error_state.? == error.Overflow);
    
    // Build should return the accumulated error
    const result = builder.build();
    try testing.expectError(error.Overflow, result);
}

test "Builder error handling: Error propagation through chain" {
    var builder = TerminalBuilder.init(testing.allocator);
    defer builder.deinit();
    
    // Create a long chain that will trigger capacity error
    _ = builder
        .withCapability(.keyboard_input)
        .withCapability(.basic_writer)
        .withCapability(.cursor);
    
    // Fill beyond capacity in the middle of more operations
    var i: u32 = 0;
    while (i < 35) : (i += 1) {
        _ = builder.withCapability(.line_buffer);
    }
    
    // Continue chaining after error - should be ignored
    _ = builder
        .withCapability(.history)
        .withCapability(.scrollback);
    
    // Build should fail with original error
    const result = builder.build();
    try testing.expectError(error.Overflow, result);
}

// Test runner for all builder tests
pub fn runAllTests() !void {
    const tests = .{
        @This().@"test.TerminalBuilder: Basic construction",
        @This().@"test.TerminalBuilder: Add single capability",
        @This().@"test.TerminalBuilder: Add multiple capabilities",
        @This().@"test.TerminalBuilder: Preset loading",
        @This().@"test.TerminalBuilder: Build minimal terminal",
        @This().@"test.TerminalBuilder: Build fails with no capabilities",
        @This().@"test.CapabilityLoader: Initialize and get metadata",
        @This().@"test.CapabilityLoader: Get capabilities by category",
        @This().@"test.CapabilityLoader: Dependency resolution",
        @This().@"test.ConfigurationSystem: Create default config",
        @This().@"test.ConfigurationSystem: Load from environment",
        @This().@"test.ConfigurationSystem: Merge configurations",
        @This().@"test.ValidationSystem: Validate valid configuration",
        @This().@"test.ValidationSystem: Detect missing dependencies",
        @This().@"test.ValidationSystem: Get recommendations for use case",
        @This().@"test.BuilderPresets: Create minimal terminal",
        @This().@"test.BuilderPresets: Create standard terminal",
        @This().@"test.BuilderPresets: Create command terminal",
        @This().@"test.BuilderPresets: Create interactive terminal",
        @This().@"test.Builder integration: Full workflow",
        @This().@"test.Builder fluent API: Method chaining",
        @This().@"test.Builder error handling: Capacity exceeded",
        @This().@"test.Builder error handling: Error propagation through chain",
    };
    
    inline for (tests) |test_fn| {
        try test_fn();
    }
}