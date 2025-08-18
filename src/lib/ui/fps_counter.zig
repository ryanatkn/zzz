const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const text_renderer = @import("../text/renderer.zig");
const persistent_text = @import("../text/cache.zig");
const rendering_modes = @import("../rendering/modes.zig");
const reactive_time = @import("../reactive/time.zig");
const ReactiveComponent = @import("../reactive/component.zig").ReactiveComponent;
const createComponent = @import("../reactive/component.zig").createComponent;
const signal = @import("../reactive/signal.zig");
const derived = @import("../reactive/derived.zig");
const loggers = @import("../debug/loggers.zig");
const text_alignment = @import("../text/alignment.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

/// Reusable FPS counter component using reactive principles and persistent text rendering
/// Eliminates flashing by caching text textures and only updating when FPS changes
pub const FPSCounterData = struct {
    allocator: std.mem.Allocator,
    position: Vec2,
    font_size: f32,
    color: Color,
    alignment: text_alignment.TextAlign,
    screen_width: f32, // For alignment calculations

    // Reactive signals
    current_fps: *signal.Signal(u32),
    is_visible: *signal.Signal(bool),
    last_update_time: *signal.Signal(u64),

    // Derived values
    fps_text: *derived.Derived([]const u8),
    should_update: *derived.Derived(bool),

    // Configuration
    update_interval_ms: u64, // How often to check for FPS updates

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, position: Vec2, font_size: f32, color: Color, update_interval_ms: u64, alignment: text_alignment.TextAlign, screen_width: f32) !Self {
        // Create reactive signals
        const current_fps_signal = try allocator.create(signal.Signal(u32));
        current_fps_signal.* = try signal.Signal(u32).init(allocator, 0);

        const is_visible_signal = try allocator.create(signal.Signal(bool));
        is_visible_signal.* = try signal.Signal(bool).init(allocator, true);

        const last_update_signal = try allocator.create(signal.Signal(u64));
        last_update_signal.* = try signal.Signal(u64).init(allocator, 0);

        var self = Self{
            .allocator = allocator,
            .position = position,
            .font_size = font_size,
            .color = color,
            .alignment = alignment,
            .screen_width = screen_width,
            .current_fps = current_fps_signal,
            .is_visible = is_visible_signal,
            .last_update_time = last_update_signal,
            .fps_text = undefined, // Set below
            .should_update = undefined, // Set below
            .update_interval_ms = update_interval_ms,
        };

        // Create derived values
        self.fps_text = try self.createFPSTextDerived();
        self.should_update = try self.createShouldUpdateDerived();

        return self;
    }

    fn createFPSTextDerived(self: *Self) !*derived.Derived([]const u8) {
        const SelfRef = struct {
            var counter_ref: *FPSCounterData = undefined;
        };
        SelfRef.counter_ref = self;

        return try derived.derived(self.allocator, []const u8, struct {
            fn compute() []const u8 {
                const counter = SelfRef.counter_ref;
                const fps = counter.current_fps.get();

                // Format FPS string - use allocator for dynamic allocation
                const text = std.fmt.allocPrint(counter.allocator, "FPS: {d}", .{fps}) catch "FPS: ??";
                return text;
            }
        }.compute);
    }

    fn createShouldUpdateDerived(self: *Self) !*derived.Derived(bool) {
        const SelfRef = struct {
            var counter_ref: *FPSCounterData = undefined;
        };
        SelfRef.counter_ref = self;

        return try derived.derived(self.allocator, bool, struct {
            fn compute() bool {
                const counter = SelfRef.counter_ref;
                const current_time = @as(u64, @intCast(std.time.milliTimestamp()));
                const last_update = counter.last_update_time.get();

                // Update if enough time has passed since last update
                return (current_time - last_update) >= counter.update_interval_ms;
            }
        }.compute);
    }

    pub fn setVisible(self: *Self, visible: bool) void {
        self.is_visible.set(visible);
    }

    pub fn setPosition(self: *Self, position: Vec2) void {
        self.position = position;
    }

    pub fn updateFPS(self: *Self) void {
        // Get current FPS from reactive time system
        const new_fps = reactive_time.getFPS();
        const old_fps = self.current_fps.peek();

        // Only update if FPS has actually changed (reduces unnecessary reactive updates)
        if (new_fps != old_fps) {
            self.current_fps.set(new_fps);
            self.last_update_time.set(@as(u64, @intCast(std.time.milliTimestamp())));

            loggers.getUILog().info("fps_change", "FPS counter updated: {} -> {}", .{ old_fps, new_fps });
        }
    }

    pub fn render(self: *Self, renderer: *text_renderer.TextRenderer, font_manager: anytype, font_category: anytype) !void {
        if (!self.is_visible.peek()) return;

        // Update FPS value if needed
        if (self.should_update.get()) {
            self.updateFPS();
        }

        // Get current FPS text (this will use cached value if FPS hasn't changed)
        const fps_text = self.fps_text.get();

        // Calculate text width for alignment (rough estimation)
        const estimated_text_width = @as(f32, @floatFromInt(fps_text.len)) * self.font_size * 0.6;

        // Calculate aligned position
        const aligned_position = text_alignment.applyAlignment(self.position, self.alignment, estimated_text_width);

        // Use persistent text rendering for optimal performance
        // This follows the rendering mode guidelines - FPS changes ~1-3 times per second
        try renderer.queuePersistentText(fps_text, aligned_position, font_manager, font_category, self.font_size, self.color);

        loggers.getUILog().debug("render", "FPS counter rendered: '{s}' at ({d:.1}, {d:.1}) (aligned: {})", .{ fps_text, aligned_position.x, aligned_position.y, self.alignment });
    }

    pub fn deinit(self: *Self) void {
        // Clean up derived values
        self.fps_text.deinit();
        self.allocator.destroy(self.fps_text);
        self.should_update.deinit();
        self.allocator.destroy(self.should_update);

        // Clean up signals
        self.current_fps.deinit();
        self.allocator.destroy(self.current_fps);
        self.is_visible.deinit();
        self.allocator.destroy(self.is_visible);
        self.last_update_time.deinit();
        self.allocator.destroy(self.last_update_time);
    }

    // Component vtable implementation
    fn onMount(state: *anyopaque) !void {
        _ = state;
        loggers.getUILog().info("mount", "FPS counter component mounted", .{});
    }

    fn onUnmount(state: *anyopaque) void {
        _ = state;
        loggers.getUILog().info("unmount", "FPS counter component unmounted", .{});
    }

    fn onRender(state: *anyopaque) !void {
        const self = @as(*FPSCounterData, @ptrCast(@alignCast(state)));

        // This is called when reactive dependencies change
        loggers.getUILog().debug("reactive_render", "FPS counter render triggered - FPS: {}, visible: {}", .{ self.current_fps.peek(), self.is_visible.peek() });
    }

    fn shouldRender(state: *anyopaque) bool {
        const self = @as(*FPSCounterData, @ptrCast(@alignCast(state)));

        // Only render if visible and something has changed
        return self.is_visible.peek() and self.should_update.peek();
    }

    fn destroy(state: *anyopaque, allocator: std.mem.Allocator) void {
        const self = @as(*FPSCounterData, @ptrCast(@alignCast(state)));
        self.deinit();
        allocator.destroy(self);
    }

    pub const vtable = ReactiveComponent.ComponentVTable{
        .onMount = FPSCounterData.onMount,
        .onUnmount = FPSCounterData.onUnmount,
        .onRender = FPSCounterData.onRender,
        .shouldRender = FPSCounterData.shouldRender,
        .destroy = FPSCounterData.destroy,
    };
};

