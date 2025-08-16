const std = @import("std");
const Vec2 = @import("../math/mod.zig").Vec2;
const Color = @import("../core/colors.zig").Color;

/// Geometric text rendering using pixel patterns
/// Provides simple bitmap-style character rendering without external fonts

/// Configuration for geometric text rendering
pub const TextConfig = struct {
    pixel_size: f32 = 2.0,
    char_width: u32 = 3,
    char_height: u32 = 5,
    char_spacing: f32 = 4.0,
    line_spacing: f32 = 8.0,
    
    pub fn getCharPixelWidth(self: TextConfig) f32 {
        return @as(f32, @floatFromInt(self.char_width)) * self.pixel_size;
    }
    
    pub fn getCharPixelHeight(self: TextConfig) f32 {
        return @as(f32, @floatFromInt(self.char_height)) * self.pixel_size;
    }
};

/// Standard 3x5 character patterns for digits and letters
pub const CharacterPatterns = struct {
    // 3x5 digit patterns (15 bits each)
    const DIGIT_PATTERNS = [_][15]bool{
        .{ true, true, true, true, false, true, true, false, true, true, false, true, true, true, true }, // 0
        .{ false, true, false, false, true, false, false, true, false, false, true, false, false, true, false }, // 1
        .{ true, true, true, false, false, true, true, true, true, true, false, false, true, true, true }, // 2
        .{ true, true, true, false, false, true, true, true, true, false, false, true, true, true, true }, // 3
        .{ true, false, true, true, false, true, true, true, true, false, false, true, false, false, true }, // 4
        .{ true, true, true, true, false, false, true, true, true, false, false, true, true, true, true }, // 5
        .{ true, true, true, true, false, false, true, true, true, true, false, true, true, true, true }, // 6
        .{ true, true, true, false, false, true, false, false, true, false, false, true, false, false, true }, // 7
        .{ true, true, true, true, false, true, true, true, true, true, false, true, true, true, true }, // 8
        .{ true, true, true, true, false, true, true, true, true, false, false, true, true, true, true }, // 9
    };
    
    // 3x5 uppercase letter patterns
    const LETTER_PATTERNS = [_][15]bool{
        .{ true, true, true, true, false, true, true, true, true, true, false, true, true, false, true }, // A
        .{ true, true, false, true, false, true, true, true, false, true, false, true, true, true, false }, // B
        .{ true, true, true, true, false, false, true, false, false, true, false, false, true, true, true }, // C
        .{ true, true, false, true, false, true, true, false, true, true, false, true, true, true, false }, // D
        .{ true, true, true, true, false, false, true, true, false, true, false, false, true, true, true }, // E
        .{ true, true, true, true, false, false, true, true, false, true, false, false, true, false, false }, // F
        .{ true, true, true, true, false, false, true, false, true, true, false, true, true, true, true }, // G
        .{ true, false, true, true, false, true, true, true, true, true, false, true, true, false, true }, // H
        .{ true, true, true, false, true, false, false, true, false, false, true, false, true, true, true }, // I
        .{ false, false, true, false, false, true, false, false, true, true, false, true, true, true, true }, // J
        .{ true, false, true, true, true, false, true, true, false, true, false, true, true, false, true }, // K
        .{ true, false, false, true, false, false, true, false, false, true, false, false, true, true, true }, // L
        .{ true, false, true, true, true, true, true, false, true, true, false, true, true, false, true }, // M
        .{ true, false, true, true, true, true, true, false, true, true, false, true, true, false, true }, // N
        .{ true, true, true, true, false, true, true, false, true, true, false, true, true, true, true }, // O
        .{ true, true, true, true, false, true, true, true, true, true, false, false, true, false, false }, // P
        .{ true, true, true, true, false, true, true, false, true, true, true, true, true, true, true }, // Q
        .{ true, true, true, true, false, true, true, true, false, true, false, true, true, false, true }, // R
        .{ true, true, true, true, false, false, true, true, true, false, false, true, true, true, true }, // S
        .{ true, true, true, false, true, false, false, true, false, false, true, false, false, true, false }, // T
        .{ true, false, true, true, false, true, true, false, true, true, false, true, true, true, true }, // U
        .{ true, false, true, true, false, true, true, false, true, false, true, false, false, true, false }, // V
        .{ true, false, true, true, false, true, true, false, true, true, true, true, true, false, true }, // W
        .{ true, false, true, false, true, false, false, true, false, false, true, false, true, false, true }, // X
        .{ true, false, true, true, false, true, false, true, false, false, true, false, false, true, false }, // Y
        .{ true, true, true, false, false, true, false, true, false, true, false, false, true, true, true }, // Z
    };
    
    // Special characters
    const SPACE_PATTERN = [_]bool{false} ** 15;
    const PERIOD_PATTERN = [_]bool{ false, false, false, false, false, false, false, false, false, false, false, false, false, true, false };
    const COLON_PATTERN = [_]bool{ false, false, false, false, true, false, false, false, false, false, true, false, false, false, false };
    const EXCLAMATION_PATTERN = [_]bool{ false, true, false, false, true, false, false, true, false, false, false, false, false, true, false };
    
    pub fn getDigitPattern(digit: u8) ?[15]bool {
        if (digit > 9) return null;
        return DIGIT_PATTERNS[digit];
    }
    
    pub fn getLetterPattern(letter: u8) ?[15]bool {
        if (letter >= 'A' and letter <= 'Z') {
            return LETTER_PATTERNS[letter - 'A'];
        } else if (letter >= 'a' and letter <= 'z') {
            return LETTER_PATTERNS[letter - 'a'];
        }
        return null;
    }
    
    pub fn getCharPattern(char: u8) [15]bool {
        return switch (char) {
            '0'...'9' => DIGIT_PATTERNS[char - '0'],
            'A'...'Z' => LETTER_PATTERNS[char - 'A'],
            'a'...'z' => LETTER_PATTERNS[char - 'a'],
            ' ' => SPACE_PATTERN,
            '.' => PERIOD_PATTERN,
            ':' => COLON_PATTERN,
            '!' => EXCLAMATION_PATTERN,
            else => SPACE_PATTERN, // Default to space for unknown characters
        };
    }
};

