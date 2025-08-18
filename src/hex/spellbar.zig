const math = @import("../lib/math/mod.zig");
const colors = @import("../lib/core/colors.zig");
const constants = @import("constants.zig");
const spells = @import("spells.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const SpellType = spells.SpellType;

/// Visual configuration for the spellbar
pub const SpellbarConfig = struct {
    slot_size: Vec2 = Vec2{ .x = 50, .y = 50 },
    slot_spacing: f32 = 5.0,
    bottom_margin: f32 = 100.0,
    border_width: f32 = 2.0,
    cooldown_alpha: f32 = 0.6, // Semi-transparent cooldown overlay
    
    // Colors
    active_border_color: Color = colors.WHITE,
    hover_border_color: Color = colors.BACKGROUND_LIGHT,
    cooldown_overlay_color: Color = Color{ .r = 60, .g = 60, .b = 60, .a = 150 },
    empty_slot_color: Color = colors.BACKGROUND_DARK,
};

/// Hotkey labels for each slot (0-7)
const HOTKEY_LABELS = [8][]const u8{ "1", "2", "3", "4", "Q", "E", "R", "F" };

/// Bright spell colors (always visible base colors)
pub fn getSpellColor(spell_type: SpellType) Color {
    return switch (spell_type) {
        .None => colors.BACKGROUND_DARK,
        .Lull => colors.GREEN_BRIGHT,     // Calming effect
        .Blink => colors.PURPLE_BRIGHT,   // Teleportation magic
        .Phase => colors.CYAN,            // Ethereal state
        .Charm => colors.YELLOW_BRIGHT,   // Control magic
        .Lethargy => colors.INFO,         // Movement slow
        .Haste => colors.ORANGE_BRIGHT,   // Speed boost
        .Multishot => colors.RED_BRIGHT,  // Combat enhancement
        .Dazzle => colors.PRIMARY,        // Area confusion
    };
}

/// Darker spell colors (for cooldown overlays)
pub fn getDarkSpellColor(spell_type: SpellType) Color {
    const bright_color = getSpellColor(spell_type);
    
    // Return darker version (60% darker) except for None which stays dark
    if (spell_type == .None) {
        return bright_color;
    }
    
    return colors.darken(bright_color, 0.6);
}

/// Spellbar UI component
pub const Spellbar = struct {
    config: SpellbarConfig,
    hovered_slot: ?usize = null,
    
    pub fn init() Spellbar {
        return Spellbar{
            .config = SpellbarConfig{},
        };
    }
    
    /// Calculate spellbar position centered at bottom of screen
    pub fn getSpellbarRect(self: *const Spellbar) struct { x: f32, y: f32, width: f32, height: f32 } {
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
    pub fn getSlotRect(self: *const Spellbar, slot_index: usize) struct { x: f32, y: f32, width: f32, height: f32 } {
        const spellbar_rect = self.getSpellbarRect();
        const slot_x = spellbar_rect.x + @as(f32, @floatFromInt(slot_index)) * (self.config.slot_size.x + self.config.slot_spacing);
        
        return .{
            .x = slot_x,
            .y = spellbar_rect.y,
            .width = self.config.slot_size.x,
            .height = self.config.slot_size.y,
        };
    }
    
    /// Check if a screen position is over a specific slot
    pub fn isPointInSlot(self: *const Spellbar, screen_pos: Vec2, slot_index: usize) bool {
        const slot_rect = self.getSlotRect(slot_index);
        return screen_pos.x >= slot_rect.x and 
               screen_pos.x <= slot_rect.x + slot_rect.width and
               screen_pos.y >= slot_rect.y and 
               screen_pos.y <= slot_rect.y + slot_rect.height;
    }
    
    /// Check if a screen position is over any slot, returns slot index if found
    pub fn getSlotAtPosition(self: *const Spellbar, screen_pos: Vec2) ?usize {
        for (0..8) |slot_index| {
            if (self.isPointInSlot(screen_pos, slot_index)) {
                return slot_index;
            }
        }
        return null;
    }
    
    /// Check if a screen position is anywhere over the spellbar
    pub fn isPointInSpellbar(self: *const Spellbar, screen_pos: Vec2) bool {
        const rect = self.getSpellbarRect();
        return screen_pos.x >= rect.x and 
               screen_pos.x <= rect.x + rect.width and
               screen_pos.y >= rect.y and 
               screen_pos.y <= rect.y + rect.height;
    }
    
    /// Update hover state based on mouse position
    pub fn updateHover(self: *Spellbar, mouse_pos: Vec2) void {
        self.hovered_slot = self.getSlotAtPosition(mouse_pos);
    }
    
    /// Get the color for a spell slot (bright base color)
    pub fn getSlotColor(_: *const Spellbar, spell_type: SpellType, is_hovered: bool) Color {
        var color = getSpellColor(spell_type);
        
        // Brighten slightly on hover
        if (is_hovered and spell_type != .None) {
            color = colors.lighten(color, 0.2);
        }
        
        return color;
    }
    
    /// Get border color for a slot
    pub fn getBorderColor(self: *const Spellbar, _: usize, is_active: bool, is_hovered: bool) Color {
        if (is_active) {
            return self.config.active_border_color;
        } else if (is_hovered) {
            return self.config.hover_border_color;
        }
        return colors.TRANSPARENT; // No border for inactive slots
    }
    
    /// Get the hotkey label for a slot
    pub fn getHotkeyLabel(slot_index: usize) []const u8 {
        if (slot_index < HOTKEY_LABELS.len) {
            return HOTKEY_LABELS[slot_index];
        }
        return "";
    }
};