/// CSS box model layout algorithm implementation
const std = @import("std");
const math = @import("../../../math/mod.zig");
const core = @import("../../core/types.zig");
const interface = @import("../../core/interface.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const LayoutElement = interface.LayoutElement;
const LayoutResult = core.LayoutResult;
const LayoutContext = core.LayoutContext;
const Spacing = core.Spacing;
const Constraints = core.Constraints;

/// CSS-like box model implementation with dirty flag pattern
pub const BoxModel = struct {
    allocator: std.mem.Allocator,

    // Box model state
    position: Vec2,
    size: Vec2,
    padding: Spacing,
    margin: Spacing,
    border: Spacing,
    constraints: Constraints,

    // Cached computed layout
    cached_layout: ?ComputedLayout,

    // Dirty tracking
    dirty: bool,

    /// Box sizing mode (CSS box-sizing)
    pub const SizingMode = enum {
        /// Width/height includes only content (CSS content-box)
        content_box,
        /// Width/height includes content + padding + border (CSS border-box)
        border_box,
    };

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

        /// Get the content rectangle
        pub fn getContentArea(self: ComputedLayout) Rectangle {
            return self.content;
        }

        /// Get the border rectangle (content + padding + border)
        pub fn getBorderArea(self: ComputedLayout) Rectangle {
            return self.border;
        }

        /// Get the full outer bounds (including margin)
        pub fn getOuterBounds(self: ComputedLayout) Rectangle {
            return self.outer_bounds;
        }
    };

    pub fn init(allocator: std.mem.Allocator, position: Vec2, element_size: Vec2) !BoxModel {
        return BoxModel{
            .allocator = allocator,
            .position = position,
            .size = element_size,
            .padding = Spacing{},
            .margin = Spacing{},
            .border = Spacing{},
            .constraints = Constraints{},
            .cached_layout = null,
            .dirty = true,
        };
    }

    pub fn deinit(self: *BoxModel, allocator: std.mem.Allocator) void {
        _ = allocator;
        _ = self;
        // No cleanup needed for simple struct fields
    }

    /// Get the current computed layout (with caching)
    pub fn getLayout(self: *BoxModel) ComputedLayout {
        if (self.dirty or self.cached_layout == null) {
            self.cached_layout = self.computeLayout();
            self.dirty = false;
        }
        return self.cached_layout.?;
    }

    /// Compute layout from current box model state
    fn computeLayout(self: *const BoxModel) ComputedLayout {
        return calculateBoxModel(self.position, self.size, self.padding, self.margin, self.border);
    }

    /// Set position and mark dirty
    pub fn setPosition(self: *BoxModel, position: Vec2) void {
        self.position = position;
        self.markDirty();
    }

    /// Set size and mark dirty
    pub fn setSize(self: *BoxModel, size: Vec2) void {
        self.size = size;
        self.markDirty();
    }

    /// Set padding uniformly
    pub fn setPadding(self: *BoxModel, padding: f32) void {
        self.padding = Spacing.uniform(padding);
        self.markDirty();
    }

    /// Set padding per side
    pub fn setPaddingDetailed(self: *BoxModel, top: f32, right: f32, bottom: f32, left: f32) void {
        self.padding = Spacing{ .top = top, .right = right, .bottom = bottom, .left = left };
        self.markDirty();
    }

    /// Set margin uniformly
    pub fn setMargin(self: *BoxModel, margin: f32) void {
        self.margin = Spacing.uniform(margin);
        self.markDirty();
    }

    /// Set constraints
    pub fn setConstraints(self: *BoxModel, constraints: Constraints) void {
        self.constraints = constraints;
        self.markDirty();
    }

    /// Mark as needing recalculation
    pub fn markDirty(self: *BoxModel) void {
        self.dirty = true;
        self.cached_layout = null;
    }

    /// Check if layout needs recalculation
    pub fn isDirty(self: *BoxModel) bool {
        return self.dirty;
    }

    /// Clear dirty flag
    pub fn clearDirty(self: *BoxModel) void {
        self.dirty = false;
    }
};

/// Pure function to calculate box model layout areas
/// Note: `size` parameter represents the content size, not total element size
pub fn calculateBoxModel(position: Vec2, content_size: Vec2, padding: Spacing, margin: Spacing, border: Spacing) BoxModel.ComputedLayout {
    // Content area (innermost) - position offset by all spacing, size as specified
    const content = Rectangle{
        .position = Vec2{
            .x = position.x + margin.left + border.left + padding.left,
            .y = position.y + margin.top + border.top + padding.top,
        },
        .size = content_size,
    };

    // Padding area (content + padding)
    const padding_area = Rectangle{
        .position = Vec2{
            .x = position.x + margin.left + border.left,
            .y = position.y + margin.top + border.top,
        },
        .size = Vec2{
            .x = content_size.x + padding.left + padding.right,
            .y = content_size.y + padding.top + padding.bottom,
        },
    };

    // Border area (content + padding + border)
    const border_area = Rectangle{
        .position = Vec2{
            .x = position.x + margin.left,
            .y = position.y + margin.top,
        },
        .size = Vec2{
            .x = content_size.x + padding.left + padding.right + border.left + border.right,
            .y = content_size.y + padding.top + padding.bottom + border.top + border.bottom,
        },
    };

    // Margin area (outermost - full element bounds)
    const margin_area = Rectangle{
        .position = position,
        .size = Vec2{
            .x = content_size.x + padding.left + padding.right + border.left + border.right + margin.left + margin.right,
            .y = content_size.y + padding.top + padding.bottom + border.top + border.bottom + margin.top + margin.bottom,
        },
    };

    return BoxModel.ComputedLayout{
        .content = content,
        .padding = padding_area,
        .border = border_area,
        .margin = margin_area,
        .outer_bounds = margin_area,
    };
}

