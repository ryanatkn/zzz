/// Real layout benchmarking using actual algorithms (replacing fake backends)
const std = @import("std");
const core = @import("../core/types.zig");
const interface = @import("../core/interface.zig");
const engine_mod = @import("engine.zig");
const box_model = @import("../algorithms/box_model/mod.zig");

const LayoutElement = interface.LayoutElement;
const LayoutResult = core.LayoutResult;
const LayoutContext = core.LayoutContext;
const LayoutEngine = engine_mod.LayoutEngine;

/// Benchmark configuration
pub const BenchmarkConfig = struct {
    /// Element counts to test
    element_counts: []const usize = &[_]usize{ 10, 50, 100, 500, 1000 },
    /// Iterations per test
    iterations: usize = 100,
    /// Minimum runtime per test (milliseconds)
    min_runtime_ms: f64 = 500,
    /// Warmup iterations
    warmup_iterations: usize = 5,
    /// Test CPU implementation
    test_cpu: bool = true,
    /// Test GPU implementation (if available)
    test_gpu: bool = true,
};

/// Benchmark result for a single test
pub const BenchmarkResult = struct {
    element_count: usize,
    algorithm: []const u8,
    implementation: []const u8,
    iterations: usize,
    total_time_ns: u64,
    avg_time_ns: f64,
    min_time_ns: u64,
    max_time_ns: u64,
    success_rate: f64,

    pub fn getAvgTimeMicros(self: BenchmarkResult) f64 {
        return self.avg_time_ns / 1000.0;
    }

    pub fn getAvgTimeMillis(self: BenchmarkResult) f64 {
        return self.avg_time_ns / 1_000_000.0;
    }
};

/// Complete benchmark suite results
pub const BenchmarkSuite = struct {
    results: std.ArrayList(BenchmarkResult),
    config: BenchmarkConfig,
    gpu_available: bool,

    pub fn init(allocator: std.mem.Allocator, config: BenchmarkConfig) BenchmarkSuite {
        return BenchmarkSuite{
            .results = std.ArrayList(BenchmarkResult).init(allocator),
            .config = config,
            .gpu_available = false, // Will be detected during run
        };
    }

    pub fn deinit(self: *BenchmarkSuite) void {
        self.results.deinit();
    }

    /// Get results for a specific algorithm and implementation
    pub fn getResults(self: *BenchmarkSuite, algorithm: []const u8, implementation: []const u8) []BenchmarkResult {
        var filtered = std.ArrayList(BenchmarkResult).init(self.results.allocator);
        defer filtered.deinit();

        for (self.results.items) |result| {
            if (std.mem.eql(u8, result.algorithm, algorithm) and
                std.mem.eql(u8, result.implementation, implementation))
            {
                filtered.append(result) catch continue;
            }
        }

        return filtered.toOwnedSlice() catch &[_]BenchmarkResult{};
    }
};

