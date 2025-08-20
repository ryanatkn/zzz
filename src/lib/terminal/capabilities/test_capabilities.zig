const std = @import("std");
const testing = std.testing;
const kernel = @import("../kernel/mod.zig");
const KeyboardInput = @import("input/keyboard.zig").KeyboardInput;
const BasicWriter = @import("output/basic_writer.zig").BasicWriter;
const LineBuffer = @import("state/line_buffer.zig").LineBuffer;
const Cursor = @import("state/cursor.zig").Cursor;
const MinimalTerminal = @import("../presets/minimal.zig").MinimalTerminal;

// Test event callback globals for testing
var test_event_received: bool = false;
var test_event_type: kernel.EventType = .input;
var test_event_data: []const u8 = "";

fn testEventCallback(event: kernel.Event, context: ?*anyopaque) !void {
    _ = context;
    test_event_received = true;
    test_event_type = event.type;

    switch (event.data) {
        .input => |input_data| {
            switch (input_data.key) {
                .char => |ch| {
                    test_event_data = &[_]u8{ch};
                },
                .special => |special| {
                    test_event_data = @tagName(special);
                },
                .text => |text| {
                    test_event_data = text;
                },
            }
        },
        .command_execute => |cmd_data| {
            test_event_data = cmd_data.command;
        },
        else => {
            test_event_data = "other_event";
        },
    }
}

test "KeyboardInput - emit character events" {
    const allocator = testing.allocator;
    var keyboard = KeyboardInput{};
    var event_bus = kernel.createEventBus(allocator);

    // Reset test globals
    test_event_received = false;

    // Subscribe to input events
    try event_bus.subscribe(.input, testEventCallback, null);

    // Initialize keyboard capability
    try keyboard.initialize(&[_]kernel.TypeSafeCapability{}, &event_bus);
    defer keyboard.deinit();

    // Handle character input
    try keyboard.handleKey(.{ .char = 'a' });

    // Verify event was emitted
    try testing.expect(test_event_received);
    try testing.expectEqual(kernel.EventType.input, test_event_type);
    try testing.expectEqual(@as(u8, 'a'), test_event_data[0]);
}

test "KeyboardInput - emit enter input event" {
    const allocator = testing.allocator;
    var keyboard = KeyboardInput{};
    var event_bus = kernel.createEventBus(allocator);

    // Reset test globals
    test_event_received = false;

    // Subscribe to input events
    try event_bus.subscribe(.input, testEventCallback, null);

    // Initialize keyboard capability
    try keyboard.initialize(&[_]kernel.TypeSafeCapability{}, &event_bus);
    defer keyboard.deinit();

    // Handle enter key
    try keyboard.handleKey(.enter);

    // Verify input event was emitted
    try testing.expect(test_event_received);
    try testing.expectEqual(kernel.EventType.input, test_event_type);
    try testing.expectEqualStrings("enter", test_event_data);
}

test "BasicWriter - write text to scrollback" {
    const allocator = testing.allocator;
    var writer = BasicWriter.init(allocator);
    var event_bus = kernel.createEventBus(allocator);

    // Initialize writer capability
    try writer.initialize(&[_]kernel.TypeSafeCapability{}, &event_bus);
    defer writer.deinit();

    // Write text
    try writer.write("Hello, World!");

    // Verify text was added to scrollback
    const scrollback = writer.getScrollback();
    try testing.expect(scrollback.count() > 0);
}

test "BasicWriter - clear scrollback" {
    const allocator = testing.allocator;
    var writer = BasicWriter.init(allocator);
    var event_bus = kernel.createEventBus(allocator);

    // Initialize writer capability
    try writer.initialize(&[_]kernel.TypeSafeCapability{}, &event_bus);
    defer writer.deinit();

    // Write some text
    try writer.write("Test text");

    // Verify text was added
    var scrollback = writer.getScrollback();
    try testing.expect(scrollback.count() > 0);

    // Clear and verify
    try writer.clear();
    scrollback = writer.getScrollback();
    try testing.expectEqual(@as(usize, 0), scrollback.count());
}

test "LineBuffer - character insertion and deletion" {
    const allocator = testing.allocator;
    var line_buffer = LineBuffer.init(allocator);
    var event_bus = kernel.createEventBus(allocator);

    // Initialize line buffer capability
    try line_buffer.initialize(&[_]kernel.TypeSafeCapability{}, &event_bus);
    defer line_buffer.deinit();

    // Simulate character input events
    const char_event = kernel.Event.init(.input, kernel.EventData{
        .input = kernel.events.InputEventData{
            .input_type = .keyboard,
            .key = .{ .char = 'a' },
        },
    });
    try event_bus.emit(char_event);

    // Check line content
    try testing.expectEqualStrings("a", line_buffer.getCurrentLine());
    try testing.expectEqual(@as(usize, 1), line_buffer.getCursorPosition());

    // Simulate backspace
    const backspace_event = kernel.Event.init(.input, kernel.EventData{
        .input = kernel.events.InputEventData{
            .input_type = .keyboard,
            .key = .{ .special = .backspace },
        },
    });
    try event_bus.emit(backspace_event);

    // Check line was cleared
    try testing.expectEqualStrings("", line_buffer.getCurrentLine());
    try testing.expectEqual(@as(usize, 0), line_buffer.getCursorPosition());
}

