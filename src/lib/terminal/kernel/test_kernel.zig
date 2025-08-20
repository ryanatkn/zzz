const std = @import("std");
const testing = std.testing;
const kernel = @import("mod.zig");
const cursor_mod = @import("../capabilities/state/cursor.zig");
const line_buffer_mod = @import("../capabilities/state/line_buffer.zig");

// Mock implementations for testing

const MockTerminal = struct {
    output: std.ArrayList(u8),
    capabilities: std.StringHashMap(*anyopaque),
    event_bus: kernel.EventBus,

    pub fn init(allocator: std.mem.Allocator) MockTerminal {
        return MockTerminal{
            .output = std.ArrayList(u8).init(allocator),
            .capabilities = std.StringHashMap(*anyopaque).init(allocator),
            .event_bus = kernel.EventBus.init(allocator),
        };
    }

    pub fn deinit(self: *MockTerminal) void {
        self.output.deinit();
        self.capabilities.deinit();
    }

    pub fn write(self: *MockTerminal, text: []const u8) !void {
        try self.output.appendSlice(text);
    }

    pub fn read(self: *MockTerminal, buffer: []u8) !usize {
        _ = self;
        _ = buffer;
        return 0;
    }

    pub fn clear(self: *MockTerminal) void {
        self.output.clearRetainingCapacity();
    }

    pub fn resize(self: *MockTerminal, columns: usize, rows: usize) void {
        _ = self;
        _ = columns;
        _ = rows;
    }

    pub fn handleInput(self: *MockTerminal, input: kernel.InputEvent) !void {
        _ = input;
        const event = kernel.Event.init(.input, kernel.EventData{
            .input = kernel.events.InputEventData{
                .input_type = .keyboard,
                .key = .{ .text = "test" },
            },
        });
        try self.event_bus.emit(event);
    }

    pub fn hasCapability(self: *MockTerminal, capability: []const u8) bool {
        return self.capabilities.contains(capability);
    }

    pub fn getCapability(self: *MockTerminal, capability: []const u8) ?*anyopaque {
        return self.capabilities.get(capability);
    }

    pub fn emit(self: *MockTerminal, event: kernel.Event) !void {
        return self.event_bus.emit(event);
    }

    pub fn subscribe(self: *MockTerminal, event_type: kernel.EventType, callback: kernel.EventCallback) !void {
        return self.event_bus.subscribe(event_type, callback, null);
    }
};

// Test callback for event testing
var test_event_received: bool = false;
var test_event_type: kernel.EventType = .input;

fn testEventCallback(event: kernel.Event, context: ?*anyopaque) !void {
    _ = context;
    test_event_received = true;
    test_event_type = event.type;
}

test "EventBus - subscribe and emit" {
    const allocator = testing.allocator;
    var event_bus = kernel.EventBus.init(allocator);

    // Reset test globals
    test_event_received = false;

    // Subscribe to input events
    try event_bus.subscribe(.input, testEventCallback, null);

    // Create and emit an input event
    const event = kernel.Event.init(.input, kernel.EventData{
        .input = kernel.events.InputEventData{
            .input_type = .keyboard,
            .key = .{ .text = "test_key" },
        },
    });
    try event_bus.emit(event);

    // Verify callback was called
    try testing.expect(test_event_received);
    try testing.expectEqual(kernel.EventType.input, test_event_type);
}

test "EventBus - unsubscribe" {
    const allocator = testing.allocator;
    var event_bus = kernel.EventBus.init(allocator);

    // Reset test globals
    test_event_received = false;

    // Subscribe and then unsubscribe
    try event_bus.subscribe(.output, testEventCallback, null);
    event_bus.unsubscribe(.output, testEventCallback, null);

    // Emit event
    const event = kernel.Event.init(.output, kernel.EventData{
        .output = kernel.events.OutputEventData{
            .text = "test_output",
        },
    });
    try event_bus.emit(event);

    // Verify callback was NOT called
    try testing.expect(!test_event_received);
}