/// Main FPS counter component wrapper
pub const FPSCounter = struct {
    component: *ReactiveComponent,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, position: Vec2, font_size: f32, color: Color, update_interval_ms: u64, alignment: text_alignment.TextAlign, screen_width: f32) !Self {
        const counter_data = try FPSCounterData.init(allocator, position, font_size, color, update_interval_ms, alignment, screen_width);

        const component = try createComponent(FPSCounterData, allocator, counter_data, FPSCounterData.vtable);

        // Mount the component to start reactive lifecycle
        try component.mount();

        return Self{
            .component = component,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.component.deinit();
    }

    pub fn getCounterData(self: *Self) *FPSCounterData {
        return @as(*FPSCounterData, @ptrCast(@alignCast(self.component.state)));
    }

    // Convenience methods
    pub fn setVisible(self: *Self, visible: bool) void {
        self.getCounterData().setVisible(visible);
    }

    pub fn setPosition(self: *Self, position: Vec2) void {
        self.getCounterData().setPosition(position);
    }

    pub fn render(self: *Self, renderer: *text_renderer.TextRenderer, font_manager: anytype, font_category: anytype) !void {
        try self.getCounterData().render(renderer, font_manager, font_category);
    }
};

/// Create a pre-configured FPS counter for common use cases
pub const FPSCounterPresets = struct {
    pub const default_white = struct {
        pub const position = Vec2{ .x = 100.0, .y = 100.0 };
        pub const font_size = 48.0;
        pub const color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
        pub const update_interval_ms = 500; // Update twice per second
        pub const alignment = text_alignment.TextAlign.left;
        pub const screen_width = 1920.0;
    };

    pub const debug_overlay = struct {
        pub const position = Vec2{ .x = 1910.0, .y = 1060.0 }; // Right edge with margin
        pub const font_size = 24.0;
        pub const color = Color{ .r = 230, .g = 230, .b = 230, .a = 255 };
        pub const update_interval_ms = 1000; // Update once per second
        pub const alignment = text_alignment.TextAlign.right; // Right-aligned
        pub const screen_width = 1920.0;
    };

    pub const small_corner = struct {
        pub const position = Vec2{ .x = 10.0, .y = 10.0 };
        pub const font_size = 18.0;
        pub const color = Color{ .r = 200, .g = 200, .b = 200, .a = 180 };
        pub const update_interval_ms = 1000; // Update once per second
        pub const alignment = text_alignment.TextAlign.left;
        pub const screen_width = 1920.0;
    };

    /// New right-aligned top corner preset
    pub const top_right_corner = struct {
        pub const position = Vec2{ .x = 1910.0, .y = 10.0 }; // Top-right with margin
        pub const font_size = 18.0;
        pub const color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
        pub const update_interval_ms = 1000; // Update once per second
        pub const alignment = text_alignment.TextAlign.right; // Right-aligned
        pub const screen_width = 1920.0;
    };
};

