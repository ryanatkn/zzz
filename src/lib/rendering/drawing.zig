const std = @import("std");
const c = @import("../platform/sdl.zig");
const types = @import("../core/types.zig");
const colors = @import("../core/colors.zig");
const simple_gpu_renderer = @import("gpu.zig");
const font_config = @import("../font/config.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
pub const Rectangle = types.Rectangle;
const SimpleGPURenderer = simple_gpu_renderer.SimpleGPURenderer;

// Higher-level drawing utilities that build on the basic GPU primitives

/// Draw a bordered rectangle with outline and fill
pub fn drawBorderedRect(gpu: *SimpleGPURenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, size: Vec2, fill_color: Color, border_color: Color, border_width: f32) void {
    // Draw fill
    gpu.drawRect(cmd_buffer, render_pass, pos, size, fill_color);

    // Draw borders
    const bw = border_width;
    // Top border
    gpu.drawRect(cmd_buffer, render_pass, pos, Vec2{ .x = size.x, .y = bw }, border_color);
    // Bottom border
    gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = pos.x, .y = pos.y + size.y - bw }, Vec2{ .x = size.x, .y = bw }, border_color);
    // Left border
    gpu.drawRect(cmd_buffer, render_pass, pos, Vec2{ .x = bw, .y = size.y }, border_color);
    // Right border
    gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = pos.x + size.x - bw, .y = pos.y }, Vec2{ .x = bw, .y = size.y }, border_color);
}

/// Draw a panel with background and border (common UI pattern)
pub fn drawPanel(gpu: *SimpleGPURenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, size: Vec2, style: PanelStyle) void {
    drawBorderedRect(gpu, cmd_buffer, render_pass, pos, size, style.background, style.border, style.border_width);
}

/// Predefined panel styles for consistent UI
pub const PanelStyle = struct {
    background: Color,
    border: Color,
    border_width: f32,

    pub const dark = PanelStyle{
        .background = colors.BACKGROUND_DARK,
        .border = colors.SECONDARY,
        .border_width = 1.0,
    };

    pub const light = PanelStyle{
        .background = colors.BACKGROUND_LIGHT,
        .border = colors.SECONDARY,
        .border_width = 1.0,
    };

    pub const navigation = PanelStyle{
        .background = Color{ .r = 20, .g = 25, .b = 35, .a = 255 },
        .border = Color{ .r = 40, .g = 45, .b = 55, .a = 255 },
        .border_width = 1.0,
    };

    pub const button = PanelStyle{
        .background = Color{ .r = 60, .g = 70, .b = 90, .a = 255 },
        .border = Color{ .r = 80, .g = 90, .b = 110, .a = 255 },
        .border_width = 1.0,
    };

    pub const button_disabled = PanelStyle{
        .background = Color{ .r = 30, .g = 35, .b = 45, .a = 128 },
        .border = Color{ .r = 50, .g = 55, .b = 65, .a = 128 },
        .border_width = 1.0,
    };
};

/// Draw a button with appropriate styling based on state
pub fn drawButton(gpu: *SimpleGPURenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, size: Vec2, state: ButtonState) void {
    const style = switch (state) {
        .normal => PanelStyle.button,
        .hovered => PanelStyle{
            .background = colors.lighten(PanelStyle.button.background, 0.1),
            .border = colors.lighten(PanelStyle.button.border, 0.1),
            .border_width = 1.0,
        },
        .pressed => PanelStyle{
            .background = colors.darken(PanelStyle.button.background, 0.1),
            .border = colors.darken(PanelStyle.button.border, 0.1),
            .border_width = 1.0,
        },
        .disabled => PanelStyle.button_disabled,
    };

    drawPanel(gpu, cmd_buffer, render_pass, pos, size, style);
}

pub const ButtonState = enum {
    normal,
    hovered,
    pressed,
    disabled,
};

