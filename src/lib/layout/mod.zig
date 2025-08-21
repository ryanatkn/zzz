/// Unified Layout System
///
/// This module provides comprehensive layout functionality for the engine,
/// organized into focused capabilities:
/// - Core Types: Common layout types and enums
/// - Layout Engines: Box model and flexbox engines  
/// - Measurement: Constraint resolution and intrinsic sizing
/// - Arrangement: Flow, alignment, and stacking algorithms
/// - Backends: CPU, GPU, and hybrid layout calculation
/// - Animation: Springs, transitions, and sequences
/// - Algorithms: Block, flexbox, grid, and absolute positioning
/// - Debug: Validation, profiling, and debugging tools
/// - Text Integration: Layout system integration with text rendering
///
/// This consolidates all layout functionality following the engine's
/// capability-based architectural principles.

// Core layout types and enums
pub const types = @import("types.zig");

// Layout engines
pub const engines = @import("engines/mod.zig");

// Measurement systems
pub const measurement = @import("measurement/mod.zig");

// Arrangement algorithms
pub const arrangement = @import("arrangement/mod.zig");

// Backend implementations
pub const backends = @import("backends/interface.zig");

// Animation systems
pub const animation = @import("animation/mod.zig");

// Core layout algorithms
pub const algorithms = @import("algorithms/mod.zig");

// Debug and profiling tools
pub const debug = @import("debug/mod.zig");

// Text layout integration
pub const text_integration = @import("text_integration.zig");

// Legacy compatibility - keep existing imports for backward compatibility
pub const box_model = @import("box_model.zig");
pub const text_baseline = @import("text_baseline.zig");
pub const primitives = @import("primitives/mod.zig");
pub const text = @import("../text/layout.zig");
pub const gpu = @import("gpu/mod.zig");

// Re-export core types for convenience
pub const LayoutResult = types.LayoutResult;
pub const LayoutContext = types.LayoutContext;
pub const Constraints = types.Constraints;
pub const FlexConstraint = types.FlexConstraint;
pub const Spacing = types.Spacing;
pub const Offset = types.Offset;
pub const DirtyFlags = types.DirtyFlags;

// Re-export layout enums
pub const PositionMode = types.PositionMode;
pub const Alignment = types.Alignment;
pub const Direction = types.Direction;
pub const JustifyContent = types.JustifyContent;
pub const AlignItems = types.AlignItems;
pub const SizingMode = types.SizingMode;
pub const LayoutMode = types.LayoutMode;
pub const BaselineMode = types.BaselineMode;
pub const FlexWrap = types.FlexWrap;

// Re-export engines
pub const BoxModel = engines.BoxModel;
pub const FlexboxEngine = engines.FlexboxEngine;

// Re-export measurement utilities
pub const ConstraintResolver = measurement.ConstraintResolver;
pub const IntrinsicSizing = measurement.IntrinsicSizing;
pub const ContentSizing = measurement.ContentSizing;

// Re-export arrangement utilities
pub const BlockFlow = arrangement.BlockFlow;
pub const InlineFlow = arrangement.InlineFlow;
pub const ContentAlignment = arrangement.ContentAlignment;
pub const StackingContext = arrangement.StackingContext;

// Re-export backend interfaces
pub const LayoutBackend = backends.LayoutBackend;
pub const BackendCapabilities = backends.BackendCapabilities;
pub const BackendConfig = backends.BackendConfig;
pub const BackendStrategy = backends.BackendStrategy;

// Re-export animation systems
pub const SpringConfig = animation.SpringConfig;
pub const LayoutSpring = animation.LayoutSpring;
pub const LayoutTransition = animation.LayoutTransition;
pub const AnimationSequence = animation.AnimationSequence;
pub const TimingPresets = animation.TimingPresets;

// Re-export algorithms
pub const BlockLayout = algorithms.BlockLayout;
pub const FlexLayout = algorithms.FlexLayout;
pub const GridLayout = algorithms.GridLayout;
pub const AbsoluteLayout = algorithms.AbsoluteLayout;
pub const LayoutAlgorithm = algorithms.LayoutAlgorithm;
pub const AlgorithmRecommender = algorithms.AlgorithmRecommender;

