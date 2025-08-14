// Font configuration and metadata
// This module defines available fonts and font categories for the pure Zig font system

const std = @import("std");

// Font categories for semantic font selection
pub const FontCategory = enum {
    mono,          // Monospace fonts for code
    sans,          // Sans-serif for UI
    serif_display, // Serif for titles/headers
    serif_text,    // Serif for body text
};

pub const FontVariant = struct {
    path: []const u8,
    weight: i32,      // 100-900 (100=Thin, 400=Regular, 700=Bold, 900=Black)
    italic: bool,
    condensed: enum { normal, semi, condensed, extra } = .normal,
    optical_size: ?i32 = null,  // For fonts with optical size variants
};

pub const FontFamily = struct {
    name: []const u8,
    category: FontCategory,
    variants: []const FontVariant,
};

// Available font families with all their variants
pub const available_fonts = [_]FontFamily{
    .{
        .name = "DM Mono",
        .category = .mono,
        .variants = &[_]FontVariant{
            .{ .path = "static/fonts/DM_Mono/DMMono-Light.ttf", .weight = 300, .italic = false },
            .{ .path = "static/fonts/DM_Mono/DMMono-LightItalic.ttf", .weight = 300, .italic = true },
            .{ .path = "static/fonts/DM_Mono/DMMono-Regular.ttf", .weight = 400, .italic = false },
            .{ .path = "static/fonts/DM_Mono/DMMono-Italic.ttf", .weight = 400, .italic = true },
            .{ .path = "static/fonts/DM_Mono/DMMono-Medium.ttf", .weight = 500, .italic = false },
            .{ .path = "static/fonts/DM_Mono/DMMono-MediumItalic.ttf", .weight = 500, .italic = true },
        },
    },
    .{
        .name = "DM Sans",
        .category = .sans,
        .variants = &[_]FontVariant{
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Thin.ttf", .weight = 100, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ThinItalic.ttf", .weight = 100, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ExtraLight.ttf", .weight = 200, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ExtraLightItalic.ttf", .weight = 200, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Light.ttf", .weight = 300, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-LightItalic.ttf", .weight = 300, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf", .weight = 400, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Italic.ttf", .weight = 400, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Medium.ttf", .weight = 500, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-MediumItalic.ttf", .weight = 500, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-SemiBold.ttf", .weight = 600, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-SemiBoldItalic.ttf", .weight = 600, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Bold.ttf", .weight = 700, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-BoldItalic.ttf", .weight = 700, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ExtraBold.ttf", .weight = 800, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ExtraBoldItalic.ttf", .weight = 800, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Black.ttf", .weight = 900, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-BlackItalic.ttf", .weight = 900, .italic = true },
        },
    },
    .{
        .name = "DM Serif Display",
        .category = .serif_display,
        .variants = &[_]FontVariant{
            .{ .path = "static/fonts/DM_Serif_Display/DMSerifDisplay-Regular.ttf", .weight = 400, .italic = false },
            .{ .path = "static/fonts/DM_Serif_Display/DMSerifDisplay-Italic.ttf", .weight = 400, .italic = true },
        },
    },
    .{
        .name = "DM Serif Text",
        .category = .serif_text,
        .variants = &[_]FontVariant{
            .{ .path = "static/fonts/DM_Serif_Text/DMSerifText-Regular.ttf", .weight = 400, .italic = false },
            .{ .path = "static/fonts/DM_Serif_Text/DMSerifText-Italic.ttf", .weight = 400, .italic = true },
        },
    },
};

pub const FontSettings = struct {
    mono_family: []const u8 = "DM Mono",
    mono_weight: i32 = 400,
    mono_italic: bool = false,
    
    sans_family: []const u8 = "DM Sans",
    sans_weight: i32 = 400,
    sans_italic: bool = false,
    
    serif_display_family: []const u8 = "DM Serif Display",
    serif_display_weight: i32 = 400,
    serif_display_italic: bool = false,
    
    serif_text_family: []const u8 = "DM Serif Text",
    serif_text_weight: i32 = 400,
    serif_text_italic: bool = false,
    
    default_size: f32 = 16.0,
    ui_size: f32 = 14.0,
    code_size: f32 = 13.0,
    heading_size: f32 = 24.0,
    body_size: f32 = 16.0,
};