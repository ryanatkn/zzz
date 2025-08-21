/// Layout Benchmark Page - Real CPU vs GPU performance comparison
const std = @import("std");
const page = @import("../../../lib/browser/page.zig");
const math = @import("../../../lib/math/mod.zig");
const reactive = @import("../../../lib/reactive/mod.zig");
const loggers = @import("../../../lib/debug/loggers.zig");
const benchmark_mod = @import("../../../lib/layout/runtime/benchmark.zig");
const statistical_analysis = @import("statistical_analysis.zig");
const layout_validator = @import("layout_validator.zig");

const Vec2 = math.Vec2;
const LayoutBenchmark = benchmark_mod.LayoutBenchmark;
const BenchmarkConfig = benchmark_mod.BenchmarkConfig;
const BenchmarkResult = benchmark_mod.BenchmarkResult;
const BenchmarkSuite = benchmark_mod.BenchmarkSuite;

pub const LayoutBenchmarkPage = struct {
    base: page.Page,
    allocator: std.mem.Allocator,

    // Benchmark infrastructure
    benchmark: ?LayoutBenchmark = null,
    current_suite: ?BenchmarkSuite = null,

    // Benchmark state
    benchmark_running: bool = false,
    current_test_index: usize = 0,
    total_tests: usize = 0,

    // UI state - reactive signals
    status_text: reactive.Signal([]const u8),
    progress_text: reactive.Signal([]const u8),
    results_text: reactive.Signal([]const u8),

    // Configuration
    config: BenchmarkConfig = BenchmarkConfig{
        .element_counts = &[_]usize{ 10, 50, 100, 500, 1000 },
        .iterations = 100,
        .min_runtime_ms = 500,
        .warmup_iterations = 5,
        .test_cpu = true,
        .test_gpu = false, // Disabled until real GPU pipeline connected
    },

    // GPU availability detection
    gpu_available: bool = false,

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const benchmark_page: *LayoutBenchmarkPage = @fieldParentPtr("base", self);
        benchmark_page.allocator = allocator;

        // Initialize reactive signals
        benchmark_page.status_text = try reactive.signal(allocator, []const u8, "Ready to benchmark");
        benchmark_page.progress_text = try reactive.signal(allocator, []const u8, "");
        benchmark_page.results_text = try reactive.signal(allocator, []const u8, "Click 'Start Benchmark' to begin");

        // Initialize benchmark infrastructure
        benchmark_page.benchmark = LayoutBenchmark.init(allocator) catch |err| {
            loggers.getUILog().err("benchmark_init_failed", "Failed to initialize benchmark: {}", .{err});
            return;
        };

        // Detect GPU availability
        benchmark_page.detectGPU();

        loggers.getUILog().info("benchmark_page_init", "Layout benchmark page initialized", .{});
    }

    fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
        const benchmark_page: *LayoutBenchmarkPage = @fieldParentPtr("base", self);
        _ = allocator;

        if (benchmark_page.current_suite) |*suite| {
            suite.deinit();
        }

        if (benchmark_page.benchmark) |*bench| {
            bench.deinit();
        }

        loggers.getUILog().info("benchmark_page_cleanup", "Layout benchmark page cleaned up", .{});
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const benchmark_page: *LayoutBenchmarkPage = @fieldParentPtr("base", self);
        allocator.destroy(benchmark_page);
    }

    fn update(self: *page.Page, dt: f32) void {
        _ = dt;
        const benchmark_page: *LayoutBenchmarkPage = @fieldParentPtr("base", self);

        // Update progress if benchmark is running
        if (benchmark_page.benchmark_running) {
            // TODO: Implement async benchmark progress updates
            // For now, benchmarks run synchronously
        }
    }

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link), arena: std.mem.Allocator) !void {
        _ = arena;
        const benchmark_page: *const LayoutBenchmarkPage = @fieldParentPtr("base", self);

        // Layout constants
        const screen_width = 1920.0;
        const screen_height = 1080.0;
        const center_x = screen_width / 2.0;
        const start_y = screen_height * 0.15;
        const button_width = 300.0;
        const button_height = 50.0;
        const section_spacing = 80.0;

        var current_y: f32 = start_y;

        // Title
        // TODO: Add text rendering for title

        // Status section
        current_y += 60;
        // Status: {status_text.get()}
        // Progress: {progress_text.get()}

        // Configuration section
        current_y += section_spacing;
        // Configuration display
        // Element counts: 10, 50, 100, 500, 1000
        // Iterations: 100, Min runtime: 500ms
        // GPU Available: {gpu_available}

        // Control buttons
        current_y += section_spacing;

        if (!benchmark_page.benchmark_running) {
            // Start Benchmark button
            try links.append(page.createLink(
                "Start Benchmark",
                "javascript:startBenchmark",
                center_x - button_width / 2.0,
                current_y,
                button_width,
                button_height,
            ));
        } else {
            // Show running status
            // TODO: Add progress indicator
        }

        current_y += button_height + 20;

        // Clear Results button (if results exist)
        if (benchmark_page.current_suite != null) {
            try links.append(page.createLink(
                "Clear Results",
                "javascript:clearResults",
                center_x - button_width / 2.0,
                current_y,
                button_width,
                button_height,
            ));
        }

        // Results section
        current_y += section_spacing;

        // Display results text
        _ = &benchmark_page.results_text; // TODO: Render results text

        // Navigation
        current_y = screen_height - 100;
        try links.append(page.createLink(
            "Back to Menu",
            "/",
            center_x - button_width / 2.0,
            current_y,
            button_width,
            button_height,
        ));
    }

    /// Detect GPU availability for honest benchmark reporting
    fn detectGPU(self: *LayoutBenchmarkPage) void {
        // TODO: Implement real GPU detection once GPU pipeline is connected
        // For now, GPU is not available since we removed the fake implementation
        self.gpu_available = false;
        self.config.test_gpu = false;

        if (self.gpu_available) {
            loggers.getUILog().info("gpu_detection", "GPU compute shaders available", .{});
        } else {
            loggers.getUILog().info("gpu_detection", "GPU compute shaders not yet connected", .{});
        }
    }

    /// Start benchmark execution
    pub fn startBenchmark(self: *LayoutBenchmarkPage) !void {
        if (self.benchmark_running) return;
        if (self.benchmark == null) return;

        self.benchmark_running = true;
        self.status_text.set("Running benchmarks...");
        self.progress_text.set("Initializing...");

        // Calculate total tests
        var test_count: usize = 0;
        if (self.config.test_cpu) test_count += self.config.element_counts.len;
        if (self.config.test_gpu and self.gpu_available) test_count += self.config.element_counts.len;
        self.total_tests = test_count;
        self.current_test_index = 0;

        // Run benchmark suite
        const suite = self.benchmark.?.runSuite(self.config) catch |err| {
            self.benchmark_running = false;
            self.status_text.set("Benchmark failed");
            self.progress_text.set("");
            loggers.getUILog().err("benchmark_failed", "Benchmark execution failed: {}", .{err});
            return;
        };

        // Store results
        if (self.current_suite) |*old_suite| {
            old_suite.deinit();
        }
        self.current_suite = suite;

        // Format results
        self.formatResults();

        self.benchmark_running = false;
        self.status_text.set("Benchmark completed");
        self.progress_text.set("");

        loggers.getUILog().info("benchmark_completed", "Benchmark suite completed successfully", .{});
    }

    /// Set GPU device for benchmarking (called by router)
    pub fn setGPUDevice(self: *LayoutBenchmarkPage, gpu_device: *anyopaque) void {
        // TODO: Use GPU device for real GPU benchmarking once pipeline connected
        _ = gpu_device;
        self.detectGPU();
    }

    /// Handle benchmark actions (called by router)
    pub fn handleAction(self: *LayoutBenchmarkPage, action: []const u8) !void {
        if (std.mem.eql(u8, action, "start")) {
            try self.startBenchmark();
        } else if (std.mem.eql(u8, action, "clear")) {
            self.clearResults();
        } else {
            loggers.getUILog().info("unknown_benchmark_action", "Unknown benchmark action: {s}", .{action});
        }
    }

    /// Clear benchmark results
    pub fn clearResults(self: *LayoutBenchmarkPage) void {
        if (self.current_suite) |*suite| {
            suite.deinit();
            self.current_suite = null;
        }

        self.results_text.set("Click 'Start Benchmark' to begin");
        self.status_text.set("Ready to benchmark");
        self.progress_text.set("");

        loggers.getUILog().info("benchmark_cleared", "Benchmark results cleared", .{});
    }

    /// Format benchmark results for display
    fn formatResults(self: *LayoutBenchmarkPage) void {
        if (self.current_suite == null) return;

        var results_buffer = std.ArrayList(u8).init(self.allocator);
        defer results_buffer.deinit();

        const writer = results_buffer.writer();

        // Write header
        writer.print("Layout Algorithm Benchmark Results\n", .{}) catch return;
        writer.print("=====================================\n\n", .{}) catch return;

        // Configuration info
        writer.print("Configuration:\n", .{}) catch return;
        writer.print("- Element counts: ", .{}) catch return;
        for (self.config.element_counts, 0..) |count, i| {
            if (i > 0) writer.print(", ", .{}) catch return;
            writer.print("{}", .{count}) catch return;
        }
        writer.print("\n", .{}) catch return;
        writer.print("- Iterations: {}\n", .{self.config.iterations}) catch return;
        writer.print("- Min runtime: {}ms\n", .{self.config.min_runtime_ms}) catch return;
        writer.print("- GPU available: {}\n\n", .{self.gpu_available}) catch return;

        // Results table
        writer.print("┌──────────────┬────────────┬──────────────┬──────────────┐\n", .{}) catch return;
        writer.print("│ Element Count│ Algorithm  │ Avg Time (μs)│ Success Rate │\n", .{}) catch return;
        writer.print("├──────────────┼────────────┼──────────────┼──────────────┤\n", .{}) catch return;

        for (self.current_suite.?.results.items) |result| {
            writer.print("│ {:>12} │ {s:>10} │ {:>12.2} │ {:>11.1}% │\n", .{
                result.element_count,
                result.implementation,
                result.getAvgTimeMicros(),
                result.success_rate * 100.0,
            }) catch return;
        }

        writer.print("└──────────────┴────────────┴──────────────┴──────────────┘\n", .{}) catch return;

        // Performance analysis
        if (self.current_suite.?.results.items.len > 1) {
            writer.print("\nPerformance Analysis:\n", .{}) catch return;
            writer.print("- All results are for CPU implementation\n", .{}) catch return;
            writer.print("- GPU compute shaders not yet connected to benchmark\n", .{}) catch return;
            writer.print("- Real GPU vs CPU comparison coming soon\n", .{}) catch return;
        }

        const final_results = results_buffer.toOwnedSlice() catch return;
        self.results_text.set(final_results);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const benchmark_page = try allocator.create(LayoutBenchmarkPage);
    benchmark_page.* = .{
        .base = .{
            .vtable = .{
                .init = LayoutBenchmarkPage.init,
                .deinit = LayoutBenchmarkPage.deinit,
                .update = LayoutBenchmarkPage.update,
                .render = LayoutBenchmarkPage.render,
                .destroy = LayoutBenchmarkPage.destroy,
            },
            .path = "/layout_benchmark",
            .title = "Layout Algorithm Benchmark",
        },
        .allocator = allocator,
        // Reactive signals will be initialized in init()
        .status_text = undefined,
        .progress_text = undefined,
        .results_text = undefined,
    };
    return &benchmark_page.base;
}
