/// Layout performance profiler
///
/// This module provides detailed performance profiling for layout operations,
/// helping identify bottlenecks and optimization opportunities.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;

/// Performance timing utilities
pub const Timer = struct {
    start_time: i64,
    
    pub fn start() Timer {
        return Timer{
            .start_time = std.time.nanoTimestamp(),
        };
    }
    
    pub fn end(self: Timer) f64 {
        const end_time = std.time.nanoTimestamp();
        return @as(f64, @floatFromInt(end_time - self.start_time)) / 1_000_000.0; // Convert to milliseconds
    }
    
    pub fn endMicroseconds(self: Timer) f64 {
        const end_time = std.time.nanoTimestamp();
        return @as(f64, @floatFromInt(end_time - self.start_time)) / 1_000.0; // Convert to microseconds
    }
};

/// Performance measurement data
pub const PerformanceMeasurement = struct {
    operation: Operation,
    duration_ms: f64,
    element_count: usize,
    timestamp: i64,
    memory_usage: ?usize = null,
    
    pub const Operation = enum {
        // Layout calculation phases
        measure_phase,
        constraint_resolution,
        position_calculation,
        size_calculation,
        layout_pass,
        
        // Backend operations
        backend_selection,
        cpu_layout,
        gpu_layout,
        hybrid_layout,
        
        // Animation operations
        spring_update,
        transition_update,
        sequence_update,
        
        // Validation and debugging
        validation,
        debug_collection,
        
        // Full pipeline
        complete_layout,
        
        pub fn toString(self: Operation) []const u8 {
            return switch (self) {
                .measure_phase => "Measure Phase",
                .constraint_resolution => "Constraint Resolution",
                .position_calculation => "Position Calculation",
                .size_calculation => "Size Calculation",
                .layout_pass => "Layout Pass",
                .backend_selection => "Backend Selection",
                .cpu_layout => "CPU Layout",
                .gpu_layout => "GPU Layout",
                .hybrid_layout => "Hybrid Layout",
                .spring_update => "Spring Update",
                .transition_update => "Transition Update",
                .sequence_update => "Sequence Update",
                .validation => "Validation",
                .debug_collection => "Debug Collection",
                .complete_layout => "Complete Layout",
            };
        }
    };
    
    /// Calculate operations per second
    pub fn getOpsPerSecond(self: PerformanceMeasurement) f64 {
        if (self.duration_ms <= 0.0) return 0.0;
        return @as(f64, @floatFromInt(self.element_count)) / (self.duration_ms / 1000.0);
    }
    
    /// Calculate time per element in microseconds
    pub fn getTimePerElement(self: PerformanceMeasurement) f64 {
        if (self.element_count == 0) return 0.0;
        return (self.duration_ms * 1000.0) / @as(f64, @floatFromInt(self.element_count));
    }
};

/// Performance statistics aggregation
pub const PerformanceStats = struct {
    total_duration_ms: f64 = 0.0,
    min_duration_ms: f64 = std.math.inf(f64),
    max_duration_ms: f64 = 0.0,
    measurement_count: usize = 0,
    total_elements: usize = 0,
    
    pub fn addMeasurement(self: *PerformanceStats, measurement: PerformanceMeasurement) void {
        self.total_duration_ms += measurement.duration_ms;
        self.min_duration_ms = @min(self.min_duration_ms, measurement.duration_ms);
        self.max_duration_ms = @max(self.max_duration_ms, measurement.duration_ms);
        self.measurement_count += 1;
        self.total_elements += measurement.element_count;
    }
    
    pub fn getAverageDuration(self: PerformanceStats) f64 {
        if (self.measurement_count == 0) return 0.0;
        return self.total_duration_ms / @as(f64, @floatFromInt(self.measurement_count));
    }
    
    pub fn getAverageElementCount(self: PerformanceStats) f64 {
        if (self.measurement_count == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_elements)) / @as(f64, @floatFromInt(self.measurement_count));
    }
    
    pub fn getAverageOpsPerSecond(self: PerformanceStats) f64 {
        const avg_duration = self.getAverageDuration();
        const avg_elements = self.getAverageElementCount();
        if (avg_duration <= 0.0) return 0.0;
        return avg_elements / (avg_duration / 1000.0);
    }
    
    pub fn reset(self: *PerformanceStats) void {
        self.* = PerformanceStats{};
    }
};