test "LineBuffer - command execution" {
    const allocator = testing.allocator;
    var line_buffer = LineBuffer.init(allocator);
    var event_bus = kernel.createEventBus(allocator);

    // Reset test globals
    test_event_received = false;

    // Subscribe to command execute events
    try event_bus.subscribe(.command_execute, testEventCallback, null);

    // Initialize line buffer capability
    try line_buffer.initialize(&[_]kernel.TypeSafeCapability{}, &event_bus);
    defer line_buffer.deinit();

    // Add some text
    const char_event1 = kernel.Event.init(.input, kernel.EventData{
        .input = kernel.events.InputEventData{
            .input_type = .keyboard,
            .key = .{ .char = 'l' },
        },
    });
    try event_bus.emit(char_event1);

    const char_event2 = kernel.Event.init(.input, kernel.EventData{
        .input = kernel.events.InputEventData{
            .input_type = .keyboard,
            .key = .{ .char = 's' },
        },
    });
    try event_bus.emit(char_event2);

    // Trigger enter
    const enter_event = kernel.Event.init(.input, kernel.EventData{
        .input = kernel.events.InputEventData{
            .input_type = .keyboard,
            .key = .{ .special = .enter },
        },
    });
    try event_bus.emit(enter_event);

    // Verify command was executed
    try testing.expect(test_event_received);
    try testing.expectEqualStrings("ls", test_event_data);

    // Verify line was cleared
    try testing.expectEqualStrings("", line_buffer.getCurrentLine());
    try testing.expectEqual(@as(usize, 0), line_buffer.getCursorPosition());
}

test "Cursor - position and visibility" {
    const allocator = testing.allocator;
    var cursor = Cursor.init();
    var event_bus = kernel.createEventBus(allocator);

    // Initialize cursor capability
    try cursor.initialize(&[_]kernel.TypeSafeCapability{}, &event_bus);
    defer cursor.deinit();

    // Test initial position
    var pos = cursor.getPosition();
    try testing.expectEqual(@as(usize, 0), pos.x);
    try testing.expectEqual(@as(usize, 0), pos.y);
    try testing.expect(cursor.isVisible());

    // Test position setting
    try cursor.setPosition(5, 10);
    pos = cursor.getPosition();
    try testing.expectEqual(@as(usize, 5), pos.x);
    try testing.expectEqual(@as(usize, 10), pos.y);

    // Test hiding
    try cursor.hide();
    try testing.expect(!cursor.isVisible());

    // Test showing
    try cursor.show();
    try testing.expect(cursor.isVisible());
}

test "Cursor - dimension bounds checking" {
    const allocator = testing.allocator;
    var cursor = Cursor.init();
    var event_bus = kernel.createEventBus(allocator);

    // Initialize cursor capability
    try cursor.initialize(&[_]kernel.TypeSafeCapability{}, &event_bus);
    defer cursor.deinit();

    // Set smaller dimensions
    try cursor.setDimensions(10, 5);

    // Try to set position beyond bounds
    try cursor.setPosition(15, 10);

    // Verify position was bounded
    const pos = cursor.getPosition();
    try testing.expectEqual(@as(usize, 9), pos.x); // 10 - 1
    try testing.expectEqual(@as(usize, 4), pos.y); // 5 - 1
}

test "MinimalTerminal - end-to-end functionality" {
    const allocator = testing.allocator;
    var terminal = try MinimalTerminal.init(allocator);
    defer terminal.deinit();

    // Reset test globals
    test_event_received = false;

    // Subscribe to command execution
    try terminal.subscribeToCommands(testEventCallback, null);

    // Type a command
    try terminal.handleKey(.{ .char = 'l' });
    try terminal.handleKey(.{ .char = 's' });

    // Verify line buffer state
    try testing.expectEqualStrings("ls", terminal.getCurrentLine());

    // Execute command
    try terminal.handleKey(.enter);

    // Verify command was executed
    try testing.expect(test_event_received);
    try testing.expectEqualStrings("ls", test_event_data);

    // Verify line was cleared
    try testing.expectEqualStrings("", terminal.getCurrentLine());
}

test "MinimalTerminal - basic I/O operations" {
    const allocator = testing.allocator;
    var terminal = try MinimalTerminal.init(allocator);
    defer terminal.deinit();

    // Write some output
    try terminal.write("Hello from terminal!");

    // Verify output was added to scrollback
    const scrollback = terminal.getScrollback();
    try testing.expect(scrollback.count() > 0);

    // Test clear
    try terminal.clear();
    try testing.expectEqual(@as(usize, 0), scrollback.count());

    // Test resize
    try terminal.resize(100, 50);

    // Verify cursor respects new bounds
    const pos = terminal.getCursorPosition();
    try testing.expect(pos.x < 100);
    try testing.expect(pos.y < 50);
}

test "Capability Integration - event flow" {
    const allocator = testing.allocator;
    var registry = kernel.createRegistry(allocator);
    defer registry.deinit();

    // Create all capabilities
    var keyboard = KeyboardInput{};
    var writer = BasicWriter.init(allocator);
    var line_buffer = LineBuffer.init(allocator);
    var cursor = Cursor.init();

    // Register capabilities
    const keyboard_cap = kernel.createCapability(&keyboard);
    const writer_cap = kernel.createCapability(&writer);
    const line_buffer_cap = kernel.createCapability(&line_buffer);
    const cursor_cap = kernel.createCapability(&cursor);

    try registry.register("keyboard_input", keyboard_cap);
    try registry.register("basic_writer", writer_cap);
    try registry.register("line_buffer", line_buffer_cap);
    try registry.register("cursor", cursor_cap);

    // Initialize all capabilities
    try registry.initializeAll();

    // Verify all capabilities are initialized
    try testing.expectEqual(@as(usize, 4), registry.getInitializedCount());
    try testing.expect(keyboard.isActive());
    try testing.expect(writer.isActive());
    try testing.expect(line_buffer.isActive());
    try testing.expect(cursor.isActive());
}
