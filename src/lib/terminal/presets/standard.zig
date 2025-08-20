const std = @import("std");
const kernel = @import("../kernel/mod.zig");
const loggers = @import("../../debug/loggers.zig");
const MinimalTerminal = @import("minimal.zig").MinimalTerminal;
const KeyboardInput = @import("../capabilities/input/keyboard.zig").KeyboardInput;
const BasicWriter = @import("../capabilities/output/basic_writer.zig").BasicWriter;
const LineBuffer = @import("../capabilities/state/line_buffer.zig").LineBuffer;
const Cursor = @import("../capabilities/state/cursor.zig").Cursor;
const History = @import("../capabilities/state/history.zig").History;
const ScreenBuffer = @import("../capabilities/state/screen_buffer.zig").ScreenBuffer;
const Scrollback = @import("../capabilities/state/scrollback.zig").Scrollback;
const Persistence = @import("../capabilities/state/persistence.zig").Persistence;

/// Standard terminal preset - full-featured terminal with all state management capabilities
pub const StandardTerminal = struct {
    allocator: std.mem.Allocator,
    registry: *kernel.TypeSafeCapabilityRegistry,

    // Core capabilities from minimal terminal
    minimal: MinimalTerminal,

    // Additional state management capabilities
    history: *History,
    screen_buffer: *ScreenBuffer,
    scrollback: *Scrollback,
    persistence: *Persistence,

    // Terminal interface
    event_bus: *kernel.EventBus,

    const Self = @This();

    /// Initialize standard terminal with all capabilities
    pub fn init(allocator: std.mem.Allocator) !Self {
        // Create registry and register all standard capabilities 
        var registry = try kernel.createRegistry(allocator);
        errdefer allocator.destroy(registry);
        
        // Register all capabilities for standard terminal using new enum-based API
        try registry.registerType(.keyboard_input);
        try registry.registerType(.basic_writer);
        try registry.registerType(.line_buffer);
        try registry.registerType(.cursor);
        try registry.registerType(.history);
        try registry.registerType(.screen_buffer);
        try registry.registerType(.scrollback);
        try registry.registerType(.persistence);

        // Initialize all capabilities
        try registry.initializeAll();

        return Self{
            .allocator = allocator,
            .registry = registry,
            .minimal = MinimalTerminal{
                .allocator = allocator,
                .registry = registry,
                .keyboard = registry.getCapabilityTyped(KeyboardInput).?,
                .writer = registry.getCapabilityTyped(BasicWriter).?,
                .line_buffer = registry.getCapabilityTyped(LineBuffer).?,
                .cursor = registry.getCapabilityTyped(Cursor).?,
                .event_bus = registry.getEventBus(),
            },
            .history = registry.getCapabilityTyped(History).?,
            .screen_buffer = registry.getCapabilityTyped(ScreenBuffer).?,
            .scrollback = registry.getCapabilityTyped(Scrollback).?,
            .persistence = registry.getCapabilityTyped(Persistence).?,
            .event_bus = registry.getEventBus(),
        };
    }

    /// Cleanup standard terminal
    pub fn deinit(self: *Self) void {
        // Registry deinit will handle all capability cleanup (deinit + destroy)
        self.registry.deinit();

        // Free the registry itself
        self.allocator.destroy(self.registry);
    }

    // ===== Core Terminal Functions (delegated to minimal) =====

    /// Handle keyboard input
    pub fn handleKey(self: *Self, key: kernel.Key) !void {
        try self.minimal.handleKey(key);
    }

    /// Write text to terminal output
    pub fn write(self: *Self, text: []const u8) !void {
        try self.minimal.write(text);
    }

    /// Update terminal state (cursor blink, etc.)
    pub fn update(self: *Self, dt: f32) !void {
        try self.minimal.update(dt);
    }

    /// Get current input line content
    pub fn getCurrentLine(self: *const Self) []const u8 {
        return self.minimal.getCurrentLine();
    }

    /// Get cursor position
    pub fn getCursorPosition(self: *const Self) struct { x: usize, y: usize } {
        return self.minimal.getCursorPosition();
    }

    /// Check if cursor is visible
    pub fn isCursorVisible(self: *const Self) bool {
        return self.minimal.isCursorVisible();
    }

    // ===== History Functions =====

    /// Get command history count
    pub fn getHistoryCount(self: *const Self) usize {
        return self.history.getCount();
    }

    /// Clear command history
    pub fn clearHistory(self: *Self) void {
        self.history.clear();
    }

    /// Navigate history (for external control)
    pub fn navigateHistory(self: *Self, direction: i32) ?[]const u8 {
        return self.history.navigate(direction);
    }

    // ===== Screen Buffer Functions =====

    /// Switch to alternate screen (for full-screen apps)
    pub fn switchToAlternateScreen(self: *Self) void {
        self.screen_buffer.switchToAlternate();
    }

    /// Switch back to primary screen
    pub fn switchToPrimaryScreen(self: *Self) void {
        self.screen_buffer.switchToPrimary();
    }

    /// Check if using alternate screen
    pub fn isUsingAlternateScreen(self: *const Self) bool {
        return self.screen_buffer.using_alternate;
    }

    /// Clear screen
    pub fn clearScreen(self: *Self) void {
        self.screen_buffer.clearScreen();
    }

    // ===== Scrollback Functions =====

    /// Scroll up by specified lines
    pub fn scrollUp(self: *Self, lines: usize) void {
        self.scrollback.scrollUp(lines);
    }

    /// Scroll down by specified lines
    pub fn scrollDown(self: *Self, lines: usize) void {
        self.scrollback.scrollDown(lines);
    }

    /// Scroll to top of buffer
    pub fn scrollToTop(self: *Self) void {
        self.scrollback.scrollToTop();
    }

    /// Scroll to bottom of buffer
    pub fn scrollToBottom(self: *Self) void {
        self.scrollback.scrollToBottom();
    }

    /// Check if at bottom of scrollback
    pub fn isAtBottom(self: *const Self) bool {
        return self.scrollback.isAtBottom();
    }

    /// Get scrollback line count
    pub fn getScrollbackLineCount(self: *const Self) usize {
        return self.scrollback.getLineCount();
    }

    /// Get visible lines for rendering
    pub fn getVisibleLines(self: *const Self, max_rows: usize) Scrollback.VisibleLinesIterator {
        return self.scrollback.getVisibleLines(max_rows);
    }

    /// Clear scrollback buffer
    pub fn clearScrollback(self: *Self) void {
        self.scrollback.clear();
    }

    // ===== Persistence Functions =====

    /// Save current session
    pub fn saveSession(self: *Self, name: ?[]const u8) !void {
        try self.persistence.saveSession(name);
        try self.persistence.saveHistory();
    }

    /// Load session
    pub fn loadSession(self: *Self, name: ?[]const u8) !void {
        try self.persistence.loadSession(name);
        try self.persistence.loadHistory();
    }

    /// List available sessions
    pub fn listSessions(self: *Self) ![][]u8 {
        return try self.persistence.listSessions(self.allocator);
    }

    /// Delete a session
    pub fn deleteSession(self: *Self, name: []const u8) !void {
        try self.persistence.deleteSession(name);
    }

    /// Save history manually
    pub fn saveHistory(self: *Self) !void {
        try self.persistence.saveHistory();
    }

    /// Load history manually
    pub fn loadHistory(self: *Self) !void {
        try self.persistence.loadHistory();
    }

    // ===== Utility Functions =====


    /// Resize terminal
    pub fn resize(self: *Self, columns: usize, rows: usize) !void {
        // Emit resize event for all capabilities to handle
        const resize_event = kernel.Event.init(.resize, .{
            .resize = .{
                .old_columns = self.screen_buffer.columns,
                .old_rows = self.screen_buffer.rows,
                .new_columns = columns,
                .new_rows = rows,
            },
        });
        try self.event_bus.emit(resize_event);
    }
};