/// Create FPS counter with default settings
pub fn createDefault(allocator: std.mem.Allocator) !FPSCounter {
    return FPSCounter.init(allocator, FPSCounterPresets.default_white.position, FPSCounterPresets.default_white.font_size, FPSCounterPresets.default_white.color, FPSCounterPresets.default_white.update_interval_ms, FPSCounterPresets.default_white.alignment, FPSCounterPresets.default_white.screen_width);
}

/// Create debug overlay FPS counter (right-aligned)
pub fn createDebugOverlay(allocator: std.mem.Allocator) !FPSCounter {
    return FPSCounter.init(allocator, FPSCounterPresets.debug_overlay.position, FPSCounterPresets.debug_overlay.font_size, FPSCounterPresets.debug_overlay.color, FPSCounterPresets.debug_overlay.update_interval_ms, FPSCounterPresets.debug_overlay.alignment, FPSCounterPresets.debug_overlay.screen_width);
}

/// Create small corner FPS counter
pub fn createSmallCorner(allocator: std.mem.Allocator) !FPSCounter {
    return FPSCounter.init(allocator, FPSCounterPresets.small_corner.position, FPSCounterPresets.small_corner.font_size, FPSCounterPresets.small_corner.color, FPSCounterPresets.small_corner.update_interval_ms, FPSCounterPresets.small_corner.alignment, FPSCounterPresets.small_corner.screen_width);
}

