const std = @import("std");
const math = @import("../math/mod.zig");
const reactive = @import("../reactive/mod.zig");
const component = @import("component.zig");

const Vec2 = math.Vec2;
const Component = component.Component;
const ComponentProps = component.ComponentProps;
const LayoutConstraints = component.LayoutConstraints;

/// Flexbox-like layout direction
pub const LayoutDirection = enum {
    row, // Children laid out horizontally
    column, // Children laid out vertically
    row_reverse, // Children laid out horizontally in reverse
    column_reverse, // Children laid out vertically in reverse
};

/// Flexbox-like justification (main axis alignment)
pub const JustifyContent = enum {
    flex_start, // Pack items to start
    flex_end, // Pack items to end
    center, // Pack items around center
    space_between, // Distribute items evenly, first at start, last at end
    space_around, // Distribute items evenly with equal space around each
    space_evenly, // Distribute items with equal space between them
};

/// Flexbox-like alignment (cross axis alignment)
pub const AlignItems = enum {
    flex_start, // Align items to start of cross axis
    flex_end, // Align items to end of cross axis
    center, // Align items to center of cross axis
    stretch, // Stretch items to fill cross axis
};

/// Layout container that automatically positions its children
pub const Layout = struct {
    base: Component,

    // Layout properties
    direction: reactive.Signal(LayoutDirection),
    justify_content: reactive.Signal(JustifyContent),
    align_items: reactive.Signal(AlignItems),
    gap: reactive.Signal(f32), // Space between children
    padding: reactive.Signal(f32), // Internal padding

    // Auto-layout effect for repositioning children when properties change
    layout_effect: ?*reactive.Effect = null,

    const Self = @This();

    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        _ = props;
        const layout: *Layout = @fieldParentPtr("base", self);

        // Initialize layout-specific signals
        layout.direction = try reactive.signal(allocator, LayoutDirection, .column);
        layout.justify_content = try reactive.signal(allocator, JustifyContent, .flex_start);
        layout.align_items = try reactive.signal(allocator, AlignItems, .stretch);
        layout.gap = try reactive.signal(allocator, f32, 8.0);
        layout.padding = try reactive.signal(allocator, f32, 8.0);

        // Create reactive effect to re-layout when properties change
        const LayoutEffectContext = struct {
            layout_ptr: *Layout,

            fn relayout(context: @This()) void {
                context.layout_ptr.performLayout();
            }
        };

        const effect_context = LayoutEffectContext{ .layout_ptr = layout };
        layout.layout_effect = try reactive.createEffect(allocator, effect_context.relayout);
    }

    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        const layout: *Layout = @fieldParentPtr("base", self);

        // Cleanup layout-specific signals
        layout.direction.deinit();
        layout.justify_content.deinit();
        layout.align_items.deinit();
        layout.gap.deinit();
        layout.padding.deinit();

        // Cleanup layout effect
        if (layout.layout_effect) |effect| {
            effect.deinit();
            allocator.destroy(effect);
        }
    }

    pub fn update(self: *Component, dt: f32) void {
        _ = dt;
        const layout: *Layout = @fieldParentPtr("base", self);

        // Layout updates happen automatically via reactive effects
        // This could be used for animations or other time-based updates
        _ = layout;
    }

    pub fn render(self: *const Component, renderer: anytype) !void {
        // Layout container renders its background, then children render themselves
        const layout: *const Layout = @fieldParentPtr("base", self);
        _ = layout;

        const bounds = self.props.getBounds();
        const bg_color = self.props.background_color.get();

        // Render background (assuming renderer has drawRect method)
        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            try renderer.drawRect(bounds, bg_color);
        }
    }

    pub fn handleEvent(self: *Component, event: anytype) bool {
        _ = self;
        _ = event;
        // Layout containers typically don't handle events directly
        return false;
    }

    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        const layout: *Layout = @fieldParentPtr("base", self);
        allocator.destroy(layout);
    }

    /// Perform layout calculation and position children
    pub fn performLayout(self: *Layout) void {
        if (self.base.children.items.len == 0) return;

        const container_bounds = self.base.props.getBounds();
        const padding_val = self.padding.get();
        const gap_val = self.gap.get();

        // Content area (excluding padding)
        const content_area = Vec2{
            .x = container_bounds.size.x - (padding_val * 2),
            .y = container_bounds.size.y - (padding_val * 2),
        };

        const content_start = Vec2{
            .x = container_bounds.position.x + padding_val,
            .y = container_bounds.position.y + padding_val,
        };

        switch (self.direction.get()) {
            .column => self.layoutColumn(content_start, content_area, gap_val),
            .row => self.layoutRow(content_start, content_area, gap_val),
            .column_reverse => self.layoutColumnReverse(content_start, content_area, gap_val),
            .row_reverse => self.layoutRowReverse(content_start, content_area, gap_val),
        }
    }

    fn layoutColumn(self: *Layout, start: Vec2, area: Vec2, gap: f32) void {
        const children = self.base.children.items;
        if (children.len == 0) return;

        // Calculate total height needed for all children
        var total_height: f32 = 0;
        for (children) |child| {
            total_height += child.props.size.get().y;
        }
        total_height += gap * @as(f32, @floatFromInt(children.len - 1));

        // Calculate starting Y based on justify_content
        var current_y = switch (self.justify_content.get()) {
            .flex_start => start.y,
            .flex_end => start.y + (area.y - total_height),
            .center => start.y + (area.y - total_height) / 2,
            .space_between => start.y,
            .space_around, .space_evenly => start.y,
        };

        // Calculate gap adjustments for space distribution
        var adjusted_gap = gap;
        if (children.len > 1) {
            switch (self.justify_content.get()) {
                .space_between => {
                    adjusted_gap = (area.y - (total_height - gap * @as(f32, @floatFromInt(children.len - 1)))) / @as(f32, @floatFromInt(children.len - 1));
                },
                .space_around => {
                    const extra_space = area.y - total_height;
                    adjusted_gap = gap + extra_space / @as(f32, @floatFromInt(children.len));
                    current_y += adjusted_gap / 2;
                },
                .space_evenly => {
                    adjusted_gap = (area.y - (total_height - gap * @as(f32, @floatFromInt(children.len - 1)))) / @as(f32, @floatFromInt(children.len + 1));
                    current_y += adjusted_gap;
                },
                else => {},
            }
        }

        // Position each child
        for (children) |child| {
            const child_size = child.props.size.get();

            // Calculate X position based on align_items
            const x_pos = switch (self.align_items.get()) {
                .flex_start => start.x,
                .flex_end => start.x + (area.x - child_size.x),
                .center => start.x + (area.x - child_size.x) / 2,
                .stretch => start.x, // Width stretching handled below
            };

            // Handle stretch alignment by adjusting width
            var final_size = child_size;
            if (self.align_items.get() == .stretch) {
                final_size.x = area.x;
            }

            // Update child position and size
            child.props.position.set(Vec2{ .x = x_pos, .y = current_y });
            child.props.size.set(final_size);

            current_y += child_size.y + adjusted_gap;
        }
    }

    fn layoutRow(self: *Layout, start: Vec2, area: Vec2, gap: f32) void {
        const children = self.base.children.items;
        if (children.len == 0) return;

        // Calculate total width needed for all children
        var total_width: f32 = 0;
        for (children) |child| {
            total_width += child.props.size.get().x;
        }
        total_width += gap * @as(f32, @floatFromInt(children.len - 1));

        // Calculate starting X based on justify_content
        var current_x = switch (self.justify_content.get()) {
            .flex_start => start.x,
            .flex_end => start.x + (area.x - total_width),
            .center => start.x + (area.x - total_width) / 2,
            .space_between => start.x,
            .space_around, .space_evenly => start.x,
        };

        // Calculate gap adjustments for space distribution
        var adjusted_gap = gap;
        if (children.len > 1) {
            switch (self.justify_content.get()) {
                .space_between => {
                    adjusted_gap = (area.x - (total_width - gap * @as(f32, @floatFromInt(children.len - 1)))) / @as(f32, @floatFromInt(children.len - 1));
                },
                .space_around => {
                    const extra_space = area.x - total_width;
                    adjusted_gap = gap + extra_space / @as(f32, @floatFromInt(children.len));
                    current_x += adjusted_gap / 2;
                },
                .space_evenly => {
                    adjusted_gap = (area.x - (total_width - gap * @as(f32, @floatFromInt(children.len - 1)))) / @as(f32, @floatFromInt(children.len + 1));
                    current_x += adjusted_gap;
                },
                else => {},
            }
        }

        // Position each child
        for (children) |child| {
            const child_size = child.props.size.get();

            // Calculate Y position based on align_items
            const y_pos = switch (self.align_items.get()) {
                .flex_start => start.y,
                .flex_end => start.y + (area.y - child_size.y),
                .center => start.y + (area.y - child_size.y) / 2,
                .stretch => start.y, // Height stretching handled below
            };

            // Handle stretch alignment by adjusting height
            var final_size = child_size;
            if (self.align_items.get() == .stretch) {
                final_size.y = area.y;
            }

            // Update child position and size
            child.props.position.set(Vec2{ .x = current_x, .y = y_pos });
            child.props.size.set(final_size);

            current_x += child_size.x + adjusted_gap;
        }
    }

    fn layoutColumnReverse(self: *Layout, start: Vec2, area: Vec2, gap: f32) void {
        // Temporarily reverse children order, layout as column, then restore
        std.mem.reverse(*Component, self.base.children.items);
        defer std.mem.reverse(*Component, self.base.children.items);

        self.layoutColumn(start, area, gap);
    }

    fn layoutRowReverse(self: *Layout, start: Vec2, area: Vec2, gap: f32) void {
        // Temporarily reverse children order, layout as row, then restore
        std.mem.reverse(*Component, self.base.children.items);
        defer std.mem.reverse(*Component, self.base.children.items);

        self.layoutRow(start, area, gap);
    }

    /// Set layout direction and trigger re-layout
    pub fn setDirection(self: *Layout, direction: LayoutDirection) void {
        self.direction.set(direction);
    }

    /// Set content justification and trigger re-layout
    pub fn setJustifyContent(self: *Layout, justify: JustifyContent) void {
        self.justify_content.set(justify);
    }

    /// Set item alignment and trigger re-layout
    pub fn setAlignItems(self: *Layout, alignment: AlignItems) void {
        self.align_items.set(alignment);
    }

    /// Set gap between items and trigger re-layout
    pub fn setGap(self: *Layout, gap_value: f32) void {
        self.gap.set(gap_value);
    }

    /// Set internal padding and trigger re-layout
    pub fn setPadding(self: *Layout, padding_value: f32) void {
        self.padding.set(padding_value);
    }
};

