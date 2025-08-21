const std = @import("std");
const page = @import("../../../lib/browser/page.zig");
const math = @import("../../../lib/math/mod.zig");
const layout_mod = @import("../../../lib/layout/mod.zig");
const reactive = @import("../../../lib/reactive/mod.zig");
const loggers = @import("../../../lib/debug/loggers.zig");
const sdl = @import("../../../lib/platform/sdl.zig");
const layout_backends = @import("layout_backends.zig");
const layout_validator = @import("layout_validator.zig");
const statistical_analysis = @import("statistical_analysis.zig");

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
    gpu_available: bool = false, // True only if real GPU backend successfully initialized

    // Layout backends for real layout calculations
    cpu_backend: layout_backends.CpuLayoutEngine,
    gpu_backend: ?layout_backends.GpuLayoutEngine,

    // Reusable buffer for layout calculations to avoid allocations per iteration
    results_buffer: std.ArrayList(UIElement),
    
    // Layout validation system
    validator: layout_validator.LayoutValidator,
    
    // Statistical analysis system
    statistical_analyzer: statistical_analysis.StatisticalAnalysis,

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
        // Enhanced statistics
        median_time_us: f64,
        outlier_count: usize,
        measurement_quality: statistical_analysis.MeasurementQuality,
        coefficient_of_variation: f64,
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

        // Clean up layout backends
        benchmark_page.cpu_backend.deinit();
        if (benchmark_page.gpu_backend) |*gpu| {
            gpu.deinit();
        }
        
        // Clean up validator
        benchmark_page.validator.deinit();

        // Free any remaining results text content before deinit signals
        const current_results = benchmark_page.results_text.get();
        if (current_results.len > 0) {
            benchmark_page.allocator.free(current_results);
        }

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

        // Pre-allocate any backend resources to avoid allocation during timing
        self.cpu_backend.ensureBoxModels(results.len) catch {
            loggers.getUILog().err("backend_prealloc_fail", "Failed to pre-allocate CPU backend resources for {} elements", .{results.len});
            return;
        };

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
        } else if (test_run.backend_type == .gpu and self.gpu_available) {
            self.performGPULayout(results, true);
        } else {
            // This should not happen - indicates scheduling logic error
            loggers.getUILog().err("invalid_gpu_test", "GPU test scheduled but GPU not available", .{});
            return;
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

        // Enhanced statistical analysis with outlier detection
        const times = test_run.times.items;
        if (times.len == 0) return;

        // Perform comprehensive statistical analysis
        var stats = try self.statistical_analyzer.analyzeData(times);
        defer self.statistical_analyzer.freeOutlierResult(&stats.outliers);

        // Log measurement quality
        const quality_str = switch (stats.measurement_quality) {
            .excellent => "excellent",
            .good => "good", 
            .fair => "fair",
            .poor => "poor",
        };
        
        if (stats.outliers.outlier_count > 0) {
            loggers.getUILog().info("benchmark_outliers", "Test {s} {} elements: {} outliers detected, quality: {s}, CV: {d:.3}", 
                .{ if (test_run.backend_type == .gpu) "GPU" else "CPU", test_run.element_count, stats.outliers.outlier_count, quality_str, stats.coefficient_of_variation });
        }

        // Create result with enhanced statistics
        const result = BenchmarkResult{
            .element_count = test_run.element_count,
            .backend_used = test_run.backend_type,
            .avg_time_us = stats.mean,
            .min_time_us = stats.min,
            .max_time_us = stats.max,
            .std_dev_us = stats.std_dev,
            .iterations = times.len,
            .median_time_us = stats.median,
            .outlier_count = stats.outliers.outlier_count,
            .measurement_quality = stats.measurement_quality,
            .coefficient_of_variation = stats.coefficient_of_variation,
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
            } else if (!gpu_tested and self.gpu_available) {
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

        // Pre-allocate CPU backend resources for this test size to avoid allocations during timing
        self.cpu_backend.ensureBoxModels(element_count) catch |err| {
            loggers.getUILog().err("backend_prealloc_startup_fail", "Failed to pre-allocate CPU backend resources for {} elements: {}", .{ element_count, err });
            test_data.deinit(self.allocator);
            return err;
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

        // Perform validation check once per test to ensure correctness
        self.validateLayoutResults(test_data.elements) catch |err| {
            loggers.getUILog().err("validation_setup_error", "Failed to validate layout for {} elements: {}", .{ element_count, err });
        };
    }

    fn performCPULayout(self: *LayoutBenchmarkPage, results: []UIElement) void {
        // Use real CPU layout backend with box model calculations
        self.cpu_backend.performLayout(results);
    }

    fn performGPULayout(self: *LayoutBenchmarkPage, results: []UIElement, has_gpu: bool) void {
        _ = has_gpu; // Parameter no longer needed since function only called when GPU available
        
        if (self.gpu_backend) |*gpu| {
            // Use real GPU layout backend
            gpu.performLayout(results);
        } else {
            // This should never happen since gpu_available is checked before calling
            loggers.getUILog().err("gpu_backend_missing", "GPU layout called but backend is null", .{});
        }
    }

    /// Validate that CPU and GPU backends produce equivalent results
    fn validateLayoutResults(self: *LayoutBenchmarkPage, elements: []UIElement) !void {
        if (!self.validator.validation_enabled) return;
        
        // Skip validation when GPU is not available
        if (!self.gpu_available) {
            loggers.getUILog().debug("validation_skipped", "Skipping cross-backend validation - GPU not available", .{});
            return;
        }

        // Create a copy of elements for CPU layout
        const cpu_elements = try self.validator.copyElements(elements);
        self.performCPULayout(cpu_elements);

        // Create another copy for GPU layout  
        const gpu_elements = try self.validator.copyElements(elements);
        self.performGPULayout(gpu_elements, true);

        // Validate the results match
        const validation_result = try self.validator.validateResults(cpu_elements, gpu_elements);

        if (!validation_result.is_valid) {
            const error_msg = std.fmt.bufPrint(&self.error_buffer, 
                "Layout validation failed: max pos error {d:.6}, max size error {d:.6}", 
                .{ validation_result.max_position_error, validation_result.max_size_error }) catch "Validation error";
            loggers.getUILog().err("layout_validation_error", "{s}", .{error_msg});
            
            // For development, we could pause the benchmark or show warnings
            // For now, just log the error and continue
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
        
        // Backend availability status
        try results_buffer.appendSlice("Backend Status:\n");
        try results_buffer.appendSlice("• CPU Backend: Available\n");
        if (self.gpu_available) {
            try results_buffer.appendSlice("• GPU Backend: Available (Simulated - not real GPU compute)\n");
        } else {
            try results_buffer.appendSlice("• GPU Backend: Not Available (skipped GPU tests)\n");
        }
        try results_buffer.appendSlice("\n");

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
            } else if (self.gpu_available) {
                // GPU available but no result yet (test pending)
                try results_buffer.appendSlice("     --     │");
            } else {
                // GPU not available
                try results_buffer.appendSlice("    N/A     │");
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
            } else if (!self.gpu_available) {
                // GPU not available - show N/A instead of --
                try results_buffer.appendSlice("   N/A   │  N/A    │\n");
            } else {
                // GPU available but no results yet (tests pending)
                try results_buffer.appendSlice("    --    │   --    │\n");
            }
        }

        try results_buffer.appendSlice("└──────────────┴────────────┴────────────┴──────────┴─────────┘\n");

        // Summary statistics
        try results_buffer.appendSlice("\nSUMMARY STATISTICS:\n");
        
        if (!self.gpu_available) {
            try results_buffer.appendSlice("• GPU Performance: Not Available (GPU device or backend unavailable)\n");
            
            // Show CPU-only statistics
            var cpu_tests: usize = 0;
            var total_cpu_only_time: f64 = 0;
            
            for (cpu_results.items) |result| {
                total_cpu_only_time += result.avg_time_us;
                cpu_tests += 1;
            }
            
            if (cpu_tests > 0) {
                const avg_cpu_only_time = total_cpu_only_time / @as(f64, @floatFromInt(cpu_tests));
                try results_buffer.writer().print("• Average CPU Time: {d:.1} μs\n", .{avg_cpu_only_time});
                try results_buffer.writer().print("• CPU Tests Completed: {} of {} element counts\n", .{ cpu_tests, all_element_counts.items.len });
            }
        } else if (comparison_count > 0) {
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
        } else {
            try results_buffer.appendSlice("• GPU Backend: Available but no GPU vs CPU comparisons yet\n");
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
        
        // Try to initialize GPU backend (currently simulated, but tests the architecture)
        self.gpu_backend = layout_backends.GpuLayoutEngine.init(self.allocator, device) catch |err| blk: {
            loggers.getUILog().err("gpu_backend_init_fail", "Failed to initialize GPU layout backend: {}", .{err});
            self.gpu_available = false;
            break :blk null;
        };
        
        if (self.gpu_backend != null) {
            self.gpu_available = true;
            loggers.getUILog().info("gpu_backend_ready", "GPU layout backend initialized successfully (simulated)", .{});
            loggers.getUILog().warn("gpu_backend_simulated", "GPU backend is currently simulated - results show architecture performance, not real GPU compute", .{});
        } else {
            self.gpu_available = false;
            loggers.getUILog().warn("gpu_backend_unavailable", "GPU layout backend unavailable - GPU tests will be skipped", .{});
        }
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
        .cpu_backend = layout_backends.CpuLayoutEngine.init(allocator),
        .gpu_backend = null, // Will be initialized if GPU device is available
        .validator = layout_validator.LayoutValidator.init(allocator, 0.01), // Default validation tolerance
        .statistical_analyzer = statistical_analysis.StatisticalAnalysis.init(allocator, statistical_analysis.StatisticalAnalysis.OutlierConfig{}),
        .status_text = undefined, // Will be initialized in init()
        .progress_text = undefined,
        .results_text = undefined,
    };
    return &benchmark_page.base;
}
