const std = @import("std");
const layout_mod = @import("lib/layout/mod.zig");
const math = @import("lib/math/mod.zig");
const loggers = @import("lib/debug/loggers.zig");
const sdl = @import("lib/platform/sdl.zig");

const HybridLayoutManager = layout_mod.gpu.hybrid.HybridLayoutManager;
const UIElement = layout_mod.UIElement;
const LayoutConstraint = layout_mod.LayoutConstraint;
const SpringState = layout_mod.SpringState;
const Vec2 = math.Vec2;

/// Benchmark configuration
const BenchmarkConfig = struct {
    element_counts: []const usize = &[_]usize{ 10, 50, 100, 200, 500, 1000 },
    iterations_per_test: usize = 50,
    warmup_iterations: usize = 10,
};

/// Benchmark results for a single test
const BenchmarkResult = struct {
    element_count: usize,
    backend_used: enum { cpu, gpu },
    avg_time_us: f64,
    min_time_us: f64,
    max_time_us: f64,
    std_dev_us: f64,
    iterations: usize,

    pub fn print(self: BenchmarkResult) void {
        const backend_name = if (self.backend_used == .gpu) "GPU" else "CPU";
        std.debug.print("  {} elements ({s}): avg={d:.1}μs, min={d:.1}μs, max={d:.1}μs, σ={d:.1}μs (n={})\n", .{ self.element_count, backend_name, self.avg_time_us, self.min_time_us, self.max_time_us, self.std_dev_us, self.iterations });
    }
};

/// Complete benchmark suite
const BenchmarkSuite = struct {
    allocator: std.mem.Allocator,
    results: std.ArrayList(BenchmarkResult),

    pub fn init(allocator: std.mem.Allocator) BenchmarkSuite {
        return BenchmarkSuite{
            .allocator = allocator,
            .results = std.ArrayList(BenchmarkResult).init(allocator),
        };
    }

    pub fn deinit(self: *BenchmarkSuite) void {
        self.results.deinit();
    }

    pub fn addResult(self: *BenchmarkSuite, result: BenchmarkResult) !void {
        try self.results.append(result);
    }

    pub fn printSummary(self: *const BenchmarkSuite) void {
        std.debug.print("\n=== Hybrid Layout Performance Benchmark ===\n");

        for (self.results.items) |result| {
            result.print();
        }

        // Find crossover point where GPU becomes faster
        var cpu_results = std.ArrayList(BenchmarkResult).init(self.allocator);
        var gpu_results = std.ArrayList(BenchmarkResult).init(self.allocator);
        defer cpu_results.deinit();
        defer gpu_results.deinit();

        for (self.results.items) |result| {
            if (result.backend_used == .cpu) {
                cpu_results.append(result) catch {};
            } else {
                gpu_results.append(result) catch {};
            }
        }

        std.debug.print("\n=== Performance Analysis ===\n");
        if (cpu_results.items.len > 0 and gpu_results.items.len > 0) {
            std.debug.print("CPU performance:\n");
            for (cpu_results.items) |result| {
                std.debug.print("  {} elements: {d:.1}μs/elem\n", .{ result.element_count, result.avg_time_us / @as(f64, @floatFromInt(result.element_count)) });
            }

            std.debug.print("GPU performance:\n");
            for (gpu_results.items) |result| {
                std.debug.print("  {} elements: {d:.1}μs/elem\n", .{ result.element_count, result.avg_time_us / @as(f64, @floatFromInt(result.element_count)) });
            }
        }

        std.debug.print("\n");
    }
};

/// Run benchmark for specific element count
fn benchmarkElementCount(allocator: std.mem.Allocator, manager: *HybridLayoutManager, device: *sdl.sdl.SDL_GPUDevice, element_count: usize, config: BenchmarkConfig) !BenchmarkResult {
    // Create test data
    const test_data = try layout_mod.gpu.hybrid.createTestData(allocator, element_count);
    defer test_data.deinit(allocator);

    var times = try allocator.alloc(f64, config.iterations_per_test + config.warmup_iterations);
    defer allocator.free(times);

    // Create command buffer for GPU operations
    var cmd_buffer: ?*sdl.sdl.SDL_GPUCommandBuffer = null;
    if (manager.hasGPUBackend()) {
        cmd_buffer = sdl.sdl.SDL_AcquireGPUCommandBuffer(device);
    }

    // Warmup + actual iterations
    for (0..config.warmup_iterations + config.iterations_per_test) |i| {
        const start_time = std.time.nanoTimestamp();

        // Perform layout calculation
        const results = manager.performLayout(cmd_buffer, 0.016, // 60 FPS delta time
            test_data.elements, test_data.constraints, test_data.springs) catch |err| {
            std.debug.print("Layout failed for {} elements: {}\n", .{ element_count, err });
            return err;
        };

        // Clean up results
        allocator.free(results);

        const end_time = std.time.nanoTimestamp();
        const time_us = @as(f64, @floatFromInt(end_time - start_time)) / 1000.0;

        if (i >= config.warmup_iterations) {
            times[i - config.warmup_iterations] = time_us;
        }
    }

    // Submit command buffer if GPU was used
    if (cmd_buffer) |cb| {
        _ = sdl.sdl.SDL_SubmitGPUCommandBuffer(cb);
    }

    // Calculate statistics
    const actual_times = times[0..config.iterations_per_test];
    var sum: f64 = 0;
    var min_time: f64 = std.math.floatMax(f64);
    var max_time: f64 = -std.math.floatMax(f64);

    for (actual_times) |time| {
        sum += time;
        min_time = @min(min_time, time);
        max_time = @max(max_time, time);
    }

    const avg_time = sum / @as(f64, @floatFromInt(config.iterations_per_test));

    // Calculate standard deviation
    var variance_sum: f64 = 0;
    for (actual_times) |time| {
        const diff = time - avg_time;
        variance_sum += diff * diff;
    }
    const std_dev = @sqrt(variance_sum / @as(f64, @floatFromInt(config.iterations_per_test)));

    return BenchmarkResult{
        .element_count = element_count,
        .backend_used = manager.getCurrentBackend(),
        .avg_time_us = avg_time,
        .min_time_us = min_time,
        .max_time_us = max_time,
        .std_dev_us = std_dev,
        .iterations = config.iterations_per_test,
    };
}

