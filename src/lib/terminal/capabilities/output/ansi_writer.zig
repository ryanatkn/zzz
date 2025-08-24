const std = @import("std");
const kernel = @import("../../kernel/mod.zig");
const BasicWriter = @import("basic_writer.zig").BasicWriter;
const colors = @import("../../../core/colors.zig");

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
    foreground: Color = colors.ANSI_BRIGHT_WHITE,
    background: Color = colors.ANSI_BLACK,
    attributes: TextAttributes = TextAttributes{},

    pub fn reset(self: *Style) void {
        self.foreground = colors.ANSI_BRIGHT_WHITE;
        self.background = colors.ANSI_BLACK;
        self.attributes = TextAttributes{};
    }
};

/// ANSI output writer capability - extends basic writer with ANSI escape sequence support
pub const AnsiWriter = struct {
    allocator: std.mem.Allocator,
    basic_writer_capability: ?*BasicWriter = null,
    event_bus: ?*kernel.EventBus = null,
    current_style: Style = Style{},

    /// Factory method for creating ANSI writer capability
    pub fn create(allocator: std.mem.Allocator) !*AnsiWriter {
        const writer = try allocator.create(AnsiWriter);
        writer.* = AnsiWriter{
            .allocator = allocator,
        };
        return writer;
    }

    /// Factory method for destroying ANSI writer capability
    pub fn destroy(self: *AnsiWriter, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    pub fn getDependencies(self: *const AnsiWriter) []const []const u8 {
        _ = self;
        return &[_][]const u8{"basic_writer"};
    }

    pub fn initialize(self: *AnsiWriter, dependencies: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        self.event_bus = event_bus;

        // Find basic writer dependency using type-safe casting
        for (dependencies) |dep| {
            if (dep.cast(BasicWriter)) |writer| {
                self.basic_writer_capability = writer;
                break;
            }
        }

        if (self.basic_writer_capability == null) {
            return error.MissingDependency;
        }
    }

    pub fn deinit(self: *AnsiWriter) void {
        self.event_bus = null;
        self.basic_writer_capability = null;
    }

    pub fn isActive(self: *const AnsiWriter) bool {
        return self.event_bus != null and self.basic_writer_capability != null;
    }

    /// Write text with current ANSI styling
    pub fn write(self: *AnsiWriter, text: []const u8) !void {
        if (!self.isActive()) {
            return error.NotInitialized;
        }

        // Delegate to basic writer - ANSI styling would be applied here in full implementation
        const basic_writer = self.basic_writer_capability.?;
        try basic_writer.write(text);

        // For now, just emit a write event
        if (self.event_bus) |bus| {
            const event = kernel.Event.init(.state_change, .{
                .state_change = .{
                    .component = .writer,
                    .state = .{ .writer = .text_written },
                },
            });
            try bus.emit(event);
        }
    }

    /// Write text with specific foreground color
    pub fn writeColored(self: *AnsiWriter, text: []const u8, color: AnsiColor) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[3{d}m{s}\x1b[0m", .{ @intFromEnum(color), text });
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Write text with specific foreground and background colors
    pub fn writeColoredBg(self: *AnsiWriter, text: []const u8, fg_color: AnsiColor, bg_color: AnsiColor) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[3{d};4{d}m{s}\x1b[0m", .{ @intFromEnum(fg_color), @intFromEnum(bg_color), text });
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Write bold text
    pub fn writeBold(self: *AnsiWriter, text: []const u8) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[1m{s}\x1b[0m", .{text});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Write underlined text
    pub fn writeUnderlined(self: *AnsiWriter, text: []const u8) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[4m{s}\x1b[0m", .{text});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Write italic text
    pub fn writeItalic(self: *AnsiWriter, text: []const u8) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[3m{s}\x1b[0m", .{text});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Set foreground color
    pub fn setForegroundColor(self: *AnsiWriter, color: AnsiColor) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[3{d}m", .{@intFromEnum(color)});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
        self.current_style.foreground = color.toColor();
    }

    /// Set background color
    pub fn setBackgroundColor(self: *AnsiWriter, color: AnsiColor) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[4{d}m", .{@intFromEnum(color)});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
        self.current_style.background = color.toColor();
    }

    /// Enable bold
    pub fn setBold(self: *AnsiWriter, enable: bool) !void {
        const ansi_seq = if (enable) "\x1b[1m" else "\x1b[22m";
        try self.write(ansi_seq);
        self.current_style.attributes.bold = enable;
    }

    /// Enable underline
    pub fn setUnderline(self: *AnsiWriter, enable: bool) !void {
        const ansi_seq = if (enable) "\x1b[4m" else "\x1b[24m";
        try self.write(ansi_seq);
        self.current_style.attributes.underline = enable;
    }

    /// Enable italic
    pub fn setItalic(self: *AnsiWriter, enable: bool) !void {
        const ansi_seq = if (enable) "\x1b[3m" else "\x1b[23m";
        try self.write(ansi_seq);
        self.current_style.attributes.italic = enable;
    }

    /// Reset all styling to defaults
    pub fn resetStyle(self: *AnsiWriter) !void {
        try self.write("\x1b[0m");
        self.current_style.reset();
    }

    /// Clear screen
    pub fn clearScreen(self: *AnsiWriter) !void {
        try self.write("\x1b[2J\x1b[H");
    }

    /// Move cursor to position (1-based)
    pub fn moveCursor(self: *AnsiWriter, row: usize, col: usize) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[{d};{d}H", .{ row, col });
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Move cursor up by lines
    pub fn moveCursorUp(self: *AnsiWriter, lines: usize) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[{d}A", .{lines});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Move cursor down by lines
    pub fn moveCursorDown(self: *AnsiWriter, lines: usize) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[{d}B", .{lines});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Hide cursor
    pub fn hideCursor(self: *AnsiWriter) !void {
        try self.write("\x1b[?25l");
    }

    /// Show cursor
    pub fn showCursor(self: *AnsiWriter) !void {
        try self.write("\x1b[?25h");
    }

    /// Get current style
    pub fn getCurrentStyle(self: *const AnsiWriter) Style {
        return self.current_style;
    }
};

// Tests
test "AnsiWriter capability initialization" {
    const allocator = std.testing.allocator;
    var writer = try AnsiWriter.create(allocator);
    defer writer.destroy(allocator);

    // Test that capability can be created and has correct properties
    try std.testing.expect(writer.getDependencies().len == 1);
    try std.testing.expectEqualStrings("basic_writer", writer.getDependencies()[0]);

    // Test initial state
    try std.testing.expect(writer.basic_writer_capability == null);
    try std.testing.expect(writer.event_bus == null);
    try std.testing.expect(writer.allocator.ptr == allocator.ptr);
}

test "AnsiWriter ANSI color conversion" {
    const red_color = AnsiColor.red.toColor();
    const green_color = AnsiColor.green.toColor();
    const blue_color = AnsiColor.blue.toColor();
    const white_color = AnsiColor.white.toColor();

    // Test that colors are in expected f32 range (0.0-1.0)
    try std.testing.expect(red_color.r > 0.8 and red_color.r < 0.81); // ~205/255 = 0.804
    try std.testing.expect(green_color.g > 0.73 and green_color.g < 0.74); // ~188/255 = 0.737
    try std.testing.expect(blue_color.b > 0.78 and blue_color.b < 0.79); // ~200/255 = 0.784
    try std.testing.expect(white_color.r > 0.89 and white_color.r < 0.90); // ~229/255 = 0.898
}

test "AnsiWriter style management" {
    const allocator = std.testing.allocator;
    var writer = try AnsiWriter.create(allocator);
    defer writer.destroy(allocator);

    // Test initial style
    const initial_style = writer.getCurrentStyle();
    try std.testing.expect(!initial_style.attributes.bold);
    try std.testing.expect(!initial_style.attributes.italic);
    try std.testing.expect(!initial_style.attributes.underline);

    // Test style reset
    writer.current_style.attributes.bold = true;
    writer.current_style.reset();
    try std.testing.expect(!writer.current_style.attributes.bold);
}
