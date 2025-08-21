/// Layout debugging and profiling utilities
///
/// This module provides comprehensive debugging and performance analysis tools
/// for layout systems, including validation, profiling, and diagnostic utilities.
pub const validator = @import("validator.zig");
pub const profiler = @import("profiler.zig");

// Re-export commonly used types
pub const ValidationError = validator.ValidationError;
pub const LayoutValidator = validator.LayoutValidator;
pub const LayoutDebugger = validator.LayoutDebugger;

pub const Timer = profiler.Timer;
pub const PerformanceMeasurement = profiler.PerformanceMeasurement;
pub const PerformanceStats = profiler.PerformanceStats;
pub const LayoutProfiler = profiler.LayoutProfiler;
pub const ProfilerHelper = profiler.ProfilerHelper;

/// Integrated debugging suite combining validation and profiling
pub const LayoutDebugSuite = struct {
    allocator: std.mem.Allocator,
    validator: LayoutValidator,
    profiler: LayoutProfiler,
    debugger: LayoutDebugger,
    config: DebugConfig,

    pub const DebugConfig = struct {
        /// Enable validation during layout operations
        enable_validation: bool = true,
        /// Enable performance profiling
        enable_profiling: bool = true,
        /// Enable operation debugging/tracing
        enable_debugging: bool = false,
        /// Automatically generate reports
        auto_report: bool = false,
        /// Report output interval (in layout operations)
        report_interval: usize = 100,
        /// Validation configuration
        validation_config: validator.LayoutValidator.ValidationConfig = .{},
        /// Profiler configuration
        profiler_config: profiler.LayoutProfiler.ProfilerConfig = .{},
    };

    pub fn init(allocator: std.mem.Allocator, config: DebugConfig) LayoutDebugSuite {
        return LayoutDebugSuite{
            .allocator = allocator,
            .validator = LayoutValidator.init(allocator, config.validation_config),
            .profiler = LayoutProfiler.init(allocator, config.profiler_config),
            .debugger = LayoutDebugger.init(allocator),
            .config = config,
        };
    }

    pub fn deinit(self: *LayoutDebugSuite) void {
        self.validator.deinit();
        self.profiler.deinit();
        self.debugger.deinit();
    }

    /// Validate layout results with optional profiling
    pub fn validateLayout(
        self: *LayoutDebugSuite,
        elements: []const types.LayoutResult,
        container_bounds: math.Rectangle,
    ) !void {
        if (!self.config.enable_validation) return;

        if (self.config.enable_profiling) {
            try self.profiler.timeOperation(.validation, elements.len, struct {
                fn validate(validator_ptr: *LayoutValidator, elems: []const types.LayoutResult, bounds: math.Rectangle) !void {
                    try validator_ptr.validateLayout(elems, bounds);
                }
            }.validate, .{ &self.validator, elements, container_bounds });
        } else {
            try self.validator.validateLayout(elements, container_bounds);
        }
    }

    /// Profile a layout operation
    pub fn profileLayoutOperation(
        self: *LayoutDebugSuite,
        operation: PerformanceMeasurement.Operation,
        element_count: usize,
        func: anytype,
    ) !@TypeOf(func()) {
        if (!self.config.enable_profiling) return func();
        return self.profiler.timeOperation(operation, element_count, func);
    }

    /// Record a debug operation
    pub fn recordDebugOperation(
        self: *LayoutDebugSuite,
        element_index: usize,
        operation: LayoutDebugger.DebugEntry.Operation,
        before_state: ?LayoutDebugger.DebugEntry.ElementState,
        after_state: ?LayoutDebugger.DebugEntry.ElementState,
    ) !void {
        if (!self.config.enable_debugging) return;
        try self.debugger.recordOperation(element_index, operation, before_state, after_state);
    }

    /// Generate comprehensive debug report
    pub fn generateReport(self: *const LayoutDebugSuite, writer: anytype) !void {
        try writer.print("Layout Debug Suite Report\n");
        try writer.print("========================\n\n");

        // Validation report
        if (self.config.enable_validation) {
            try self.validator.formatReport(writer);
            try writer.print("\n");
        }

        // Performance report
        if (self.config.enable_profiling) {
            try self.profiler.formatReport(writer);
            try writer.print("\n");
        }

        // Debug operation history
        if (self.config.enable_debugging) {
            try self.debugger.formatReport(writer);
            try writer.print("\n");
        }

        // Summary
        try self.generateSummary(writer);
    }

    /// Generate a quick summary of the debugging session
    pub fn generateSummary(self: *const LayoutDebugSuite, writer: anytype) !void {
        try writer.print("Debug Session Summary\n");
        try writer.print("====================\n");

        if (self.config.enable_validation) {
            const validation_errors = self.validator.getErrors();
            try writer.print("Validation: {d} issues found", .{validation_errors.len});
            if (validation_errors.len > 0) {
                const critical_count = self.validator.getErrorCountBySeverity(.critical);
                const error_count = self.validator.getErrorCountBySeverity(.err);
                if (critical_count > 0 or error_count > 0) {
                    try writer.print(" ({d} critical, {d} errors)", .{ critical_count, error_count });
                }
            }
            try writer.print("\n");
        }

        if (self.config.enable_profiling) {
            const perf_summary = self.profiler.getPerformanceSummary();
            try writer.print("Performance: {d} measurements, avg {d:.3} ms", .{
                perf_summary.total_measurements,
                perf_summary.average_duration_ms,
            });
            if (perf_summary.slowest_operation) |slowest| {
                try writer.print(" (slowest: {s})", .{slowest.toString()});
            }
            try writer.print("\n");
        }

        if (self.config.enable_debugging) {
            const debug_history = self.debugger.getHistory();
            try writer.print("Debug Operations: {d} recorded\n", .{debug_history.len});
        }

        // Overall health assessment
        const is_healthy = self.assessLayoutHealth();
        try writer.print("Overall Health: {s}\n", .{if (is_healthy) "GOOD" else "ISSUES DETECTED"});
    }

    /// Assess overall layout system health
    pub fn assessLayoutHealth(self: *const LayoutDebugSuite) bool {
        // Check validation health
        if (self.config.enable_validation) {
            if (!self.validator.isValid()) {
                const critical_count = self.validator.getErrorCountBySeverity(.critical);
                const error_count = self.validator.getErrorCountBySeverity(.err);
                if (critical_count > 0 or error_count > 0) {
                    return false;
                }
            }
        }

        // Check performance health
        if (self.config.enable_profiling) {
            const perf_summary = self.profiler.getPerformanceSummary();

            // Consider layout unhealthy if average duration is too high
            const duration_threshold_ms = 16.67; // ~60 FPS frame budget
            if (perf_summary.average_duration_ms > duration_threshold_ms) {
                return false;
            }

            // Check for very low throughput
            const min_ops_per_second = 100.0;
            if (perf_summary.average_ops_per_second < min_ops_per_second and perf_summary.total_measurements > 5) {
                return false;
            }
        }

        return true;
    }

    /// Clear all debug data
    pub fn clear(self: *LayoutDebugSuite) void {
        if (self.config.enable_validation) {
            self.validator.clear();
        }
        if (self.config.enable_profiling) {
            self.profiler.clear();
        }
        if (self.config.enable_debugging) {
            self.debugger.clear();
        }
    }

    /// Get debug statistics
    pub fn getDebugStats(self: *const LayoutDebugSuite) DebugStats {
        return DebugStats{
            .validation_enabled = self.config.enable_validation,
            .profiling_enabled = self.config.enable_profiling,
            .debugging_enabled = self.config.enable_debugging,
            .validation_error_count = if (self.config.enable_validation) self.validator.getErrors().len else 0,
            .performance_measurement_count = if (self.config.enable_profiling) self.profiler.getAllMeasurements().len else 0,
            .debug_operation_count = if (self.config.enable_debugging) self.debugger.getHistory().len else 0,
            .layout_health = self.assessLayoutHealth(),
        };
    }

    pub const DebugStats = struct {
        validation_enabled: bool,
        profiling_enabled: bool,
        debugging_enabled: bool,
        validation_error_count: usize,
        performance_measurement_count: usize,
        debug_operation_count: usize,
        layout_health: bool,
    };
};

