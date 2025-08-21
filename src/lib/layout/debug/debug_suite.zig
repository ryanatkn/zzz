/// Integrated debugging suite combining validation and profiling
///
/// This module provides a comprehensive debugging system that combines
/// layout validation, performance profiling, and diagnostic utilities
/// into a unified interface for layout system debugging.
const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../core/types.zig");
const validator = @import("validator.zig");
const profiler = @import("profiler.zig");

/// Integrated debugging suite combining validation and profiling
pub const LayoutDebugSuite = struct {
    allocator: std.mem.Allocator,
    validator: validator.LayoutValidator,
    profiler: profiler.LayoutProfiler,
    debugger: validator.LayoutDebugger,
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
            .validator = validator.LayoutValidator.init(allocator, config.validation_config),
            .profiler = profiler.LayoutProfiler.init(allocator, config.profiler_config),
            .debugger = validator.LayoutDebugger.init(allocator),
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

        // TODO: Fix profiling integration for validation - for now skip profiling
        try self.validator.validateLayout(elements, container_bounds);
    }

    /// Profile a layout operation
    pub fn profileLayoutOperation(
        self: *LayoutDebugSuite,
        operation: profiler.PerformanceMeasurement.Operation,
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
        operation: validator.LayoutDebugger.DebugEntry.Operation,
        before_state: ?validator.LayoutDebugger.DebugEntry.ElementState,
        after_state: ?validator.LayoutDebugger.DebugEntry.ElementState,
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
