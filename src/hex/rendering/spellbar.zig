const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const math = @import("../../lib/math/mod.zig");
const core_colors = @import("../../lib/core/colors.zig");

// Reuse lib/rendering UI utilities for bordered rectangles
const ui_drawing = @import("../../lib/rendering/ui/drawing.zig");

// UI capabilities
const geometric_text = @import("../../lib/ui/geometric_text.zig");

// Hex game modules
const spells = @import("../spells.zig");
const ui = @import("../ui/mod.zig");

const Vec2 = math.Vec2;
const Color = core_colors.Color;

/// Spellbar rendering system extracted from game_renderer.zig
/// Uses lib/rendering/ui/drawing utilities for consistent bordered UI elements
pub const SpellbarRenderer = struct {
    /// Draw the spellbar at the bottom center of the screen
    /// Extracted from game_renderer.zig lines 442-491
    /// Now uses lib/rendering/ui/drawing.drawBorderedRect for consistent UI styling
    pub fn drawSpellbar(gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, spell_system: *const spells.SpellSystem, spellbar_ui: *const ui.spellbar.Spellbar) void {
        for (0..8) |slot_index| {
            const slot_rect = spellbar_ui.getSlotRect(slot_index);
            const slot = spell_system.getSlot(slot_index);

            // Determine slot state
            const spell_type = if (slot) |s| s.spell_type else .None;
            const is_active = spell_system.getActiveSlot().spell_type == spell_type and spell_type != .None;
            const is_hovered = spellbar_ui.hovered_slot == slot_index;
            const cooldown_progress = if (slot) |s| s.cooldown_timer.getProgress() else 0.0;

            // Get slot color
            const slot_color = spellbar_ui.getSlotColor(spell_type, is_hovered);
            const slot_pos = Vec2{ .x = slot_rect.x, .y = slot_rect.y };
            const slot_size = Vec2{ .x = slot_rect.width, .y = slot_rect.height };

            // Draw slot background
            gpu_renderer.drawRect(cmd_buffer, render_pass, slot_pos, slot_size, slot_color);

            // Draw cooldown overlay if spell is on cooldown
            if (slot != null and cooldown_progress < 1.0) {
                const overlay_height = slot_rect.height * (1.0 - cooldown_progress);
                // Use dark spell color for cooldown overlay
                const dark_color = ui.spellbar.getDarkSpellColor(spell_type);
                gpu_renderer.drawRect(cmd_buffer, render_pass, slot_pos, Vec2{ .x = slot_rect.width, .y = overlay_height }, dark_color);
            }

            // Draw border for active/hovered slots using lib/rendering/ui utilities
            const border_color = spellbar_ui.getBorderColor(slot_index, is_active, is_hovered);
            if (border_color.a > 0) {
                const border_width = spellbar_ui.config.border_width;

                // REUSE: lib/rendering/ui/drawing.drawBorderedRect for consistent UI styling
                ui_drawing.drawBorderedRect(gpu_renderer, cmd_buffer, render_pass, slot_pos, slot_size, Color{ .r = 0, .g = 0, .b = 0, .a = 0 }, // Transparent fill (slot already drawn)
                    border_color, border_width);
            }

            // Draw hotkey label
            const label = ui.spellbar.Spellbar.getHotkeyLabel(slot_index);
            const label_x = slot_rect.x + slot_rect.width - 12.0; // Top right corner
            const label_y = slot_rect.y + 2.0;

            // Draw label using geometric text
            drawHotkeyLabel(gpu_renderer, cmd_buffer, render_pass, label, label_x, label_y, core_colors.WHITE);
        }
    }

    /// Draw a single character hotkey label
    /// Extracted from game_renderer.zig lines 494-516
    fn drawHotkeyLabel(gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, text: []const u8, x: f32, y: f32, color: Color) void {
        if (text.len == 0) return;

        const config = geometric_text.TextConfig{
            .pixel_size = 1.5,
            .char_width = 3,
            .char_height = 5,
        };

        const char = text[0];
        const pattern = geometric_text.CharacterPatterns.getCharPattern(char);

        for (0..config.char_height) |row| {
            for (0..config.char_width) |col| {
                if (pattern[row * config.char_width + col]) {
                    const px = x + @as(f32, @floatFromInt(col)) * config.pixel_size;
                    const py = y + @as(f32, @floatFromInt(row)) * config.pixel_size;
                    const pixel_size = Vec2.size(config.pixel_size, config.pixel_size);
                    gpu_renderer.drawRect(cmd_buffer, render_pass, Vec2.position(px, py), pixel_size, color);
                }
            }
        }
    }
};