// Re-export debug tools
pub const LayoutValidator = debug.LayoutValidator;
pub const LayoutProfiler = debug.LayoutProfiler;
pub const LayoutDebugSuite = debug.LayoutDebugSuite;

// Re-export text integration
pub const TextMeasurer = text_integration.TextMeasurer;
pub const TextLayoutElement = text_integration.TextLayoutElement;
pub const TextMeasurementOptions = text_integration.TextMeasurementOptions;

// Legacy re-exports for backward compatibility
pub const TextBaseline = text_baseline.TextBaseline;
pub const TextPositioning = text_baseline.TextPositioning;
pub const SpacingUtils = primitives.SpacingUtils;
pub const SizingUtils = primitives.SizingUtils;
pub const PositioningUtils = primitives.PositioningUtils;
pub const Flexbox = primitives.Flexbox;
pub const FlexItem = primitives.FlexItem;
pub const FlexItemLayout = primitives.FlexItemLayout;
pub const TextLayoutEngine = text.TextLayoutEngine;
pub const LayoutOptions = text.LayoutOptions;
pub const LayoutedText = text.LayoutedText;
pub const LayoutedLine = text.LayoutedLine;
pub const LayoutedGlyph = text.LayoutedGlyph;
pub const TextAlign = text.TextAlign;
pub const GPULayoutEngine = gpu.GPULayoutEngine;
pub const UIElement = gpu.UIElement;
pub const LayoutConstraint = gpu.LayoutConstraint;
pub const SpringState = gpu.SpringState;

/// Layout system configuration
pub const LayoutConfig = struct {
    /// Default backend selection strategy
    backend_strategy: BackendStrategy = .{},
    /// Enable debug validation
    enable_validation: bool = false,
    /// Enable performance profiling
    enable_profiling: bool = false,
    /// Animation configuration
    animation_config: AnimationConfig = .{},

    pub const AnimationConfig = struct {
        /// Default spring configuration
        default_spring: SpringConfig = animation.SpringPresets.stiff,
        /// Default transition timing
        default_timing: animation.TimingConfig = animation.TimingPresets.standard,
        /// Enable animation by default
        enable_animations: bool = true,
    };
};