/// Draw a navigation bar background (common pattern in HUD)
pub fn drawNavigationBar(gpu: *SimpleGPURenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, screen_width: f32, bar_width: f32, bar_height: f32, bar_y: f32) void {
    const bar_x = (screen_width - bar_width) / 2.0;
    drawPanel(gpu, cmd_buffer, render_pass, Vec2{ .x = bar_x, .y = bar_y }, Vec2{ .x = bar_width, .y = bar_height }, PanelStyle.navigation);
}

/// Draw an overlay background (semi-transparent screen overlay)
pub fn drawOverlay(gpu: *SimpleGPURenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, screen_width: f32, screen_height: f32, overlay_color: ?Color) void {
    const color = overlay_color orelse colors.OVERLAY;
    gpu.drawRect(cmd_buffer, render_pass, Vec2.ZERO, Vec2{ .x = screen_width, .y = screen_height }, color);
}

/// Draw a centered rectangle (useful for modal dialogs, popups)
pub fn drawCenteredRect(gpu: *SimpleGPURenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, screen_width: f32, screen_height: f32, rect_width: f32, rect_height: f32, color: Color) void {
    const x = (screen_width - rect_width) / 2.0;
    const y = (screen_height - rect_height) / 2.0;
    gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = x, .y = y }, Vec2{ .x = rect_width, .y = rect_height }, color);
}

/// Draw a progress bar
pub fn drawProgressBar(
    gpu: *SimpleGPURenderer,
    cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
    render_pass: *c.sdl.SDL_GPURenderPass,
    pos: Vec2,
    size: Vec2,
    progress: f32, // 0.0 to 1.0
    background_color: Color,
    fill_color: Color,
    border_color: Color,
) void {
    const clamped_progress = std.math.clamp(progress, 0.0, 1.0);

    // Draw background
    gpu.drawRect(cmd_buffer, render_pass, pos, size, background_color);

    // Draw progress fill
    if (clamped_progress > 0.0) {
        const fill_width = size.x * clamped_progress;
        gpu.drawRect(cmd_buffer, render_pass, pos, Vec2{ .x = fill_width, .y = size.y }, fill_color);
    }

    // Draw border
    drawBorderedRect(gpu, cmd_buffer, render_pass, pos, size, colors.TRANSPARENT, border_color, 1.0);
}

/// Common rectangle patterns for UI elements
pub const UIRects = struct {
    /// Create a button-sized rectangle with standard padding
    /// Now uses font configuration for proper scaling
    pub fn button(pos: Vec2, text_width: f32) Rectangle {
        const config = font_config.getGlobalConfig();
        const padding = config.buttonPadding();
        const height = config.buttonHeight();
        return Rectangle{
            .position = pos,
            .size = Vec2{ .x = text_width + padding * 2, .y = height },
        };
    }

    /// Create a navigation bar rectangle
    pub fn navigationBar(screen_width: f32, y: f32) Rectangle {
        const bar_width = 800.0;
        const bar_height = 50.0;
        return Rectangle{
            .position = Vec2{ .x = (screen_width - bar_width) / 2.0, .y = y },
            .size = Vec2{ .x = bar_width, .y = bar_height },
        };
    }

    /// Create a modal dialog rectangle
    pub fn modalDialog(screen_width: f32, screen_height: f32, dialog_width: f32, dialog_height: f32) Rectangle {
        return Rectangle{
            .position = Vec2{ .x = (screen_width - dialog_width) / 2.0, .y = (screen_height - dialog_height) / 2.0 },
            .size = Vec2{ .x = dialog_width, .y = dialog_height },
        };
    }
};

/// Calculate text bounds for centering and layout
pub fn getTextBounds(text: []const u8, char_width: f32, char_height: f32) Vec2 {
    return Vec2{
        .x = @as(f32, @floatFromInt(text.len)) * char_width,
        .y = char_height,
    };
}

/// Center text within a rectangle
pub fn getCenteredTextPos(rect: Rectangle, text: []const u8, char_width: f32, char_height: f32) Vec2 {
    const text_bounds = getTextBounds(text, char_width, char_height);
    return Vec2{
        .x = rect.position.x + (rect.size.x - text_bounds.x) / 2.0,
        .y = rect.position.y + (rect.size.y - text_bounds.y) / 2.0,
    };
}
