const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const math = @import("../../lib/math/mod.zig");
const core_colors = @import("../../lib/core/colors.zig");

// Reuse lib/rendering UI utilities for bordered rectangles
const ui_drawing = @import("../../lib/rendering/ui/drawing.zig");
// TODO: Text rendering disabled due to SDL/Vulkan texture lifecycle bug in ui_overlay.zig

// Hex game modules
const abilities = @import("../ability_system.zig");
const ui = @import("../ui/mod.zig");

const Vec2 = math.Vec2;
const Color = core_colors.Color;

/// AbilityBar rendering system extracted from game_renderer.zig
/// Uses lib/rendering/ui/drawing utilities for consistent bordered UI elements
pub const AbilityBarRenderer = struct {
    /// Draw the ability bar at the bottom center of the screen
    /// Extracted from game_renderer.zig lines 442-491
    /// Now uses lib/rendering/ui/drawing.drawBorderedRect for consistent UI styling
    pub fn drawAbilityBar(gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, ability_system: *const abilities.AbilitySystem, ability_bar_ui: *const ui.ability_bar.AbilityBar) void {
        for (0..8) |slot_index| {
            const slot_rect = ability_bar_ui.getSlotRect(slot_index);
            const slot = ability_system.slot_system.getSlot(slot_index);

            // Determine slot state
            const ability_type = if (slot) |s| s.ability_type else .None;
            const is_active = ability_system.slot_system.getActiveSlot().ability_type == ability_type and ability_type != .None;
            const is_hovered = ability_bar_ui.hovered_slot == slot_index;
            const cooldown_progress = if (slot) |s| s.cooldown_timer.getProgress() else 0.0;

            // Get slot color
            const slot_color = ability_bar_ui.getSlotColor(ability_type, is_hovered);
            const slot_pos = Vec2{ .x = slot_rect.x, .y = slot_rect.y };
            const slot_size = Vec2{ .x = slot_rect.width, .y = slot_rect.height };

            // Draw slot background
            gpu_renderer.drawRect(cmd_buffer, render_pass, slot_pos, slot_size, slot_color);

            // Draw cooldown overlay if ability is on cooldown
            if (slot != null and cooldown_progress < 1.0) {
                const overlay_height = slot_rect.height * (1.0 - cooldown_progress);
                // Use dark ability color for cooldown overlay
                const dark_color = ui.ability_bar.getDarkAbilityColor(ability_type);
                gpu_renderer.drawRect(cmd_buffer, render_pass, slot_pos, Vec2{ .x = slot_rect.width, .y = overlay_height }, dark_color);
            }

            // Draw border for active/hovered slots using lib/rendering/ui utilities
            const border_color = ability_bar_ui.getBorderColor(slot_index, is_active, is_hovered);
            if (border_color.a > 0) {
                const border_width = ability_bar_ui.config.border_width;

                // REUSE: lib/rendering/ui/drawing.drawBorderedRect for consistent UI styling
                ui_drawing.drawBorderedRect(gpu_renderer, cmd_buffer, render_pass, slot_pos, slot_size, core_colors.TRANSPARENT, // Transparent fill (slot already drawn)
                    border_color, border_width);
            }

            // Draw hotkey label using lib/rendering text utilities
            const label = ui.ability_bar.AbilityBar.getHotkeyLabel(slot_index);
            const label_x = slot_rect.x + slot_rect.width - 12.0; // Top right corner
            const label_y = slot_rect.y + 2.0;

            // TODO: Text rendering disabled due to SDL/Vulkan texture lifecycle bug (see ui_overlay.zig)
            _ = label;
            _ = label_x;
            _ = label_y;
        }
    }
};
