const std = @import("std");
const colors = @import("../lib/core/colors.zig");
const animated_borders = @import("../lib/ui/animated_borders.zig");
const time_utils = @import("../lib/core/time.zig");
const constants = @import("constants.zig");

const Color = colors.Color;

// Lifestone colors using animated_borders pattern
const LIFESTONE_COLORS = animated_borders.ColorPairs.BLUE;

// Create border stack with game-specific configuration
const BorderConfig = animated_borders.BorderConfig{
    .max_layers = constants.MAX_BORDER_LAYERS,
    .screen_width = constants.SCREEN_WIDTH,
    .screen_height = constants.SCREEN_HEIGHT,
    .visibility_threshold = constants.VISIBILITY_THRESHOLD,
};

const BorderStack = animated_borders.BorderStack(constants.MAX_BORDER_LAYERS);

// Border calculation function
pub fn calculateBorderRects(width: f32, offset: f32) [4]animated_borders.BorderRect {
    const border_config = BorderConfig;
    const dummy_stack = BorderStack.init(border_config);
    return dummy_stack.calculateBorderRects(width, offset);
}
