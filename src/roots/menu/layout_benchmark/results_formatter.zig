const std = @import("std");

/// Professional results formatting for layout benchmark
pub const ResultsFormatter = struct {
    allocator: std.mem.Allocator,

    pub const ComparisonResult = struct {
        element_count: usize,
        cpu_time_us: ?f64,
        gpu_time_us: ?f64,
        cpu_runtime_ms: u64,
        gpu_runtime_ms: u64,
        backend_used: []const u8, // "CPU", "GPU", "GPU (CPU Fallback)"

        pub fn getSpeedup(self: *const ComparisonResult) ?f64 {
            if (self.cpu_time_us != null and self.gpu_time_us != null) {
                return self.cpu_time_us.? / self.gpu_time_us.?;
            }
            return null;
        }

        pub fn getWinner(self: *const ComparisonResult) []const u8 {
            if (self.getSpeedup()) |speedup| {
                return if (speedup > 1.0) "↑" else "↓";
            }
            return "--";
        }
    };

    pub fn init(allocator: std.mem.Allocator) ResultsFormatter {
        return .{ .allocator = allocator };
    }

    /// Generate professional table format for CPU vs GPU comparison
    pub fn formatComparisonTable(
        self: *ResultsFormatter,
        results: []const ComparisonResult,
    ) ![]const u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        // Title
        try buffer.appendSlice("CPU vs GPU LAYOUT BENCHMARK RESULTS\\n\\n");

        // Table header
        try buffer.appendSlice("┌──────────────┬────────────┬────────────┬──────────┬─────────┐\\n");
        try buffer.appendSlice("│ Element Count│ CPU Time   │ GPU Time   │ GPU vs   │  GPU    │\\n");
        try buffer.appendSlice("│              │            │            │ CPU      │ Status  │\\n");
        try buffer.appendSlice("├──────────────┼────────────┼────────────┼──────────┼─────────┤\\n");

        // Data rows
        for (results) |result| {
            // Element count column
            try buffer.writer().print("│ {d:>12} │", .{result.element_count});

            // CPU time column
            if (result.cpu_time_us) |cpu| {
                try buffer.writer().print(" {d:>8.1} μs │", .{cpu});
            } else {
                try buffer.appendSlice("     --     │");
            }

            // GPU time column
            if (result.gpu_time_us) |gpu| {
                try buffer.writer().print(" {d:>8.1} μs │", .{gpu});
            } else {
                try buffer.appendSlice("     --     │");
            }

            // Speedup and status columns (GPU perspective)
            if (result.getSpeedup()) |speedup| {
                if (speedup > 1.0) {
                    // GPU is faster than CPU
                    try buffer.writer().print(" {d:>6.1}x │   ↑     │\\n", .{speedup});
                } else {
                    // GPU is slower than CPU
                    const slowdown = 1.0 / speedup;
                    try buffer.writer().print(" {d:>6.1}x │   ↓     │\\n", .{slowdown});
                }
            } else {
                try buffer.appendSlice("    --    │   --    │\\n");
            }
        }

        try buffer.appendSlice("└──────────────┴────────────┴────────────┴──────────┴─────────┘\\n");

        // Summary statistics
        const summary = try self.calculateSummaryStats(results);
        if (summary.comparison_count > 0) {
            try buffer.appendSlice("\\nSUMMARY STATISTICS:\\n");

            if (summary.overall_speedup > 1.0) {
                try buffer.writer().print("• GPU Performance: {d:.1}x faster than CPU (overall winner)\\n", .{summary.overall_speedup});
            } else {
                const slowdown = 1.0 / summary.overall_speedup;
                try buffer.writer().print("• GPU Performance: {d:.1}x slower than CPU\\n", .{slowdown});
            }

            try buffer.writer().print("• Average CPU Time: {d:.1} μs\\n", .{summary.avg_cpu_time});
            try buffer.writer().print("• Average GPU Time: {d:.1} μs\\n", .{summary.avg_gpu_time});
            try buffer.writer().print("• Tests Completed: {} of {} element counts\\n", .{ summary.comparison_count, results.len });
            try buffer.writer().print("• Backend Info: {s}\\n", .{summary.backend_info});
        }

        return try buffer.toOwnedSlice();
    }

    const SummaryStats = struct {
        avg_cpu_time: f64,
        avg_gpu_time: f64,
        overall_speedup: f64,
        comparison_count: usize,
        backend_info: []const u8,
    };

    fn calculateSummaryStats(self: *ResultsFormatter, results: []const ComparisonResult) !SummaryStats {
        _ = self;

        var total_cpu_time: f64 = 0;
        var total_gpu_time: f64 = 0;
        var comparison_count: usize = 0;
        var has_real_gpu = false;
        var has_fallback = false;

        for (results) |result| {
            if (result.cpu_time_us != null and result.gpu_time_us != null) {
                total_cpu_time += result.cpu_time_us.?;
                total_gpu_time += result.gpu_time_us.?;
                comparison_count += 1;

                if (std.mem.eql(u8, result.backend_used, "GPU")) {
                    has_real_gpu = true;
                } else if (std.mem.eql(u8, result.backend_used, "GPU (CPU Fallback)")) {
                    has_fallback = true;
                }
            }
        }

        const avg_cpu_time = if (comparison_count > 0) total_cpu_time / @as(f64, @floatFromInt(comparison_count)) else 0;
        const avg_gpu_time = if (comparison_count > 0) total_gpu_time / @as(f64, @floatFromInt(comparison_count)) else 0;
        const overall_speedup = if (avg_gpu_time > 0) avg_cpu_time / avg_gpu_time else 1.0;

        const backend_info = if (has_real_gpu)
            "Real GPU compute shaders"
        else if (has_fallback)
            "GPU fallback (CPU simulation)"
        else
            "CPU only";

        return SummaryStats{
            .avg_cpu_time = avg_cpu_time,
            .avg_gpu_time = avg_gpu_time,
            .overall_speedup = overall_speedup,
            .comparison_count = comparison_count,
            .backend_info = backend_info,
        };
    }
};
