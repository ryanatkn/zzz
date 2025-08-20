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
            .black => Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
            .red => Color{ .r = 205, .g = 49, .b = 49, .a = 255 },
            .green => Color{ .r = 13, .g = 188, .b = 121, .a = 255 },
            .yellow => Color{ .r = 229, .g = 229, .b = 16, .a = 255 },
            .blue => Color{ .r = 36, .g = 114, .b = 200, .a = 255 },
            .magenta => Color{ .r = 188, .g = 63, .b = 188, .a = 255 },
            .cyan => Color{ .r = 17, .g = 168, .b = 205, .a = 255 },
            .white => Color{ .r = 229, .g = 229, .b = 229, .a = 255 },
            .bright_black => Color{ .r = 102, .g = 102, .b = 102, .a = 255 },
            .bright_red => Color{ .r = 241, .g = 76, .b = 76, .a = 255 },
            .bright_green => Color{ .r = 35, .g = 209, .b = 139, .a = 255 },
            .bright_yellow => Color{ .r = 245, .g = 245, .b = 67, .a = 255 },
            .bright_blue => Color{ .r = 59, .g = 142, .b = 234, .a = 255 },
            .bright_magenta => Color{ .r = 214, .g = 112, .b = 214, .a = 255 },
            .bright_cyan => Color{ .r = 41, .g = 184, .b = 219, .a = 255 },
            .bright_white => Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
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