/// Text measurement utilities
pub const TextMeasure = struct {
    pub fn measureText(text: []const u8, config: TextConfig) Vec2 {
        if (text.len == 0) return Vec2{ .x = 0, .y = 0 };
        
        var lines: u32 = 1;
        var max_width: u32 = 0;
        var current_width: u32 = 0;
        
        for (text) |char| {
            if (char == '\n') {
                lines += 1;
                max_width = @max(max_width, current_width);
                current_width = 0;
            } else {
                current_width += 1;
            }
        }
        max_width = @max(max_width, current_width);
        
        const width = @as(f32, @floatFromInt(max_width)) * (config.getCharPixelWidth() + config.char_spacing) - config.char_spacing;
        const height = @as(f32, @floatFromInt(lines)) * (config.getCharPixelHeight() + config.line_spacing) - config.line_spacing;
        
        return Vec2{ .x = width, .y = height };
    }
    
    pub fn measureLine(text: []const u8, config: TextConfig) Vec2 {
        if (text.len == 0) return Vec2{ .x = 0, .y = 0 };
        
        const width = @as(f32, @floatFromInt(text.len)) * (config.getCharPixelWidth() + config.char_spacing) - config.char_spacing;
        const height = config.getCharPixelHeight();
        
        return Vec2{ .x = width, .y = height };
    }
};

/// Text alignment options
pub const Alignment = enum {
    left,
    center,
    right,
};

/// Geometric text renderer interface
/// Expects a drawing function that can render rectangles
pub fn GeometricTextRenderer(comptime DrawRectFn: type) type {
    return struct {
        const Self = @This();
        
        draw_rect_fn: DrawRectFn,
        config: TextConfig,
        
        pub fn init(draw_rect_fn: DrawRectFn, config: TextConfig) Self {
            return .{
                .draw_rect_fn = draw_rect_fn,
                .config = config,
            };
        }
        
        /// Draw a single character at the specified position
        pub fn drawChar(self: *const Self, char: u8, position: Vec2, color: Color) void {
            const pattern = CharacterPatterns.getCharPattern(char);
            
            for (0..self.config.char_height) |row| {
                for (0..self.config.char_width) |col| {
                    if (pattern[row * self.config.char_width + col]) {
                        const px = position.x + @as(f32, @floatFromInt(col)) * self.config.pixel_size;
                        const py = position.y + @as(f32, @floatFromInt(row)) * self.config.pixel_size;
                        const pixel_pos = Vec2{ .x = px, .y = py };
                        const pixel_size = Vec2{ .x = self.config.pixel_size, .y = self.config.pixel_size };
                        self.draw_rect_fn(pixel_pos, pixel_size, color);
                    }
                }
            }
        }
        
        /// Draw a string of text (single line)
        pub fn drawText(self: *const Self, text: []const u8, position: Vec2, color: Color, alignment: Alignment) void {
            if (text.len == 0) return;
            
            const text_size = TextMeasure.measureLine(text, self.config);
            var start_x = position.x;
            
            switch (alignment) {
                .center => start_x -= text_size.x / 2.0,
                .right => start_x -= text_size.x,
                .left => {},
            }
            
            var current_pos = Vec2{ .x = start_x, .y = position.y };
            
            for (text) |char| {
                self.drawChar(char, current_pos, color);
                current_pos.x += self.config.getCharPixelWidth() + self.config.char_spacing;
            }
        }
        
        /// Draw multi-line text with line breaks
        pub fn drawMultilineText(self: *const Self, text: []const u8, position: Vec2, color: Color, alignment: Alignment) void {
            var lines = std.mem.split(u8, text, "\n");
            var current_y = position.y;
            
            while (lines.next()) |line| {
                self.drawText(line, Vec2{ .x = position.x, .y = current_y }, color, alignment);
                current_y += self.config.getCharPixelHeight() + self.config.line_spacing;
            }
        }
        
        /// Draw a number with right alignment (useful for scores, FPS, etc.)
        pub fn drawNumber(self: *const Self, number: u32, position: Vec2, color: Color) void {
            var buffer: [32]u8 = undefined;
            const text = std.fmt.bufPrint(&buffer, "{}", .{number}) catch return;
            self.drawText(text, position, color, .right);
        }
        
        /// Draw a number with leading zeros (useful for time display)
        pub fn drawNumberPadded(self: *const Self, number: u32, digits: u32, position: Vec2, color: Color) void {
            var buffer: [32]u8 = undefined;
            const format_str = switch (digits) {
                1 => "{}",
                2 => "{:0>2}",
                3 => "{:0>3}",
                4 => "{:0>4}",
                else => "{}",
            };
            const text = std.fmt.bufPrint(&buffer, format_str, .{number}) catch return;
            self.drawText(text, position, color, .right);
        }
    };
}

