const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const text_renderer = @import("../text/renderer.zig");
const persistent_text = @import("../text/cache.zig");
const rendering_modes = @import("../rendering/modes.zig");
const ReactiveComponent = @import("../reactive/component.zig").ReactiveComponent;
const createComponent = @import("../reactive/component.zig").createComponent;
const getComponentData = @import("../reactive/component.zig").getComponentData;
const castComponentState = @import("../reactive/component.zig").castComponentState;
const signal = @import("../reactive/signal.zig");
const derived = @import("../reactive/derived.zig");
const loggers = @import("../debug/loggers.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

/// Debug value that can be displayed in the overlay
pub const DebugValue = struct {
    key: []const u8, // Display name (e.g. "Memory Usage")
    format_string: []const u8, // Format for value (e.g. "{d} MB")
    rendering_mode: rendering_modes.RenderingMode,
    change_frequency: f32, // Expected changes per second

    // Value storage (union for different types)
    value: ValueType,

    pub const ValueType = union(enum) {
        int: i64,
        uint: u64,
        float: f64,
        string: []const u8,
        bool: bool,
    };

    pub fn formatValue(self: *const DebugValue, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self.value) {
            .int => |v| try std.fmt.allocPrint(allocator, self.format_string, .{v}),
            .uint => |v| try std.fmt.allocPrint(allocator, self.format_string, .{v}),
            .float => |v| try std.fmt.allocPrint(allocator, self.format_string, .{v}),
            .string => |v| try std.fmt.allocPrint(allocator, self.format_string, .{v}),
            .bool => |v| try std.fmt.allocPrint(allocator, self.format_string, .{v}),
        };
    }

    pub fn setValue(self: *DebugValue, value: ValueType) void {
        self.value = value;
    }
};