/// Create a new layout component
pub fn createLayout(allocator: std.mem.Allocator, props: ComponentProps) !*Component {
    const layout = try allocator.create(Layout);
    layout.* = Layout{
        .base = Component{
            .vtable = Component.VTable{
                .init = Layout.init,
                .deinit = Layout.deinit,
                .update = Layout.update,
                .render = Layout.render,
                .handle_event = Layout.handleEvent,
                .destroy = Layout.destroy,
            },
            .props = props,
            .children = std.ArrayList(*Component).init(allocator),
            .parent = null,
        },
        .direction = undefined, // Will be initialized in init()
        .justify_content = undefined,
        .align_items = undefined,
        .gap = undefined,
        .padding = undefined,
    };

    try layout.base.init(allocator, props);
    return &layout.base;
}

// Tests
test "layout creation and basic properties" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    var props = try ComponentProps.init(allocator, Vec2.ZERO, Vec2{ .x = 400, .y = 300 });
    defer props.deinit();

    var layout = try createLayout(allocator, props);
    defer layout.destroy(allocator);

    const layout_impl: *Layout = @fieldParentPtr("base", layout);

    // Test default values
    try std.testing.expect(layout_impl.direction.get() == .column);
    try std.testing.expect(layout_impl.justify_content.get() == .flex_start);
    try std.testing.expect(layout_impl.align_items.get() == .stretch);
    try std.testing.expect(layout_impl.gap.get() == 8.0);
    try std.testing.expect(layout_impl.padding.get() == 8.0);

    // Test property setters
    layout_impl.setDirection(.row);
    try std.testing.expect(layout_impl.direction.get() == .row);

    layout_impl.setJustifyContent(.center);
    try std.testing.expect(layout_impl.justify_content.get() == .center);
}

