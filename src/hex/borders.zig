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

pub fn drawScreenBorder(game_state: anytype) void {
    var border_stack = BorderStack.init(BorderConfig);
    const current_time_ms = time_utils.Time.getTimeMs();

    // Iris wipe effect (highest priority - renders over everything)
    if (game_state.iris_wipe_active) {
        const elapsed_sec = game_state.iris_wipe_start_time.getElapsedSec();

        const wipe_colors = [_]Color{
            colors.BLUE_BRIGHT,   colors.GREEN_BRIGHT,  colors.YELLOW_BRIGHT,
            colors.ORANGE_BRIGHT, colors.PURPLE_BRIGHT, colors.CYAN,
        };

        const iris_wipe = animated_borders.IrisWipe{
            .colors = &wipe_colors,
            .band_width = constants.IRIS_WIPE_BAND_WIDTH,
            .duration = constants.IRIS_WIPE_DURATION,
            .easing_fn = animated_borders.Easing.quarticEaseOut,
        };

        iris_wipe.getBorders(elapsed_sec, &border_stack);

        if (elapsed_sec >= constants.IRIS_WIPE_DURATION) {
            @constCast(game_state).iris_wipe_active = false;
        }
    }

    // Game state borders (lower priority)
    if (game_state.isPaused()) {
        border_stack.pushAnimated(constants.PAUSED_BORDER_BASE_WIDTH, animated_borders.ColorPairs.GOLD_YELLOW, constants.BORDER_PULSE_PAUSED, constants.PAUSED_BORDER_PULSE_AMPLITUDE);
    }

    if (!game_state.world.getPlayerAlive()) {
        border_stack.pushAnimated(constants.DEAD_BORDER_BASE_WIDTH, animated_borders.ColorPairs.RED, constants.BORDER_PULSE_DEAD, constants.DEAD_BORDER_PULSE_AMPLITUDE);
    }

    // Lifestone completion border
    if (game_state.hasAttunedAllLifestones()) {
        border_stack.pushAnimated(5.0, LIFESTONE_COLORS, 3.0, 2.0);
    }

    // Render all borders manually (simpler than callback for this use case)
    var current_offset: f32 = 0;
    for (0..border_stack.count) |i| {
        const spec = &border_stack.specs[i];
        const current_width = spec.getCurrentWidth(current_time_ms);
        const current_color = spec.getCurrentColor(current_time_ms);

        if (current_width > BorderConfig.visibility_threshold) {
            game_state.drawBorderWithOffset(current_color, current_width, current_offset);
            current_offset += current_width;
        }
    }
}