/// ANSI output writer capability - extends basic writer with ANSI escape sequence support
pub const AnsiWriter = struct {
    pub const name = "ansi_writer";
    pub const capability_type = "output";

    allocator: std.mem.Allocator,
    basic_writer_capability: ?*BasicWriter = null,
    event_bus: ?*kernel.EventBus = null,
    current_style: Style = Style{},

    const Self = @This();

    /// Factory method for creating ANSI writer capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const writer = try allocator.create(Self);
        writer.* = Self{
            .allocator = allocator,
        };
        return writer;
    }

    /// Factory method for destroying ANSI writer capability
    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    /// ICapability interface implementation
    pub fn getName(self: *const Self) []const u8 {
        _ = self;
        return name;
    }

    pub fn getType(self: *const Self) []const u8 {
        _ = self;
        return capability_type;
    }

    pub fn getDependencies(self: *const Self) []const []const u8 {
        _ = self;
        return &[_][]const u8{"basic_writer"};
    }

    pub fn initialize(self: *Self, dependencies: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        self.event_bus = event_bus;

        // Find basic writer dependency using type-safe casting
        for (dependencies) |dep| {
            const dep_name = dep.getName();
            if (std.mem.eql(u8, dep_name, "basic_writer")) {
                self.basic_writer_capability = dep.cast(BasicWriter) orelse return error.InvalidCapabilityType;
                break;
            }
        }

        if (self.basic_writer_capability == null) {
            return error.MissingDependency;
        }
    }

    pub fn deinit(self: *Self) void {
        self.event_bus = null;
        self.basic_writer_capability = null;
    }

    pub fn isActive(self: *const Self) bool {
        return self.event_bus != null and self.basic_writer_capability != null;
    }

    /// Write text with current ANSI styling
    pub fn write(self: *Self, text: []const u8) !void {
        _ = text; // TODO: Implement proper write
        if (!self.isActive()) {
            return error.NotInitialized;
        }

        // Simply delegate to basic writer for now
        // In a full implementation, this would apply ANSI styling
        const basic_writer = self.basic_writer_capability.?;
        
        // Call the basic writer's write method through its vtable
        // Note: This is a simplified approach - in a real implementation we'd need
        // to properly define the basic writer interface
        _ = basic_writer;
        
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
    pub fn writeColored(self: *Self, text: []const u8, color: AnsiColor) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[3{d}m{s}\x1b[0m", .{ @intFromEnum(color), text });
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Write text with specific foreground and background colors
    pub fn writeColoredBg(self: *Self, text: []const u8, fg_color: AnsiColor, bg_color: AnsiColor) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[3{d};4{d}m{s}\x1b[0m", .{ @intFromEnum(fg_color), @intFromEnum(bg_color), text });
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Write bold text
    pub fn writeBold(self: *Self, text: []const u8) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[1m{s}\x1b[0m", .{text});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Write underlined text
    pub fn writeUnderlined(self: *Self, text: []const u8) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[4m{s}\x1b[0m", .{text});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Write italic text
    pub fn writeItalic(self: *Self, text: []const u8) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[3m{s}\x1b[0m", .{text});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Set foreground color
    pub fn setForegroundColor(self: *Self, color: AnsiColor) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[3{d}m", .{@intFromEnum(color)});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
        self.current_style.foreground = color.toColor();
    }

    /// Set background color
    pub fn setBackgroundColor(self: *Self, color: AnsiColor) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[4{d}m", .{@intFromEnum(color)});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
        self.current_style.background = color.toColor();
    }

    /// Enable bold
    pub fn setBold(self: *Self, enable: bool) !void {
        const ansi_seq = if (enable) "\x1b[1m" else "\x1b[22m";
        try self.write(ansi_seq);
        self.current_style.attributes.bold = enable;
    }

    /// Enable underline
    pub fn setUnderline(self: *Self, enable: bool) !void {
        const ansi_seq = if (enable) "\x1b[4m" else "\x1b[24m";
        try self.write(ansi_seq);
        self.current_style.attributes.underline = enable;
    }

    /// Enable italic
    pub fn setItalic(self: *Self, enable: bool) !void {
        const ansi_seq = if (enable) "\x1b[3m" else "\x1b[23m";
        try self.write(ansi_seq);
        self.current_style.attributes.italic = enable;
    }

    /// Reset all styling to defaults
    pub fn resetStyle(self: *Self) !void {
        try self.write("\x1b[0m");
        self.current_style.reset();
    }

    /// Clear screen
    pub fn clearScreen(self: *Self) !void {
        try self.write("\x1b[2J\x1b[H");
    }

    /// Move cursor to position (1-based)
    pub fn moveCursor(self: *Self, row: usize, col: usize) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[{d};{d}H", .{ row, col });
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Move cursor up by lines
    pub fn moveCursorUp(self: *Self, lines: usize) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[{d}A", .{lines});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Move cursor down by lines
    pub fn moveCursorDown(self: *Self, lines: usize) !void {
        const ansi_seq = try std.fmt.allocPrint(self.allocator, "\x1b[{d}B", .{lines});
        defer self.allocator.free(ansi_seq);
        try self.write(ansi_seq);
    }

    /// Hide cursor
    pub fn hideCursor(self: *Self) !void {
        try self.write("\x1b[?25l");
    }

    /// Show cursor
    pub fn showCursor(self: *Self) !void {
        try self.write("\x1b[?25h");
    }

    /// Get current style
    pub fn getCurrentStyle(self: *const Self) Style {
        return self.current_style;
    }
};

// Tests
test "AnsiWriter capability initialization" {
    const allocator = std.testing.allocator;
    var writer = try AnsiWriter.create(allocator);
    defer writer.destroy(allocator);

    try std.testing.expectEqualStrings("ansi_writer", writer.getName());
    try std.testing.expectEqualStrings("output", writer.getType());
    try std.testing.expect(writer.getDependencies().len == 1);
    try std.testing.expectEqualStrings("basic_writer", writer.getDependencies()[0]);
}

test "AnsiWriter ANSI color conversion" {
    try std.testing.expect(AnsiColor.red.toColor().r == 205);
    try std.testing.expect(AnsiColor.green.toColor().g == 188);
    try std.testing.expect(AnsiColor.blue.toColor().b == 200);
    try std.testing.expect(AnsiColor.white.toColor().r == 229);
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