/// Debug overlay component that can display multiple debug values
/// Uses appropriate rendering modes based on value change frequency
pub const DebugOverlayData = struct {
    allocator: std.mem.Allocator,
    position: Vec2,
    line_height: f32,
    font_size: f32,
    color: Color,
    background_color: ?Color, // Optional background

    // Debug values storage
    values: std.ArrayList(DebugValue),

    // Reactive signals
    is_visible: *signal.Signal(bool),
    last_update_time: *signal.Signal(u64),
    values_changed: *signal.Signal(bool),

    // Configuration
    update_interval_ms: u64,
    max_values: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, position: Vec2, font_size: f32, line_height: f32, color: Color, background_color: ?Color, max_values: usize, update_interval_ms: u64) !Self {
        // Create reactive signals
        const is_visible_signal = try allocator.create(signal.Signal(bool));
        is_visible_signal.* = try signal.Signal(bool).init(allocator, true);

        const last_update_signal = try allocator.create(signal.Signal(u64));
        last_update_signal.* = try signal.Signal(u64).init(allocator, 0);

        const values_changed_signal = try allocator.create(signal.Signal(bool));
        values_changed_signal.* = try signal.Signal(bool).init(allocator, false);

        return Self{
            .allocator = allocator,
            .position = position,
            .line_height = line_height,
            .font_size = font_size,
            .color = color,
            .background_color = background_color,
            .values = std.ArrayList(DebugValue).init(allocator),
            .is_visible = is_visible_signal,
            .last_update_time = last_update_signal,
            .values_changed = values_changed_signal,
            .update_interval_ms = update_interval_ms,
            .max_values = max_values,
        };
    }

    pub fn addValue(self: *Self, key: []const u8, format_string: []const u8, initial_value: DebugValue.ValueType, change_frequency: f32) !void {
        if (self.values.items.len >= self.max_values) {
            return error.TooManyDebugValues;
        }

        const recommended_mode = rendering_modes.recommendModeByRate(change_frequency);

        const debug_value = DebugValue{
            .key = key,
            .format_string = format_string,
            .rendering_mode = recommended_mode.recommended_mode,
            .change_frequency = change_frequency,
            .value = initial_value,
        };

        try self.values.append(debug_value);
        self.values_changed.set(true);

        loggers.getUILog().info("add_debug_value", "Added debug value '{s}' with {s} mode (changes: {d:.2}/sec)", .{ key, @tagName(recommended_mode.recommended_mode), change_frequency });
    }

    pub fn updateValue(self: *Self, key: []const u8, new_value: DebugValue.ValueType) !void {
        for (self.values.items) |*value| {
            if (std.mem.eql(u8, value.key, key)) {
                value.setValue(new_value);
                self.values_changed.set(true);
                self.last_update_time.set(@as(u64, @intCast(std.time.milliTimestamp())));
                return;
            }
        }
        return error.DebugValueNotFound;
    }

    pub fn removeValue(self: *Self, key: []const u8) void {
        for (self.values.items, 0..) |value, i| {
            if (std.mem.eql(u8, value.key, key)) {
                _ = self.values.orderedRemove(i);
                self.values_changed.set(true);
                break;
            }
        }
    }

    pub fn setVisible(self: *Self, visible: bool) void {
        self.is_visible.set(visible);
    }

    pub fn clear(self: *Self) void {
        self.values.clearRetainingCapacity();
        self.values_changed.set(true);
    }

    pub fn render(self: *Self, renderer: *text_renderer.TextRenderer, font_manager: anytype, font_category: anytype) !void {
        if (!self.is_visible.peek() or self.values.items.len == 0) return;

        loggers.getUILog().debug("render_overlay", "Rendering debug overlay with {} values", .{self.values.items.len});

        // Render background if specified
        if (self.background_color) |bg_color| {
            // Background rendering available via drawing.zig utilities if needed
            _ = bg_color;
        }

        // Render each debug value
        for (self.values.items, 0..) |*value, i| {
            const line_position = Vec2{
                .x = self.position.x,
                .y = self.position.y + @as(f32, @floatFromInt(i)) * self.line_height,
            };

            // Format the debug line: "Key: Value"
            const formatted_text = try self.formatDebugLine(value);
            defer self.allocator.free(formatted_text);

            // Choose rendering mode based on value characteristics
            switch (value.rendering_mode) {
                .immediate => {
                    // Use immediate mode for frequently changing values
                    const text_result = font_manager.renderTextToTexture(formatted_text, font_category, self.font_size, self.color, renderer.device) catch |err| {
                        loggers.getUILog().err("render_error", "Failed to render debug text '{}': {}", .{ formatted_text, err });
                        continue;
                    };

                    renderer.queueTextTexture(text_result.texture, line_position, text_result.width, text_result.height, self.color);

                    loggers.getUILog().debug("render_immediate", "Rendered immediate debug text: '{s}'", .{formatted_text});
                },
                .persistent => {
                    // Use persistent mode for slowly changing values
                    try renderer.queuePersistentText(formatted_text, line_position, font_manager, font_category, self.font_size, self.color);

                    loggers.getUILog().debug("queue_persistent", "Queued persistent debug text: '{s}'", .{formatted_text});
                },
            }
        }

        // Reset values changed flag
        self.values_changed.set(false);
    }

    fn formatDebugLine(self: *Self, value: *const DebugValue) ![]const u8 {
        const formatted_value = try value.formatValue(self.allocator);
        defer self.allocator.free(formatted_value);

        return try std.fmt.allocPrint(self.allocator, "{s}: {s}", .{ value.key, formatted_value });
    }

    pub fn getStats(self: *Self) DebugOverlayStats {
        var immediate_count: u32 = 0;
        var persistent_count: u32 = 0;

        for (self.values.items) |value| {
            switch (value.rendering_mode) {
                .immediate => immediate_count += 1,
                .persistent => persistent_count += 1,
            }
        }

        return DebugOverlayStats{
            .total_values = @intCast(self.values.items.len),
            .immediate_mode_count = immediate_count,
            .persistent_mode_count = persistent_count,
            .is_visible = self.is_visible.peek(),
        };
    }

    pub fn deinit(self: *Self) void {
        // Clean up signals
        self.is_visible.deinit();
        self.allocator.destroy(self.is_visible);
        self.last_update_time.deinit();
        self.allocator.destroy(self.last_update_time);
        self.values_changed.deinit();
        self.allocator.destroy(self.values_changed);

        // Clean up values
        self.values.deinit();
    }

    // Component vtable implementation
    fn onMount(state: *anyopaque) !void {
        _ = state;
        loggers.getUILog().info("mount", "Debug overlay component mounted", .{});
    }

    fn onUnmount(state: *anyopaque) void {
        _ = state;
        loggers.getUILog().info("unmount", "Debug overlay component unmounted", .{});
    }

    fn onRender(state: *anyopaque) !void {
        const self = castComponentState(DebugOverlayData, state);

        loggers.getUILog().debug("reactive_render", "Debug overlay render triggered - {} values, visible: {}", .{ self.values.items.len, self.is_visible.peek() });
    }

    fn shouldRender(state: *anyopaque) bool {
        const self = castComponentState(DebugOverlayData, state);
        return self.is_visible.peek() and self.values_changed.peek();
    }

    fn destroy(state: *anyopaque, allocator: std.mem.Allocator) void {
        const self = castComponentState(DebugOverlayData, state);
        self.deinit();
        allocator.destroy(self);
    }

    pub const vtable = ReactiveComponent.ComponentVTable{
        .onMount = DebugOverlayData.onMount,
        .onUnmount = DebugOverlayData.onUnmount,
        .onRender = DebugOverlayData.onRender,
        .shouldRender = DebugOverlayData.shouldRender,
        .destroy = DebugOverlayData.destroy,
    };
};

