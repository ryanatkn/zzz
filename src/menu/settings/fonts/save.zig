const std = @import("std");
const font_config = @import("../../../lib/font/config.zig");

pub fn saveSettings(allocator: std.mem.Allocator, settings: font_config.FontSettings) !void {
    const config_path = "font_settings.json";
    
    // Create JSON object
    var json_buf = std.ArrayList(u8).init(allocator);
    defer json_buf.deinit();
    
    try json_buf.appendSlice(
        \\{
        \\  "fonts": {
        \\    "mono": {
        \\
    );
    
    try std.fmt.format(json_buf.writer(), 
        \\      "family": "{s}",
        \\      "weight": {d},
        \\      "italic": {any}
        \\    }},
        \\    "sans": {{
        \\      "family": "{s}",
        \\      "weight": {d},
        \\      "italic": {any}
        \\    }},
        \\    "serif_display": {{
        \\      "family": "{s}",
        \\      "weight": {d},
        \\      "italic": {any}
        \\    }},
        \\    "serif_text": {{
        \\      "family": "{s}",
        \\      "weight": {d},
        \\      "italic": {any}
        \\    }},
        \\    "sizes": {{
        \\      "default": {d:.1},
        \\      "ui": {d:.1},
        \\      "code": {d:.1},
        \\      "heading": {d:.1},
        \\      "body": {d:.1}
        \\    }}
        \\  }}
        \\}}
    , .{
        settings.mono_family,
        settings.mono_weight,
        settings.mono_italic,
        settings.sans_family,
        settings.sans_weight,
        settings.sans_italic,
        settings.serif_display_family,
        settings.serif_display_weight,
        settings.serif_display_italic,
        settings.serif_text_family,
        settings.serif_text_weight,
        settings.serif_text_italic,
        settings.default_size,
        settings.ui_size,
        settings.code_size,
        settings.heading_size,
        settings.body_size,
    });
    
    // Write to file
    const file = try std.fs.cwd().createFile(config_path, .{});
    defer file.close();
    
    try file.writeAll(json_buf.items);
    
    const log = std.log.scoped(.font_settings);
    log.info("Font settings saved to {s}", .{config_path});
}

pub fn exportConfig(allocator: std.mem.Allocator, settings: font_config.FontSettings) ![]const u8 {
    // Generate a Zig configuration snippet
    var config_buf = std.ArrayList(u8).init(allocator);
    
    try std.fmt.format(config_buf.writer(),
        \\// Font Configuration for Dealt/Hex
        \\// Generated on {d}
        \\
        \\pub const font_settings = font_config.FontSettings{{
        \\    .mono_family = "{s}",
        \\    .mono_weight = {d},
        \\    .mono_italic = {any},
        \\    
        \\    .sans_family = "{s}",
        \\    .sans_weight = {d},
        \\    .sans_italic = {any},
        \\    
        \\    .serif_display_family = "{s}",
        \\    .serif_display_weight = {d},
        \\    .serif_display_italic = {any},
        \\    
        \\    .serif_text_family = "{s}",
        \\    .serif_text_weight = {d},
        \\    .serif_text_italic = {any},
        \\    
        \\    .default_size = {d:.1},
        \\    .ui_size = {d:.1},
        \\    .code_size = {d:.1},
        \\    .heading_size = {d:.1},
        \\    .body_size = {d:.1},
        \\}};
    , .{
        std.time.timestamp(),
        settings.mono_family,
        settings.mono_weight,
        settings.mono_italic,
        settings.sans_family,
        settings.sans_weight,
        settings.sans_italic,
        settings.serif_display_family,
        settings.serif_display_weight,
        settings.serif_display_italic,
        settings.serif_text_family,
        settings.serif_text_weight,
        settings.serif_text_italic,
        settings.default_size,
        settings.ui_size,
        settings.code_size,
        settings.heading_size,
        settings.body_size,
    });
    
    return config_buf.toOwnedSlice();
}