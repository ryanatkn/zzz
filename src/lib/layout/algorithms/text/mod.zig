/// Text Layout Algorithm Module
///
/// Provides text measurement, baseline alignment, and layout
/// capabilities for text elements within the layout system.
const std = @import("std");
const core = @import("../../core/types.zig");
const interface = @import("../../core/interface.zig");

pub const cpu = @import("cpu.zig");
pub const gpu = @import("gpu.zig");
pub const baseline = @import("baseline.zig");
pub const measurement = @import("measurement.zig");
pub const factory = @import("factory.zig");

// Re-export main types
pub const TextLayoutCPU = cpu.TextLayoutCPU;
pub const TextLayoutGPU = gpu.TextLayoutGPU;
pub const TextBaseline = baseline.TextBaseline;
pub const TextMeasurer = measurement.TextMeasurer;

// Re-export factory functionality
pub const Config = factory.Config;
pub const createAlgorithm = factory.createAlgorithm;