/// Box model layout algorithm implementation
pub const BoxModelAlgorithm = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BoxModelAlgorithm {
        return BoxModelAlgorithm{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BoxModelAlgorithm) void {
        _ = self;
    }

    /// Calculate layout using box model algorithm
    pub fn calculate(
        self: *BoxModelAlgorithm,
        elements: []LayoutElement,
        context: LayoutContext,
        allocator: std.mem.Allocator,
    ) ![]LayoutResult {
        _ = self;

        var results = try allocator.alloc(LayoutResult, elements.len);

        for (elements, 0..) |*element, i| {
            // Create temporary box model for calculation
            var box_model = try BoxModel.init(allocator, element.position, element.size);
            defer box_model.deinit(allocator);

            // Apply element properties
            box_model.padding = element.padding;
            box_model.margin = element.margin;
            box_model.constraints = element.constraints;
            box_model.markDirty();

            // Handle parent-child relationships
            if (element.parent_index) |parent_idx| {
                if (parent_idx < i) {
                    const parent_layout = results[parent_idx];
                    // Position relative to parent's content area
                    const relative_pos = Vec2{
                        .x = parent_layout.content.position.x + element.position.x,
                        .y = parent_layout.content.position.y + element.position.y,
                    };
                    box_model.setPosition(relative_pos);
                }
            } else {
                // Position relative to container
                const container_pos = Vec2{
                    .x = context.container_bounds.position.x + element.position.x,
                    .y = context.container_bounds.position.y + element.position.y,
                };
                box_model.setPosition(container_pos);
            }

            // Get computed layout
            const computed = box_model.getLayout();

            results[i] = LayoutResult{
                .position = computed.border.position,
                .size = computed.border.size,
                .content = computed.content,
                .valid = true,
            };
        }

        return results;
    }

    /// Get algorithm capabilities
    pub fn getCapabilities(self: *BoxModelAlgorithm) interface.AlgorithmCapabilities {
        _ = self;
        return interface.AlgorithmCapabilities{
            .name = "Box Model",
            .features = .{
                .nesting = true,
                .flexible_sizing = false,
                .alignment = false,
                .spacing = true,
                .text_layout = false,
            },
        };
    }

    /// Check if algorithm can handle the given elements
    pub fn canHandle(self: *BoxModelAlgorithm, elements: []const LayoutElement, context: LayoutContext) bool {
        _ = self;
        _ = context;
        // Box model can handle any number of elements
        return elements.len <= 10000;
    }

    /// Get algorithm name
    pub fn getName(self: *BoxModelAlgorithm) []const u8 {
        _ = self;
        return "Box Model";
    }
};

// Tests
test "box model creation and basic properties" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var box = try BoxModel.init(allocator, Vec2{ .x = 10, .y = 20 }, Vec2{ .x = 100, .y = 50 });
    defer box.deinit(allocator);

    const layout = box.getLayout();

    // Should have correct content position and size
    try testing.expect(layout.content.position.x == 10);
    try testing.expect(layout.content.position.y == 20);
    try testing.expect(layout.content.size.x == 100);
    try testing.expect(layout.content.size.y == 50);
}

test "box model with padding" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var box = try BoxModel.init(allocator, Vec2.ZERO, Vec2{ .x = 100, .y = 50 });
    defer box.deinit(allocator);

    box.setPadding(10);

    const layout = box.getLayout();

    // Content should be inset by padding
    try testing.expect(layout.content.position.x == 10);
    try testing.expect(layout.content.position.y == 10);
    try testing.expect(layout.content.size.x == 100);
    try testing.expect(layout.content.size.y == 50);

    // Padding area should include padding
    try testing.expect(layout.padding.size.x == 120); // 100 + 10*2
    try testing.expect(layout.padding.size.y == 70); // 50 + 10*2
}

test "box model algorithm" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var algorithm = BoxModelAlgorithm.init(allocator);
    defer algorithm.deinit();

    var elements = [_]LayoutElement{
        LayoutElement{
            .position = Vec2{ .x = 10, .y = 10 },
            .size = Vec2{ .x = 100, .y = 50 },
            .margin = Spacing.uniform(5),
            .padding = Spacing.uniform(10),
            .constraints = Constraints{},
        },
    };

    const context = LayoutContext{
        .container_bounds = Rectangle{
            .position = Vec2.ZERO,
            .size = Vec2{ .x = 800, .y = 600 },
        },
    };

    const results = try algorithm.calculate(&elements, context, allocator);
    defer allocator.free(results);

    try testing.expect(results.len == 1);
    try testing.expect(results[0].valid);

    // Content should be positioned accounting for margin and padding
    try testing.expect(results[0].content.position.x == 25); // 10 + 5 + 10
    try testing.expect(results[0].content.position.y == 25); // 10 + 5 + 10
}
