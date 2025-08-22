/// Common interface for all layout algorithms and implementations
const std = @import("std");
const types = @import("types.zig");

const LayoutResult = types.LayoutResult;
const LayoutContext = types.LayoutContext;
const Vec2 = types.Vec2;
const Constraints = types.Constraints;
const Spacing = types.Spacing;

/// Generic layout element for algorithm interfaces
pub const LayoutElement = struct {
    /// Element position (will be updated by layout)
    position: Vec2,
    /// Element size (may be updated by layout)
    size: Vec2,
    /// Element margins
    margin: Spacing,
    /// Element padding
    padding: Spacing,
    /// Parent element index (if any)
    parent_index: ?usize = null,
    /// Layout constraints
    constraints: Constraints,
    /// Element index in original array
    element_index: usize = 0,
    /// Dirty flags for incremental updates
    dirty_flags: types.DirtyFlags = types.DirtyFlags{},
};

/// Simplified layout algorithm interface - direct function calls
pub const LayoutAlgorithm = struct {
    algorithm_type: types.LayoutMode,

    /// Calculate layout for elements using the specified algorithm
    pub fn calculate(self: LayoutAlgorithm, elements: []LayoutElement, context: LayoutContext, allocator: std.mem.Allocator) ![]LayoutResult {
        return switch (self.algorithm_type) {
            .block, .absolute, .relative => {
                const box_model = @import("../algorithms/box_model/mod.zig");
                var algorithm = box_model.BoxModelAlgorithm.init(allocator);
                defer algorithm.deinit();
                return algorithm.calculate(elements, context, allocator);
            },
            .flex => {
                const flex = @import("../algorithms/flex/mod.zig");

                // Convert LayoutElements to FlexItems
                var flex_items = try allocator.alloc(flex.FlexItem, elements.len);
                defer allocator.free(flex_items);

                for (elements, 0..) |element, i| {
                    flex_items[i] = flex.FlexItem{
                        .size = element.size,
                        .margin = element.margin,
                        .constraints = element.constraints,
                        .index = i,
                    };
                }

                // Create flex config from context
                const config = flex.Config{
                    .direction = .row, // TODO: Get from context when available
                    .justify_content = .start, // TODO: Get from context when available
                    .align_items = .stretch, // TODO: Get from context when available
                };

                // Convert context bounds to Rectangle
                const math = @import("../../math/mod.zig");
                const container_bounds = math.Rectangle{
                    .position = context.container_bounds.position,
                    .size = context.container_bounds.size,
                };

                return flex.FlexLayout.calculateLayout(container_bounds, flex_items, config, allocator);
            },
            .grid => {
                // TODO: Implement grid layout
                return error.AlgorithmNotImplemented;
            },
        };
    }

    /// Get algorithm capabilities
    pub fn getCapabilities(self: LayoutAlgorithm) AlgorithmCapabilities {
        return switch (self.algorithm_type) {
            .block, .absolute, .relative => {
                const box_model = @import("../algorithms/box_model/mod.zig");
                var algorithm = box_model.BoxModelAlgorithm.init(std.heap.page_allocator);
                defer algorithm.deinit();
                return algorithm.getCapabilities();
            },
            .flex => AlgorithmCapabilities{
                .name = "Flexbox Layout",
                .features = .{
                    .nesting = true,
                    .flexible_sizing = true,
                    .alignment = true,
                    .spacing = true,
                },
            },
            .grid => AlgorithmCapabilities{
                .name = "Grid (Not Implemented)",
                .features = .{},
            },
        };
    }

    /// Check if algorithm can handle elements
    pub fn canHandle(self: LayoutAlgorithm, elements: []const LayoutElement, context: LayoutContext) bool {
        return switch (self.algorithm_type) {
            .block, .absolute, .relative => {
                const box_model = @import("../algorithms/box_model/mod.zig");
                var algorithm = box_model.BoxModelAlgorithm.init(std.heap.page_allocator);
                defer algorithm.deinit();
                return algorithm.canHandle(elements, context);
            },
            .flex => true, // Implemented
            .grid => false, // Not implemented
        };
    }

    /// Get algorithm name
    pub fn getName(self: LayoutAlgorithm) []const u8 {
        return switch (self.algorithm_type) {
            .block => "Box Model (Block)",
            .absolute => "Box Model (Absolute)",
            .relative => "Box Model (Relative)",
            .flex => "Flexbox Layout",
            .grid => "Grid (Not Implemented)",
        };
    }
};

