/// Layout engine coordinator - manages algorithm selection and execution
const std = @import("std");
const core = @import("../core/types.zig");
const interface = @import("../core/interface.zig");
const box_model = @import("../algorithms/box_model/mod.zig");

const LayoutElement = interface.LayoutElement;
const LayoutResult = core.LayoutResult;
const LayoutContext = core.LayoutContext;
const LayoutAlgorithm = interface.LayoutAlgorithm;

/// Main layout engine that coordinates different algorithms
pub const LayoutEngine = struct {
    allocator: std.mem.Allocator,
    algorithms: std.ArrayList(AlgorithmEntry),
    default_algorithm: core.LayoutMode,
    gpu_device: ?*anyopaque = null,

    const AlgorithmEntry = struct {
        algorithm_type: core.LayoutMode,
        algorithm: LayoutAlgorithm,
        config: interface.AlgorithmConfig,
    };

    pub fn init(allocator: std.mem.Allocator) LayoutEngine {
        return LayoutEngine{
            .allocator = allocator,
            .algorithms = std.ArrayList(AlgorithmEntry).init(allocator),
            .default_algorithm = .block,
        };
    }

    pub fn deinit(self: *LayoutEngine) void {
        // Clean up all algorithms
        for (self.algorithms.items) |*entry| {
            entry.algorithm.deinit();
            // Note: Individual algorithm pointers are cleaned up by their own deinit
        }
        self.algorithms.deinit();
    }

    /// Initialize with GPU device (optional)
    pub fn initGPU(self: *LayoutEngine, gpu_device: *anyopaque) void {
        self.gpu_device = gpu_device;
    }

    /// Register an algorithm with the engine
    pub fn registerAlgorithm(
        self: *LayoutEngine,
        algorithm_type: core.LayoutMode,
        config: interface.AlgorithmConfig,
    ) !void {
        const algorithm = switch (algorithm_type) {
            .block, .absolute => try box_model.createAlgorithm(
                self.allocator,
                box_model.Config{ .implementation = .cpu_only },
                self.gpu_device,
            ),
            .flex => {
                // TODO: Create flexbox algorithm
                return error.AlgorithmNotImplemented;
            },
            .grid => {
                // TODO: Create grid algorithm
                return error.AlgorithmNotImplemented;
            },
            .relative => try box_model.createAlgorithm(
                self.allocator,
                box_model.Config{ .implementation = .cpu_only },
                self.gpu_device,
            ),
        };

        try self.algorithms.append(AlgorithmEntry{
            .algorithm_type = algorithm_type,
            .algorithm = algorithm,
            .config = config,
        });
    }

    /// Calculate layout using specified or default algorithm
    pub fn calculateLayout(
        self: *LayoutEngine,
        elements: []LayoutElement,
        context: LayoutContext,
    ) ![]LayoutResult {
        const algorithm_type = context.algorithm;

        // Find the appropriate algorithm
        for (self.algorithms.items) |*entry| {
            if (entry.algorithm_type == algorithm_type) {
                if (entry.algorithm.canHandle(elements, context)) {
                    return entry.algorithm.calculate(elements, context, self.allocator);
                }
            }
        }

        // Fallback to default algorithm if no specific one found
        for (self.algorithms.items) |*entry| {
            if (entry.algorithm_type == self.default_algorithm) {
                if (entry.algorithm.canHandle(elements, context)) {
                    return entry.algorithm.calculate(elements, context, self.allocator);
                }
            }
        }

        return error.NoSuitableAlgorithm;
    }

    /// Get capabilities for a specific algorithm
    pub fn getAlgorithmCapabilities(self: *LayoutEngine, algorithm_type: core.LayoutMode) ?interface.AlgorithmCapabilities {
        for (self.algorithms.items) |*entry| {
            if (entry.algorithm_type == algorithm_type) {
                return entry.algorithm.getCapabilities();
            }
        }
        return null;
    }

    /// List all registered algorithms
    pub fn listAlgorithms(self: *LayoutEngine) []const core.LayoutMode {
        var result = self.allocator.alloc(core.LayoutMode, self.algorithms.items.len) catch return &[_]core.LayoutMode{};
        for (self.algorithms.items, 0..) |entry, i| {
            result[i] = entry.algorithm_type;
        }
        return result;
    }

    /// Recommend best algorithm for given requirements
    pub fn recommendAlgorithm(self: *LayoutEngine, requirements: AlgorithmRequirements) core.LayoutMode {
        _ = self;

        // Simple heuristics for algorithm selection
        if (requirements.needs_2d_positioning) {
            return .grid;
        }

        if (requirements.needs_flexible_sizing or requirements.needs_alignment) {
            return .flex;
        }

        if (requirements.element_count == 1) {
            return .absolute;
        }

        return .block; // Default for simple stacking
    }

    pub const AlgorithmRequirements = struct {
        element_count: usize,
        needs_flexible_sizing: bool = false,
        needs_alignment: bool = false,
        needs_2d_positioning: bool = false,
        performance_critical: bool = false,
        has_text_content: bool = false,
    };
};

/// Simple layout engine for single-algorithm use cases
pub const SimpleLayoutEngine = struct {
    algorithm: LayoutAlgorithm,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, algorithm: LayoutAlgorithm) SimpleLayoutEngine {
        return SimpleLayoutEngine{
            .algorithm = algorithm,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SimpleLayoutEngine) void {
        self.algorithm.deinit();
    }

    pub fn calculateLayout(
        self: *SimpleLayoutEngine,
        elements: []LayoutElement,
        context: LayoutContext,
    ) ![]LayoutResult {
        return self.algorithm.calculate(elements, context, self.allocator);
    }

    pub fn getCapabilities(self: *SimpleLayoutEngine) interface.AlgorithmCapabilities {
        return self.algorithm.getCapabilities();
    }
};

// Tests
test "layout engine creation and algorithm registration" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = LayoutEngine.init(allocator);
    defer engine.deinit();

    // Register box model algorithm
    const config = interface.AlgorithmConfig{};
    try engine.registerAlgorithm(.block, config);

    // Should have one algorithm registered
    const algorithms = engine.listAlgorithms();
    defer allocator.free(algorithms);

    try testing.expect(algorithms.len == 1);
    try testing.expect(algorithms[0] == .block);

    // Should be able to get capabilities
    const caps = engine.getAlgorithmCapabilities(.block);
    try testing.expect(caps != null);
    try testing.expect(caps.?.supports_gpu == false); // CPU implementation
}

test "algorithm recommendation" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = LayoutEngine.init(allocator);
    defer engine.deinit();

    // Test flex recommendation
    const flex_req = LayoutEngine.AlgorithmRequirements{
        .element_count = 5,
        .needs_flexible_sizing = true,
    };
    try testing.expect(engine.recommendAlgorithm(flex_req) == .flex);

    // Test block recommendation
    const block_req = LayoutEngine.AlgorithmRequirements{
        .element_count = 3,
    };
    try testing.expect(engine.recommendAlgorithm(block_req) == .block);

    // Test absolute recommendation
    const abs_req = LayoutEngine.AlgorithmRequirements{
        .element_count = 1,
    };
    try testing.expect(engine.recommendAlgorithm(abs_req) == .absolute);
}
