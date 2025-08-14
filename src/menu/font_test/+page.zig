const std = @import("std");
const page = @import("../../hud/page.zig");

const FontTestPage = struct {
    base: page.Page,

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        _ = self;
        _ = allocator;
    }

    fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    fn update(self: *page.Page, dt: f32) void {
        _ = self;
        _ = dt;
    }

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link)) !void {
        _ = self;

        const screen_width = 1920.0;
        const screen_height = 1080.0;

        // Page header
        try links.append(page.createLink("FONT RENDERING TEST PAGE", "", 50, 50, 600, 60));

        // Basic character tests
        const test_x = 100.0;
        var y_pos: f32 = 150.0;
        const line_height = 50.0;

        // Test 1: Uppercase alphabet
        try links.append(page.createLink("UPPERCASE:", "", test_x, y_pos, 150, 30));
        try links.append(page.createLink("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "", test_x + 160, y_pos, 900, 30));
        y_pos += line_height;

        // Test 2: Lowercase alphabet
        try links.append(page.createLink("lowercase:", "", test_x, y_pos, 150, 30));
        try links.append(page.createLink("abcdefghijklmnopqrstuvwxyz", "", test_x + 160, y_pos, 900, 30));
        y_pos += line_height;

        // Test 3: Numbers
        try links.append(page.createLink("Numbers:", "", test_x, y_pos, 150, 30));
        try links.append(page.createLink("0123456789", "", test_x + 160, y_pos, 400, 30));
        y_pos += line_height;

        // Test 4: Special characters
        try links.append(page.createLink("Special:", "", test_x, y_pos, 150, 30));
        try links.append(page.createLink("!@#$%^&*()[]{}+-=<>?/|\\~`", "", test_x + 160, y_pos, 600, 30));
        y_pos += line_height;

        // Test 5: Punctuation
        try links.append(page.createLink("Punctuation:", "", test_x, y_pos, 150, 30));
        try links.append(page.createLink(".,;:'\"-_", "", test_x + 160, y_pos, 300, 30));
        y_pos += line_height;

        // Test 6: Pangram for kerning
        y_pos += 20; // Extra spacing
        try links.append(page.createLink("Pangram Test:", "", test_x, y_pos, 150, 30));
        y_pos += 35;
        try links.append(page.createLink("The quick brown fox jumps over the lazy dog.", "", test_x, y_pos, 900, 30));
        y_pos += 35;
        try links.append(page.createLink("THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG.", "", test_x, y_pos, 900, 30));
        y_pos += line_height;

        // Size tests
        y_pos += 30;
        try links.append(page.createLink("SIZE TESTS", "", test_x, y_pos, 200, 40));
        y_pos += 50;

        // Different sizes of the same text
        const size_test_text = "Font Size Test ABCabc123";

        // 12pt equivalent
        try links.append(page.createLink("12pt:", "", test_x, y_pos, 60, 20));
        try links.append(page.createLink(size_test_text, "", test_x + 70, y_pos, 350, 20));
        y_pos += 30;

        // 16pt equivalent (normal)
        try links.append(page.createLink("16pt:", "", test_x, y_pos, 60, 25));
        try links.append(page.createLink(size_test_text, "", test_x + 70, y_pos, 400, 25));
        y_pos += 35;

        // 24pt equivalent
        try links.append(page.createLink("24pt:", "", test_x, y_pos, 80, 35));
        try links.append(page.createLink(size_test_text, "", test_x + 90, y_pos, 500, 35));
        y_pos += 45;

        // 32pt equivalent
        try links.append(page.createLink("32pt:", "", test_x, y_pos, 100, 45));
        try links.append(page.createLink(size_test_text, "", test_x + 110, y_pos, 600, 45));
        y_pos += 60;

        // 48pt equivalent
        try links.append(page.createLink("48pt:", "", test_x, y_pos, 120, 60));
        try links.append(page.createLink(size_test_text, "", test_x + 140, y_pos, 700, 60));
        y_pos += 80;

        // Individual letter tests for debugging
        const letter_x = 1200.0;
        var letter_y: f32 = 150.0;

        try links.append(page.createLink("INDIVIDUAL LETTERS", "", letter_x, letter_y, 300, 30));
        letter_y += 50;

        // Large individual letters to see glyph quality
        const letters = [_][]const u8{ "A", "B", "g", "y", "Q", "0", "8", "@" };
        var row: usize = 0;
        for (letters) |letter| {
            const x = letter_x + @as(f32, @floatFromInt(row % 4)) * 80.0;
            const y = letter_y + @as(f32, @floatFromInt(row / 4)) * 80.0;
            try links.append(page.createLink(letter, "", x, y, 70, 70));
            row += 1;
        }

        // Spacing and kerning tests
        const spacing_x = 100.0;
        var spacing_y: f32 = y_pos + 20;

        try links.append(page.createLink("SPACING & KERNING", "", spacing_x, spacing_y, 300, 30));
        spacing_y += 40;

        // Kerning pairs that commonly need adjustment
        try links.append(page.createLink("AV AW LT LY To Yo", "", spacing_x, spacing_y, 400, 30));
        spacing_y += 35;
        try links.append(page.createLink("ff fi fl ffi ffl", "", spacing_x, spacing_y, 300, 30));
        spacing_y += 35;
        try links.append(page.createLink("111 III ||| lll", "", spacing_x, spacing_y, 300, 30));
        spacing_y += 35;
        try links.append(page.createLink("mmm www MMM WWW", "", spacing_x, spacing_y, 400, 30));

        // Debug info section
        const debug_x = 1200.0;
        var debug_y: f32 = letter_y + 200.0;

        try links.append(page.createLink("DEBUG INFO", "", debug_x, debug_y, 200, 30));
        debug_y += 40;
        try links.append(page.createLink("Atlas: RGBA format", "", debug_x, debug_y, 300, 25));
        debug_y += 30;
        try links.append(page.createLink("Shader: Alpha channel", "", debug_x, debug_y, 300, 25));
        debug_y += 30;
        try links.append(page.createLink("Rasterizer: Scanline", "", debug_x, debug_y, 300, 25));

        // Navigation buttons
        try links.append(page.createLink("Back to Menu", "/", screen_width / 2.0 - 100.0, screen_height - 100.0, 200, 50));

        // Performance test - many small text items
        const perf_x = 600.0;
        var perf_y: f32 = 650.0;

        try links.append(page.createLink("PERFORMANCE TEST", "", perf_x, perf_y, 250, 30));
        perf_y += 40;

        // Create a grid of small text items
        var perf_row: usize = 0;
        while (perf_row < 5) : (perf_row += 1) {
            var perf_col: usize = 0;
            while (perf_col < 10) : (perf_col += 1) {
                const px = perf_x + @as(f32, @floatFromInt(perf_col)) * 55.0;
                const py = perf_y + @as(f32, @floatFromInt(perf_row)) * 25.0;
                try links.append(page.createLink("Test", "", px, py, 50, 20));
            }
        }
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const test_page: *FontTestPage = @fieldParentPtr("base", self);
        allocator.destroy(test_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const test_page = try allocator.create(FontTestPage);
    test_page.* = .{
        .base = .{
            .vtable = .{
                .init = FontTestPage.init,
                .deinit = FontTestPage.deinit,
                .update = FontTestPage.update,
                .render = FontTestPage.render,
                .destroy = FontTestPage.destroy,
            },
            .path = "/font-test",
            .title = "Font Test",
        },
    };
    return &test_page.base;
}
