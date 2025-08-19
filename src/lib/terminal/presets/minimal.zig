const std = @import("std");
const kernel = @import("../kernel/mod.zig");
const KeyboardInput = @import("../capabilities/input/keyboard.zig").KeyboardInput;
const BasicWriter = @import("../capabilities/output/basic_writer.zig").BasicWriter;
const LineBuffer = @import("../capabilities/state/line_buffer.zig").LineBuffer;
const Cursor = @import("../capabilities/state/cursor.zig").Cursor;

/// Minimal terminal preset - basic input/output with line editing
pub const MinimalTerminal = struct {
    allocator: std.mem.Allocator,
    registry: kernel.CapabilityRegistry,
    
    // Capabilities stored as pointers to heap-allocated instances
    keyboard: *KeyboardInput,
    writer: *BasicWriter,
    line_buffer: *LineBuffer,
    cursor: *Cursor,
    
    // Terminal interface implementation
    event_bus: *kernel.EventBus,
    
    const Self = @This();

    /// Initialize minimal terminal with all capabilities
    pub fn init(allocator: std.mem.Allocator) !Self {
        var registry = kernel.createRegistry(allocator);
        
        // Allocate capabilities on heap
        const keyboard = try allocator.create(KeyboardInput);
        keyboard.* = KeyboardInput{};
        
        const writer = try allocator.create(BasicWriter);
        writer.* = BasicWriter.init(allocator);
        
        const line_buffer = try allocator.create(LineBuffer);
        line_buffer.* = LineBuffer.init(allocator);
        
        const cursor = try allocator.create(Cursor);
        cursor.* = Cursor.init();
        
        // Create capability interfaces and register them
        const keyboard_cap = kernel.createCapability(keyboard);
        const writer_cap = kernel.createCapability(writer);
        const line_buffer_cap = kernel.createCapability(line_buffer);
        const cursor_cap = kernel.createCapability(cursor);
        
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

    /// Cleanup minimal terminal
    pub fn deinit(self: *Self) void {
        // Registry deinit will call capability deinit methods
        self.registry.deinit();
        
        // Free allocated memory for capabilities
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

    /// Update cursor animation (should be called regularly)
    pub fn update(self: *Self, dt: f32) !void {
        try self.cursor.update(dt);
    }

    /// Get current input line content
    pub fn getCurrentLine(self: *const Self) []const u8 {
        return self.line_buffer.getCurrentLine();
    }

    /// Get cursor position
    pub fn getCursorPosition(self: *const Self) struct { x: usize, y: usize } {
        const pos = self.cursor.getPosition();
        return .{ .x = pos.x, .y = pos.y };
    }

    /// Check if cursor is visible
    pub fn isCursorVisible(self: *const Self) bool {
        return self.cursor.isVisible();
    }

    /// Get scrollback for rendering
    pub fn getScrollback(self: *const Self) *const @import("../core.zig").RingBuffer(@import("../core.zig").Line, 1000) {
        return self.writer.getScrollback();
    }

    /// Clear terminal output
    pub fn clear(self: *Self) !void {
        try self.writer.clear();
    }

    /// Set terminal dimensions
    pub fn resize(self: *Self, columns: usize, rows: usize) !void {
        // Emit resize event that cursor will pick up
        const event = kernel.Event.init(.resize, kernel.EventData{
            .resize = kernel.events.ResizeEventData{
                .old_columns = 80, // Default previous size
                .old_rows = 24,
                .new_columns = columns,
                .new_rows = rows,
            },
        });
        try self.event_bus.emit(event);
    }

    /// Subscribe to command execution events
    pub fn subscribeToCommands(self: *Self, callback: kernel.EventCallback, context: ?*anyopaque) !void {
        try self.event_bus.subscribe(.command_execute, callback, context);
    }

    /// Get event bus for external integration
    pub fn getEventBus(self: *Self) *kernel.EventBus {
        return self.event_bus;
    }
};