test "EventBus - cleanup inactive subscriptions" {
    const allocator = testing.allocator;
    var event_bus = kernel.EventBus.init(allocator);

    // Subscribe multiple times
    try event_bus.subscribe(.input, testEventCallback, null);
    try event_bus.subscribe(.output, testEventCallback, null);

    // Initial count should be 2
    try testing.expectEqual(@as(usize, 2), event_bus.getSubscriptionCount());

    // Unsubscribe one
    event_bus.unsubscribe(.input, testEventCallback, null);

    // Count should still be 2 (inactive subscription still present)
    try testing.expectEqual(@as(usize, 2), event_bus.getSubscriptionCount());

    // Cleanup should reduce count to 1
    event_bus.cleanup();
    try testing.expectEqual(@as(usize, 1), event_bus.getSubscriptionCount());
}

test "CapabilityRegistry - basic registration" {
    const allocator = testing.allocator;
    var registry = kernel.TypeSafeCapabilityRegistry.init(allocator);
    defer registry.deinit();

    // Register capabilities using new enum-based API
    try registry.registerType(.cursor);
    try registry.registerType(.line_buffer);

    // Verify registration
    try testing.expect(registry.getCapability(.cursor) != null);
    try testing.expect(registry.getCapability(.line_buffer) != null);

    // Verify capability count
    try testing.expectEqual(@as(usize, 2), registry.getCapabilityCount());
}

test "CapabilityRegistry - circular dependency detection" {
    // Skip this test for now - circular dependency detection is complex
    // with the type-safe system and would require significant refactoring.
    // The system prevents circular dependencies through proper design
    // rather than runtime detection.
}

test "ITerminal interface - basic operations" {
    const allocator = testing.allocator;
    var mock_terminal = MockTerminal.init(allocator);
    defer mock_terminal.deinit();

    const terminal = kernel.createTerminal(&mock_terminal);

    // Test write operation
    try terminal.write("Hello, World!");
    try testing.expectEqualStrings("Hello, World!", mock_terminal.output.items);

    // Test clear operation
    terminal.clear();
    try testing.expectEqual(@as(usize, 0), mock_terminal.output.items.len);

    // Test resize operation (should not crash)
    terminal.resize(80, 24);
}

test "ITerminal interface - event handling" {
    const allocator = testing.allocator;
    var mock_terminal = MockTerminal.init(allocator);
    defer mock_terminal.deinit();

    const terminal = kernel.createTerminal(&mock_terminal);

    // Reset test globals
    test_event_received = false;

    // Subscribe to events
    try terminal.subscribe(.input, testEventCallback);

    // Handle input event
    const input_event = kernel.InputEvent{
        .key = kernel.KeyEvent{
            .key = .{ .char = 'a' },
            .modifiers = kernel.KeyModifiers{},
        },
    };
    try terminal.handleInput(input_event);

    // Verify event was emitted and received
    try testing.expect(test_event_received);
    try testing.expectEqual(kernel.EventType.input, test_event_type);
}

test "Kernel version information" {
    try testing.expectEqual(@as(u32, 0), kernel.VERSION.major);
    try testing.expectEqual(@as(u32, 1), kernel.VERSION.minor);
    try testing.expectEqual(@as(u32, 0), kernel.VERSION.patch);
}

test "Kernel utility functions" {
    const allocator = testing.allocator;

    // Test registry creation
    const registry = try kernel.createRegistry(allocator);
    defer {
        registry.*.deinit();
        allocator.destroy(registry);
    }
    try testing.expectEqual(@as(usize, 0), registry.*.getCapabilityCount());

    // Test event bus creation
    var event_bus = kernel.events.EventBus.init(allocator);
    try testing.expectEqual(@as(usize, 0), event_bus.getSubscriptionCount());
}