/// Algorithm capabilities
pub const AlgorithmCapabilities = struct {
    /// Algorithm name for identification
    name: []const u8,
    /// Features this algorithm supports
    features: FeatureSet,

    pub const FeatureSet = packed struct(u8) {
        /// Supports nested layouts
        nesting: bool = false,
        /// Supports flexible sizing
        flexible_sizing: bool = false,
        /// Supports alignment
        alignment: bool = false,
        /// Supports spacing distribution
        spacing: bool = false,
        /// Supports text layout
        text_layout: bool = false,
        _reserved: u3 = 0,
    };
};

/// Algorithm configuration
pub const AlgorithmConfig = struct {
    /// Enable debug validation
    debug_mode: bool = false,
};

/// Algorithm selection strategy
pub const AlgorithmSelector = struct {
    /// Select best algorithm for given requirements
    pub fn selectAlgorithm(requirements: LayoutRequirements) types.LayoutMode {
        // Grid layout for 2D positioning
        if (requirements.needs_2d_positioning) {
            return .grid;
        }

        // Flexbox for flexible 1D layouts
        if (requirements.needs_flexible_sizing or requirements.needs_alignment) {
            return .flex;
        }

        // Block layout for simple stacking
        if (requirements.element_count > 1) {
            return .block;
        }

        // Absolute for single elements or precise positioning
        return .absolute;
    }

    pub const LayoutRequirements = struct {
        /// Number of elements to layout
        element_count: usize,
        /// Whether flexible sizing is needed
        needs_flexible_sizing: bool = false,
        /// Whether alignment is important
        needs_alignment: bool = false,
        /// Whether 2D grid positioning is needed
        needs_2d_positioning: bool = false,
        /// Whether text layout is involved
        has_text_content: bool = false,
        /// Performance requirements
        performance_critical: bool = false,
    };
};

/// Layout execution errors
pub const LayoutError = error{
    /// Algorithm not available or not initialized
    AlgorithmNotAvailable,
    /// Elements exceed algorithm capabilities
    TooManyElements,
    /// Invalid element configuration
    InvalidElements,
    /// Calculation failed
    CalculationFailed,
    /// Out of memory
    OutOfMemory,
    /// Invalid configuration
    InvalidConfiguration,
};

// Tests
test "algorithm selector" {
    const testing = std.testing;

    // Test simple requirements
    const simple_req = AlgorithmSelector.LayoutRequirements{
        .element_count = 3,
        .needs_flexible_sizing = false,
    };

    const selected = AlgorithmSelector.selectAlgorithm(simple_req);
    try testing.expect(selected == .block);

    // Test flex requirements
    const flex_req = AlgorithmSelector.LayoutRequirements{
        .element_count = 5,
        .needs_flexible_sizing = true,
    };

    const flex_selected = AlgorithmSelector.selectAlgorithm(flex_req);
    try testing.expect(flex_selected == .flex);
}

test "algorithm capabilities" {
    const testing = std.testing;

    const caps = AlgorithmCapabilities{
        .name = "test",
        .features = .{
            .nesting = true,
            .flexible_sizing = true,
            .alignment = true,
        },
    };

    try testing.expect(caps.features.nesting);
    try testing.expect(caps.features.flexible_sizing);
    try testing.expect(caps.features.alignment);
    try testing.expect(!caps.features.spacing);
}
