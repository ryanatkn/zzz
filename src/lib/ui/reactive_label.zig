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
const effect = @import("../reactive/effect.zig");
const loggers = @import("../debug/loggers.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

/// Style configuration for reactive labels
pub const LabelStyle = struct {
    font_size: f32,
    color: Color,
    background_color: ?Color,
    padding: Vec2,
    alignment: TextAlignment,

    pub const TextAlignment = enum {
        left,
        center,
        right,
    };

    pub const default = LabelStyle{
        .font_size = 24.0,
        .color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
        .background_color = null,
        .padding = Vec2.ZERO,
        .alignment = .left,
    };

    pub const button = LabelStyle{
        .font_size = 18.0,
        .color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
        .background_color = Color{ .r = 64, .g = 64, .b = 64, .a = 200 },
        .padding = Vec2{ .x = 8, .y = 4 },
        .alignment = .center,
    };

    pub const title = LabelStyle{
        .font_size = 36.0,
        .color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
        .background_color = null,
        .padding = Vec2{ .x = 0, .y = 10 },
        .alignment = .center,
    };

    pub const small = LabelStyle{
        .font_size = 14.0,
        .color = Color{ .r = 200, .g = 200, .b = 200, .a = 255 },
        .background_color = null,
        .padding = Vec2.ZERO,
        .alignment = .left,
    };
};

/// Text content source for reactive labels
pub const TextContent = union(enum) {
    /// Static text that never changes
    static: []const u8,

    /// Dynamic text from a reactive signal
    signal: *signal.Signal([]const u8),

    /// Derived text from reactive dependencies
    derived: *derived.Derived([]const u8),

    /// Text formatted from multiple values
    formatted: FormattedText,

    pub const FormattedText = struct {
        format_string: []const u8,
        values: []const FormattedValue,

        pub const FormattedValue = union(enum) {
            int_signal: *signal.Signal(i64),
            uint_signal: *signal.Signal(u64),
            float_signal: *signal.Signal(f64),
            string_signal: *signal.Signal([]const u8),
            bool_signal: *signal.Signal(bool),
            static_int: i64,
            static_uint: u64,
            static_float: f64,
            static_string: []const u8,
            static_bool: bool,
        };
    };

    pub fn getChangeFrequency(self: *const TextContent) f32 {
        return switch (self.*) {
            .static => 0.0, // Never changes
            .signal => 5.0, // Moderate changes
            .derived => 2.0, // Occasional changes
            .formatted => |fmt| {
                // Estimate based on number of dynamic values
                var dynamic_count: f32 = 0;
                for (fmt.values) |value| {
                    switch (value) {
                        .int_signal, .uint_signal, .float_signal, .string_signal, .bool_signal => dynamic_count += 1,
                        else => {},
                    }
                }
                return dynamic_count * 2.0; // Each dynamic value contributes 2 changes/sec
            },
        };
    }
};

/// Reactive label component data
pub const ReactiveLabelData = struct {
    allocator: std.mem.Allocator,
    position: Vec2,
    style: LabelStyle,
    content: TextContent,

    // Reactive signals
    is_visible: *signal.Signal(bool),
    needs_update: *signal.Signal(bool),
    last_text: *signal.Signal([]const u8),

    // Derived values
    current_text: *derived.Derived([]const u8),
    rendering_mode: rendering_modes.RenderingMode,

    // Cache for text allocation
    cached_text: ?[]const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, position: Vec2, style: LabelStyle, content: TextContent) !Self {
        // Create reactive signals
        const is_visible_signal = try allocator.create(signal.Signal(bool));
        is_visible_signal.* = try signal.Signal(bool).init(allocator, true);

        const needs_update_signal = try allocator.create(signal.Signal(bool));
        needs_update_signal.* = try signal.Signal(bool).init(allocator, true);

        const last_text_signal = try allocator.create(signal.Signal([]const u8));
        last_text_signal.* = try signal.Signal([]const u8).init(allocator, "");

        // Determine rendering mode based on content change frequency
        const change_freq = content.getChangeFrequency();
        const mode_profile = rendering_modes.recommendModeByRate(change_freq);

        var self = Self{
            .allocator = allocator,
            .position = position,
            .style = style,
            .content = content,
            .is_visible = is_visible_signal,
            .needs_update = needs_update_signal,
            .last_text = last_text_signal,
            .current_text = undefined, // Set below
            .rendering_mode = mode_profile.recommended_mode,
            .cached_text = null,
        };

        // Create derived text value
        self.current_text = try self.createCurrentTextDerived();

        loggers.getUILog().info("create_label", "Created reactive label with {s} mode (changes: {d:.2}/sec)", .{ @tagName(self.rendering_mode), change_freq });

        return self;
    }

    fn createCurrentTextDerived(self: *Self) !*derived.Derived([]const u8) {
        const SelfRef = struct {
            var label_ref: *ReactiveLabelData = undefined;
        };
        SelfRef.label_ref = self;

        return try derived.derived(self.allocator, []const u8, struct {
            fn compute() []const u8 {
                const label = SelfRef.label_ref;
                return label.computeText() catch "Error";
            }
        }.compute);
    }

    fn computeText(self: *Self) ![]const u8 {
        // Free previous cached text
        if (self.cached_text) |old_text| {
            self.allocator.free(old_text);
            self.cached_text = null;
        }

        const text = switch (self.content) {
            .static => |static_text| try self.allocator.dupe(u8, static_text),
            .signal => |text_signal| try self.allocator.dupe(u8, text_signal.get()),
            .derived => |text_derived| try self.allocator.dupe(u8, text_derived.get()),
            .formatted => |fmt| try self.formatText(fmt),
        };

        self.cached_text = text;
        return text;
    }

    fn formatText(self: *Self, fmt: TextContent.FormattedText) ![]const u8 {
        var values = std.ArrayList(std.fmt.FormatArg).init(self.allocator);
        defer values.deinit();

        for (fmt.values) |value| {
            const format_arg = switch (value) {
                .int_signal => |sig| std.fmt.FormatArg{ .int = sig.get() },
                .uint_signal => |sig| std.fmt.FormatArg{ .uint = sig.get() },
                .float_signal => |sig| std.fmt.FormatArg{ .float = sig.get() },
                .string_signal => |sig| std.fmt.FormatArg{ .string = sig.get() },
                .bool_signal => |sig| std.fmt.FormatArg{ .bool = sig.get() },
                .static_int => |val| std.fmt.FormatArg{ .int = val },
                .static_uint => |val| std.fmt.FormatArg{ .uint = val },
                .static_float => |val| std.fmt.FormatArg{ .float = val },
                .static_string => |val| std.fmt.FormatArg{ .string = val },
                .static_bool => |val| std.fmt.FormatArg{ .bool = val },
            };
            try values.append(format_arg);
        }

        // Note: This is a simplified implementation - real formatting would need proper argument handling
        return try std.fmt.allocPrint(self.allocator, fmt.format_string, .{});
    }

    pub fn setVisible(self: *Self, visible: bool) void {
        self.is_visible.set(visible);
    }

    pub fn setPosition(self: *Self, position: Vec2) void {
        self.position = position;
        self.needs_update.set(true);
    }

    pub fn updateContent(self: *Self, new_content: TextContent) void {
        self.content = new_content;

        // Update rendering mode based on new content characteristics
        const change_freq = new_content.getChangeFrequency();
        const mode_profile = rendering_modes.recommendModeByRate(change_freq);
        self.rendering_mode = mode_profile.recommended_mode;

        self.needs_update.set(true);

        loggers.getUILog().debug("content_update", "Label content updated, new mode: {s}", .{@tagName(self.rendering_mode)});
    }

    pub fn render(self: *Self, renderer: *text_renderer.TextRenderer, font_manager: anytype, font_category: anytype) !void {
        if (!self.is_visible.peek()) return;

        // Get current text (this will trigger reactive computation if needed)
        const text = self.current_text.get();

        // Check if text has actually changed
        const last_text = self.last_text.peek();
        const text_changed = !std.mem.eql(u8, text, last_text);

        if (text_changed) {
            self.last_text.set(text);

            loggers.getUILog().info("text_change", "Label text changed: '{s}' -> '{s}'", .{ last_text, text });
        }

        // Calculate effective position based on alignment
        const effective_position = self.calculateAlignedPosition(text);

        // Render based on the determined mode
        switch (self.rendering_mode) {
            .immediate => {
                // Use immediate mode for frequently changing content
                const text_result = font_manager.renderTextToTexture(text, font_category, self.style.font_size, self.style.color, renderer.device) catch |err| {
                    loggers.getUILog().err("render_error", "Failed to render immediate label text: {}", .{err});
                    return;
                };

                renderer.queueTextTexture(text_result.texture, effective_position, text_result.width, text_result.height, self.style.color);
            },
            .persistent => {
                // Use persistent mode for stable content
                try renderer.queuePersistentText(text, effective_position, font_manager, font_category, self.style.font_size, self.style.color);
            },
        }

        // Render background if specified
        if (self.style.background_color) |bg_color| {
            // Background rendering available via drawing.zig utilities if needed
            _ = bg_color;
        }

        self.needs_update.set(false);
    }

    fn calculateAlignedPosition(self: *Self, text: []const u8) Vec2 {
        // For now, just return the base position
        // Real implementation would calculate text width and adjust based on alignment
        _ = text;
        return Vec2{
            .x = self.position.x + self.style.padding.x,
            .y = self.position.y + self.style.padding.y,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free cached text
        if (self.cached_text) |text| {
            self.allocator.free(text);
        }

        // Clean up derived value
        self.current_text.deinit();
        self.allocator.destroy(self.current_text);

        // Clean up signals
        self.is_visible.deinit();
        self.allocator.destroy(self.is_visible);
        self.needs_update.deinit();
        self.allocator.destroy(self.needs_update);
        self.last_text.deinit();
        self.allocator.destroy(self.last_text);
    }

    // Component vtable implementation
    fn onMount(state: *anyopaque) !void {
        _ = state;
        loggers.getUILog().info("mount", "Reactive label component mounted", .{});
    }

    fn onUnmount(state: *anyopaque) void {
        _ = state;
        loggers.getUILog().info("unmount", "Reactive label component unmounted", .{});
    }

    fn onRender(state: *anyopaque) !void {
        const self = castComponentState(ReactiveLabelData, state);

        loggers.getUILog().debug("reactive_render", "Reactive label render triggered - visible: {}, needs update: {}", .{ self.is_visible.peek(), self.needs_update.peek() });
    }

    fn shouldRender(state: *anyopaque) bool {
        const self = castComponentState(ReactiveLabelData, state);
        return self.is_visible.peek() and self.needs_update.peek();
    }

    fn destroy(state: *anyopaque, allocator: std.mem.Allocator) void {
        const self = castComponentState(ReactiveLabelData, state);
        self.deinit();
        allocator.destroy(self);
    }

    pub const vtable = ReactiveComponent.ComponentVTable{
        .onMount = ReactiveLabelData.onMount,
        .onUnmount = ReactiveLabelData.onUnmount,
        .onRender = ReactiveLabelData.onRender,
        .shouldRender = ReactiveLabelData.shouldRender,
        .destroy = ReactiveLabelData.destroy,
    };
};

/// Main reactive label component wrapper
pub const ReactiveLabel = struct {
    component: *ReactiveComponent,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, position: Vec2, style: LabelStyle, content: TextContent) !Self {
        const label_data = try ReactiveLabelData.init(allocator, position, style, content);

        const component = try createComponent(ReactiveLabelData, allocator, label_data, ReactiveLabelData.vtable);

        try component.mount();

        return Self{
            .component = component,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.component.deinit();
    }

    pub fn getLabelData(self: *Self) *ReactiveLabelData {
        return getComponentData(ReactiveLabelData, self.component);
    }

    // Convenience methods
    pub fn setVisible(self: *Self, visible: bool) void {
        self.getLabelData().setVisible(visible);
    }

    pub fn setPosition(self: *Self, position: Vec2) void {
        self.getLabelData().setPosition(position);
    }

    pub fn updateContent(self: *Self, new_content: TextContent) void {
        self.getLabelData().updateContent(new_content);
    }

    pub fn render(self: *Self, renderer: *text_renderer.TextRenderer, font_manager: anytype, font_category: anytype) !void {
        try self.getLabelData().render(renderer, font_manager, font_category);
    }
};

/// Helper functions for creating common label types
pub fn createStaticLabel(allocator: std.mem.Allocator, text: []const u8, position: Vec2, style: LabelStyle) !ReactiveLabel {
    return ReactiveLabel.init(allocator, position, style, TextContent{ .static = text });
}

pub fn createSignalLabel(allocator: std.mem.Allocator, text_signal: *signal.Signal([]const u8), position: Vec2, style: LabelStyle) !ReactiveLabel {
    return ReactiveLabel.init(allocator, position, style, TextContent{ .signal = text_signal });
}

pub fn createDerivedLabel(allocator: std.mem.Allocator, text_derived: *derived.Derived([]const u8), position: Vec2, style: LabelStyle) !ReactiveLabel {
    return ReactiveLabel.init(allocator, position, style, TextContent{ .derived = text_derived });
}

/// Common label presets
pub fn createTitle(allocator: std.mem.Allocator, text: []const u8, position: Vec2) !ReactiveLabel {
    return createStaticLabel(allocator, text, position, LabelStyle.title);
}

pub fn createButton(allocator: std.mem.Allocator, text: []const u8, position: Vec2) !ReactiveLabel {
    return createStaticLabel(allocator, text, position, LabelStyle.button);
}

pub fn createSmallLabel(allocator: std.mem.Allocator, text: []const u8, position: Vec2) !ReactiveLabel {
    return createStaticLabel(allocator, text, position, LabelStyle.small);
}

test "reactive label creation and basic operations" {
    const allocator = std.testing.allocator;

    // Test static label
    var static_label = try createTitle(allocator, "Test Title", Vec2{ .x = 100, .y = 200 });
    defer static_label.deinit();

    const label_data = static_label.getLabelData();

    // Test visibility toggle
    static_label.setVisible(false);
    try std.testing.expectEqual(false, label_data.is_visible.peek());

    static_label.setVisible(true);
    try std.testing.expectEqual(true, label_data.is_visible.peek());

    // Test position setting
    const new_pos = Vec2{ .x = 300, .y = 400 };
    static_label.setPosition(new_pos);
    try std.testing.expectEqual(new_pos.x, label_data.position.x);
    try std.testing.expectEqual(new_pos.y, label_data.position.y);
}

test "text content change frequency calculation" {
    const static_content = TextContent{ .static = "Hello" };
    try std.testing.expectEqual(@as(f32, 0.0), static_content.getChangeFrequency());
}

/// Performance analysis for reactive labels
pub const PerformanceAnalysis = struct {
    /// Static labels are perfect for persistent mode:
    /// - Content never changes (0 changes/sec)
    /// - Excellent cache efficiency
    /// - Minimal memory overhead
    pub const static_label_recommendation = rendering_modes.recommendModeByRate(0.0);

    /// Signal-based labels are good for persistent mode:
    /// - Changes based on user actions or events
    /// - Good cache hit rate for stable content
    pub const signal_label_recommendation = rendering_modes.recommendModeByRate(5.0);

    /// Derived labels depend on their dependencies:
    /// - Change frequency varies based on inputs
    /// - System automatically selects appropriate mode
    pub const derived_label_recommendation = rendering_modes.recommendModeByRate(2.0);
};

test "label style defaults" {
    const testing = std.testing;
    
    const style = LabelStyle.default;
    
    // Test default values
    try testing.expectEqual(@as(f32, 24.0), style.font_size);
    try testing.expectEqual(Color{ .r = 255, .g = 255, .b = 255, .a = 255 }, style.color);
    try testing.expectEqual(@as(?Color, null), style.background_color);
    try testing.expectEqual(Vec2.ZERO, style.padding);
    try testing.expectEqual(LabelStyle.TextAlignment.left, style.alignment);
}

test "label style button preset" {
    const testing = std.testing;
    
    const style = LabelStyle.button;
    
    // Test button preset values
    try testing.expectEqual(@as(f32, 18.0), style.font_size);
    try testing.expectEqual(Color{ .r = 255, .g = 255, .b = 255, .a = 255 }, style.color);
    try testing.expectEqual(Color{ .r = 64, .g = 64, .b = 64, .a = 200 }, style.background_color.?);
    try testing.expectEqual(Vec2{ .x = 8, .y = 4 }, style.padding);
    try testing.expectEqual(LabelStyle.TextAlignment.center, style.alignment);
}

test "label style title preset" {
    const testing = std.testing;
    
    const style = LabelStyle.title;
    
    // Test title preset values
    try testing.expectEqual(@as(f32, 36.0), style.font_size);
}

test "text alignment enum values" {
    const testing = std.testing;
    
    // Test that all alignment values exist and are distinct
    const left = LabelStyle.TextAlignment.left;
    const center = LabelStyle.TextAlignment.center;
    const right = LabelStyle.TextAlignment.right;
    
    try testing.expect(left != center);
    try testing.expect(center != right);
    try testing.expect(left != right);
}

test "custom label style" {
    const testing = std.testing;
    
    const custom_style = LabelStyle{
        .font_size = 20.0,
        .color = Color{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .background_color = Color{ .r = 0, .g = 0, .b = 0, .a = 128 },
        .padding = Vec2{ .x = 12, .y = 6 },
        .alignment = .right,
    };
    
    try testing.expectEqual(@as(f32, 20.0), custom_style.font_size);
    try testing.expectEqual(Color{ .r = 255, .g = 0, .b = 0, .a = 255 }, custom_style.color);
    try testing.expectEqual(Color{ .r = 0, .g = 0, .b = 0, .a = 128 }, custom_style.background_color.?);
    try testing.expectEqual(Vec2{ .x = 12, .y = 6 }, custom_style.padding);
    try testing.expectEqual(LabelStyle.TextAlignment.right, custom_style.alignment);
}