/// Layout performance profiler
pub const LayoutProfiler = struct {
    allocator: std.mem.Allocator,
    measurements: std.ArrayList(PerformanceMeasurement),
    stats_by_operation: std.HashMap(PerformanceMeasurement.Operation, PerformanceStats, std.hash_map.AutoContext(PerformanceMeasurement.Operation), 80),
    active_timers: std.HashMap(PerformanceMeasurement.Operation, Timer, std.hash_map.AutoContext(PerformanceMeasurement.Operation), 80),
    config: ProfilerConfig,
    
    pub const ProfilerConfig = struct {
        /// Maximum number of measurements to keep in memory
        max_measurements: usize = 1000,
        /// Whether to collect memory usage data
        collect_memory_stats: bool = false,
        /// Whether to automatically aggregate statistics
        auto_aggregate: bool = true,
        /// Minimum duration to record (filter out very short operations)
        min_duration_threshold_ms: f64 = 0.001,
    };
    
    pub fn init(allocator: std.mem.Allocator, config: ProfilerConfig) LayoutProfiler {
        return LayoutProfiler{
            .allocator = allocator,
            .measurements = std.ArrayList(PerformanceMeasurement).init(allocator),
            .stats_by_operation = std.HashMap(PerformanceMeasurement.Operation, PerformanceStats, std.hash_map.AutoContext(PerformanceMeasurement.Operation), 80).init(allocator),
            .active_timers = std.HashMap(PerformanceMeasurement.Operation, Timer, std.hash_map.AutoContext(PerformanceMeasurement.Operation), 80).init(allocator),
            .config = config,
        };
    }
    
    pub fn deinit(self: *LayoutProfiler) void {
        self.measurements.deinit();
        self.stats_by_operation.deinit();
        self.active_timers.deinit();
    }
    
    /// Start timing an operation
    pub fn startTiming(self: *LayoutProfiler, operation: PerformanceMeasurement.Operation) !void {
        const timer = Timer.start();
        try self.active_timers.put(operation, timer);
    }
    
    /// End timing an operation and record measurement
    pub fn endTiming(self: *LayoutProfiler, operation: PerformanceMeasurement.Operation, element_count: usize) !void {
        if (self.active_timers.get(operation)) |timer| {
            const duration_ms = timer.end();
            
            // Filter out very short operations if configured
            if (duration_ms >= self.config.min_duration_threshold_ms) {
                const measurement = PerformanceMeasurement{
                    .operation = operation,
                    .duration_ms = duration_ms,
                    .element_count = element_count,
                    .timestamp = std.time.nanoTimestamp(),
                    .memory_usage = if (self.config.collect_memory_stats) self.getCurrentMemoryUsage() else null,
                };
                
                try self.recordMeasurement(measurement);
            }
            
            _ = self.active_timers.remove(operation);
        }
    }
    
    /// Record a measurement directly
    pub fn recordMeasurement(self: *LayoutProfiler, measurement: PerformanceMeasurement) !void {
        // Add to measurements list
        try self.measurements.append(measurement);
        
        // Limit measurement history
        if (self.measurements.items.len > self.config.max_measurements) {
            _ = self.measurements.orderedRemove(0);
        }
        
        // Update aggregated statistics
        if (self.config.auto_aggregate) {
            var stats = self.stats_by_operation.get(measurement.operation) orelse PerformanceStats{};
            stats.addMeasurement(measurement);
            try self.stats_by_operation.put(measurement.operation, stats);
        }
    }
    
    /// Time a block of code automatically
    pub fn timeOperation(
        self: *LayoutProfiler,
        operation: PerformanceMeasurement.Operation,
        element_count: usize,
        func: anytype,
    ) !@TypeOf(func()) {
        try self.startTiming(operation);
        defer self.endTiming(operation, element_count) catch {};
        return func();
    }
    
    /// Get recent measurements
    pub fn getRecentMeasurements(self: *const LayoutProfiler, count: usize) []const PerformanceMeasurement {
        const measurements = self.measurements.items;
        const start_index = if (measurements.len > count) measurements.len - count else 0;
        return measurements[start_index..];
    }
    
    /// Get statistics for an operation
    pub fn getStatsForOperation(self: *const LayoutProfiler, operation: PerformanceMeasurement.Operation) ?PerformanceStats {
        return self.stats_by_operation.get(operation);
    }
    
    /// Get all measurements
    pub fn getAllMeasurements(self: *const LayoutProfiler) []const PerformanceMeasurement {
        return self.measurements.items;
    }
    
    /// Clear all measurements and statistics
    pub fn clear(self: *LayoutProfiler) void {
        self.measurements.clearRetainingCapacity();
        self.stats_by_operation.clearRetainingCapacity();
        self.active_timers.clearRetainingCapacity();
    }
    
    /// Reset statistics while keeping recent measurements
    pub fn resetStats(self: *LayoutProfiler) void {
        var iterator = self.stats_by_operation.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.reset();
        }
    }
    
    /// Get memory usage (placeholder implementation)
    fn getCurrentMemoryUsage(self: *LayoutProfiler) usize {
        _ = self;
        // TODO: Implement actual memory usage tracking
        return 0;
    }
    
    /// Generate performance report
    pub fn formatReport(self: *const LayoutProfiler, writer: anytype) !void {
        try writer.print("Layout Performance Report\n");
        try writer.print("========================\n\n");
        
        if (self.measurements.items.len == 0) {
            try writer.print("No performance data collected\n");
            return;
        }
        
        try writer.print("Total measurements: {d}\n", .{self.measurements.items.len});
        
        // Overall statistics
        var total_duration: f64 = 0;
        var total_elements: usize = 0;
        for (self.measurements.items) |measurement| {
            total_duration += measurement.duration_ms;
            total_elements += measurement.element_count;
        }
        
        const avg_duration = total_duration / @as(f64, @floatFromInt(self.measurements.items.len));
        const avg_elements = @as(f64, @floatFromInt(total_elements)) / @as(f64, @floatFromInt(self.measurements.items.len));
        
        try writer.print("Average duration: {d:.3} ms\n", .{avg_duration});
        try writer.print("Average elements: {d:.1}\n", .{avg_elements});
        try writer.print("Total time measured: {d:.3} ms\n\n", .{total_duration});
        
        // Per-operation statistics
        try writer.print("Performance by Operation:\n");
        try writer.print("========================\n");
        
        var iterator = self.stats_by_operation.iterator();
        while (iterator.next()) |entry| {
            const operation = entry.key_ptr.*;
            const stats = entry.value_ptr.*;
            
            try writer.print("{s}:\n", .{operation.toString()});
            try writer.print("  Count: {d}\n", .{stats.measurement_count});
            try writer.print("  Average: {d:.3} ms\n", .{stats.getAverageDuration()});
            try writer.print("  Min: {d:.3} ms\n", .{stats.min_duration_ms});
            try writer.print("  Max: {d:.3} ms\n", .{stats.max_duration_ms});
            try writer.print("  Ops/sec: {d:.0}\n", .{stats.getAverageOpsPerSecond()});
            try writer.print("\n");
        }
        
        // Recent measurements
        try writer.print("Recent Measurements (last 10):\n");
        try writer.print("==============================\n");
        
        const recent = self.getRecentMeasurements(10);
        for (recent, 0..) |measurement, i| {
            try writer.print("{d}. {s}: {d:.3} ms ({d} elements, {d:.1} ops/sec)\n", .{
                i + 1,
                measurement.operation.toString(),
                measurement.duration_ms,
                measurement.element_count,
                measurement.getOpsPerSecond(),
            });
        }
    }
    
    /// Get performance summary for quick analysis
    pub fn getPerformanceSummary(self: *const LayoutProfiler) PerformanceSummary {
        var summary = PerformanceSummary{};
        
        if (self.measurements.items.len == 0) return summary;
        
        // Find bottlenecks
        var slowest_operation: ?PerformanceMeasurement.Operation = null;
        var slowest_avg_duration: f64 = 0;
        
        var iterator = self.stats_by_operation.iterator();
        while (iterator.next()) |entry| {
            const stats = entry.value_ptr.*;
            const avg_duration = stats.getAverageDuration();
            
            if (avg_duration > slowest_avg_duration) {
                slowest_avg_duration = avg_duration;
                slowest_operation = entry.key_ptr.*;
            }
        }
        
        summary.slowest_operation = slowest_operation;
        summary.slowest_operation_avg_duration = slowest_avg_duration;
        
        // Calculate totals
        for (self.measurements.items) |measurement| {
            summary.total_measurements += 1;
            summary.total_duration_ms += measurement.duration_ms;
            summary.total_elements += measurement.element_count;
        }
        
        summary.average_duration_ms = summary.total_duration_ms / @as(f64, @floatFromInt(summary.total_measurements));
        summary.average_ops_per_second = (@as(f64, @floatFromInt(summary.total_elements)) / @as(f64, @floatFromInt(summary.total_measurements))) / (summary.average_duration_ms / 1000.0);
        
        return summary;
    }
    
    pub const PerformanceSummary = struct {
        total_measurements: usize = 0,
        total_duration_ms: f64 = 0,
        total_elements: usize = 0,
        average_duration_ms: f64 = 0,
        average_ops_per_second: f64 = 0,
        slowest_operation: ?PerformanceMeasurement.Operation = null,
        slowest_operation_avg_duration: f64 = 0,
    };
};

