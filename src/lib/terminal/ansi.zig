const std = @import("std");
const colors = @import("../core/colors.zig");

const Color = colors.Color;

/// ANSI color codes
pub const AnsiColor = enum(u8) {
    black = 0,
    red = 1,
    green = 2,
    yellow = 3,
    blue = 4,
    magenta = 5,
    cyan = 6,
    white = 7,
    bright_black = 8,
    bright_red = 9,
    bright_green = 10,
    bright_yellow = 11,
    bright_blue = 12,
    bright_magenta = 13,
    bright_cyan = 14,
    bright_white = 15,

    pub fn toColor(self: AnsiColor) Color {
        return switch (self) {
            .black => colors.ANSI_BLACK,
            .red => colors.ANSI_RED,
            .green => colors.ANSI_GREEN,
            .yellow => colors.ANSI_YELLOW,
            .blue => colors.ANSI_BLUE,
            .magenta => colors.ANSI_MAGENTA,
            .cyan => colors.ANSI_CYAN,
            .white => colors.ANSI_WHITE,
            .bright_black => colors.ANSI_BRIGHT_BLACK,
            .bright_red => colors.ANSI_BRIGHT_RED,
            .bright_green => colors.ANSI_BRIGHT_GREEN,
            .bright_yellow => colors.ANSI_BRIGHT_YELLOW,
            .bright_blue => colors.ANSI_BRIGHT_BLUE,
            .bright_magenta => colors.ANSI_BRIGHT_MAGENTA,
            .bright_cyan => colors.ANSI_BRIGHT_CYAN,
            .bright_white => colors.ANSI_BRIGHT_WHITE,
        };
    }
};

/// Text attributes
pub const TextAttributes = packed struct {
    bold: bool = false,
    dim: bool = false,
    italic: bool = false,
    underline: bool = false,
    blink: bool = false,
    reverse: bool = false,
    strikethrough: bool = false,
};

/// Terminal styling state
pub const Style = struct {
    foreground: Color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
    background: Color = Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
    attributes: TextAttributes = TextAttributes{},

    pub fn reset(self: *Style) void {
        self.foreground = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
        self.background = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
        self.attributes = TextAttributes{};
    }
};