/// Create top-right corner FPS counter (right-aligned)
pub fn createTopRightCorner(allocator: std.mem.Allocator) !FPSCounter {
    return FPSCounter.init(allocator, FPSCounterPresets.top_right_corner.position, FPSCounterPresets.top_right_corner.font_size, FPSCounterPresets.top_right_corner.color, FPSCounterPresets.top_right_corner.update_interval_ms, FPSCounterPresets.top_right_corner.alignment, FPSCounterPresets.top_right_corner.screen_width);
}

/// Performance analysis for FPS counter
pub const PerformanceAnalysis = struct {
    /// Based on rendering mode guidelines, FPS counters are perfect for persistent mode:
    /// - Changes 1-3 times per second (occasional frequency)
    /// - Text content is predictable and cacheable
    /// - Memory impact is low (single texture cached)
    /// - CPU overhead is minimal after initial texture creation
    pub const recommendation = rendering_modes.UseCases.fps_counter;

    /// Expected cache hit rate for FPS counters
    /// At 60fps, FPS typically stabilizes to specific values (59, 60, 61)
    /// This results in excellent cache efficiency
    pub const expected_cache_hit_rate = 0.95;

    /// Memory usage estimate
    /// Single FPS texture ~= width*height*4 bytes (RGBA)
    /// Typical FPS text "FPS: 60" at 48pt ~= 120x48 pixels = 23KB
    pub const estimated_memory_bytes = 23 * 1024;
};

test "FPS counter creation and basic operations" {
    const allocator = std.testing.allocator;

    // Test FPS counter creation
    var counter = try createDefault(allocator);
    defer counter.deinit();

    const counter_data = counter.getCounterData();

    // Test visibility toggle
    counter.setVisible(false);
    try std.testing.expectEqual(false, counter_data.is_visible.peek());

    counter.setVisible(true);
    try std.testing.expectEqual(true, counter_data.is_visible.peek());

    // Test position setting
    const new_pos = Vec2{ .x = 200.0, .y = 300.0 };
    counter.setPosition(new_pos);
    try std.testing.expectEqual(new_pos.x, counter_data.position.x);
    try std.testing.expectEqual(new_pos.y, counter_data.position.y);

    // Test alignment
    try std.testing.expectEqual(text_alignment.TextAlign.left, counter_data.alignment);
}

test "FPS counter presets" {
    const allocator = std.testing.allocator;

    // Test different presets
    var default_counter = try createDefault(allocator);
    defer default_counter.deinit();

    var debug_counter = try createDebugOverlay(allocator);
    defer debug_counter.deinit();

    var corner_counter = try createSmallCorner(allocator);
    defer corner_counter.deinit();

    var top_right_counter = try createTopRightCorner(allocator);
    defer top_right_counter.deinit();

    // Verify different positions
    const default_data = default_counter.getCounterData();
    const debug_data = debug_counter.getCounterData();
    const corner_data = corner_counter.getCounterData();
    const top_right_data = top_right_counter.getCounterData();

    try std.testing.expect(default_data.position.x != debug_data.position.x);
    try std.testing.expect(debug_data.position.x != corner_data.position.x);

    // Test alignment settings
    try std.testing.expectEqual(text_alignment.TextAlign.left, default_data.alignment);
    try std.testing.expectEqual(text_alignment.TextAlign.right, debug_data.alignment);
    try std.testing.expectEqual(text_alignment.TextAlign.left, corner_data.alignment);
    try std.testing.expectEqual(text_alignment.TextAlign.right, top_right_data.alignment);
}
