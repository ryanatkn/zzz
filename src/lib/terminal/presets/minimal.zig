const std = @import("std");
const kernel = @import("../kernel/mod.zig");
const KeyboardInput = @import("../capabilities/input/keyboard.zig").KeyboardInput;
const BasicWriter = @import("../capabilities/output/basic_writer.zig").BasicWriter;
const LineBuffer = @import("../capabilities/state/line_buffer.zig").LineBuffer;
const Cursor = @import("../capabilities/state/cursor.zig").Cursor;
const core = @import("../core.zig");

/// Minimal terminal preset - basic input/output with line editing
pub const MinimalTerminal = struct {
    allocator: std.mem.Allocator,
    registry: *kernel.TypeSafeCapabilityRegistry,

    // Capabilities stored as pointers to heap-allocated instances
    keyboard: *KeyboardInput,
    writer: *BasicWriter,
    line_buffer: *LineBuffer,
    cursor: *Cursor,

    // Terminal interface implementation
    event_bus: *kernel.EventBus,

    /// Initialize minimal terminal with all capabilities
    pub fn init(allocator: std.mem.Allocator) !MinimalTerminal {
        var registry = try kernel.createRegistry(allocator);

        // Register capabilities using new enum-based API
        try registry.registerType(.keyboard_input);
        try registry.registerType(.basic_writer);
        try registry.registerType(.line_buffer);
        try registry.registerType(.cursor);

        // Initialize all capabilities in dependency order
        try registry.initializeAll();

        return MinimalTerminal{
            .allocator = allocator,
            .registry = registry,
            .keyboard = registry.getCapabilityTyped(KeyboardInput).?,
            .writer = registry.getCapabilityTyped(BasicWriter).?,
            .line_buffer = registry.getCapabilityTyped(LineBuffer).?,
            .cursor = registry.getCapabilityTyped(Cursor).?,
            .event_bus = registry.getEventBus(),
        };
    }

    /// Cleanup minimal terminal
    pub fn deinit(self: *MinimalTerminal) void {
        // Registry deinit will handle all capability cleanup (deinit + destroy)
        self.registry.deinit();

        // Free the registry itself
        self.allocator.destroy(self.registry);
    }

    /// Handle keyboard input - main entry point for terminal interaction
    pub fn handleKey(self: *MinimalTerminal, key: kernel.Key) !void {
        try self.keyboard.handleKey(key);
    }

    /// Write text to terminal output
    pub fn write(self: *MinimalTerminal, text: []const u8) !void {
        try self.writer.write(text);
    }

    /// Update cursor animation (should be called regularly)
    pub fn update(self: *MinimalTerminal, dt: f32) !void {
        try self.cursor.update(dt);
    }

    /// Get current input line content
    pub fn getCurrentLine(self: *const MinimalTerminal) []const u8 {
        return self.line_buffer.getCurrentLine();
    }

    /// Get cursor position
    pub fn getCursorPosition(self: *const MinimalTerminal) struct { x: usize, y: usize } {
        const pos = self.cursor.getPosition();
        return .{ .x = pos.x, .y = pos.y };
    }

    /// Check if cursor is visible
    pub fn isCursorVisible(self: *const MinimalTerminal) bool {
        return self.cursor.isVisible();
    }

    /// Get scrollback for rendering
    pub fn getScrollback(self: *const MinimalTerminal) *const core.RingBuffer(core.Line, 1000) {
        return self.writer.getScrollback();
    }

    /// Clear terminal output
    pub fn clear(self: *MinimalTerminal) !void {
        try self.writer.clear();
    }

    /// Set terminal dimensions
    pub fn resize(self: *MinimalTerminal, columns: usize, rows: usize) !void {
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
    pub fn subscribeToCommands(self: *MinimalTerminal, callback: kernel.EventCallback, context: ?*anyopaque) !void {
        try self.event_bus.subscribe(.command_execute, callback, context);
    }

    /// Get event bus for external integration
    pub fn getEventBus(self: *MinimalTerminal) *kernel.EventBus {
        return self.event_bus;
    }
};