pub const DebugOverlayStats = struct {
    total_values: u32,
    immediate_mode_count: u32,
    persistent_mode_count: u32,
    is_visible: bool,
};

/// Main debug overlay component wrapper
pub const DebugOverlay = struct {
    component: *ReactiveComponent,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, position: Vec2, font_size: f32, line_height: f32, color: Color, background_color: ?Color, max_values: usize, update_interval_ms: u64) !Self {
        const overlay_data = try DebugOverlayData.init(allocator, position, font_size, line_height, color, background_color, max_values, update_interval_ms);

        const component = try createComponent(DebugOverlayData, allocator, overlay_data, DebugOverlayData.vtable);

        try component.mount();

        return Self{
            .component = component,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.component.deinit();
    }

    pub fn getOverlayData(self: *Self) *DebugOverlayData {
        return getComponentData(DebugOverlayData, self.component);
    }

    // Convenience methods
    pub fn addValue(self: *Self, key: []const u8, format_string: []const u8, initial_value: DebugValue.ValueType, change_frequency: f32) !void {
        try self.getOverlayData().addValue(key, format_string, initial_value, change_frequency);
    }

    pub fn updateValue(self: *Self, key: []const u8, new_value: DebugValue.ValueType) !void {
        try self.getOverlayData().updateValue(key, new_value);
    }

    pub fn setVisible(self: *Self, visible: bool) void {
        self.getOverlayData().setVisible(visible);
    }

    pub fn render(self: *Self, renderer: *text_renderer.TextRenderer, font_manager: anytype, font_category: anytype) !void {
        try self.getOverlayData().render(renderer, font_manager, font_category);
    }

    pub fn getStats(self: *Self) DebugOverlayStats {
        return self.getOverlayData().getStats();
    }
};

