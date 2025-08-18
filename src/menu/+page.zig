const std = @import("std");
const page = @import("../hud/page.zig");

const IndexPage = struct {
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

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link), arena: std.mem.Allocator) !void {
        _ = self;

        const constants = @import("../hud/constants.zig");
        const screen_width = constants.SCREEN.BASE_WIDTH;
        const screen_height = constants.SCREEN.BASE_HEIGHT;

        // Wide character layout - use full screen width

        // World selection section at top
        const loader = @import("../hex/loader.zig");
        
        // World selection header
        try links.append(page.createLink("WORLD SELECTION", "", 100, 100, 300, 40));
        
        // Current world display
        const current_world_name = loader.getCurrentWorldDisplayName();
        const current_text = try std.fmt.allocPrint(arena, "Current: {s}", .{current_world_name});
        try links.append(page.createLink(current_text, "", 100, 140, 400, 30));
        
        // World selection buttons
        const world_button_width = 150.0;
        const world_button_height = 40.0;
        const world_button_y = 180.0;
        
        try links.append(page.createLink("Test World", "/?load_world=worlds/test_world.zon", 100, world_button_y, world_button_width, world_button_height));
        try links.append(page.createLink("Game World", "/?load_world=worlds/game_world.zon", 270, world_button_y, world_button_width, world_button_height));

        // Header spanning full width (moved down)
        try links.append(page.createLink("CHARACTER SHEET", "", 760, 250, 400, 60));

        // Left column - Spells
        const left_x = 100.0;
        const spell_width = 180.0;
        const spell_height = 35.0;
        const spell_spacing = 10.0;

        try links.append(page.createLink("EQUIPPED SPELLS", "", left_x, 350, 400, 40));

        // Spell row 1: Keys 1-4
        try links.append(page.createLink("1 LULL", "", left_x, 400, spell_width, spell_height));
        try links.append(page.createLink("2 BLINK", "", left_x + spell_width + spell_spacing, 400, spell_width, spell_height));
        try links.append(page.createLink("3 EMPTY", "", left_x + (spell_width + spell_spacing) * 2, 400, spell_width, spell_height));
        try links.append(page.createLink("4 EMPTY", "", left_x + (spell_width + spell_spacing) * 3, 400, spell_width, spell_height));

        // Spell row 2: Keys Q E R F
        try links.append(page.createLink("Q EMPTY", "", left_x, 450, spell_width, spell_height));
        try links.append(page.createLink("E EMPTY", "", left_x + spell_width + spell_spacing, 450, spell_width, spell_height));
        try links.append(page.createLink("R EMPTY", "", left_x + (spell_width + spell_spacing) * 2, 450, spell_width, spell_height));
        try links.append(page.createLink("F EMPTY", "", left_x + (spell_width + spell_spacing) * 3, 450, spell_width, spell_height));

        // Center column - Stats
        const center_x = 450.0;
        const stat_width = 250.0;
        const stat_height = 35.0;

        try links.append(page.createLink("PLAYER STATS", "", center_x, 350, stat_width, 40));
        try links.append(page.createLink("Health: Full (100/100)", "", center_x, 400, stat_width, stat_height));
        try links.append(page.createLink("Speed: Normal (200 u/s)", "", center_x, 450, stat_width, stat_height));
        try links.append(page.createLink("Bullets: 6 max", "", center_x, 500, stat_width, stat_height));
        try links.append(page.createLink("Recharge: 2/sec", "", center_x, 550, stat_width, stat_height));
        try links.append(page.createLink("Damage: Normal", "", center_x, 600, stat_width, stat_height));

        // Right column - Upgrades
        const right_x = 950.0;
        const upgrade_width = 250.0;
        const upgrade_height = 35.0;

        try links.append(page.createLink("UPGRADES", "", right_x, 350, upgrade_width, 40));
        try links.append(page.createLink("Bullet Range", "", right_x, 400, upgrade_width, upgrade_height));
        try links.append(page.createLink("Multi-shot", "", right_x, 450, upgrade_width, upgrade_height));
        try links.append(page.createLink("Recharge Rate", "", right_x, 500, upgrade_width, upgrade_height));
        try links.append(page.createLink("Damage Boost", "", right_x, 550, upgrade_width, upgrade_height));
        try links.append(page.createLink("Health Boost", "", right_x, 600, upgrade_width, upgrade_height));

        // Far right - Combat info
        const far_right_x = 1350.0;
        const combat_width = 280.0;
        const combat_height = 35.0;

        try links.append(page.createLink("COMBAT INFO", "", far_right_x, 350, combat_width, 40));
        try links.append(page.createLink("Hold LMB: Burst mode", "", far_right_x, 400, combat_width, combat_height));
        try links.append(page.createLink("Click LMB: Rhythm mode", "", far_right_x, 450, combat_width, combat_height));
        try links.append(page.createLink("RMB: Cast spell", "", far_right_x, 500, combat_width, combat_height));
        try links.append(page.createLink("Ctrl+RMB: Self-cast", "", far_right_x, 550, combat_width, combat_height));
        try links.append(page.createLink("Bullet lifetime: 4s", "", far_right_x, 600, combat_width, combat_height));

        // Bottom navigation
        const nav_y = screen_height * 0.79; // 850/1080 ≈ 0.79
        const nav_width = 200.0;
        const nav_height = 50.0;
        const nav_spacing = 50.0;
        const nav_center_x = screen_width / 2.0;

        try links.append(page.createLink("Settings", "/settings", nav_center_x - nav_width - nav_spacing / 2.0, nav_y, nav_width, nav_height));

        try links.append(page.createLink("Statistics", "/stats", nav_center_x + nav_spacing / 2.0, nav_y, nav_width, nav_height));

        // Add font test link
        try links.append(page.createLink("Font Test", "/font-grid-test", nav_center_x, nav_y - nav_height - 20, nav_width, nav_height));

        // Add IDE link
        try links.append(page.createLink("IDE", "/ide", nav_center_x - nav_width * 2 - nav_spacing, nav_y - nav_height - 20, nav_width, nav_height));

        // Test panel for font debugging - black background with various glyphs
        const test_y = 600.0;

        // Skip the black background panel - it might be causing rendering issues
        // try links.append(page.createLink("", "", 100, test_y, 1720, 200));

        // Panel header
        try links.append(page.createLink("FONT TEST PANEL", "", 100, test_y - 30, 300, 25));

        // Row 1: Full ASCII uppercase alphabet
        try links.append(page.createLink("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "", 150, test_y + 20, 1620, 40));

        // Row 2: Lowercase alphabet
        try links.append(page.createLink("abcdefghijklmnopqrstuvwxyz", "", 150, test_y + 60, 1620, 40));

        // Row 3: Numbers and common symbols
        try links.append(page.createLink("0123456789 !@#$%^&*()[]{}+-=<>?/", "", 150, test_y + 100, 1620, 40));

        // Row 4: Mixed case pangram to test kerning and spacing
        try links.append(page.createLink("The Quick Brown Fox Jumps Over The Lazy Dog 1234567890", "", 150, test_y + 140, 1620, 40));

        // Single large letter test for debugging
        try links.append(page.createLink("A", "", 850, 400, 100, 100));
        try links.append(page.createLink("SINGLE LETTER TEST", "", 750, 370, 300, 25));
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const index_page: *IndexPage = @fieldParentPtr("base", self);
        allocator.destroy(index_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const index_page = try allocator.create(IndexPage);
    index_page.* = .{
        .base = .{
            .vtable = .{
                .init = IndexPage.init,
                .deinit = IndexPage.deinit,
                .update = IndexPage.update,
                .render = IndexPage.render,
                .destroy = IndexPage.destroy,
            },
            .path = "/",
            .title = "System Menu",
        },
    };
    return &index_page.base;
}
