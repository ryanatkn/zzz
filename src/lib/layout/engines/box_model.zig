const std = @import("std");
const math = @import("../../math/mod.zig");
const reactive = @import("../../reactive/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Spacing = types.Spacing;
const SizingMode = types.SizingMode;
const Constraints = types.Constraints;

/// CSS-like box model for UI layout with dirty flag optimization
/// Follows web standards: content -> padding -> border -> margin
pub const BoxModel = struct {
    /// Computed layout areas (read-only, calculated from box properties)
    pub const ComputedLayout = struct {
        /// Content area (inner content)
        content: Rectangle,
        /// Padding area (content + padding)
        padding: Rectangle,
        /// Border area (content + padding + border)
        border: Rectangle,
        /// Margin area (content + padding + border + margin)
        margin: Rectangle,

        /// Full outer bounds (same as margin area)
        outer_bounds: Rectangle,

        /// Dirty flag - set to true when layout needs recalculation
        dirty: bool = true,

        pub fn init() ComputedLayout {
            const empty_rect = Rectangle{ .position = Vec2.ZERO, .size = Vec2.ZERO };
            return ComputedLayout{
                .content = empty_rect,
                .padding = empty_rect,
                .border = empty_rect,
                .margin = empty_rect,
                .outer_bounds = empty_rect,
                .dirty = true,
            };
        }
    };

    // Box properties
    position: reactive.Signal(Vec2),
    size: reactive.Signal(Vec2),
    sizing_mode: reactive.Signal(SizingMode),

    // Spacing properties
    padding: reactive.Signal(Spacing),
    border_width: reactive.Signal(Spacing),
    margin: reactive.Signal(Spacing),

    // Layout constraints
    constraints: reactive.Signal(Constraints),

    // Computed layout (cached, invalidated by dirty flag)
    computed: ComputedLayout,

    // Layout invalidation tracking
    layout_effect: ?*reactive.Effect = null,

    const Self = @This();

    /// Initialize a new box model
    pub fn init(allocator: std.mem.Allocator, initial_position: Vec2, initial_size: Vec2) !Self {
        return Self{
            .position = try reactive.signal(allocator, Vec2, initial_position),
            .size = try reactive.signal(allocator, Vec2, initial_size),
            .sizing_mode = try reactive.signal(allocator, SizingMode, .content_box),
            .padding = try reactive.signal(allocator, Spacing, Spacing{}),
            .border_width = try reactive.signal(allocator, Spacing, Spacing{}),
            .margin = try reactive.signal(allocator, Spacing, Spacing{}),
            .constraints = try reactive.signal(allocator, Constraints, Constraints{}),
            .computed = ComputedLayout.init(),
            .layout_effect = null,
        };
    }

    /// Initialize with reactive layout invalidation
    pub fn initWithReactivity(allocator: std.mem.Allocator, initial_position: Vec2, initial_size: Vec2) !Self {
        var self = try Self.init(allocator, initial_position, initial_size);

        // Create effect to mark layout dirty when any property changes
        // We'll need to store the pointer globally for the effect function to access
        // For now, disable reactivity until this pattern is properly implemented
        self.layout_effect = null;

        return self;
    }

    /// Clean up resources
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.position.deinit();
        self.size.deinit();
        self.sizing_mode.deinit();
        self.padding.deinit();
        self.border_width.deinit();
        self.margin.deinit();
        self.constraints.deinit();

        if (self.layout_effect) |effect| {
            effect.deinit();
            allocator.destroy(effect);
        }
    }

    /// Get computed layout, recalculating if dirty
    pub fn getLayout(self: *Self) *const ComputedLayout {
        if (self.computed.dirty) {
            self.computeLayout();
        }
        return &self.computed;
    }

    /// Force layout recalculation on next access
    pub fn markDirty(self: *Self) void {
        self.computed.dirty = true;
    }

    /// Check if layout needs recalculation
    pub fn isDirty(self: *const Self) bool {
        return self.computed.dirty;
    }

    /// Compute all layout areas based on current properties
    fn computeLayout(self: *Self) void {
        const pos = self.position.get();
        const size = self.size.get();
        const mode = self.sizing_mode.get();
        const padding_space = self.padding.get();
        const border_space = self.border_width.get();
        const margin_space = self.margin.get();
        const constraints = self.constraints.get();

        // Calculate content size based on sizing mode
        const content_size = switch (mode) {
            .content_box => blk: {
                // Size includes only content
                break :blk constraints.constrain(size);
            },
            .border_box => blk: {
                // Size includes content + padding + border, so subtract to get content
                const padding_border_total = Vec2{
                    .x = padding_space.getHorizontal() + border_space.getHorizontal(),
                    .y = padding_space.getVertical() + border_space.getVertical(),
                };
                const content_size_calc = Vec2{
                    .x = size.x - padding_border_total.x,
                    .y = size.y - padding_border_total.y,
                };
                break :blk constraints.constrain(Vec2{
                    .x = @max(0, content_size_calc.x),
                    .y = @max(0, content_size_calc.y),
                });
            },
        };

        // Calculate areas from inside out (content -> padding -> border -> margin)

        // Content area
        self.computed.content = Rectangle{
            .position = Vec2{
                .x = pos.x + margin_space.left + border_space.left + padding_space.left,
                .y = pos.y + margin_space.top + border_space.top + padding_space.top,
            },
            .size = content_size,
        };

        // Padding area (content + padding)
        self.computed.padding = Rectangle{
            .position = Vec2{
                .x = self.computed.content.position.x - padding_space.left,
                .y = self.computed.content.position.y - padding_space.top,
            },
            .size = Vec2{
                .x = content_size.x + padding_space.getHorizontal(),
                .y = content_size.y + padding_space.getVertical(),
            },
        };

        // Border area (content + padding + border)
        self.computed.border = Rectangle{
            .position = Vec2{
                .x = self.computed.padding.position.x - border_space.left,
                .y = self.computed.padding.position.y - border_space.top,
            },
            .size = Vec2{
                .x = self.computed.padding.size.x + border_space.getHorizontal(),
                .y = self.computed.padding.size.y + border_space.getVertical(),
            },
        };

        // Margin area (content + padding + border + margin)
        self.computed.margin = Rectangle{
            .position = Vec2{
                .x = self.computed.border.position.x - margin_space.left,
                .y = self.computed.border.position.y - margin_space.top,
            },
            .size = Vec2{
                .x = self.computed.border.size.x + margin_space.getHorizontal(),
                .y = self.computed.border.size.y + margin_space.getVertical(),
            },
        };

        // Outer bounds (same as margin area)
        self.computed.outer_bounds = self.computed.margin;

        // Mark as clean
        self.computed.dirty = false;
    }

    /// Update position and mark dirty
    pub fn setPosition(self: *Self, new_position: Vec2) void {
        self.position.set(new_position);
        self.markDirty();
    }

    /// Update size and mark dirty
    pub fn setSize(self: *Self, new_size: Vec2) void {
        self.size.set(new_size);
        self.markDirty();
    }

    /// Set uniform padding
    pub fn setPadding(self: *Self, padding: f32) void {
        self.padding.set(Spacing.uniform(padding));
        self.markDirty();
    }

    /// Set padding per side
    pub fn setPaddingDetailed(self: *Self, top: f32, right: f32, bottom: f32, left: f32) void {
        self.padding.set(Spacing{ .top = top, .right = right, .bottom = bottom, .left = left });
        self.markDirty();
    }

    /// Set uniform margin
    pub fn setMargin(self: *Self, margin: f32) void {
        self.margin.set(Spacing.uniform(margin));
        self.markDirty();
    }

    /// Set border width
    pub fn setBorderWidth(self: *Self, width: f32) void {
        self.border_width.set(Spacing.uniform(width));
        self.markDirty();
    }

    /// Set sizing mode
    pub fn setSizingMode(self: *Self, mode: SizingMode) void {
        self.sizing_mode.set(mode);
        self.markDirty();
    }

    /// Set constraints
    pub fn setConstraints(self: *Self, constraints: Constraints) void {
        self.constraints.set(constraints);
        self.markDirty();
    }

    /// Get content rectangle (for placing child elements)
    pub fn getContentBounds(self: *Self) Rectangle {
        return self.getLayout().content;
    }

    /// Get padding rectangle (for background rendering)
    pub fn getPaddingBounds(self: *Self) Rectangle {
        return self.getLayout().padding;
    }

    /// Get border rectangle (for border rendering)
    pub fn getBorderBounds(self: *Self) Rectangle {
        return self.getLayout().border;
    }

    /// Get outer bounds (for hit testing, positioning)
    pub fn getOuterBounds(self: *Self) Rectangle {
        return self.getLayout().outer_bounds;
    }
};

