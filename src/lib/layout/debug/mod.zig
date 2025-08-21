/// Layout debugging and profiling utilities
///
/// This module provides comprehensive debugging and performance analysis tools
/// for layout systems, including validation, profiling, and diagnostic utilities.
pub const validator = @import("validator.zig");
pub const profiler = @import("profiler.zig");
pub const debug_suite = @import("debug_suite.zig");
pub const presets = @import("presets.zig");

// Re-export commonly used types
pub const ValidationError = validator.ValidationError;
pub const LayoutValidator = validator.LayoutValidator;
pub const LayoutDebugger = validator.LayoutDebugger;

pub const Timer = profiler.Timer;
pub const PerformanceMeasurement = profiler.PerformanceMeasurement;
pub const PerformanceStats = profiler.PerformanceStats;
pub const LayoutProfiler = profiler.LayoutProfiler;
pub const ProfilerHelper = profiler.ProfilerHelper;

// Re-export debug suite and presets
pub const LayoutDebugSuite = debug_suite.LayoutDebugSuite;
pub const DebugPresets = presets.DebugPresets;

// Re-export tests
pub usingnamespace @import("tests.zig");
