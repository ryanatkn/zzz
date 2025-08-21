/// Debug presets for common scenarios
///
/// This module provides pre-configured debug setups for different use cases,
/// from development debugging to production monitoring.

const debug_suite = @import("debug_suite.zig");

/// Debug presets for common scenarios
pub const DebugPresets = struct {
    /// Development preset - all debugging features enabled
    pub const development = debug_suite.LayoutDebugSuite.DebugConfig{
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
    pub const production = debug_suite.LayoutDebugSuite.DebugConfig{
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
    pub const performance_testing = debug_suite.LayoutDebugSuite.DebugConfig{
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
    pub const debugging = debug_suite.LayoutDebugSuite.DebugConfig{
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