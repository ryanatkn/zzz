const std = @import("std");
const testing = std.testing;
const kernel = @import("mod.zig");

// Mock implementations for testing

const MockTerminal = struct {
    output: std.ArrayList(u8),
    capabilities: std.StringHashMap(*anyopaque),
    event_bus: kernel.EventBus,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .output = std.ArrayList(u8).init(allocator),
            .capabilities = std.StringHashMap(*anyopaque).init(allocator),
            .event_bus = kernel.EventBus.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.output.deinit();
        self.capabilities.deinit();
    }

    pub fn write(self: *Self, text: []const u8) !void {
        try self.output.appendSlice(text);
    }

    pub fn read(self: *Self, buffer: []u8) !usize {
        _ = self;
        _ = buffer;
        return 0;
    }

    pub fn clear(self: *Self) void {
        self.output.clearRetainingCapacity();
    }

    pub fn resize(self: *Self, columns: usize, rows: usize) void {
        _ = self;
        _ = columns;
        _ = rows;
    }

    pub fn handleInput(self: *Self, input: kernel.InputEvent) !void {
        _ = input;
        const event = kernel.Event.init(.input, kernel.EventData{
            .input = kernel.events.InputEventData{
                .input_type = .keyboard,
                .key = .{ .text = "test" },
            },
        });
        try self.event_bus.emit(event);
    }

    pub fn hasCapability(self: *Self, capability: []const u8) bool {
        return self.capabilities.contains(capability);
    }

    pub fn getCapability(self: *Self, capability: []const u8) ?*anyopaque {
        return self.capabilities.get(capability);
    }

    pub fn emit(self: *Self, event: kernel.Event) !void {
        return self.event_bus.emit(event);
    }

    pub fn subscribe(self: *Self, event_type: kernel.EventType, callback: kernel.EventCallback) !void {
        return self.event_bus.subscribe(event_type, callback, null);
    }
};

pub const MockCapability = struct {
    name: []const u8,
    capability_type: []const u8,
    dependencies: []const []const u8,
    active: bool,
    initialized: bool,

    const Self = @This();

    pub fn create(
        name: []const u8,
        capability_type: []const u8,
        dependencies: []const []const u8,
    ) Self {
        return Self{
            .name = name,
            .capability_type = capability_type,
            .dependencies = dependencies,
            .active = false,
            .initialized = false,
        };
    }

    pub fn getName(self: *Self) []const u8 {
        return self.name;
    }

    pub fn getType(self: *Self) []const u8 {
        return self.capability_type;
    }

    pub fn getDependencies(self: *Self) []const []const u8 {
        return self.dependencies;
    }

    pub fn initialize(self: *Self, dependencies: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        _ = dependencies;
        _ = event_bus;
        self.initialized = true;
        self.active = true;
    }

    pub fn deinit(self: *Self) void {
        self.active = false;
        self.initialized = false;
    }

    pub fn isActive(self: *Self) bool {
        return self.active;
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

test "CapabilityRegistry - register and retrieve capabilities" {
    const allocator = testing.allocator;
    var registry = kernel.TypeSafeCapabilityRegistry.init(allocator);
    defer registry.deinit();

    // Create mock capabilities
    var mock_input = MockCapability.create("input", "input_capability", &[_][]const u8{});
    var mock_output = MockCapability.create("output", "output_capability", &[_][]const u8{});

    const input_cap = kernel.createCapability(&mock_input);
    const output_cap = kernel.createCapability(&mock_output);

    // Register capabilities
    try registry.register("input", input_cap);
    try registry.register("output", output_cap);

    // Verify registration
    try testing.expectEqual(@as(usize, 2), registry.getCapabilityCount());
    try testing.expect(registry.hasCapability("input"));
    try testing.expect(registry.hasCapability("output"));
    try testing.expect(!registry.hasCapability("nonexistent"));

    // Retrieve capabilities
    const retrieved_input = registry.getCapability("input");
    try testing.expect(retrieved_input != null);
}

test "CapabilityRegistry - dependency resolution" {
    const allocator = testing.allocator;
    var registry = kernel.TypeSafeCapabilityRegistry.init(allocator);
    defer registry.deinit();

    // Create capabilities with dependencies
    var mock_basic = MockCapability.create("basic", "basic_type", &[_][]const u8{});
    var mock_dependent = MockCapability.create("dependent", "dependent_type", &[_][]const u8{"basic"});

    const basic_cap = kernel.createCapability(&mock_basic);
    const dependent_cap = kernel.createCapability(&mock_dependent);

    // Register in reverse order to test dependency resolution
    try registry.register("dependent", dependent_cap);
    try registry.register("basic", basic_cap);

    // Initialize all capabilities
    try registry.initializeAll();

    // Both should be initialized
    try testing.expectEqual(@as(usize, 2), registry.getInitializedCount());
}

test "CapabilityRegistry - circular dependency detection" {
    const allocator = testing.allocator;
    var registry = kernel.TypeSafeCapabilityRegistry.init(allocator);
    defer registry.deinit();

    // Create capabilities with circular dependencies
    var mock_a = MockCapability.create("a", "type_a", &[_][]const u8{"b"});
    var mock_b = MockCapability.create("b", "type_b", &[_][]const u8{"a"});

    const cap_a = kernel.createCapability(&mock_a);
    const cap_b = kernel.createCapability(&mock_b);

    try registry.register("a", cap_a);
    try registry.register("b", cap_b);

    // Should detect circular dependency
    try testing.expectError(error.CircularDependency, registry.initializeAll());
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
    var registry = kernel.createRegistry(allocator);
    defer registry.deinit();
    try testing.expectEqual(@as(usize, 0), registry.getCapabilityCount());

    // Test event bus creation
    var event_bus = kernel.createEventBus(allocator);
    try testing.expectEqual(@as(usize, 0), event_bus.getSubscriptionCount());
}