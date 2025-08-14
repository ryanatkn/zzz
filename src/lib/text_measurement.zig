const std = @import("std");
const types = @import("types.zig");
const font_manager = @import("font_manager.zig");
const fonts = @import("fonts.zig");
const text_layout = @import("text_layout.zig");

const Vec2 = types.Vec2;

/// Text measurement result containing dimensions and metrics
pub const TextMetrics = struct {
    width: f32,
    height: f32,
    baseline: f32,
    line_height: f32,
    num_lines: u32,
};

/// Measure text dimensions without rendering
pub fn measureText(
    manager: *font_manager.FontManager,
    text: []const u8,
    font_category: fonts.FontCategory,
    font_size: f32,
    max_width: ?f32,
) !TextMetrics {
    // Get or create layout engine
    if (manager.layout_engine == null) {
        manager.layout_engine = try text_layout.TextLayoutEngine.init(manager.allocator);
    }
    
    const layout_engine = &manager.layout_engine.?;
    
    // Layout the text
    const layout_result = try layout_engine.layoutText(
        manager,
        text,
        font_category,
        font_size,
        max_width,
    );
    defer layout_result.deinit();
    
    // Calculate metrics from layout
    var metrics = TextMetrics{
        .width = 0,
        .height = 0,
        .baseline = 0,
        .line_height = layout_result.line_height,
        .num_lines = @intCast(layout_result.lines.items.len),
    };
    
    // Find max width and total height
    for (layout_result.lines.items) |line| {
        metrics.width = @max(metrics.width, line.width);
        metrics.height += line.height;
        if (metrics.baseline == 0) {
            metrics.baseline = line.baseline;
        }
    }
    
    return metrics;
}

/// Measure single character dimensions
pub fn measureChar(
    manager: *font_manager.FontManager,
    codepoint: u32,
    font_category: fonts.FontCategory,
    font_size: f32,
) !Vec2 {
    // Load font if needed
    const font_id = try manager.loadFont(font_category, font_size);
    const font = blk: {
        for (manager.loaded_fonts.items) |*f| {
            if (f.id == font_id) break :blk f;
        }
        return error.FontNotFound;
    };
    
    // Get or create rasterizer for this size
    const size_key = @as(u32, @intFromFloat(font_size * 64));
    const rasterizer = if (font.rasterizers.get(size_key)) |r| 
        r
    else blk: {
        const new_rasterizer = try manager.allocator.create(font_rasterizer.FontRasterizer);
        new_rasterizer.* = try font_rasterizer.FontRasterizer.init(
            manager.allocator,
            font.parser,
            font_size
        );
        try font.rasterizers.put(size_key, new_rasterizer);
        break :blk new_rasterizer;
    };
    
    // Get glyph metrics
    const glyph_info = try manager.atlas.getOrRasterizeGlyph(
        rasterizer,
        codepoint,
        font_id,
        size_key
    );
    
    return Vec2{
        .x = @floatFromInt(glyph_info.width),
        .y = @floatFromInt(glyph_info.height),
    };
}

/// Calculate optimal font size to fit text in given bounds
pub fn calculateFitSize(
    manager: *font_manager.FontManager,
    text: []const u8,
    font_category: fonts.FontCategory,
    max_width: f32,
    max_height: f32,
    min_size: f32,
    max_size: f32,
) !f32 {
    var low = min_size;
    var high = max_size;
    var best_size = min_size;
    
    // Binary search for optimal size
    while (high - low > 0.5) {
        const mid = (low + high) / 2.0;
        const metrics = try measureText(manager, text, font_category, mid, max_width);
        
        if (metrics.width <= max_width and metrics.height <= max_height) {
            best_size = mid;
            low = mid;
        } else {
            high = mid;
        }
    }
    
    return best_size;
}

/// Check if text will fit in given bounds
pub fn willFit(
    manager: *font_manager.FontManager,
    text: []const u8,
    font_category: fonts.FontCategory,
    font_size: f32,
    max_width: f32,
    max_height: f32,
) !bool {
    const metrics = try measureText(manager, text, font_category, font_size, max_width);
    return metrics.width <= max_width and metrics.height <= max_height;
}

/// Split text to fit within width constraints
pub fn splitTextToFit(
    allocator: std.mem.Allocator,
    manager: *font_manager.FontManager,
    text: []const u8,
    font_category: fonts.FontCategory,
    font_size: f32,
    max_width: f32,
) !std.ArrayList([]const u8) {
    var lines = std.ArrayList([]const u8).init(allocator);
    errdefer lines.deinit();
    
    var current_line_start: usize = 0;
    var last_space: ?usize = null;
    var i: usize = 0;
    
    while (i < text.len) {
        // Track last space for word wrapping
        if (text[i] == ' ') {
            last_space = i;
        }
        
        // Check if current substring fits
        const test_text = text[current_line_start..i + 1];
        const metrics = try measureText(manager, test_text, font_category, font_size, null);
        
        if (metrics.width > max_width) {
            // Need to break line
            const break_point = if (last_space) |space|
                if (space > current_line_start) space else i
            else
                i;
            
            try lines.append(text[current_line_start..break_point]);
            
            // Skip space at start of new line
            current_line_start = if (text[break_point] == ' ') break_point + 1 else break_point;
            last_space = null;
            i = current_line_start;
        } else {
            i += 1;
        }
    }
    
    // Add remaining text
    if (current_line_start < text.len) {
        try lines.append(text[current_line_start..]);
    }
    
    return lines;
}

/// Get the index of character at given position in text
pub fn getCharAtPosition(
    manager: *font_manager.FontManager,
    text: []const u8,
    font_category: fonts.FontCategory,
    font_size: f32,
    x_position: f32,
) !usize {
    var current_x: f32 = 0;
    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    
    const font_id = try manager.loadFont(font_category, font_size);
    const font = blk: {
        for (manager.loaded_fonts.items) |*f| {
            if (f.id == font_id) break :blk f;
        }
        return error.FontNotFound;
    };
    
    const size_key = @as(u32, @intFromFloat(font_size * 64));
    const rasterizer = if (font.rasterizers.get(size_key)) |r| 
        r
    else blk: {
        const new_rasterizer = try manager.allocator.create(font_rasterizer.FontRasterizer);
        new_rasterizer.* = try font_rasterizer.FontRasterizer.init(
            manager.allocator,
            font.parser,
            font_size
        );
        try font.rasterizers.put(size_key, new_rasterizer);
        break :blk new_rasterizer;
    };
    
    var char_index: usize = 0;
    while (iter.nextCodepoint()) |codepoint| {
        const glyph_info = try manager.atlas.getOrRasterizeGlyph(
            rasterizer,
            codepoint,
            font_id,
            size_key
        );
        
        const char_center = current_x + glyph_info.advance / 2.0;
        if (x_position < char_center) {
            return char_index;
        }
        
        current_x += glyph_info.advance;
        char_index += 1;
    }
    
    return text.len;
}

const font_rasterizer = @import("font_rasterizer.zig");