/// Text layout integration module
///
/// This module provides integration between the layout system and the existing
/// text rendering system, enabling proper text measurement and layout within
/// the broader layout framework.

const std = @import("std");
const math = @import("../math/mod.zig");
const types = @import("types.zig");
const text_layout = @import("../text/layout.zig");
const text_primitives = @import("../text/primitives.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;

/// Text measurement interface for layout integration
pub const TextMeasurer = struct {
    /// Measure text dimensions for layout purposes
    pub fn measureText(
        text: []const u8,
        font_size: f32,
        max_width: ?f32,
        options: TextMeasurementOptions,
    ) TextMeasurementResult {
        // TODO: Integrate with actual text system
        // For now, provide estimated measurements
        
        const estimated_char_width = font_size * 0.6;
        const line_height = font_size * options.line_height_multiplier;
        
        if (max_width) |max_w| {
            const chars_per_line = @max(1, @as(usize, @intFromFloat(max_w / estimated_char_width)));
            const lines_needed = @max(1, @divTrunc(text.len, chars_per_line));
            
            const actual_width = @min(max_w, @as(f32, @floatFromInt(text.len)) * estimated_char_width);
            const total_height = @as(f32, @floatFromInt(lines_needed)) * line_height;
            
            return TextMeasurementResult{
                .width = actual_width,
                .height = total_height,
                .line_count = lines_needed,
                .baseline_offset = line_height * 0.8, // Estimated baseline position
                .fits_in_bounds = true,
            };
        } else {
            const width = @as(f32, @floatFromInt(text.len)) * estimated_char_width;
            
            return TextMeasurementResult{
                .width = width,
                .height = line_height,
                .line_count = 1,
                .baseline_offset = line_height * 0.8,
                .fits_in_bounds = true,
            };
        }
    }

    /// Measure text to fit within specific constraints
    pub fn measureTextConstrained(
        text: []const u8,
        font_size: f32,
        constraints: types.Constraints,
        options: TextMeasurementOptions,
    ) TextMeasurementResult {
        const max_width = if (constraints.max_width < std.math.inf(f32)) constraints.max_width else null;
        var result = measureText(text, font_size, max_width, options);
        
        // Apply constraints
        result.width = std.math.clamp(result.width, constraints.min_width, constraints.max_width);
        result.height = std.math.clamp(result.height, constraints.min_height, constraints.max_height);
        
        // Check if text fits after constraint application
        const unconstrained_result = measureText(text, font_size, max_width, options);
        result.fits_in_bounds = unconstrained_result.width <= constraints.max_width and 
                               unconstrained_result.height <= constraints.max_height;
        
        return result;
    }

    /// Get intrinsic text size (minimum and preferred dimensions)
    pub fn getIntrinsicTextSize(
        text: []const u8,
        font_size: f32,
        options: TextMeasurementOptions,
    ) IntrinsicTextSize {
        // Minimum width is the width of the longest word (approximated)
        const min_width = font_size * 8.0; // Assume longest word is ~8 characters
        
        // Preferred width is single-line width
        const preferred_width = measureText(text, font_size, null, options).width;
        
        // Height is consistent for given font size
        const height = font_size * options.line_height_multiplier;
        
        return IntrinsicTextSize{
            .min_width = min_width,
            .preferred_width = preferred_width,
            .height = height,
            .baseline_offset = height * 0.8,
        };
    }
};

/// Text measurement options
pub const TextMeasurementOptions = struct {
    /// Line height multiplier (default 1.2)
    line_height_multiplier: f32 = 1.2,
    /// Text alignment
    alignment: text_layout.TextAlign = .left,
    /// Baseline alignment
    baseline: text_layout.TextBaseline = .alphabetic,
    /// Whether to enable text wrapping
    wrap_text: bool = true,
    /// Word break behavior
    word_break: WordBreak = .normal,
    /// Letter spacing
    letter_spacing: f32 = 0.0,
    /// Word spacing multiplier
    word_spacing: f32 = 1.0,

    pub const WordBreak = enum {
        normal,      // Break at word boundaries
        break_all,   // Break anywhere
        keep_all,    // Never break words
    };
};

/// Result of text measurement
pub const TextMeasurementResult = struct {
    /// Measured width
    width: f32,
    /// Measured height
    height: f32,
    /// Number of lines
    line_count: usize,
    /// Baseline offset from top
    baseline_offset: f32,
    /// Whether text fits within given bounds
    fits_in_bounds: bool,
};

/// Intrinsic text size information
pub const IntrinsicTextSize = struct {
    /// Minimum width (longest word)
    min_width: f32,
    /// Preferred width (single line)
    preferred_width: f32,
    /// Height for given font size
    height: f32,
    /// Baseline offset from top
    baseline_offset: f32,
};

/// Text element for layout system integration
pub const TextLayoutElement = struct {
    /// Text content
    content: []const u8,
    /// Font size
    font_size: f32,
    /// Text options
    options: TextMeasurementOptions,
    /// Current layout state
    layout_state: TextLayoutState,
    /// Cached measurement
    cached_measurement: ?TextMeasurementResult = null,
    /// Whether measurement cache is valid
    cache_valid: bool = false,

    pub const TextLayoutState = struct {
        /// Allocated bounds for the text
        bounds: Rectangle,
        /// Actual text dimensions within bounds
        text_bounds: Rectangle,
        /// Whether text was clipped
        is_clipped: bool,
        /// Current line break positions
        line_breaks: std.ArrayList(usize),

        pub fn init(allocator: std.mem.Allocator) TextLayoutState {
            return TextLayoutState{
                .bounds = Rectangle.ZERO,
                .text_bounds = Rectangle.ZERO,
                .is_clipped = false,
                .line_breaks = std.ArrayList(usize).init(allocator),
            };
        }

        pub fn deinit(self: *TextLayoutState) void {
            self.line_breaks.deinit();
        }
    };

    pub fn init(content: []const u8, font_size: f32, options: TextMeasurementOptions, allocator: std.mem.Allocator) TextLayoutElement {
        return TextLayoutElement{
            .content = content,
            .font_size = font_size,
            .options = options,
            .layout_state = TextLayoutState.init(allocator),
        };
    }

    pub fn deinit(self: *TextLayoutElement) void {
        self.layout_state.deinit();
    }

    /// Measure text and update cache
    pub fn measure(self: *TextLayoutElement, constraints: types.Constraints) TextMeasurementResult {
        if (self.cache_valid and self.cached_measurement != null) {
            return self.cached_measurement.?;
        }

        const result = TextMeasurer.measureTextConstrained(
            self.content,
            self.font_size,
            constraints,
            self.options,
        );

        self.cached_measurement = result;
        self.cache_valid = true;
        
        return result;
    }

    /// Invalidate measurement cache
    pub fn invalidateCache(self: *TextLayoutElement) void {
        self.cache_valid = false;
        self.cached_measurement = null;
    }

    /// Update layout state with new bounds
    pub fn updateLayout(self: *TextLayoutElement, bounds: Rectangle) void {
        self.layout_state.bounds = bounds;
        
        // Measure text within the new bounds
        const constraints = types.Constraints{
            .max_width = bounds.size.x,
            .max_height = bounds.size.y,
        };
        
        const measurement = self.measure(constraints);
        
        // Update text bounds within allocated bounds
        self.layout_state.text_bounds = Rectangle{
            .position = self.calculateTextPosition(bounds, measurement),
            .size = Vec2{ .x = measurement.width, .y = measurement.height },
        };
        
        self.layout_state.is_clipped = !measurement.fits_in_bounds;
    }

    /// Calculate text position within bounds based on alignment
    fn calculateTextPosition(self: *TextLayoutElement, bounds: Rectangle, measurement: TextMeasurementResult) Vec2 {
        var position = bounds.position;

        // Horizontal alignment
        switch (self.options.alignment) {
            .left => {}, // Already at left edge
            .center => position.x += (bounds.size.x - measurement.width) / 2.0,
            .right => position.x += bounds.size.x - measurement.width,
            .justify => {}, // TODO: Implement justify positioning
        }

        // Vertical alignment (based on baseline)
        switch (self.options.baseline) {
            .top => {}, // Already at top edge
            .middle => position.y += (bounds.size.y - measurement.height) / 2.0,
            .bottom => position.y += bounds.size.y - measurement.height,
            .alphabetic => position.y += measurement.baseline_offset,
        }

        return position;
    }

    /// Get intrinsic size for this text element
    pub fn getIntrinsicSize(self: *TextLayoutElement) IntrinsicTextSize {
        return TextMeasurer.getIntrinsicTextSize(self.content, self.font_size, self.options);
    }
};

/// Text layout utility functions
pub const TextLayoutUtils = struct {
    /// Convert text element to generic layout element
    pub fn textElementToLayoutElement(
        text_element: *TextLayoutElement,
        element_index: usize,
        parent_index: ?usize,
    ) types.LayoutResult {
        // Use intrinsic size as fallback if text_bounds is not set
        const intrinsic = text_element.getIntrinsicSize();
        const position = text_element.layout_state.text_bounds.position;
        var size = text_element.layout_state.text_bounds.size;
        
        // If size is zero, use intrinsic sizing
        if (size.x <= 0 or size.y <= 0) {
            size = Vec2{ .x = intrinsic.preferred_width, .y = intrinsic.height };
        }
        
        // TODO: Use parent_index for relative positioning when implemented
        _ = parent_index;
        
        return types.LayoutResult{
            .position = position,
            .size = size,
            .element_index = element_index,
        };
    }

    /// Create layout constraints from text requirements
    pub fn createConstraintsForText(
        text: []const u8,
        font_size: f32,
        options: TextMeasurementOptions,
    ) types.Constraints {
        const intrinsic = TextMeasurer.getIntrinsicTextSize(text, font_size, options);
        
        return types.Constraints{
            .min_width = intrinsic.min_width,
            .max_width = intrinsic.preferred_width,
            .min_height = intrinsic.height,
            .max_height = intrinsic.height,
        };
    }

    /// Calculate text layout within flexbox
    pub fn layoutTextInFlex(
        text_elements: []TextLayoutElement,
        container_bounds: Rectangle,
        direction: types.Direction,
        justify_content: types.JustifyContent,
        align_items: types.AlignItems,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        // Basic flex implementation for text elements
        // TODO: Full flexbox integration with the flex engine
        
        var results = try allocator.alloc(types.LayoutResult, text_elements.len);
        
        const is_horizontal = direction == .row or direction == .row_reverse;
        
        // Calculate total content size
        var total_content_size: f32 = 0;
        var max_cross_size: f32 = 0;
        
        for (text_elements) |*text_element| {
            const intrinsic = text_element.getIntrinsicSize();
            const main_size = if (is_horizontal) intrinsic.preferred_width else intrinsic.height;
            const cross_size = if (is_horizontal) intrinsic.height else intrinsic.preferred_width;
            
            total_content_size += main_size;
            max_cross_size = @max(max_cross_size, cross_size);
        }
        
        // Apply justify_content for main axis positioning
        const container_main_size = if (is_horizontal) container_bounds.size.x else container_bounds.size.y;
        const remaining_space = @max(0, container_main_size - total_content_size);
        
        var current_main_pos: f32 = switch (justify_content) {
            .flex_start => 0,
            .flex_end => remaining_space,
            .center => remaining_space / 2.0,
            .space_between => 0,
            .space_around => remaining_space / @as(f32, @floatFromInt(text_elements.len * 2)),
            .space_evenly => remaining_space / @as(f32, @floatFromInt(text_elements.len + 1)),
        };
        
        const space_between_items: f32 = if (text_elements.len > 1) switch (justify_content) {
            .space_between => remaining_space / @as(f32, @floatFromInt(text_elements.len - 1)),
            .space_around => remaining_space / @as(f32, @floatFromInt(text_elements.len)),
            .space_evenly => remaining_space / @as(f32, @floatFromInt(text_elements.len + 1)),
            else => 0,
        } else 0;
        
        // Layout each text element
        for (text_elements, 0..) |*text_element, i| {
            const intrinsic = text_element.getIntrinsicSize();
            const main_size = if (is_horizontal) intrinsic.preferred_width else intrinsic.height;
            const cross_size = if (is_horizontal) intrinsic.height else intrinsic.preferred_width;
            
            // Apply align_items for cross axis positioning
            const container_cross_size = if (is_horizontal) container_bounds.size.y else container_bounds.size.x;
            const cross_pos: f32 = switch (align_items) {
                .flex_start => 0,
                .flex_end => container_cross_size - cross_size,
                .center => (container_cross_size - cross_size) / 2.0,
                .stretch => 0, // Could expand cross_size here
                .baseline => 0, // TODO: Implement baseline alignment
            };
            
            const position = if (is_horizontal) Vec2{
                .x = container_bounds.position.x + current_main_pos,
                .y = container_bounds.position.y + cross_pos,
            } else Vec2{
                .x = container_bounds.position.x + cross_pos,
                .y = container_bounds.position.y + current_main_pos,
            };
            
            const size = if (is_horizontal) Vec2{
                .x = main_size,
                .y = if (align_items == .stretch) container_cross_size else cross_size,
            } else Vec2{
                .x = if (align_items == .stretch) container_cross_size else cross_size,
                .y = main_size,
            };
            
            text_element.updateLayout(Rectangle{
                .position = position,
                .size = size,
            });
            
            results[i] = TextLayoutUtils.textElementToLayoutElement(text_element, i, null);
            
            // Advance main position
            current_main_pos += main_size + space_between_items;
            if (justify_content == .space_around) {
                current_main_pos += space_between_items; // Double spacing for space-around
            }
        }
        
        return results;
    }
};

/// Text layout benchmark utilities
pub const TextLayoutBenchmark = struct {
    /// Benchmark text measurement performance
    pub fn benchmarkTextMeasurement(
        texts: []const []const u8,
        font_sizes: []const f32,
        iterations: usize,
        allocator: std.mem.Allocator,
    ) !BenchmarkResult {
        _ = allocator;
        
        const start_time = std.time.nanoTimestamp();
        
        var total_measurements: usize = 0;
        
        for (0..iterations) |_| {
            for (texts) |text| {
                for (font_sizes) |font_size| {
                    const constraints = types.Constraints{
                        .max_width = 800.0,
                        .max_height = 600.0,
                    };
                    
                    _ = TextMeasurer.measureTextConstrained(
                        text,
                        font_size,
                        constraints,
                        TextMeasurementOptions{},
                    );
                    
                    total_measurements += 1;
                }
            }
        }
        
        const end_time = std.time.nanoTimestamp();
        const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
        
        return BenchmarkResult{
            .total_measurements = total_measurements,
            .duration_ms = duration_ms,
            .measurements_per_second = @as(f64, @floatFromInt(total_measurements)) / (duration_ms / 1000.0),
            .average_time_per_measurement_us = (duration_ms * 1000.0) / @as(f64, @floatFromInt(total_measurements)),
        };
    }

    pub const BenchmarkResult = struct {
        total_measurements: usize,
        duration_ms: f64,
        measurements_per_second: f64,
        average_time_per_measurement_us: f64,
    };
};

// Tests
test "text measurement basic functionality" {
    const testing = std.testing;
    
    const result = TextMeasurer.measureText(
        "Hello World",
        16.0,
        200.0,
        TextMeasurementOptions{},
    );
    
    try testing.expect(result.width > 0);
    try testing.expect(result.height > 0);
    try testing.expect(result.line_count >= 1);
    try testing.expect(result.baseline_offset > 0);
}

test "text measurement with constraints" {
    const testing = std.testing;
    
    const constraints = types.Constraints{
        .min_width = 50.0,
        .max_width = 200.0,
        .min_height = 20.0,
        .max_height = 100.0,
    };
    
    const result = TextMeasurer.measureTextConstrained(
        "This is a longer text that might need wrapping",
        14.0,
        constraints,
        TextMeasurementOptions{},
    );
    
    try testing.expect(result.width >= constraints.min_width);
    try testing.expect(result.width <= constraints.max_width);
    try testing.expect(result.height >= constraints.min_height);
    try testing.expect(result.height <= constraints.max_height);
}

test "intrinsic text size calculation" {
    const testing = std.testing;
    
    const intrinsic = TextMeasurer.getIntrinsicTextSize(
        "Sample text",
        18.0,
        TextMeasurementOptions{},
    );
    
    try testing.expect(intrinsic.min_width > 0);
    try testing.expect(intrinsic.preferred_width >= intrinsic.min_width);
    try testing.expect(intrinsic.height > 0);
    try testing.expect(intrinsic.baseline_offset > 0);
    try testing.expect(intrinsic.baseline_offset <= intrinsic.height);
}

test "text layout element basic operations" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; 
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var text_element = TextLayoutElement.init(
        "Test text",
        16.0,
        TextMeasurementOptions{},
        allocator,
    );
    defer text_element.deinit();
    
    const constraints = types.Constraints{
        .max_width = 200.0,
        .max_height = 100.0,
    };
    
    const measurement = text_element.measure(constraints);
    try testing.expect(measurement.width > 0);
    try testing.expect(measurement.height > 0);
    
    // Update layout
    const bounds = Rectangle{
        .position = Vec2{ .x = 10.0, .y = 20.0 },
        .size = Vec2{ .x = 200.0, .y = 100.0 },
    };
    
    text_element.updateLayout(bounds);
    
    try testing.expect(text_element.layout_state.bounds.position.x == 10.0);
    try testing.expect(text_element.layout_state.bounds.position.y == 20.0);
    try testing.expect(text_element.layout_state.text_bounds.size.x > 0);
    try testing.expect(text_element.layout_state.text_bounds.size.y > 0);
}