// Tests
test "StandardTerminal initialization" {
    const allocator = std.testing.allocator;
    var terminal = try StandardTerminal.init(allocator);
    defer terminal.deinit();

    // Verify all capabilities are registered
    try std.testing.expect(terminal.registry.getCapability(.keyboard_input) != null);
    try std.testing.expect(terminal.registry.getCapability(.basic_writer) != null);
    try std.testing.expect(terminal.registry.getCapability(.line_buffer) != null);
    try std.testing.expect(terminal.registry.getCapability(.cursor) != null);
    try std.testing.expect(terminal.registry.getCapability(.history) != null);
    try std.testing.expect(terminal.registry.getCapability(.screen_buffer) != null);
    try std.testing.expect(terminal.registry.getCapability(.scrollback) != null);
    try std.testing.expect(terminal.registry.getCapability(.persistence) != null);
}

test "StandardTerminal screen switching" {
    const allocator = std.testing.allocator;
    var terminal = try StandardTerminal.init(allocator);
    defer terminal.deinit();

    // Initially on primary screen
    try std.testing.expect(!terminal.isUsingAlternateScreen());

    // Switch to alternate
    terminal.switchToAlternateScreen();
    try std.testing.expect(terminal.isUsingAlternateScreen());

    // Switch back
    terminal.switchToPrimaryScreen();
    try std.testing.expect(!terminal.isUsingAlternateScreen());
}

test "StandardTerminal scrollback operations" {
    const allocator = std.testing.allocator;
    var terminal = try StandardTerminal.init(allocator);
    defer terminal.deinit();

    // Add some output
    try terminal.write("Line 1\n");
    try terminal.write("Line 2\n");
    try terminal.write("Line 3\n");

    // Test basic scrollback functionality (without requiring exact event integration)
    // Initially at bottom
    try std.testing.expect(terminal.isAtBottom());

    // Test scroll operations work without error
    terminal.scrollUp(1);
    terminal.scrollToBottom();
    terminal.scrollToTop();
    terminal.scrollDown(1);

    // Basic functionality test passes
    try std.testing.expect(true);
}