/// Main benchmark runner
pub fn runHybridLayoutBenchmark(allocator: std.mem.Allocator, device: ?*sdl.sdl.SDL_GPUDevice) !void {
    std.debug.print("Starting Hybrid Layout Performance Benchmark...\n");

    if (device == null) {
        std.debug.print("No GPU device available - CPU-only benchmark\n");
    }

    const config = BenchmarkConfig{};
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    // Test different GPU thresholds to show hybrid switching
    const thresholds = [_]usize{ 25, 75, 150 }; // Different switch points

    for (thresholds) |threshold| {
        std.debug.print("\n--- Testing with GPU threshold: {} elements ---\n", .{threshold});

        // Create hybrid manager with this threshold
        const manager_config = HybridLayoutManager.Config{
            .gpu_threshold = threshold,
            .force_cpu = false,
            .force_gpu = false,
            .gpu_capacity = 2000,
        };

        var manager = try HybridLayoutManager.init(allocator, device, manager_config);
        defer manager.deinit();

        // Test each element count
        for (config.element_counts) |element_count| {
            std.debug.print("Testing {} elements... ", .{element_count});

            const result = benchmarkElementCount(allocator, &manager, device orelse return, element_count, config) catch |err| {
                std.debug.print("FAILED: {}\n", .{err});
                continue;
            };

            try suite.addResult(result);
            std.debug.print("{s} backend, {d:.1}μs avg\n", .{ if (result.backend_used == .gpu) "GPU" else "CPU", result.avg_time_us });
        }

        // Print performance stats for this threshold
        const perf_stats = manager.getPerformanceStats();
        std.debug.print("Performance Summary (threshold={}):\n", .{threshold});
        std.debug.print("  CPU: {d:.1}μs avg, {} layouts\n", .{ perf_stats.getCPUAverage(), perf_stats.cpu_layout_count });
        std.debug.print("  GPU: {d:.1}μs avg, {} layouts\n", .{ perf_stats.getGPUAverage(), perf_stats.gpu_layout_count });
    }

    // Print comprehensive results
    suite.printSummary();

    std.debug.print("=== Benchmark Complete ===\n");
}

// Integration test that can be called from hex/main.zig during init
pub fn integrateWithHexGame(allocator: std.mem.Allocator, device: *sdl.sdl.SDL_GPUDevice) !void {
    std.debug.print("Running integrated hybrid layout test...\n");

    // Quick performance test with moderate element count
    const manager_config = HybridLayoutManager.Config{
        .gpu_threshold = 50,
        .force_cpu = false,
        .force_gpu = false,
        .gpu_capacity = 1000,
    };

    var manager = try HybridLayoutManager.init(allocator, device, manager_config);
    defer manager.deinit();

    // Test with hex-game relevant element counts
    const test_counts = [_]usize{ 25, 100, 300 }; // Small UI, medium scene, large scene

    for (test_counts) |count| {
        const test_data = try layout_mod.gpu.hybrid.createTestData(allocator, count);
        defer test_data.deinit(allocator);

        const cmd_buffer = sdl.sdl.SDL_AcquireGPUCommandBuffer(device);
        const start_time = std.time.nanoTimestamp();

        const results = try manager.performLayout(cmd_buffer, 0.016, test_data.elements, test_data.constraints, test_data.springs);

        const end_time = std.time.nanoTimestamp();
        const time_us = @as(f64, @floatFromInt(end_time - start_time)) / 1000.0;

        allocator.free(results);
        _ = sdl.sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer);

        std.debug.print("  {} elements: {d:.1}μs ({s} backend)\n", .{ count, time_us, if (manager.getCurrentBackend() == .gpu) "GPU" else "CPU" });
    }

    std.debug.print("Hybrid layout integration test complete.\n");
}

// For testing standalone
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Initialize minimal SDL3 for GPU device
    _ = sdl.sdl.SDL_Init(sdl.sdl.SDL_INIT_VIDEO);
    defer sdl.sdl.SDL_Quit();

    // Create minimal window and GPU device for testing
    const window = sdl.sdl.SDL_CreateWindow("Layout Benchmark", 800, 600, sdl.sdl.SDL_WINDOW_HIDDEN) orelse {
        std.debug.print("Failed to create test window\n");
        return;
    };
    defer sdl.sdl.SDL_DestroyWindow(window);

    const device = sdl.sdl.SDL_CreateGPUDevice(sdl.sdl.SDL_GPU_SHADERFORMAT_SPIRV, true, null) orelse {
        std.debug.print("No GPU device available - skipping GPU tests\n");
        return;
    };
    defer sdl.sdl.SDL_DestroyGPUDevice(device);

    if (!sdl.sdl.SDL_ClaimWindowForGPUDevice(device, window)) {
        std.debug.print("Failed to claim window for GPU device\n");
        return;
    }

    try runHybridLayoutBenchmark(gpa.allocator(), device);
}
