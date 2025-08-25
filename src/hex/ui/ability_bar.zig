const math = @import("../../lib/math/mod.zig");
const core_colors = @import("../../lib/core/colors.zig");
const hex_colors = @import("../colors.zig");
const constants = @import("../constants.zig");
const abilities = @import("../ability_system.zig");

const Vec2 = math.Vec2;
const Color = core_colors.Color;
const AbilityType = abilities.AbilityType;

/// Visual configuration for the ability bar
pub const AbilityBarConfig = struct {
    slot_size: Vec2 = Vec2.size(50, 50),
    slot_spacing: f32 = 5.0,
    bottom_margin: f32 = 100.0,
    border_width: f32 = 2.0,
    cooldown_alpha: f32 = 0.6, // Semi-transparent cooldown overlay

    // Colors
    active_border_color: Color = core_colors.WHITE,
    hover_border_color: Color = hex_colors.BACKGROUND_LIGHT,
    cooldown_overlay_color: Color = core_colors.COOLDOWN_OVERLAY,
    empty_slot_color: Color = hex_colors.BACKGROUND_DARK,
};

/// Hotkey labels for each slot (0-7)
const HOTKEY_LABELS = [8][]const u8{ "1", "2", "3", "4", "Q", "E", "R", "F" };

/// Bright ability colors (always visible base colors)
pub fn getAbilityColor(ability_type: AbilityType) Color {
    return switch (ability_type) {
        .None => hex_colors.BACKGROUND_DARK,
        .Lull => hex_colors.GREEN_BRIGHT, // Calming effect
        .Blink => hex_colors.PURPLE_BRIGHT, // Teleportation magic
        .Phase => hex_colors.CYAN, // Ethereal state
        .Charm => hex_colors.YELLOW_BRIGHT, // Control magic
        .Lethargy => hex_colors.CYAN, // Movement slow - using CYAN as placeholder for INFO
        .Haste => hex_colors.ORANGE_BRIGHT, // Speed boost
        .Multishot => hex_colors.RED_BRIGHT, // Combat enhancement
        .Dazzle => hex_colors.BLUE_BRIGHT, // Area confusion - using BLUE_BRIGHT as placeholder for PRIMARY
    };
}

/// Darker ability colors (for cooldown overlays)
pub fn getDarkAbilityColor(ability_type: AbilityType) Color {
    const bright_color = getAbilityColor(ability_type);

    // Return darker version (60% darker) except for None which stays dark
    if (ability_type == .None) {
        return bright_color;
    }

    return math.ColorMath.darken(bright_color, 0.6);
}

/// AbilityBar UI component
pub const AbilityBar = struct {
    config: AbilityBarConfig,
    hovered_slot: ?usize = null,

    pub fn init() AbilityBar {
        return AbilityBar{
            .config = AbilityBarConfig{},
        };
    }

    /// Calculate ability bar position centered at bottom of screen
    pub fn getAbilityBarRect(self: *const AbilityBar) struct { x: f32, y: f32, width: f32, height: f32 } {
        const total_width = 8.0 * self.config.slot_size.x + 7.0 * self.config.slot_spacing;
        const x = (constants.SCREEN_WIDTH - total_width) / 2.0;
        const y = constants.SCREEN_HEIGHT - self.config.bottom_margin;

        return .{
            .x = x,
            .y = y,
            .width = total_width,
            .height = self.config.slot_size.y,
        };
    }

    /// Calculate position of a specific slot
    pub fn getSlotRect(self: *const AbilityBar, slot_index: usize) struct { x: f32, y: f32, width: f32, height: f32 } {
        const ability_bar_rect = self.getAbilityBarRect();
        const slot_x = ability_bar_rect.x + @as(f32, @floatFromInt(slot_index)) * (self.config.slot_size.x + self.config.slot_spacing);

        return .{
            .x = slot_x,
            .y = ability_bar_rect.y,
            .width = self.config.slot_size.x,
            .height = self.config.slot_size.y,
        };
    }

    /// Check if a screen position is over a specific slot
    pub fn isPointInSlot(self: *const AbilityBar, screen_pos: Vec2, slot_index: usize) bool {
        const slot_rect = self.getSlotRect(slot_index);
        return screen_pos.x >= slot_rect.x and
            screen_pos.x <= slot_rect.x + slot_rect.width and
            screen_pos.y >= slot_rect.y and
            screen_pos.y <= slot_rect.y + slot_rect.height;
    }

    /// Check if a screen position is over any slot, returns slot index if found
    pub fn getSlotAtPosition(self: *const AbilityBar, screen_pos: Vec2) ?usize {
        for (0..8) |slot_index| {
            if (self.isPointInSlot(screen_pos, slot_index)) {
                return slot_index;
            }
        }
        return null;
    }

    /// Check if a screen position is anywhere over the ability bar
    pub fn isPointInAbilityBar(self: *const AbilityBar, screen_pos: Vec2) bool {
        const rect = self.getAbilityBarRect();
        return screen_pos.x >= rect.x and
            screen_pos.x <= rect.x + rect.width and
            screen_pos.y >= rect.y and
            screen_pos.y <= rect.y + rect.height;
    }

    /// Update hover state based on mouse position
    pub fn updateHover(self: *AbilityBar, mouse_pos: Vec2) void {
        self.hovered_slot = self.getSlotAtPosition(mouse_pos);
    }

    /// Get the color for a spell slot (bright base color)
    pub fn getSlotColor(_: *const AbilityBar, ability_type: AbilityType, is_hovered: bool) Color {
        var color = getAbilityColor(ability_type);

        // Brighten slightly on hover
        if (is_hovered and ability_type != .None) {
            color = math.ColorMath.lighten(color, 0.2);
        }

        return color;
    }

    /// Get border color for a slot
    pub fn getBorderColor(self: *const AbilityBar, _: usize, is_active: bool, is_hovered: bool) Color {
        if (is_active) {
            return self.config.active_border_color;
        } else if (is_hovered) {
            return self.config.hover_border_color;
        }
        return core_colors.TRANSPARENT; // No border for inactive slots
    }

    /// Get the hotkey label for a slot
    pub fn getHotkeyLabel(slot_index: usize) []const u8 {
        if (slot_index < HOTKEY_LABELS.len) {
            return HOTKEY_LABELS[slot_index];
        }
        return "";
    }
};