/// Performance measurement helper macros/functions
pub const ProfilerHelper = struct {
    /// Time a layout operation with automatic cleanup
    pub fn timeLayoutOperation(
        profiler: *LayoutProfiler,
        operation: PerformanceMeasurement.Operation,
        element_count: usize,
        comptime func: anytype,
        args: anytype,
    ) !@TypeOf(@call(.auto, func, args)) {
        try profiler.startTiming(operation);
        defer profiler.endTiming(operation, element_count) catch {};
        return @call(.auto, func, args);
    }
};

// Tests
test "timer basic functionality" {
    const testing = std.testing;
    
    const timer = Timer.start();
    
    // Small delay
    var sum: u64 = 0;
    for (0..1000) |i| {
        sum += i;
    }
    // Use the value to prevent optimization
    std.mem.doNotOptimizeAway(sum);
    
    const duration_ms = timer.end();
    try testing.expect(duration_ms >= 0.0);
    
    const duration_us = timer.endMicroseconds();
    try testing.expect(duration_us >= 0.0);
    try testing.expect(duration_us > duration_ms); // Microseconds should be larger number
}

test "performance measurement calculation" {
    const testing = std.testing;
    
    const measurement = PerformanceMeasurement{
        .operation = .layout_pass,
        .duration_ms = 10.0,
        .element_count = 100,
        .timestamp = std.time.nanoTimestamp(),
    };
    
    const ops_per_second = measurement.getOpsPerSecond();
    try testing.expect(ops_per_second == 10.0); // 100 elements in 10ms = 10 ops/sec
    
    const time_per_element = measurement.getTimePerElement();
    try testing.expect(time_per_element == 100.0); // 10ms * 1000 / 100 elements = 100 µs per element
}