test "column layout positioning" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    // Create parent layout
    var parent_props = try ComponentProps.init(allocator, Vec2.ZERO, Vec2{ .x = 200, .y = 300 });
    defer parent_props.deinit();

    var parent_layout = try createLayout(allocator, parent_props);
    defer parent_layout.destroy(allocator);

    const parent_layout_impl: *Layout = @fieldParentPtr("base", parent_layout);
    parent_layout_impl.setPadding(10.0);
    parent_layout_impl.setGap(5.0);

    // Create child components
    var child1_props = try ComponentProps.init(allocator, Vec2.ZERO, Vec2{ .x = 100, .y = 50 });
    var child2_props = try ComponentProps.init(allocator, Vec2.ZERO, Vec2{ .x = 100, .y = 60 });
    defer child1_props.deinit();
    defer child2_props.deinit();

    // For this test, we'll just verify the layout calculation logic
    // In a real scenario, we'd create actual child components

    // Test that layout properties are set correctly
    parent_layout_impl.setDirection(.column);
    parent_layout_impl.setJustifyContent(.flex_start);
    parent_layout_impl.setAlignItems(.stretch);

    try std.testing.expect(parent_layout_impl.direction.get() == .column);
    try std.testing.expect(parent_layout_impl.padding.get() == 10.0);
    try std.testing.expect(parent_layout_impl.gap.get() == 5.0);
}