// Tests
test "box model basic sizing" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    var box = try BoxModel.init(allocator, Vec2{ .x = 10, .y = 20 }, Vec2{ .x = 100, .y = 50 });
    defer box.deinit(allocator);

    // Initially, content should equal specified size with no spacing
    const layout = box.getLayout();
    try testing.expect(layout.content.size.x == 100);
    try testing.expect(layout.content.size.y == 50);
    try testing.expect(layout.content.position.x == 10);
    try testing.expect(layout.content.position.y == 20);
}

test "box model with padding" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    var box = try BoxModel.init(allocator, Vec2.ZERO, Vec2{ .x = 100, .y = 50 });
    defer box.deinit(allocator);

    box.setPadding(10);

    const layout = box.getLayout();

    // Content area should be same size
    try testing.expect(layout.content.size.x == 100);
    try testing.expect(layout.content.size.y == 50);

    // Content should be offset by padding
    try testing.expect(layout.content.position.x == 10);
    try testing.expect(layout.content.position.y == 10);

    // Padding area should be larger
    try testing.expect(layout.padding.size.x == 120);
    try testing.expect(layout.padding.size.y == 70);
}

test "box model border-box sizing" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    var box = try BoxModel.init(allocator, Vec2.ZERO, Vec2{ .x = 100, .y = 50 });
    defer box.deinit(allocator);

    box.setPadding(10);
    box.setSizingMode(.border_box);

    const layout = box.getLayout();

    // In border-box mode, total size should be 100x50
    try testing.expect(layout.padding.size.x == 100);
    try testing.expect(layout.padding.size.y == 50);

    // Content should be reduced by padding
    try testing.expect(layout.content.size.x == 80); // 100 - 20
    try testing.expect(layout.content.size.y == 30); // 50 - 20
}

test "box model dirty flags" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    var box = try BoxModel.init(allocator, Vec2.ZERO, Vec2{ .x = 100, .y = 50 });
    defer box.deinit(allocator);

    // Layout should be dirty initially
    try testing.expect(box.isDirty());

    // Access should clean it
    _ = box.getLayout();
    try testing.expect(!box.isDirty());

    // Changing properties should mark dirty
    box.setPadding(5);
    try testing.expect(box.isDirty());
}