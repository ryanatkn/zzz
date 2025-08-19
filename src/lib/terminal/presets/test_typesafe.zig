const std = @import("std");
const kernel = @import("../kernel/mod.zig");
const KeyboardInput = @import("../capabilities/input/keyboard.zig").KeyboardInput;
const BasicWriter = @import("../capabilities/output/basic_writer.zig").BasicWriter;
const LineBuffer = @import("../capabilities/state/line_buffer.zig").LineBuffer;
const Cursor = @import("../capabilities/state/cursor.zig").Cursor;

/// Test preset for validating TypeSafeCapabilityRegistry functionality
/// This serves as a proof-of-concept for the new type-safe system
pub const TestTypeSafeTerminal = struct {
    allocator: std.mem.Allocator,
    registry: kernel.TypeSafeCapabilityRegistry,
    
    // Capabilities stored as pointers to heap-allocated instances
    keyboard: *KeyboardInput,
    writer: *BasicWriter,
    line_buffer: *LineBuffer,
    cursor: *Cursor,
    
    // Terminal interface implementation
    event_bus: *kernel.EventBus,
    
    const Self = @This();

    /// Initialize test terminal with type-safe capabilities
    pub fn init(allocator: std.mem.Allocator) !Self {
        var registry = kernel.TypeSafeCapabilityRegistry.init(allocator);
        
        // Create capabilities using factory methods
        const keyboard = try KeyboardInput.create(allocator);
        errdefer keyboard.destroy(allocator);
        
        const writer = try BasicWriter.create(allocator);
        errdefer writer.destroy(allocator);
        
        const line_buffer = try LineBuffer.create(allocator);
        errdefer line_buffer.destroy(allocator);
        
        const cursor = try Cursor.create(allocator);
        errdefer cursor.destroy(allocator);
        
        // Create type-safe capability interfaces and register them
        const keyboard_cap = kernel.createTypeSafeCapability(keyboard);
        const writer_cap = kernel.createTypeSafeCapability(writer);
        const line_buffer_cap = kernel.createTypeSafeCapability(line_buffer);
        const cursor_cap = kernel.createTypeSafeCapability(cursor);
        
        try registry.register("keyboard_input", keyboard_cap);
        try registry.register("basic_writer", writer_cap);
        try registry.register("line_buffer", line_buffer_cap);
        try registry.register("cursor", cursor_cap);
        
        // Initialize all capabilities in dependency order
        try registry.initializeAll();
        
        return Self{
            .allocator = allocator,
            .registry = registry,
            .keyboard = keyboard,
            .writer = writer,
            .line_buffer = line_buffer,
            .cursor = cursor,
            .event_bus = registry.getEventBus(),
        };
    }

    /// Cleanup test terminal
    pub fn deinit(self: *Self) void {
        // Registry deinit will call capability deinit methods
        self.registry.deinit();
        
        // Just free the memory, don't call deinit again (registry already did)
        self.allocator.destroy(self.keyboard);
        self.allocator.destroy(self.writer);
        self.allocator.destroy(self.line_buffer);
        self.allocator.destroy(self.cursor);
    }

    /// Handle keyboard input - main entry point for terminal interaction
    pub fn handleKey(self: *Self, key: kernel.Key) !void {
        try self.keyboard.handleKey(key);
    }

    /// Write text to terminal output
    pub fn write(self: *Self, text: []const u8) !void {
        try self.writer.write(text);
    }

    /// Update terminal state (cursor blink, etc.)
    pub fn update(self: *Self, dt: f32) !void {
        try self.cursor.updateBlink(dt);
    }

    /// Get current input line content
    pub fn getCurrentLine(self: *const Self) []const u8 {
        return self.line_buffer.getCurrentLine();
    }

    /// Get cursor position
    pub fn getCursorPosition(self: *const Self) struct { x: usize, y: usize } {
        return .{ .x = self.cursor.getColumn(), .y = self.cursor.getRow() };
    }

    /// Check if cursor is visible
    pub fn isCursorVisible(self: *const Self) bool {
        return self.cursor.isVisible();
    }

    /// Get capability by name using type-safe casting
    pub fn getCapability(self: *Self, comptime T: type, name: []const u8) ?*T {
        const capability = self.registry.getCapability(name) orelse return null;
        return capability.cast(T);
    }

    /// Require capability with type-safe access (panics if not found)
    pub fn requireCapability(self: *Self, comptime T: type) *T {
        return self.registry.requireCapability(T);
    }

    /// Demonstrate type-safe capability resolution
    pub fn demonstrateTypeSafety(self: *Self) !void {
        // This should work - correct type
        const keyboard_ptr = self.getCapability(KeyboardInput, "keyboard_input");
        try std.testing.expect(keyboard_ptr != null);
        
        // This should return null - wrong type
        const wrong_type = self.getCapability(BasicWriter, "keyboard_input");
        try std.testing.expect(wrong_type == null);
        
        // This should work - typed access
        const typed_keyboard = self.registry.getCapabilityTyped(KeyboardInput);
        try std.testing.expect(typed_keyboard != null);
    }
};

// Tests
test "TestTypeSafeTerminal initialization" {
    const allocator = std.testing.allocator;
    var terminal = try TestTypeSafeTerminal.init(allocator);
    defer terminal.deinit();
    
    // Verify all capabilities are registered
    try std.testing.expect(terminal.registry.getCapabilityCount() == 4);
    try std.testing.expect(terminal.registry.getInitializedCount() == 4);
    
    // Test capability existence
    try std.testing.expect(terminal.registry.hasCapability("keyboard_input"));
    try std.testing.expect(terminal.registry.hasCapability("basic_writer"));
    try std.testing.expect(terminal.registry.hasCapability("line_buffer"));
    try std.testing.expect(terminal.registry.hasCapability("cursor"));
}

test "TestTypeSafeTerminal type-safe operations" {
    const allocator = std.testing.allocator;
    var terminal = try TestTypeSafeTerminal.init(allocator);
    defer terminal.deinit();
    
    // Test type-safe capability access
    const keyboard = terminal.getCapability(KeyboardInput, "keyboard_input");
    try std.testing.expect(keyboard != null);
    
    // Test wrong type returns null
    const wrong_type = terminal.getCapability(BasicWriter, "keyboard_input");
    try std.testing.expect(wrong_type == null);
    
    // Test typed capability access
    const typed_keyboard = terminal.registry.getCapabilityTyped(KeyboardInput);
    try std.testing.expect(typed_keyboard != null);
}

test "TestTypeSafeTerminal basic operations" {
    const allocator = std.testing.allocator;
    var terminal = try TestTypeSafeTerminal.init(allocator);
    defer terminal.deinit();
    
    // Test basic terminal operations work
    try terminal.write("test output\n");
    try terminal.update(0.1);
    
    // Test cursor operations
    try std.testing.expect(terminal.isCursorVisible());
    const pos = terminal.getCursorPosition();
    try std.testing.expect(pos.x == 0);
    try std.testing.expect(pos.y == 0);
    
    // Test line buffer
    const line = terminal.getCurrentLine();
    try std.testing.expect(line.len == 0); // Should be empty initially
}

test "TestTypeSafeTerminal type safety demonstration" {
    const allocator = std.testing.allocator;
    var terminal = try TestTypeSafeTerminal.init(allocator);
    defer terminal.deinit();
    
    // This should pass - demonstrates type safety works
    try terminal.demonstrateTypeSafety();
}