/// Layout benchmark runner
pub const LayoutBenchmark = struct {
    allocator: std.mem.Allocator,
    engine: LayoutEngine,

    pub fn init(allocator: std.mem.Allocator) !LayoutBenchmark {
        var layout_engine = LayoutEngine.init(allocator);

        // Register box model algorithm (CPU only for now)
        const config = interface.AlgorithmConfig{
            .implementation = .cpu_only,
        };
        try layout_engine.registerAlgorithm(.block, config);

        return LayoutBenchmark{
            .allocator = allocator,
            .engine = layout_engine,
        };
    }

    pub fn deinit(self: *LayoutBenchmark) void {
        self.engine.deinit();
    }

    /// Run complete benchmark suite
    pub fn runSuite(self: *LayoutBenchmark, config: BenchmarkConfig) !BenchmarkSuite {
        var suite = BenchmarkSuite.init(self.allocator, config);

        // Detect GPU availability
        suite.gpu_available = false; // TODO: Implement real GPU detection

        for (config.element_counts) |element_count| {
            // Test CPU implementation
            if (config.test_cpu) {
                const cpu_result = try self.benchmarkCPU(element_count, config);
                try suite.results.append(cpu_result);
            }

            // Test GPU implementation (if available and requested)
            if (config.test_gpu and suite.gpu_available) {
                const gpu_result = try self.benchmarkGPU(element_count, config);
                try suite.results.append(gpu_result);
            }
        }

        return suite;
    }

    /// Benchmark CPU implementation
    fn benchmarkCPU(self: *LayoutBenchmark, element_count: usize, config: BenchmarkConfig) !BenchmarkResult {
        // Create test elements
        const elements = try self.allocator.alloc(LayoutElement, element_count);
        defer self.allocator.free(elements);

        // Initialize test data
        for (elements, 0..) |*element, i| {
            element.* = LayoutElement{
                .position = core.Vec2{ .x = @floatFromInt(i * 10), .y = @floatFromInt(i * 10) },
                .size = core.Vec2{ .x = 100, .y = 50 },
                .margin = core.Spacing.uniform(5),
                .padding = core.Spacing.uniform(10),
                .constraints = core.Constraints{},
            };
        }

        const context = LayoutContext{
            .container_bounds = core.Rectangle{
                .position = core.Vec2.ZERO,
                .size = core.Vec2{ .x = 1920, .y = 1080 },
            },
            .algorithm = .block,
        };

        // Create arena allocator to eliminate allocation overhead during benchmarking
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // Store original allocator in engine and temporarily replace it
        const original_allocator = self.engine.allocator;
        self.engine.allocator = arena_allocator;
        defer self.engine.allocator = original_allocator;

        // Warmup with arena allocator
        for (0..config.warmup_iterations) |_| {
            _ = try self.engine.calculateLayout(elements, context);
            _ = arena.reset(.retain_capacity); // Clear arena but keep capacity
        }

        // Actual benchmark
        var total_time_ns: u64 = 0;
        var min_time_ns: u64 = std.math.maxInt(u64);
        var max_time_ns: u64 = 0;
        var successful_runs: usize = 0;

        var iteration: usize = 0;

        while (iteration < config.iterations or
            (total_time_ns < @as(u64, @intFromFloat(config.min_runtime_ms * 1_000_000))))
        {
            // Reset arena before each iteration for consistent allocation patterns
            _ = arena.reset(.retain_capacity);
            
            const iter_start = std.time.nanoTimestamp();
            _ = self.engine.calculateLayout(elements, context) catch {
                iteration += 1;
                continue;
            };
            const iter_end = std.time.nanoTimestamp();

            const iter_time = @as(u64, @intCast(iter_end - iter_start));
            total_time_ns += iter_time;
            min_time_ns = @min(min_time_ns, iter_time);
            max_time_ns = @max(max_time_ns, iter_time);
            successful_runs += 1;
            iteration += 1;

            // Safety check to prevent infinite loops
            if (iteration > config.iterations * 10) break;
        }

        return BenchmarkResult{
            .element_count = element_count,
            .algorithm = "Box Model",
            .implementation = "CPU",
            .iterations = successful_runs,
            .total_time_ns = total_time_ns,
            .avg_time_ns = if (successful_runs > 0) @as(f64, @floatFromInt(total_time_ns)) / @as(f64, @floatFromInt(successful_runs)) else 0,
            .min_time_ns = if (successful_runs > 0) min_time_ns else 0,
            .max_time_ns = max_time_ns,
            .success_rate = @as(f64, @floatFromInt(successful_runs)) / @as(f64, @floatFromInt(iteration)),
        };
    }

    /// Benchmark GPU implementation (placeholder until real GPU is connected)
    fn benchmarkGPU(self: *LayoutBenchmark, element_count: usize, config: BenchmarkConfig) !BenchmarkResult {
        _ = self;
        _ = config;

        // TODO: Implement real GPU benchmarking once GPU pipeline is connected
        return BenchmarkResult{
            .element_count = element_count,
            .algorithm = "Box Model",
            .implementation = "GPU",
            .iterations = 0,
            .total_time_ns = 0,
            .avg_time_ns = 0,
            .min_time_ns = 0,
            .max_time_ns = 0,
            .success_rate = 0,
        };
    }
};

// Tests
test "benchmark creation and basic run" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var benchmark = try LayoutBenchmark.init(allocator);
    defer benchmark.deinit();

    // Test small suite
    const config = BenchmarkConfig{
        .element_counts = &[_]usize{10},
        .iterations = 5,
        .min_runtime_ms = 10,
        .test_gpu = false, // CPU only for test
    };

    var suite = try benchmark.runSuite(config);
    defer suite.deinit();

    try testing.expect(suite.results.items.len == 1);

    const result = suite.results.items[0];
    try testing.expect(result.element_count == 10);
    try testing.expectEqualStrings("CPU", result.implementation);
    try testing.expect(result.iterations >= 5);
    try testing.expect(result.success_rate > 0);
    try testing.expect(result.avg_time_ns > 0);
}

test "benchmark result time conversions" {
    const testing = std.testing;

    const result = BenchmarkResult{
        .element_count = 100,
        .algorithm = "Test",
        .implementation = "Test",
        .iterations = 10,
        .total_time_ns = 1_000_000, // 1ms total
        .avg_time_ns = 100_000, // 100μs average
        .min_time_ns = 90_000,
        .max_time_ns = 110_000,
        .success_rate = 1.0,
    };

    try testing.expect(result.getAvgTimeMicros() == 100.0);
    try testing.expect(result.getAvgTimeMillis() == 0.1);
}
