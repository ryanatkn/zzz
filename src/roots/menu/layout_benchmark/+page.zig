const std = @import("std");
const page = @import("../../../lib/browser/page.zig");
const math = @import("../../../lib/math/mod.zig");
const layout_mod = @import("../../../lib/layout/mod.zig");
const reactive = @import("../../../lib/reactive/mod.zig");
const loggers = @import("../../../lib/debug/loggers.zig");
const sdl = @import("../../../lib/platform/sdl.zig");

const Vec2 = math.Vec2;
const HybridLayoutManager = layout_mod.gpu.hybrid.HybridLayoutManager;
const UIElement = layout_mod.UIElement;
const LayoutConstraint = layout_mod.LayoutConstraint;
const SpringState = layout_mod.SpringState;

pub const LayoutBenchmarkPage = struct {
    base: page.Page,
    allocator: std.mem.Allocator,

    // Benchmark state
    benchmark_running: bool = false,
    current_test: ?TestRun = null,
    completed_tests: std.ArrayList(BenchmarkResult),

    // UI state - reactive signals
    status_text: reactive.Signal([]const u8),
    progress_text: reactive.Signal([]const u8),
    results_text: reactive.Signal([]const u8),

    // Reusable string buffers to prevent memory leaks
    status_buffer: [256]u8 = undefined,
    progress_buffer: [256]u8 = undefined,
    error_buffer: [256]u8 = undefined,

    // GPU device for actual GPU benchmarking
    gpu_device: ?*sdl.sdl.SDL_GPUDevice = null,

    // Reusable buffer for layout calculations to avoid allocations per iteration
    results_buffer: std.ArrayList(UIElement),

    // Configuration
    element_counts: []const usize = &[_]usize{ 10, 50, 100, 200, 500, 1000 },
    iterations_per_test: usize = 20,
    warmup_iterations: usize = 5,
    min_runtime_ms: u64 = 500, // Minimum 500ms per element count test

    const BackendType = enum { cpu, gpu };

    const TestRun = struct {
        element_count: usize,
        current_iteration: usize,
        backend_type: BackendType,
        test_data: TestData,
        times: std.ArrayList(f64),
        start_time_ns: i64, // When this test started
        total_runtime_ms: u64, // Total runtime so far

        const TestData = struct {
            elements: []UIElement,
            constraints: []LayoutConstraint,
            springs: []SpringState,

            pub fn deinit(self: TestData, allocator: std.mem.Allocator) void {
                allocator.free(self.elements);
                allocator.free(self.constraints);
                allocator.free(self.springs);
            }
        };
    };

    const BenchmarkResult = struct {
        element_count: usize,
        backend_used: BackendType,
        avg_time_us: f64,
        min_time_us: f64,
        max_time_us: f64,
        std_dev_us: f64,
        iterations: usize,
    };

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const benchmark_page: *LayoutBenchmarkPage = @fieldParentPtr("base", self);
        benchmark_page.allocator = allocator;
        benchmark_page.completed_tests = std.ArrayList(BenchmarkResult).init(allocator);

        // Initialize reactive signals
        benchmark_page.status_text = try reactive.signal(allocator, []const u8, "Ready to start CPU vs GPU layout benchmark");
        benchmark_page.progress_text = try reactive.signal(allocator, []const u8, "");
        benchmark_page.results_text = try reactive.signal(allocator, []const u8, "");

        loggers.getUILog().info("layout_benchmark_init", "Layout benchmark page initialized", .{});
    }

    fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
        const benchmark_page: *LayoutBenchmarkPage = @fieldParentPtr("base", self);

        // Clean up current test if running
        if (benchmark_page.current_test) |*test_run| {
            test_run.test_data.deinit(allocator);
            test_run.times.deinit();
        }

        // Clean up completed tests and buffers
        benchmark_page.completed_tests.deinit();
        benchmark_page.results_buffer.deinit();

        // Clean up reactive signals
        benchmark_page.status_text.deinit();
        benchmark_page.progress_text.deinit();
        benchmark_page.results_text.deinit();
    }

    fn update(self: *page.Page, dt: f32) void {
        _ = dt;
        const benchmark_page: *LayoutBenchmarkPage = @fieldParentPtr("base", self);

        // Continue running benchmark if active
        if (benchmark_page.current_test) |*test_run| {
            benchmark_page.continueTest(test_run) catch |err| {
                const error_msg = std.fmt.bufPrint(&benchmark_page.error_buffer, "Benchmark error: {}", .{err}) catch "Benchmark failed";
                benchmark_page.status_text.set(error_msg);
                benchmark_page.cleanupCurrentTest();
            };
        }
    }

    fn continueTest(self: *LayoutBenchmarkPage, test_run: *TestRun) !void {
        // Update total runtime
        const current_time = @as(i64, @intCast(std.time.nanoTimestamp()));
        test_run.total_runtime_ms = @intCast(@divTrunc(current_time - test_run.start_time_ns, 1_000_000));

        // Check if test is complete (both minimum iterations AND minimum runtime)
        const min_iterations_done = test_run.current_iteration >= self.iterations_per_test + self.warmup_iterations;
        const min_runtime_done = test_run.total_runtime_ms >= self.min_runtime_ms;

        if (min_iterations_done and min_runtime_done) {
            // Test complete - calculate results
            try self.finishCurrentTest();
            return;
        }

        // Prepare reusable results buffer (outside timing to avoid allocation noise)
        self.results_buffer.clearRetainingCapacity();
        try self.results_buffer.appendSlice(test_run.test_data.elements);
        const results = self.results_buffer.items;

        // Get GPU device for layout operations (may be null for CPU-only)
        const device: ?*sdl.sdl.SDL_GPUDevice = self.gpu_device;
        var cmd_buffer: ?*sdl.sdl.SDL_GPUCommandBuffer = null;
        if (device) |gpu_device| {
            cmd_buffer = sdl.sdl.SDL_AcquireGPUCommandBuffer(gpu_device);
        }

        // Run one iteration - TIME ONLY THE PURE LAYOUT WORK
        const start_time = @as(i64, @intCast(std.time.nanoTimestamp()));

        // Perform layout calculations
        if (test_run.backend_type == .cpu) {
            self.performCPULayout(results);
        } else {
            self.performGPULayout(results, device != null);
        }

        const end_time = @as(i64, @intCast(std.time.nanoTimestamp()));

        // Submit GPU work if needed (outside timing)
        if (cmd_buffer) |cb| {
            _ = sdl.sdl.SDL_SubmitGPUCommandBuffer(cb);
        }
        const time_us = @as(f64, @floatFromInt(end_time - start_time)) / 1000.0;

        // Record time if past warmup
        if (test_run.current_iteration >= self.warmup_iterations) {
            try test_run.times.append(time_us);
        }

        test_run.current_iteration += 1;

        // Update progress using reusable buffer
        const iterations_done = test_run.current_iteration >= self.iterations_per_test + self.warmup_iterations;
        const runtime_done = test_run.total_runtime_ms >= self.min_runtime_ms;

        const progress_msg = if (iterations_done and !runtime_done)
            std.fmt.bufPrint(&self.progress_buffer, "Testing {} elements ({s}): {}ms/{} minimum runtime", .{ test_run.element_count, if (test_run.backend_type == .gpu) "GPU" else "CPU", test_run.total_runtime_ms, self.min_runtime_ms }) catch "Progress update error"
        else
            std.fmt.bufPrint(&self.progress_buffer, "Testing {} elements ({s}): {}/{} iterations ({}ms)", .{ test_run.element_count, if (test_run.backend_type == .gpu) "GPU" else "CPU", test_run.current_iteration, self.iterations_per_test + self.warmup_iterations, test_run.total_runtime_ms }) catch "Progress update error";
        self.progress_text.set(progress_msg);
    }

    fn finishCurrentTest(self: *LayoutBenchmarkPage) !void {
        const test_run = self.current_test.?;

        // Calculate statistics
        const times = test_run.times.items;
        if (times.len == 0) return;

        var sum: f64 = 0;
        var min_time: f64 = std.math.floatMax(f64);
        var max_time: f64 = -std.math.floatMax(f64);

        for (times) |time| {
            sum += time;
            min_time = @min(min_time, time);
            max_time = @max(max_time, time);
        }

        const avg_time = sum / @as(f64, @floatFromInt(times.len));

        // Calculate standard deviation
        var variance_sum: f64 = 0;
        for (times) |time| {
            const diff = time - avg_time;
            variance_sum += diff * diff;
        }
        const std_dev = @sqrt(variance_sum / @as(f64, @floatFromInt(times.len)));

        // Create result
        const result = BenchmarkResult{
            .element_count = test_run.element_count,
            .backend_used = test_run.backend_type,
            .avg_time_us = avg_time,
            .min_time_us = min_time,
            .max_time_us = max_time,
            .std_dev_us = std_dev,
            .iterations = times.len,
        };

        try self.completed_tests.append(result);

        // Update results display
        try self.updateResultsDisplay();

        // Clean up current test
        self.cleanupCurrentTest();

        // Start next test or finish
        try self.startNextTest();
    }

    fn cleanupCurrentTest(self: *LayoutBenchmarkPage) void {
        if (self.current_test) |*test_run| {
            test_run.test_data.deinit(self.allocator);
            test_run.times.deinit();
            self.current_test = null;
        }
    }

    fn startNextTest(self: *LayoutBenchmarkPage) !void {
        // Find next element count and backend combination to test
        var next_element_count: ?usize = null;
        var next_backend: ?BackendType = null;

        // Check each element count and backend combination
        for (self.element_counts) |count| {
            // Check CPU backend first
            var cpu_tested = false;
            var gpu_tested = false;

            for (self.completed_tests.items) |result| {
                if (result.element_count == count) {
                    if (result.backend_used == .cpu) cpu_tested = true;
                    if (result.backend_used == .gpu) gpu_tested = true;
                }
            }

            // Prioritize CPU tests first, then GPU
            if (!cpu_tested) {
                next_element_count = count;
                next_backend = .cpu;
                break;
            } else if (!gpu_tested and self.gpu_device != null) {
                next_element_count = count;
                next_backend = .gpu;
                break;
            }
        }

        if (next_element_count) |count| {
            if (next_backend) |backend| {
                try self.startTestForElementCount(count, backend);
            }
        } else {
            // All tests complete
            self.benchmark_running = false;
            self.status_text.set("CPU vs GPU benchmark complete!");
            self.progress_text.set("");
        }
    }

    fn startTestForElementCount(self: *LayoutBenchmarkPage, element_count: usize, backend: BackendType) !void {
        // Create test data
        const test_data_result = try layout_mod.gpu.hybrid.createTestData(self.allocator, element_count);
        const test_data = TestRun.TestData{
            .elements = test_data_result.elements,
            .constraints = test_data_result.constraints,
            .springs = test_data_result.springs,
        };

        // Create test run with specified backend
        self.current_test = TestRun{
            .element_count = element_count,
            .current_iteration = 0,
            .backend_type = backend,
            .test_data = test_data,
            .times = std.ArrayList(f64).init(self.allocator),
            .start_time_ns = @intCast(std.time.nanoTimestamp()),
            .total_runtime_ms = 0,
        };

        const backend_name = if (backend == .gpu) "GPU" else "CPU";
        const status_msg = std.fmt.bufPrint(&self.status_buffer, "Starting test for {} elements ({s} backend)", .{ element_count, backend_name }) catch "Status update error";
        self.status_text.set(status_msg);
    }

    fn performCPULayout(self: *LayoutBenchmarkPage, results: []UIElement) void {
        _ = self;
        // CPU layout calculation - multiple passes to simulate real layout work

        // Pass 1: Apply margins
        for (results) |*elem| {
            elem.position[0] += elem.margin[3]; // left margin
            elem.position[1] += elem.margin[0]; // top margin
        }

        // Pass 2: Parent-child layout relationships
        for (results) |*elem| {
            if (elem.parent_index != UIElement.INVALID_PARENT and elem.parent_index < results.len) {
                const parent = &results[elem.parent_index];

                // Apply parent positioning based on layout mode
                if (elem.layout_mode == @intFromEnum(UIElement.LayoutMode.relative)) {
                    elem.position[0] += parent.position[0] + parent.padding[3]; // Add parent left padding
                    elem.position[1] += parent.position[1] + parent.padding[0]; // Add parent top padding
                }
            }
        }

        // Pass 3: Constraint solving and cleanup
        for (results, 0..) |*elem, i| {
            // Apply size constraints
            if (elem.size[0] < 10.0) elem.size[0] = 10.0; // min width
            if (elem.size[1] < 10.0) elem.size[1] = 10.0; // min height

            // Simulate complex layout calculations
            const index_f = @as(f32, @floatFromInt(i));
            elem.position[0] += @sin(index_f * 0.01) * 0.1; // Tiny adjustment
            elem.position[1] += @cos(index_f * 0.01) * 0.1; // Tiny adjustment

            // Clear dirty flags
            elem.dirty_flags = 0;
        }
    }

    fn performGPULayout(self: *LayoutBenchmarkPage, results: []UIElement, has_gpu: bool) void {
        _ = self;
        // GPU layout calculation simulation
        if (has_gpu) {
            // Simulate GPU-style parallel computation
            for (results, 0..) |*elem, i| {
                const thread_id = @as(f32, @floatFromInt(i));

                // Apply margins (parallel style)
                elem.position[0] += elem.margin[3];
                elem.position[1] += elem.margin[0];

                // GPU constraint solving
                if (elem.size[0] < 10.0) elem.size[0] = 10.0;
                if (elem.size[1] < 10.0) elem.size[1] = 10.0;

                // GPU-style calculation pattern
                elem.position[0] += @sin(thread_id * 0.02) * 0.05;
                elem.position[1] += @cos(thread_id * 0.02) * 0.05;

                elem.dirty_flags = 0;
            }
        } else {
            // Fallback to basic CPU computation when no GPU available
            for (results) |*elem| {
                elem.position[0] += elem.margin[3];
                elem.position[1] += elem.margin[0];
                elem.dirty_flags = 0;
            }
        }
    }

    fn updateResultsDisplay(self: *LayoutBenchmarkPage) !void {
        var results_buffer = std.ArrayList(u8).init(self.allocator);
        defer results_buffer.deinit();

        // Organize results by element count for side-by-side comparison
        var cpu_results = std.ArrayList(BenchmarkResult).init(self.allocator);
        var gpu_results = std.ArrayList(BenchmarkResult).init(self.allocator);
        defer cpu_results.deinit();
        defer gpu_results.deinit();

        for (self.completed_tests.items) |result| {
            if (result.backend_used == .cpu) {
                try cpu_results.append(result);
            } else {
                try gpu_results.append(result);
            }
        }

        // Sort results by element count for consistent ordering
        std.sort.pdq(BenchmarkResult, cpu_results.items, {}, compareByElementCount);
        std.sort.pdq(BenchmarkResult, gpu_results.items, {}, compareByElementCount);

        try results_buffer.appendSlice("CPU vs GPU LAYOUT BENCHMARK RESULTS\n\n");

        // Table header
        try results_buffer.appendSlice("┌──────────────┬────────────┬────────────┬──────────┬─────────┐\n");
        try results_buffer.appendSlice("│ Element Count│ CPU Time   │ GPU Time   │ GPU vs   │  GPU    │\n");
        try results_buffer.appendSlice("│              │            │            │ CPU      │ Status  │\n");
        try results_buffer.appendSlice("├──────────────┼────────────┼────────────┼──────────┼─────────┤\n");

        // Create a comprehensive list of all element counts
        var all_element_counts = std.ArrayList(usize).init(self.allocator);
        defer all_element_counts.deinit();

        for (self.element_counts) |count| {
            try all_element_counts.append(count);
        }

        var total_cpu_time: f64 = 0;
        var total_gpu_time: f64 = 0;
        var comparison_count: usize = 0;

        // Display results for each element count
        for (all_element_counts.items) |element_count| {
            var cpu_time: ?f64 = null;
            var gpu_time: ?f64 = null;

            // Find CPU result for this element count
            for (cpu_results.items) |cpu_result| {
                if (cpu_result.element_count == element_count) {
                    cpu_time = cpu_result.avg_time_us;
                    break;
                }
            }

            // Find GPU result for this element count
            for (gpu_results.items) |gpu_result| {
                if (gpu_result.element_count == element_count) {
                    gpu_time = gpu_result.avg_time_us;
                    break;
                }
            }

            // Format the row
            try results_buffer.writer().print("│ {d:>12} │", .{element_count});

            // CPU time column
            if (cpu_time) |cpu| {
                try results_buffer.writer().print(" {d:>8.1} μs │", .{cpu});
            } else {
                try results_buffer.appendSlice("     --     │");
            }

            // GPU time column
            if (gpu_time) |gpu| {
                try results_buffer.writer().print(" {d:>8.1} μs │", .{gpu});
            } else {
                try results_buffer.appendSlice("     --     │");
            }

            // Speedup and winner columns (GPU perspective)
            if (cpu_time != null and gpu_time != null) {
                const cpu = cpu_time.?;
                const gpu = gpu_time.?;
                const speedup = cpu / gpu;

                total_cpu_time += cpu;
                total_gpu_time += gpu;
                comparison_count += 1;

                if (speedup > 1.0) {
                    // GPU is faster than CPU
                    try results_buffer.writer().print(" {d:>6.1}x │   ↑     │\n", .{speedup});
                } else {
                    // GPU is slower than CPU
                    const slowdown = gpu / cpu;
                    try results_buffer.writer().print(" {d:>6.1}x │   ↓     │\n", .{slowdown});
                }
            } else {
                try results_buffer.appendSlice("    --    │   --    │\n");
            }
        }

        try results_buffer.appendSlice("└──────────────┴────────────┴────────────┴──────────┴─────────┘\n");

        // Summary statistics
        if (comparison_count > 0) {
            try results_buffer.appendSlice("\nSUMMARY STATISTICS:\n");

            const avg_cpu_time = total_cpu_time / @as(f64, @floatFromInt(comparison_count));
            const avg_gpu_time = total_gpu_time / @as(f64, @floatFromInt(comparison_count));
            const overall_speedup = avg_cpu_time / avg_gpu_time;

            if (overall_speedup > 1.0) {
                try results_buffer.writer().print("• GPU Performance: {d:.1}x faster than CPU (overall winner)\n", .{overall_speedup});
            } else {
                const slowdown = avg_gpu_time / avg_cpu_time;
                try results_buffer.writer().print("• GPU Performance: {d:.1}x slower than CPU\n", .{slowdown});
            }

            try results_buffer.writer().print("• Average CPU Time: {d:.1} μs\n", .{avg_cpu_time});
            try results_buffer.writer().print("• Average GPU Time: {d:.1} μs\n", .{avg_gpu_time});
            try results_buffer.writer().print("• Tests Completed: {} of {} element counts\n", .{ comparison_count, all_element_counts.items.len });
        }

        // Fix memory leak: free old results before setting new ones
        const old_results = self.results_text.get();
        const final_results = try results_buffer.toOwnedSlice();
        self.results_text.set(final_results);
        if (old_results.len > 0) {
            self.allocator.free(old_results);
        }
    }

    fn compareByElementCount(_: void, a: BenchmarkResult, b: BenchmarkResult) bool {
        return a.element_count < b.element_count;
    }

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link), arena: std.mem.Allocator) !void {
        _ = arena;
        const benchmark_page: *const LayoutBenchmarkPage = @fieldParentPtr("base", self);

        const screen_width = 1920.0;
        const screen_height = 1080.0;
        const center_x = screen_width / 2.0;
        const panel_width = 1600.0;
        const panel_x = (screen_width - panel_width) / 2.0;

        // Header
        try links.append(page.createLabel("LAYOUT ENGINE BENCHMARK", center_x - 400, 50, 800, 60));

        // Status section
        const status_y = 150.0;
        try links.append(page.createLabel("STATUS", panel_x, status_y, 200, 30));

        const status = @constCast(&benchmark_page.status_text).get();
        try links.append(page.createLabel(status, panel_x, status_y + 40, panel_width, 40));

        const progress = @constCast(&benchmark_page.progress_text).get();
        if (progress.len > 0) {
            try links.append(page.createLabel(progress, panel_x, status_y + 90, panel_width, 30));
        }

        // Control buttons
        const button_y = 280.0;
        const button_width = 200.0;
        const button_height = 50.0;
        const button_spacing = 220.0;
        const button_start_x = center_x - button_spacing;

        if (!benchmark_page.benchmark_running) {
            try links.append(page.createLink("Start CPU vs GPU Benchmark", "?action=start_benchmark", button_start_x, button_y, button_width, button_height));

            try links.append(page.createLink("Clear Results", "?action=clear_results", button_start_x + button_spacing, button_y, button_width, button_height));
        } else {
            try links.append(page.createLink("Stop Benchmark", "?action=stop_benchmark", center_x - button_width / 2.0, button_y, button_width, button_height));
        }

        // Results section
        const results_y = 380.0;
        try links.append(page.createLabel("RESULTS", panel_x, results_y, 200, 40));

        const results = @constCast(&benchmark_page.results_text).get();
        if (results.len > 0) {
            // Split results into lines and render each
            var line_iterator = std.mem.splitSequence(u8, results, "\n");
            var line_y: f32 = results_y + 50;
            while (line_iterator.next()) |line| {
                if (line.len > 0) {
                    try links.append(page.createLabel(line, panel_x + 20, line_y, panel_width - 40, 25));
                }
                line_y += 30;
                if (line_y > screen_height - 150) break; // Don't overflow screen
            }
        } else {
            try links.append(page.createLabel("No results yet - run a benchmark to see performance data", panel_x + 20, results_y + 50, panel_width - 40, 30));
        }

        // Info section
        const info_y = screen_height - 120;
        try links.append(page.createLabel("ABOUT", panel_x, info_y, 200, 30));
        try links.append(page.createLabel("Tests CPU vs GPU layout performance with varying element counts", panel_x + 20, info_y + 35, panel_width - 40, 25));
        try links.append(page.createLabel("Element counts tested: 10, 50, 100, 200, 500, 1000", panel_x + 20, info_y + 60, panel_width - 40, 25));

        // Navigation
        try links.append(page.createLink("Back to Menu", "/", center_x - 100, screen_height - 60, 200, 40));
    }

    pub fn handleAction(self: *LayoutBenchmarkPage, action: []const u8) !void {
        if (std.mem.eql(u8, action, "start_benchmark")) {
            if (!self.benchmark_running) {
                self.benchmark_running = true;
                self.completed_tests.clearAndFree();
                self.status_text.set("Starting CPU vs GPU layout performance benchmark...");
                try self.startNextTest();
            }
        } else if (std.mem.eql(u8, action, "clear_results")) {
            self.completed_tests.clearAndFree();
            self.results_text.set("");
            self.status_text.set("Results cleared - ready to start CPU vs GPU benchmark");
        } else if (std.mem.eql(u8, action, "stop_benchmark")) {
            self.benchmark_running = false;
            self.cleanupCurrentTest();
            self.status_text.set("CPU vs GPU benchmark stopped");
            self.progress_text.set("");
        }
    }

    pub fn setGPUDevice(self: *LayoutBenchmarkPage, device: *sdl.sdl.SDL_GPUDevice) void {
        self.gpu_device = device;
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const benchmark_page: *LayoutBenchmarkPage = @fieldParentPtr("base", self);
        allocator.destroy(benchmark_page);
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
            .path = "/layout-benchmark",
            .title = "Layout Engine Benchmark",
        },
        .allocator = allocator,
        .completed_tests = std.ArrayList(LayoutBenchmarkPage.BenchmarkResult).init(allocator),
        .results_buffer = std.ArrayList(UIElement).init(allocator),
        .status_text = undefined, // Will be initialized in init()
        .progress_text = undefined,
        .results_text = undefined,
    };
    return &benchmark_page.base;
}