/// Simple standalone functions for basic character rendering
pub const SimpleRenderer = struct {
    /// Draw a digit using a simple callback function
    pub fn drawDigit(digit: u8, position: Vec2, config: TextConfig, color: Color, drawPixel: fn(Vec2, Vec2, Color) void) void {
        if (digit > 9) return;
        
        const pattern = CharacterPatterns.getDigitPattern(digit) orelse return;
        
        for (0..config.char_height) |row| {
            for (0..config.char_width) |col| {
                if (pattern[row * config.char_width + col]) {
                    const px = position.x + @as(f32, @floatFromInt(col)) * config.pixel_size;
                    const py = position.y + @as(f32, @floatFromInt(row)) * config.pixel_size;
                    const pixel_pos = Vec2{ .x = px, .y = py };
                    const pixel_size = Vec2{ .x = config.pixel_size, .y = config.pixel_size };
                    drawPixel(pixel_pos, pixel_size, color);
                }
            }
        }
    }
    
    /// Draw a character using a simple callback function
    pub fn drawChar(char: u8, position: Vec2, config: TextConfig, color: Color, drawPixel: fn(Vec2, Vec2, Color) void) void {
        const pattern = CharacterPatterns.getCharPattern(char);
        
        for (0..config.char_height) |row| {
            for (0..config.char_width) |col| {
                if (pattern[row * config.char_width + col]) {
                    const px = position.x + @as(f32, @floatFromInt(col)) * config.pixel_size;
                    const py = position.y + @as(f32, @floatFromInt(row)) * config.pixel_size;
                    const pixel_pos = Vec2{ .x = px, .y = py };
                    const pixel_size = Vec2{ .x = config.pixel_size, .y = config.pixel_size };
                    drawPixel(pixel_pos, pixel_size, color);
                }
            }
        }
    }
};

test "character patterns" {
    // Test digit patterns
    for (0..10) |i| {
        const pattern = CharacterPatterns.getDigitPattern(@intCast(i));
        try std.testing.expect(pattern != null);
        try std.testing.expect(pattern.?.len == 15);
    }
    
    // Test letter patterns
    const pattern_a = CharacterPatterns.getLetterPattern('A');
    try std.testing.expect(pattern_a != null);
    
    const pattern_z = CharacterPatterns.getLetterPattern('Z');
    try std.testing.expect(pattern_z != null);
    
    // Test unknown character
    const pattern = CharacterPatterns.getCharPattern('@');
    try std.testing.expect(std.mem.eql(bool, &pattern, &CharacterPatterns.SPACE_PATTERN));
}

test "text measurement" {
    const config = TextConfig{};
    
    // Test single character
    const single_size = TextMeasure.measureLine("A", config);
    try std.testing.expect(single_size.x == config.getCharPixelWidth());
    try std.testing.expect(single_size.y == config.getCharPixelHeight());
    
    // Test multiple characters
    const multi_size = TextMeasure.measureLine("ABC", config);
    const expected_width = 3.0 * config.getCharPixelWidth() + 2.0 * config.char_spacing;
    try std.testing.expectApproxEqAbs(expected_width, multi_size.x, 0.01);
    
    // Test empty string
    const empty_size = TextMeasure.measureLine("", config);
    try std.testing.expect(empty_size.x == 0.0 and empty_size.y == 0.0);
}