/// ANSI escape sequence parser
pub const AnsiParser = struct {
    state: State = .normal,
    params: [16]u32 = [_]u32{0} ** 16,
    param_count: usize = 0,
    current_param: u32 = 0,

    const State = enum {
        normal,
        escape,
        csi, // Control Sequence Introducer
        osc, // Operating System Command
    };

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    /// Parse ANSI sequences from input text and apply styling
    pub fn parse(self: *Self, input: []const u8, style: *Style, output: *std.ArrayList(u8), output_colors: *std.ArrayList(Color), output_attributes: *std.ArrayList(TextAttributes)) !void {
        for (input) |ch| {
            switch (self.state) {
                .normal => {
                    if (ch == '\x1b') { // ESC
                        self.state = .escape;
                    } else {
                        // Regular character - add to output with current styling
                        try output.append(ch);
                        try output_colors.append(style.foreground);
                        try output_attributes.append(style.attributes);
                    }
                },
                .escape => {
                    switch (ch) {
                        '[' => {
                            self.state = .csi;
                            self.resetParams();
                        },
                        ']' => {
                            self.state = .osc;
                            self.resetParams();
                        },
                        'c' => {
                            // Reset terminal
                            style.reset();
                            self.state = .normal;
                        },
                        else => {
                            // Unknown escape sequence - ignore and return to normal
                            self.state = .normal;
                        },
                    }
                },
                .csi => {
                    if (ch >= '0' and ch <= '9') {
                        self.current_param = self.current_param * 10 + (ch - '0');
                    } else if (ch == ';') {
                        self.addParam();
                    } else {
                        // End of CSI sequence
                        self.addParam();
                        try self.processCsiCommand(ch, style);
                        self.state = .normal;
                    }
                },
                .osc => {
                    // OSC sequences end with BEL (0x07) or ESC backslash
                    if (ch == '\x07' or ch == '\\') {
                        self.state = .normal;
                    }
                    // For now, ignore OSC sequences
                },
            }
        }
    }

    /// Reset parameter parsing state
    fn resetParams(self: *Self) void {
        self.params = [_]u32{0} ** 16;
        self.param_count = 0;
        self.current_param = 0;
    }

    /// Add current parameter to list
    fn addParam(self: *Self) void {
        if (self.param_count < self.params.len) {
            self.params[self.param_count] = self.current_param;
            self.param_count += 1;
        }
        self.current_param = 0;
    }

    /// Process CSI command
    fn processCsiCommand(self: *Self, command: u8, style: *Style) !void {
        switch (command) {
            'm' => { // SGR (Select Graphic Rendition)
                try self.processSgr(style);
            },
            'H', 'f' => { // Cursor Position
                // For now, ignore cursor positioning
            },
            'A' => { // Cursor Up
                // Ignore for now
            },
            'B' => { // Cursor Down
                // Ignore for now
            },
            'C' => { // Cursor Forward
                // Ignore for now
            },
            'D' => { // Cursor Back
                // Ignore for now
            },
            'J' => { // Erase in Display
                // Ignore for now - terminal will handle clearing
            },
            'K' => { // Erase in Line
                // Ignore for now
            },
            else => {
                // Unknown CSI command - ignore
            },
        }
    }

    /// Process SGR (Select Graphic Rendition) parameters
    fn processSgr(self: *Self, style: *Style) !void {
        if (self.param_count == 0) {
            // No parameters means reset
            style.reset();
            return;
        }

        var i: usize = 0;
        while (i < self.param_count) : (i += 1) {
            const param = self.params[i];

            switch (param) {
                0 => style.reset(), // Reset all attributes
                1 => style.attributes.bold = true, // Bold
                2 => style.attributes.dim = true, // Dim
                3 => style.attributes.italic = true, // Italic
                4 => style.attributes.underline = true, // Underline
                5, 6 => style.attributes.blink = true, // Blink (slow/fast)
                7 => style.attributes.reverse = true, // Reverse video
                8 => {}, // Concealed (ignore)
                9 => style.attributes.strikethrough = true, // Strikethrough
                21, 22 => style.attributes.bold = false, // Bold off
                23 => style.attributes.italic = false, // Italic off
                24 => style.attributes.underline = false, // Underline off
                25 => style.attributes.blink = false, // Blink off
                27 => style.attributes.reverse = false, // Reverse off
                29 => style.attributes.strikethrough = false, // Strikethrough off

                // Foreground colors (30-37)
                30...37 => {
                    const color = @as(AnsiColor, @enumFromInt(param - 30));
                    style.foreground = color.toColor();
                },
                // Bright foreground colors (90-97)
                90...97 => {
                    const color = @as(AnsiColor, @enumFromInt(param - 90 + 8));
                    style.foreground = color.toColor();
                },
                // Background colors (40-47)
                40...47 => {
                    const color = @as(AnsiColor, @enumFromInt(param - 40));
                    style.background = color.toColor();
                },
                // Bright background colors (100-107)
                100...107 => {
                    const color = @as(AnsiColor, @enumFromInt(param - 100 + 8));
                    style.background = color.toColor();
                },

                // 256-color and RGB color modes
                38 => {
                    if (i + 1 < self.param_count and self.params[i + 1] == 5) {
                        // 256-color foreground: ESC[38;5;n
                        if (i + 2 < self.param_count) {
                            style.foreground = self.color256ToRgb(self.params[i + 2]);
                            i += 2; // Skip the next two parameters
                        }
                    } else if (i + 1 < self.param_count and self.params[i + 1] == 2) {
                        // RGB foreground: ESC[38;2;r;g;b
                        if (i + 4 < self.param_count) {
                            style.foreground = Color{
                                .r = @intCast(self.params[i + 2] & 0xFF),
                                .g = @intCast(self.params[i + 3] & 0xFF),
                                .b = @intCast(self.params[i + 4] & 0xFF),
                                .a = 255,
                            };
                            i += 4; // Skip the next four parameters
                        }
                    }
                },
                48 => {
                    if (i + 1 < self.param_count and self.params[i + 1] == 5) {
                        // 256-color background: ESC[48;5;n
                        if (i + 2 < self.param_count) {
                            style.background = self.color256ToRgb(self.params[i + 2]);
                            i += 2; // Skip the next two parameters
                        }
                    } else if (i + 1 < self.param_count and self.params[i + 1] == 2) {
                        // RGB background: ESC[48;2;r;g;b
                        if (i + 4 < self.param_count) {
                            style.background = Color{
                                .r = @intCast(self.params[i + 2] & 0xFF),
                                .g = @intCast(self.params[i + 3] & 0xFF),
                                .b = @intCast(self.params[i + 4] & 0xFF),
                                .a = 255,
                            };
                            i += 4; // Skip the next four parameters
                        }
                    }
                },

                39 => {
                    // Default foreground color
                    style.foreground = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
                },
                49 => {
                    // Default background color
                    style.background = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
                },

                else => {
                    // Unknown parameter - ignore
                },
            }
        }
    }

    /// Convert 256-color index to RGB color
    fn color256ToRgb(self: *Self, index: u32) Color {
        _ = self;

        if (index < 16) {
            // Standard 16 colors
            const color_index: u8 = @intCast(index);
            return (@as(AnsiColor, @enumFromInt(color_index))).toColor();
        } else if (index < 232) {
            // 216-color cube (6x6x6)
            const n = index - 16;
            const r = (n / 36) * 51;
            const g = ((n % 36) / 6) * 51;
            const b = (n % 6) * 51;

            return Color{
                .r = @intCast(r),
                .g = @intCast(g),
                .b = @intCast(b),
                .a = 255,
            };
        } else {
            // 24 grayscale colors
            const level = (index - 232) * 10 + 8;
            const gray_level: u8 = @intCast(level);
            return Color{
                .r = gray_level,
                .g = gray_level,
                .b = gray_level,
                .a = 255,
            };
        }
    }
};

/// Parse ANSI escape sequences from text and return styled output
pub fn parseAnsiText(allocator: std.mem.Allocator, input: []const u8) !struct {
    text: []u8,
    colors: []Color,
    attributes: []TextAttributes,
} {
    var parser = AnsiParser.init();
    var style = Style{};

    var output = std.ArrayList(u8).init(allocator);
    var output_colors = std.ArrayList(Color).init(allocator);
    var output_attributes = std.ArrayList(TextAttributes).init(allocator);

    try parser.parse(input, &style, &output, &output_colors, &output_attributes);

    return .{
        .text = try output.toOwnedSlice(),
        .colors = try output_colors.toOwnedSlice(),
        .attributes = try output_attributes.toOwnedSlice(),
    };
}

/// Check if text contains ANSI escape sequences
pub fn hasAnsiSequences(text: []const u8) bool {
    return std.mem.indexOf(u8, text, "\x1b[") != null;
}
