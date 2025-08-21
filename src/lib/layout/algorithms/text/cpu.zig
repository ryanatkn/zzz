/// Text layout algorithm - CPU implementation
///
/// Handles text measurement, baseline alignment, and layout
/// integration with the broader layout system.
const std = @import("std");
const core = @import("../../core/types.zig");
const interface = @import("../../core/interface.zig");
const baseline = @import("baseline.zig");
const measurement = @import("measurement.zig");

const LayoutElement = interface.LayoutElement;
const LayoutResult = core.LayoutResult;
const LayoutContext = core.LayoutContext;

/// Text-specific layout algorithm
pub const TextLayoutCPU = struct {
    allocator: std.mem.Allocator,
    measurer: measurement.TextMeasurer,

    pub fn init(allocator: std.mem.Allocator) TextLayoutCPU {
        return TextLayoutCPU{
            .allocator = allocator,
            .measurer = measurement.TextMeasurer{},
        };
    }

    pub fn deinit(self: *TextLayoutCPU) void {
        _ = self;
    }

    /// Calculate layout for text elements
    pub fn calculate(
        self: *TextLayoutCPU,
        elements: []LayoutElement,
        context: LayoutContext,
        allocator: std.mem.Allocator,
    ) ![]LayoutResult {
        _ = context;
        var results = try allocator.alloc(LayoutResult, elements.len);

        for (elements, 0..) |*element, i| {
            // TODO: Extract actual text content from element
            const text_content = "Sample Text"; // Placeholder
            const font_size = 16.0; // TODO: Extract from element styling

            // Measure text dimensions
            const measurement_result = self.measurer.measureText(
                text_content,
                font_size,
                if (element.constraints.max_width < std.math.inf(f32)) element.constraints.max_width else null,
                measurement.TextMeasurementOptions{},
            );

            // Calculate baseline-aligned position
            const baseline_offset = baseline.TextBaseline.calculateOffset(
                // TODO: Get actual font metrics
                @as(baseline.FontMetrics, undefined),
                .alphabetic,
                font_size,
            );

            // Create layout result
            results[i] = LayoutResult{
                .position = core.Vec2{
                    .x = element.position.x,
                    .y = element.position.y + baseline_offset,
                },
                .size = core.Vec2{
                    .x = measurement_result.width,
                    .y = measurement_result.height,
                },
                .content = core.Rectangle{
                    .position = core.Vec2{
                        .x = element.position.x,
                        .y = element.position.y + baseline_offset,
                    },
                    .size = core.Vec2{
                        .x = measurement_result.width,
                        .y = measurement_result.height,
                    },
                },
                .valid = true,
            };
        }

        return results;
    }

    /// Get algorithm capabilities
    pub fn getCapabilities(self: *TextLayoutCPU) interface.AlgorithmCapabilities {
        _ = self;
        return interface.AlgorithmCapabilities{
            .name = "Text Layout CPU",
            .max_elements = 1000,
            .supports_gpu = false,
            .supports_incremental = false,
            .complexity = .linear,
            .features = .{
                .nesting = false,
                .flexible_sizing = false,
                .content_sizing = true,
                .alignment = true,
                .wrapping = true,
                .spacing = false,
                .text_layout = true,
                .animations = false,
            },
        };
    }

    /// Check if algorithm can handle the given elements
    pub fn canHandle(self: *TextLayoutCPU, elements: []const LayoutElement, context: LayoutContext) bool {
        _ = self;
        _ = context;
        // Text layout can handle any reasonable number of text elements
        return elements.len <= 1000;
    }

    /// Get algorithm name
    pub fn getName(self: *TextLayoutCPU) []const u8 {
        _ = self;
        return "Text Layout CPU";
    }
};
