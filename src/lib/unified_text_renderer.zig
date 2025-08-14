const std = @import("std");
const types = @import("types.zig");
const text_renderer = @import("text_renderer.zig");
const persistent_text = @import("persistent_text.zig");
const menu_text = @import("ui/menu_text.zig");
const rendering_modes = @import("rendering_modes.zig");
const font_manager = @import("font_manager.zig");
const fonts = @import("fonts.zig");
const drawing = @import("drawing.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
const Rectangle = drawing.Rectangle;

/// Unified interface for all text rendering needs in the Dealt engine
/// 
/// This module provides a single, clean API that automatically chooses the best
/// rendering strategy based on the content and usage patterns.
/// 
/// Usage:
///   - For UI buttons/menus: use renderMenuText()
///   - For frequently changing text: use renderDynamicText()
///   - For static labels: use renderStaticText()
///   - For debug text: use renderDebugText()
pub const UnifiedTextRenderer = struct {
    // Core renderers (shared references)
    text_renderer: *text_renderer.TextRenderer,
    font_manager: *font_manager.FontManager,
    
    // High-level helpers
    menu_text_renderer: menu_text.MenuTextRenderer,
    
    const Self = @This();
    
    pub fn init(core_renderer: *text_renderer.TextRenderer, fm: *font_manager.FontManager) Self {
        return Self{
            .text_renderer = core_renderer,
            .font_manager = fm,
            .menu_text_renderer = menu_text.MenuTextRenderer.init(core_renderer, fm),
        };
    }
    
    /// Render menu/UI text (buttons, labels, navigation)
    /// Automatically uses persistent mode for good performance
    pub fn renderMenuText(self: *Self, text: []const u8, rect: Rectangle, style: MenuTextStyle, is_hovered: bool) void {
        switch (style) {
            .button => self.menu_text_renderer.queueButtonText(text, rect, is_hovered),
            .navigation => {
                const pos = drawing.getCenteredTextPos(rect, text, 
                    menu_text.MenuTextStyles.navigation.char_width, 
                    menu_text.MenuTextStyles.navigation.font_size);
                self.menu_text_renderer.queueNavigationText(text, pos);
            },
            .header => self.menu_text_renderer.queueHeaderText(text, rect),
        }
    }
    
    /// Render dynamic text that changes frequently (>5 times/sec)
    /// Uses immediate mode for optimal memory usage
    pub fn renderDynamicText(
        self: *Self, 
        text: []const u8, 
        position: Vec2, 
        font_size: f32, 
        color: Color
    ) !void {
        // Use immediate mode for frequently changing content
        try self.text_renderer.queueText(
            text, 
            position, 
            self.font_manager, 
            .sans, 
            font_size, 
            color
        );
    }
    
    /// Render static text that rarely changes
    /// Uses persistent mode for maximum efficiency
    pub fn renderStaticText(
        self: *Self, 
        text: []const u8, 
        position: Vec2, 
        font_size: f32, 
        color: Color
    ) !void {
        // Use persistent mode for static content
        try self.text_renderer.queuePersistentText(
            text, 
            position, 
            self.font_manager, 
            .sans, 
            font_size, 
            color
        );
    }
    
    /// Render debug text with automatic mode selection
    /// Analyzes change frequency and picks optimal mode
    pub fn renderDebugText(
        self: *Self, 
        text: []const u8, 
        position: Vec2, 
        font_size: f32, 
        color: Color,
        change_frequency: rendering_modes.ChangeFrequency
    ) !void {
        const mode = rendering_modes.recommendModeByFrequency(change_frequency);
        
        switch (mode) {
            .immediate => try self.renderDynamicText(text, position, font_size, color),
            .persistent => try self.renderStaticText(text, position, font_size, color),
        }
    }
    
    /// Auto-render text with smart mode selection
    /// Convenience function that picks the best strategy automatically
    pub fn renderAutoText(
        self: *Self, 
        text: []const u8, 
        position: Vec2, 
        font_size: f32, 
        color: Color
    ) !void {
        // For general text, use persistent mode as it's usually better
        // for UI and labels which are the most common use case
        try self.renderStaticText(text, position, font_size, color);
    }
    
    /// Get performance statistics for debugging
    pub fn getPerformanceStats(self: *Self) TextRenderingStats {
        return TextRenderingStats{
            .immediate_queue_size = self.text_renderer.text_draw_queue.items.len,
            .persistent_queue_size = self.text_renderer.persistent_text_queue.items.len,
            .total_textures_queued = self.text_renderer.text_draw_queue.items.len + 
                                   self.text_renderer.persistent_text_queue.items.len,
        };
    }
};

/// Predefined menu text styles
pub const MenuTextStyle = enum {
    button,
    navigation, 
    header,
};

/// Performance statistics for text rendering
pub const TextRenderingStats = struct {
    immediate_queue_size: usize,
    persistent_queue_size: usize,
    total_textures_queued: usize,
};

/// Convenience functions for common text rendering patterns

/// Render centered button text
pub fn renderButtonText(
    renderer: *UnifiedTextRenderer, 
    text: []const u8, 
    rect: Rectangle, 
    is_hovered: bool
) void {
    renderer.renderMenuText(text, rect, .button, is_hovered);
}

/// Render FPS counter (optimized for frequent updates)
pub fn renderFPSText(
    renderer: *UnifiedTextRenderer, 
    fps: f32, 
    position: Vec2
) !void {
    // FPS changes ~2-3 times per second, use persistent mode
    var fps_buffer: [32]u8 = undefined;
    const fps_text = try std.fmt.bufPrint(fps_buffer[0..], "FPS: {d:.1}", .{fps});
    
    try renderer.renderStaticText(
        fps_text, 
        position, 
        14.0, 
        Color{ .r = 255, .g = 255, .b = 255, .a = 255 }
    );
}

/// Render debug value (optimized for frequent updates)  
pub fn renderDebugValue(
    renderer: *UnifiedTextRenderer, 
    label: []const u8,
    value: f32, 
    position: Vec2
) !void {
    // Debug values change constantly, use immediate mode
    var debug_buffer: [64]u8 = undefined;
    const debug_text = try std.fmt.bufPrint(debug_buffer[0..], "{s}: {d:.2}", .{ label, value });
    
    try renderer.renderDynamicText(
        debug_text, 
        position, 
        12.0, 
        Color{ .r = 200, .g = 255, .b = 200, .a = 255 }
    );
}