/// Text Layout Algorithm Module
///
/// Provides text measurement, baseline alignment, and layout
/// capabilities for text elements within the layout system.
const std = @import("std");
const core = @import("../../core/types.zig");
const interface = @import("../../core/interface.zig");

pub const layout = @import("layout.zig");
pub const baseline = @import("baseline.zig");
pub const measurement = @import("measurement.zig");
pub const factory = @import("factory.zig");

// Re-export main types
pub const TextLayout = layout.TextLayout;
pub const TextBaseline = baseline.TextBaseline;
pub const TextMeasurer = measurement.TextMeasurer;

// Re-export factory functionality
pub const Config = factory.Config;
pub const createAlgorithm = factory.createAlgorithm;