test "performance stats aggregation" {
    const testing = std.testing;
    
    var stats = PerformanceStats{};
    
    stats.addMeasurement(PerformanceMeasurement{
        .operation = .layout_pass,
        .duration_ms = 5.0,
        .element_count = 50,
        .timestamp = std.time.nanoTimestamp(),
    });
    
    stats.addMeasurement(PerformanceMeasurement{
        .operation = .layout_pass,
        .duration_ms = 15.0,
        .element_count = 150,
        .timestamp = std.time.nanoTimestamp(),
    });
    
    try testing.expect(stats.measurement_count == 2);
    try testing.expect(stats.getAverageDuration() == 10.0);
    try testing.expect(stats.getAverageElementCount() == 100.0);
    try testing.expect(stats.min_duration_ms == 5.0);
    try testing.expect(stats.max_duration_ms == 15.0);
}

test "profiler basic operation" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; 
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var profiler = LayoutProfiler.init(allocator, LayoutProfiler.ProfilerConfig{});
    defer profiler.deinit();
    
    // Record a measurement
    const measurement = PerformanceMeasurement{
        .operation = .cpu_layout,
        .duration_ms = 5.5,
        .element_count = 42,
        .timestamp = std.time.nanoTimestamp(),
    };
    
    try profiler.recordMeasurement(measurement);
    
    const measurements = profiler.getAllMeasurements();
    try testing.expect(measurements.len == 1);
    try testing.expect(measurements[0].operation == .cpu_layout);
    try testing.expect(measurements[0].duration_ms == 5.5);
    try testing.expect(measurements[0].element_count == 42);
    
    // Check aggregated stats
    const stats = profiler.getStatsForOperation(.cpu_layout);
    try testing.expect(stats != null);
    try testing.expect(stats.?.measurement_count == 1);
    try testing.expect(stats.?.getAverageDuration() == 5.5);
}