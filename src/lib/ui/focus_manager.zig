const std = @import("std");
const reactive = @import("../reactive/mod.zig");

/// Generic focus manager for UI panels/components
/// Provides clean abstraction for focus management that can be hoisted to higher levels
pub fn FocusManager(comptime FocusType: type) type {
    return struct {
        const Self = @This();

        // Reactive state for current focus
        focused_item: reactive.Signal(FocusType),

        pub fn init(allocator: std.mem.Allocator, initial_focus: FocusType) !Self {
            return Self{
                .focused_item = try reactive.signal(allocator, FocusType, initial_focus),
            };
        }

        pub fn deinit(self: *Self) void {
            self.focused_item.deinit();
        }

        /// Set focus to a specific item
        pub fn setFocus(self: *Self, item: FocusType) void {
            self.focused_item.set(item);
        }

        /// Get currently focused item
        pub fn getFocus(self: *const Self) FocusType {
            return self.focused_item.peek();
        }

        /// Check if a specific item has focus
        pub fn hasFocus(self: *const Self, item: FocusType) bool {
            return std.meta.eql(self.focused_item.peek(), item);
        }

        /// Cycle focus to next item in a list
        pub fn cycleFocus(self: *Self, items: []const FocusType) void {
            if (items.len == 0) return;

            const current = self.focused_item.get();

            // Find current item index
            for (items, 0..) |item, i| {
                if (std.meta.eql(item, current)) {
                    // Move to next item (wrap around)
                    const next_index = (i + 1) % items.len;
                    self.focused_item.set(items[next_index]);
                    return;
                }
            }

            // If current focus not found in list, set to first item
            self.focused_item.set(items[0]);
        }

        /// Handle tab navigation (useful for keyboard focus management)
        pub fn handleTabNavigation(self: *Self, items: []const FocusType, shift_held: bool) void {
            if (items.len == 0) return;

            const current = self.focused_item.get();

            // Find current item index
            for (items, 0..) |item, i| {
                if (std.meta.eql(item, current)) {
                    if (shift_held) {
                        // Move to previous item (wrap around)
                        const prev_index = if (i == 0) items.len - 1 else i - 1;
                        self.focused_item.set(items[prev_index]);
                    } else {
                        // Move to next item (wrap around)
                        const next_index = (i + 1) % items.len;
                        self.focused_item.set(items[next_index]);
                    }
                    return;
                }
            }

            // If current focus not found in list, set to first item
            self.focused_item.set(items[0]);
        }

        /// Create a reactive derived value that tracks focus for a specific item
        pub fn createFocusTracker(self: *Self, allocator: std.mem.Allocator, tracked_item: FocusType) !reactive.Derived(bool) {
            return reactive.derived(allocator, &self.focused_item, struct {
                item: FocusType,

                pub fn compute(this: @This(), signal: *const reactive.Signal(FocusType)) bool {
                    return std.meta.eql(signal.get(), this.item);
                }
            }{ .item = tracked_item });
        }
    };
}

/// Common focus types for UI components
pub const PanelFocus = enum {
    none,
    file_tree,
    content_editor,
    terminal,
    property_panel,
    search_panel,
};

/// Convenience type alias for panel focus management
pub const PanelFocusManager = FocusManager(PanelFocus);

/// Create a panel focus manager with common default
pub fn createPanelFocusManager(allocator: std.mem.Allocator) !PanelFocusManager {
    return PanelFocusManager.init(allocator, .none);
}

// Tests
test "FocusManager basic functionality" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const TestFocus = enum { a, b, c };

    var focus_manager = try FocusManager(TestFocus).init(allocator, .a);
    defer focus_manager.deinit();

    // Test initial focus
    try testing.expect(focus_manager.getFocus() == .a);
    try testing.expect(focus_manager.hasFocus(.a));
    try testing.expect(!focus_manager.hasFocus(.b));

    // Test setting focus
    focus_manager.setFocus(.b);
    try testing.expect(focus_manager.getFocus() == .b);
    try testing.expect(focus_manager.hasFocus(.b));
    try testing.expect(!focus_manager.hasFocus(.a));
}

test "FocusManager cycle functionality" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const TestFocus = enum { a, b, c };
    const items = [_]TestFocus{ .a, .b, .c };

    var focus_manager = try FocusManager(TestFocus).init(allocator, .a);
    defer focus_manager.deinit();

    // Test cycling forward
    focus_manager.cycleFocus(&items);
    try testing.expect(focus_manager.getFocus() == .b);

    focus_manager.cycleFocus(&items);
    try testing.expect(focus_manager.getFocus() == .c);

    focus_manager.cycleFocus(&items);
    try testing.expect(focus_manager.getFocus() == .a); // wrapped around
}

test "PanelFocusManager" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var panel_focus = try createPanelFocusManager(allocator);
    defer panel_focus.deinit();

    try testing.expect(panel_focus.getFocus() == .none);

    panel_focus.setFocus(.terminal);
    try testing.expect(panel_focus.hasFocus(.terminal));
}

test "FocusManager tab navigation" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const TestFocus = enum { a, b, c };
    const items = [_]TestFocus{ .a, .b, .c };

    var focus_manager = try FocusManager(TestFocus).init(allocator, .a);
    defer focus_manager.deinit();

    // Test forward tab navigation
    focus_manager.handleTabNavigation(&items, false);
    try testing.expect(focus_manager.getFocus() == .b);

    focus_manager.handleTabNavigation(&items, false);
    try testing.expect(focus_manager.getFocus() == .c);

    focus_manager.handleTabNavigation(&items, false);
    try testing.expect(focus_manager.getFocus() == .a); // wrapped around

    // Test backward tab navigation
    focus_manager.handleTabNavigation(&items, true);
    try testing.expect(focus_manager.getFocus() == .c);

    focus_manager.handleTabNavigation(&items, true);
    try testing.expect(focus_manager.getFocus() == .b);
}

test "FocusManager edge cases" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const TestFocus = enum { a, b, c };

    var focus_manager = try FocusManager(TestFocus).init(allocator, .a);
    defer focus_manager.deinit();

    // Test empty item list
    const empty_items = [_]TestFocus{};
    focus_manager.cycleFocus(&empty_items);
    try testing.expect(focus_manager.getFocus() == .a); // unchanged

    // Test single item list
    const single_item = [_]TestFocus{.b};
    focus_manager.cycleFocus(&single_item);
    try testing.expect(focus_manager.getFocus() == .b); // set to single item

    focus_manager.cycleFocus(&single_item);
    try testing.expect(focus_manager.getFocus() == .b); // still same item

    // Test focus not in list
    focus_manager.setFocus(.c);
    const ab_items = [_]TestFocus{ .a, .b };
    focus_manager.cycleFocus(&ab_items);
    try testing.expect(focus_manager.getFocus() == .a); // defaults to first
}
