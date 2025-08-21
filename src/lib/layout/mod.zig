/// Clean Layout System - Algorithm-First Architecture
///
/// This module provides a comprehensive layout system organized by algorithm type.
/// Each algorithm (box model, flexbox, grid, text) has dedicated CPU and GPU implementations
/// with a unified interface for easy selection and performance comparison.
///
/// Key Design Principles:
/// - Algorithm-first organization for natural scaling
/// - Clean separation between CPU and GPU implementations
/// - No backwards compatibility exports - breaking change for cleaner architecture
/// - Real performance benchmarking without fake implementations
/// - CPU-first development with GPU acceleration experiments
const std = @import("std");

// Core types and interfaces (shared across all algorithms)
pub const core = struct {
    pub usingnamespace @import("core/types.zig");
    pub const interface = @import("core/interface.zig");
};

// Algorithm implementations
pub const algorithms = @import("algorithms/mod.zig");

// Runtime engine and benchmarking
pub const runtime = struct {
    pub const engine = @import("runtime/engine.zig");
    pub const benchmark = @import("runtime/benchmark.zig");
};

// Re-export core types for convenience
pub const LayoutMode = core.LayoutMode;
pub const LayoutResult = core.LayoutResult;
pub const LayoutContext = core.LayoutContext;
pub const LayoutElement = core.interface.LayoutElement;
pub const LayoutAlgorithm = core.interface.LayoutAlgorithm;
pub const LayoutEngine = runtime.engine.LayoutEngine;

// Re-export essential types
pub const Vec2 = core.Vec2;
pub const Rectangle = core.Rectangle;
pub const Spacing = core.Spacing;
pub const Constraints = core.Constraints;
pub const Alignment = core.Alignment;
pub const Direction = core.Direction;

// Main layout engine creation
pub fn createEngine(allocator: std.mem.Allocator) LayoutEngine {
    return LayoutEngine.init(allocator);
}

// Algorithm creation helpers
pub fn createBoxModel(
    allocator: std.mem.Allocator,
    config: algorithms.box_model.Config,
    gpu_device: ?*anyopaque,
) !LayoutAlgorithm {
    return algorithms.box_model.createAlgorithm(allocator, config, gpu_device);
}

// Benchmark creation
pub fn createBenchmark(allocator: std.mem.Allocator) !runtime.benchmark.LayoutBenchmark {
    return runtime.benchmark.LayoutBenchmark.init(allocator);
}

/// Quick layout calculation for simple use cases
pub fn calculateSimpleLayout(
    allocator: std.mem.Allocator,
    elements: []LayoutElement,
    container_bounds: Rectangle,
    algorithm_type: LayoutMode,
) ![]LayoutResult {
    var engine = createEngine(allocator);
    defer engine.deinit();

    // Register appropriate algorithm
    const config = core.interface.AlgorithmConfig{};
    try engine.registerAlgorithm(algorithm_type, config);

    const context = LayoutContext{
        .container_bounds = container_bounds,
        .algorithm = algorithm_type,
    };

    return engine.calculateLayout(elements, context);
}

/// Layout system information
pub const Info = struct {
    pub const version = "2.0.0";
    pub const architecture = "Algorithm-First";

    pub const supported_algorithms = [_]LayoutMode{
        .block, // Box model (CPU + GPU)
        .absolute, // Box model absolute positioning
        // .flex,   // TODO: Flexbox (CPU + GPU)
        // .grid,   // TODO: CSS Grid (CPU + GPU)
        // .relative, // TODO: Relative positioning
    };

    pub const features = struct {
        pub const cpu_algorithms = true;
        pub const gpu_acceleration = true; // Via compute shaders
        pub const real_benchmarking = true;
        pub const reactive_updates = true;
        pub const backwards_compatibility = false; // Intentionally removed
    };
};

// Tests
test "layout system info" {
    const testing = std.testing;

    try testing.expectEqualStrings("2.0.0", Info.version);
    try testing.expectEqualStrings("Algorithm-First", Info.architecture);
    try testing.expect(Info.supported_algorithms.len >= 2);
    try testing.expect(Info.features.cpu_algorithms);
    try testing.expect(Info.features.gpu_acceleration);
    try testing.expect(!Info.features.backwards_compatibility);
}

test "engine creation and algorithm registration" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = createEngine(allocator);
    defer engine.deinit();

    // Register box model algorithm
    const config = core.interface.AlgorithmConfig{};
    try engine.registerAlgorithm(.block, config);

    // Should have algorithm registered
    const algorithms_list = engine.listAlgorithms();
    defer allocator.free(algorithms_list);

    try testing.expect(algorithms_list.len == 1);
    try testing.expect(algorithms_list[0] == .block);
}

test "simple layout calculation" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create test elements
    var elements = [_]LayoutElement{
        LayoutElement{
            .position = Vec2{ .x = 10, .y = 10 },
            .size = Vec2{ .x = 100, .y = 50 },
            .margin = Spacing.uniform(5),
            .padding = Spacing.uniform(10),
            .constraints = Constraints{},
        },
    };

    const container = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 800, .y = 600 },
    };

    const results = try calculateSimpleLayout(allocator, &elements, container, .block);
    defer allocator.free(results);

    try testing.expect(results.len == 1);
    try testing.expect(results[0].valid);
}