/// Debug presets for common scenarios
pub const DebugPresets = struct {
    /// Development preset - all debugging features enabled
    pub const development = LayoutDebugSuite.DebugConfig{
        .enable_validation = true,
        .enable_profiling = true,
        .enable_debugging = true,
        .auto_report = false,
        .validation_config = .{
            .check_overlaps = true,
            .validate_constraints = true,
            .check_performance = true,
        },
        .profiler_config = .{
            .collect_memory_stats = true,
            .auto_aggregate = true,
            .min_duration_threshold_ms = 0.0,
        },
    };

    /// Production preset - minimal overhead, validation only
    pub const production = LayoutDebugSuite.DebugConfig{
        .enable_validation = true,
        .enable_profiling = false,
        .enable_debugging = false,
        .auto_report = false,
        .validation_config = .{
            .check_overlaps = false,
            .validate_constraints = true,
            .check_performance = false,
        },
    };

    /// Performance testing preset - profiling focused
    pub const performance_testing = LayoutDebugSuite.DebugConfig{
        .enable_validation = false,
        .enable_profiling = true,
        .enable_debugging = false,
        .auto_report = true,
        .report_interval = 50,
        .profiler_config = .{
            .collect_memory_stats = true,
            .auto_aggregate = true,
            .min_duration_threshold_ms = 0.001,
            .max_measurements = 2000,
        },
    };

    /// Debugging preset - detailed operation tracking
    pub const debugging = LayoutDebugSuite.DebugConfig{
        .enable_validation = true,
        .enable_profiling = false,
        .enable_debugging = true,
        .auto_report = false,
        .validation_config = .{
            .check_overlaps = true,
            .validate_constraints = true,
            .check_performance = false,
        },
    };
};

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");

// Tests
test "debug suite initialization" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var debug_suite = LayoutDebugSuite.init(allocator, DebugPresets.development);
    defer debug_suite.deinit();

    const stats = debug_suite.getDebugStats();
    try testing.expect(stats.validation_enabled);
    try testing.expect(stats.profiling_enabled);
    try testing.expect(stats.debugging_enabled);
    try testing.expect(stats.layout_health); // Should be healthy initially
}

test "debug suite layout validation" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var debug_suite = LayoutDebugSuite.init(allocator, DebugPresets.development);
    defer debug_suite.deinit();

    // Test with valid layout
    const valid_elements = [_]types.LayoutResult{
        types.LayoutResult{
            .position = math.Vec2{ .x = 0, .y = 0 },
            .size = math.Vec2{ .x = 100, .y = 50 },
            .element_index = 0,
        },
    };

    const container = math.Rectangle{
        .position = math.Vec2.ZERO,
        .size = math.Vec2{ .x = 800, .y = 600 },
    };

    try debug_suite.validateLayout(&valid_elements, container);

    const stats = debug_suite.getDebugStats();
    try testing.expect(stats.validation_error_count == 0);
    try testing.expect(stats.layout_health);
}
