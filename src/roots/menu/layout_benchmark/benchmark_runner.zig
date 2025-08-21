const std = @import("std");

/// Core benchmarking logic with proper timing isolation and validation
pub const BenchmarkRunner = struct {
    allocator: std.mem.Allocator,
    min_runtime_ms: u64,
    warmup_iterations: usize,

    pub const Config = struct {
        min_runtime_ms: u64 = 500,
        warmup_iterations: usize = 5,
        validation_enabled: bool = true,
    };

    pub const TestResult = struct {
        iterations: usize,
        times_us: []f64,
        total_runtime_ms: u64,
        avg_time_us: f64,
        min_time_us: f64,
        max_time_us: f64,
        std_dev_us: f64,

        pub fn calculateStats(times: []const f64) TestResult {
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

            return TestResult{
                .iterations = times.len,
                .times_us = undefined, // Will be set by caller
                .total_runtime_ms = 0, // Will be set by caller
                .avg_time_us = avg_time,
                .min_time_us = min_time,
                .max_time_us = max_time,
                .std_dev_us = std_dev,
            };
        }
    };

    pub fn init(allocator: std.mem.Allocator, config: Config) BenchmarkRunner {
        return .{
            .allocator = allocator,
            .min_runtime_ms = config.min_runtime_ms,
            .warmup_iterations = config.warmup_iterations,
        };
    }

    /// Run a benchmark function until minimum iterations and runtime are met
    pub fn runBenchmark(
        self: *BenchmarkRunner,
        comptime T: type,
        benchmark_fn: *const fn (data: T) void,
        test_data: T,
        min_iterations: usize,
    ) !TestResult {
        var times = std.ArrayList(f64).init(self.allocator);
        defer times.deinit();

        const start_time_ns = std.time.nanoTimestamp();
        var iteration: usize = 0;

        while (true) {
            const current_time = std.time.nanoTimestamp();
            const total_runtime_ms = @as(u64, @intCast(@divTrunc(current_time - start_time_ns, 1_000_000)));

            // Check completion conditions
            const min_iterations_done = iteration >= min_iterations + self.warmup_iterations;
            const min_runtime_done = total_runtime_ms >= self.min_runtime_ms;

            if (min_iterations_done and min_runtime_done) {
                break;
            }

            // Run one iteration with precise timing
            const iter_start = std.time.nanoTimestamp();
            benchmark_fn(test_data);
            const iter_end = std.time.nanoTimestamp();

            // Record time if past warmup
            if (iteration >= self.warmup_iterations) {
                const time_us = @as(f64, @floatFromInt(iter_end - iter_start)) / 1000.0;
                try times.append(time_us);
            }

            iteration += 1;
        }

        // Calculate final statistics
        var result = TestResult.calculateStats(times.items);
        result.total_runtime_ms = @as(u64, @intCast(@divTrunc(std.time.nanoTimestamp() - start_time_ns, 1_000_000)));

        return result;
    }

    /// Validate that benchmark results are consistent (detect optimization bugs)
    pub fn validateResults(
        self: *BenchmarkRunner,
        comptime T: type,
        comptime R: type,
        benchmark_fn: *const fn (data: T) R,
        test_data: T,
        iterations: usize,
    ) !bool {
        _ = self;

        // Run benchmark multiple times and compare results
        const first_result = benchmark_fn(test_data);

        for (0..iterations) |_| {
            const result = benchmark_fn(test_data);
            if (!std.meta.eql(result, first_result)) {
                return false; // Results not consistent
            }
        }

        return true;
    }
};