/// Unified layout calculator
pub const LayoutCalculator = struct {
    allocator: std.mem.Allocator,
    config: LayoutConfig,
    backend: ?LayoutBackend = null,
    validator: ?LayoutValidator = null,
    profiler: ?LayoutProfiler = null,

    pub fn init(allocator: std.mem.Allocator, config: LayoutConfig) LayoutCalculator {
        return LayoutCalculator{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *LayoutCalculator) void {
        if (self.validator) |*validator| {
            validator.deinit();
        }
        if (self.profiler) |*profiler| {
            profiler.deinit();
        }
    }

    /// Initialize layout system with backend selection
    pub fn initializeBackend(self: *LayoutCalculator, gpu_device: ?*anyopaque) !void {
        // Create hybrid backend for automatic CPU/GPU selection
        self.backend = try @import("backends/hybrid.zig").createHybridBackend(
            self.allocator,
            gpu_device,
            self.config.backend_strategy.config,
        );

        // Initialize debug tools if enabled
        if (self.config.enable_validation) {
            self.validator = LayoutValidator.init(self.allocator, .{});
        }

        if (self.config.enable_profiling) {
            self.profiler = LayoutProfiler.init(self.allocator, .{});
        }
    }

    /// Perform layout calculation
    pub fn calculateLayout(
        self: *LayoutCalculator,
        elements: []const backends.LayoutElement,
        context: LayoutContext,
    ) ![]LayoutResult {
        if (self.backend == null) {
            return error.BackendNotInitialized;
        }

        // Profile the operation if enabled
        if (self.profiler) |*profiler| {
            try profiler.startTiming(.complete_layout);
            defer profiler.endTiming(.complete_layout, elements.len) catch {};
        }

        // Perform layout calculation
        const results = try self.backend.?.performLayout(elements, context);

        // Validate results if enabled
        if (self.validator) |*validator| {
            try validator.validateLayout(results, context.container_bounds);
        }

        return results;
    }

    /// Get performance statistics
    pub fn getPerformanceStats(self: *const LayoutCalculator) ?debug.LayoutProfiler.PerformanceSummary {
        if (self.profiler) |profiler| {
            return profiler.getPerformanceSummary();
        }
        return null;
    }

    /// Get validation errors
    pub fn getValidationErrors(self: *const LayoutCalculator) ?[]const debug.ValidationError {
        if (self.validator) |validator| {
            return validator.getErrors();
        }
        return null;
    }
};

/// High-level layout utilities
pub const LayoutUtils = struct {
    /// Create a simple block layout
    pub fn createBlockLayout(
        allocator: std.mem.Allocator,
        container_bounds: math.Rectangle,
        element_sizes: []const math.Vec2,
    ) ![]LayoutResult {
        var block_elements = try allocator.alloc(algorithms.BlockLayout.BlockElement, element_sizes.len);
        defer allocator.free(block_elements);

        for (element_sizes, 0..) |size, i| {
            block_elements[i] = algorithms.BlockLayout.BlockElement{
                .size = size,
                .margin = Spacing{},
                .constraints = Constraints{},
                .index = i,
            };
        }

        return algorithms.BlockLayout.calculateLayout(
            container_bounds,
            block_elements,
            .{},
            allocator,
        );
    }

    /// Create a simple flex layout
    pub fn createFlexLayout(
        allocator: std.mem.Allocator,
        container_bounds: math.Rectangle,
        element_sizes: []const math.Vec2,
        direction: Direction,
    ) ![]LayoutResult {
        var flex_items = try allocator.alloc(algorithms.FlexLayout.FlexItem, element_sizes.len);
        defer allocator.free(flex_items);

        for (element_sizes, 0..) |size, i| {
            flex_items[i] = algorithms.FlexLayout.FlexItem{
                .size = size,
                .margin = Spacing{},
                .constraints = Constraints{},
                .index = i,
            };
        }

        const config = algorithms.FlexLayout.Config{ .direction = direction };
        return algorithms.FlexLayout.calculateLayout(
            container_bounds,
            flex_items,
            config,
            allocator,
        );
    }

    /// Recommend layout algorithm for given requirements
    pub fn recommendAlgorithm(requirements: algorithms.AlgorithmRecommender.LayoutRequirements) LayoutAlgorithm {
        return algorithms.AlgorithmRecommender.recommend(requirements);
    }
};

const std = @import("std");
const math = @import("../math/mod.zig");

// Tests
test "layout system integration" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; 
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test layout calculator initialization
    const config = LayoutConfig{
        .enable_validation = true,
        .enable_profiling = true,
    };
    
    var calculator = LayoutCalculator.init(allocator, config);
    defer calculator.deinit();

    // Test that config is properly set
    try testing.expect(calculator.config.enable_validation);
    try testing.expect(calculator.config.enable_profiling);
}

test "layout utilities" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; 
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const container = math.Rectangle{
        .position = math.Vec2.ZERO,
        .size = math.Vec2{ .x = 400, .y = 300 },
    };

    const element_sizes = [_]math.Vec2{
        math.Vec2{ .x = 100, .y = 50 },
        math.Vec2{ .x = 120, .y = 60 },
    };

    // Test block layout utility
    const block_results = try LayoutUtils.createBlockLayout(allocator, container, &element_sizes);
    defer allocator.free(block_results);
    
    try testing.expect(block_results.len == 2);
    try testing.expect(block_results[0].size.x == 100);
    try testing.expect(block_results[1].size.x == 120);

    // Test flex layout utility
    const flex_results = try LayoutUtils.createFlexLayout(allocator, container, &element_sizes, .row);
    defer allocator.free(flex_results);
    
    try testing.expect(flex_results.len == 2);
    try testing.expect(flex_results[0].position.x < flex_results[1].position.x); // Row layout
}

test "algorithm recommendation" {
    const testing = std.testing;

    const requirements = algorithms.AlgorithmRecommender.LayoutRequirements{
        .needs_flexible_sizing = true,
        .element_count = 5,
    };

    const recommended = LayoutUtils.recommendAlgorithm(requirements);
    try testing.expect(recommended == .flex);
}