/// Pre-configured debug overlay presets
pub const DebugOverlayPresets = struct {
    pub const top_left = struct {
        pub const position = Vec2{ .x = 10.0, .y = 10.0 };
        pub const font_size = 18.0;
        pub const line_height = 22.0;
        pub const color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
        pub const background_color = Color{ .r = 0, .g = 0, .b = 0, .a = 128 };
        pub const max_values = 20;
        pub const update_interval_ms = 100;
    };

    pub const top_right = struct {
        pub const position = Vec2{ .x = 1600.0, .y = 10.0 };
        pub const font_size = 16.0;
        pub const line_height = 20.0;
        pub const color = Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
        pub const background_color = null;
        pub const max_values = 10;
        pub const update_interval_ms = 500;
    };

    pub const performance = struct {
        pub const position = Vec2{ .x = 10.0, .y = 50.0 };
        pub const font_size = 20.0;
        pub const line_height = 25.0;
        pub const color = Color{ .r = 100, .g = 255, .b = 100, .a = 255 };
        pub const background_color = Color{ .r = 0, .g = 0, .b = 0, .a = 180 };
        pub const max_values = 8;
        pub const update_interval_ms = 250;
    };
};

/// Create debug overlay with common preset configurations
pub fn createTopLeft(allocator: std.mem.Allocator) !DebugOverlay {
    const preset = DebugOverlayPresets.top_left;
    return DebugOverlay.init(allocator, preset.position, preset.font_size, preset.line_height, preset.color, preset.background_color, preset.max_values, preset.update_interval_ms);
}

pub fn createTopRight(allocator: std.mem.Allocator) !DebugOverlay {
    const preset = DebugOverlayPresets.top_right;
    return DebugOverlay.init(allocator, preset.position, preset.font_size, preset.line_height, preset.color, preset.background_color, preset.max_values, preset.update_interval_ms);
}

pub fn createPerformanceOverlay(allocator: std.mem.Allocator) !DebugOverlay {
    const preset = DebugOverlayPresets.performance;
    return DebugOverlay.init(allocator, preset.position, preset.font_size, preset.line_height, preset.color, preset.background_color, preset.max_values, preset.update_interval_ms);
}

/// Helper functions for common debug values
pub const CommonDebugValues = struct {
    pub fn addMemoryUsage(overlay: *DebugOverlay) !void {
        try overlay.addValue("Memory", "{d} MB", .{ .uint = 0 }, 0.2); // Changes ~5 times per second
    }

    pub fn addEntityCount(overlay: *DebugOverlay) !void {
        try overlay.addValue("Entities", "{d}", .{ .uint = 0 }, 2.0); // Changes 2 times per second
    }

    pub fn addFrameTime(overlay: *DebugOverlay) !void {
        try overlay.addValue("Frame Time", "{d:.2} ms", .{ .float = 0.0 }, 60.0); // Changes every frame
    }

    pub fn addDrawCalls(overlay: *DebugOverlay) !void {
        try overlay.addValue("Draw Calls", "{d}", .{ .uint = 0 }, 10.0); // Changes ~10 times per second
    }

    pub fn addPlayerPosition(overlay: *DebugOverlay) !void {
        try overlay.addValue("Player Pos", "({d:.1}, {d:.1})", .{ .string = "(0.0, 0.0)" }, 30.0); // Frequent updates
    }
};

test "debug overlay creation and basic operations" {
    const allocator = std.testing.allocator;

    var overlay = try createTopLeft(allocator);
    defer overlay.deinit();

    const overlay_data = overlay.getOverlayData();

    // Test adding values
    try overlay.addValue("Test Int", "{d}", .{ .int = 42 }, 1.0);
    try overlay.addValue("Test String", "{s}", .{ .string = "hello" }, 0.1);

    try std.testing.expectEqual(@as(usize, 2), overlay_data.values.items.len);

    // Test updating values
    try overlay.updateValue("Test Int", .{ .int = 100 });

    // Test visibility toggle
    overlay.setVisible(false);
    try std.testing.expectEqual(false, overlay_data.is_visible.peek());

    // Test stats
    const stats = overlay.getStats();
    try std.testing.expectEqual(@as(u32, 2), stats.total_values);
    try std.testing.expectEqual(false, stats.is_visible);
}
