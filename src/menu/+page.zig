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

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link)) !void {
        _ = self;
        
        const screen_width = 1920.0; // TODO: Get from renderer
        
        // Wide character layout - use full screen width
        
        // Header spanning full width
        try links.append(page.createLink("CHARACTER SHEET", "", 760, 150, 400, 60));
        
        // Left column - Spells
        const left_x = 100.0;
        const spell_width = 180.0;
        const spell_height = 35.0;
        const spell_spacing = 10.0;
        
        try links.append(page.createLink("EQUIPPED SPELLS", "", left_x, 250, 400, 40));
        
        // Spell row 1: Keys 1-4
        try links.append(page.createLink("1 LULL", "", left_x, 300, spell_width, spell_height));
        try links.append(page.createLink("2 BLINK", "", left_x + spell_width + spell_spacing, 300, spell_width, spell_height));
        try links.append(page.createLink("3 EMPTY", "", left_x + (spell_width + spell_spacing) * 2, 300, spell_width, spell_height));
        try links.append(page.createLink("4 EMPTY", "", left_x + (spell_width + spell_spacing) * 3, 300, spell_width, spell_height));
        
        // Spell row 2: Keys Q E R F
        try links.append(page.createLink("Q EMPTY", "", left_x, 350, spell_width, spell_height));
        try links.append(page.createLink("E EMPTY", "", left_x + spell_width + spell_spacing, 350, spell_width, spell_height));
        try links.append(page.createLink("R EMPTY", "", left_x + (spell_width + spell_spacing) * 2, 350, spell_width, spell_height));
        try links.append(page.createLink("F EMPTY", "", left_x + (spell_width + spell_spacing) * 3, 350, spell_width, spell_height));
        
        // Center column - Stats
        const center_x = 450.0;
        const stat_width = 250.0;
        const stat_height = 35.0;
        
        try links.append(page.createLink("PLAYER STATS", "", center_x, 250, stat_width, 40));
        try links.append(page.createLink("Health: Full (100/100)", "", center_x, 300, stat_width, stat_height));
        try links.append(page.createLink("Speed: Normal (200 u/s)", "", center_x, 350, stat_width, stat_height));
        try links.append(page.createLink("Bullets: 6 max", "", center_x, 400, stat_width, stat_height));
        try links.append(page.createLink("Recharge: 2/sec", "", center_x, 450, stat_width, stat_height));
        try links.append(page.createLink("Damage: Normal", "", center_x, 500, stat_width, stat_height));
        
        // Right column - Upgrades
        const right_x = 950.0;
        const upgrade_width = 250.0;
        const upgrade_height = 35.0;
        
        try links.append(page.createLink("UPGRADES", "", right_x, 250, upgrade_width, 40));
        try links.append(page.createLink("Bullet Range", "", right_x, 300, upgrade_width, upgrade_height));
        try links.append(page.createLink("Multi-shot", "", right_x, 350, upgrade_width, upgrade_height));
        try links.append(page.createLink("Recharge Rate", "", right_x, 400, upgrade_width, upgrade_height));
        try links.append(page.createLink("Damage Boost", "", right_x, 450, upgrade_width, upgrade_height));
        try links.append(page.createLink("Health Boost", "", right_x, 500, upgrade_width, upgrade_height));
        
        // Far right - Combat info
        const far_right_x = 1350.0;
        const combat_width = 280.0;
        const combat_height = 35.0;
        
        try links.append(page.createLink("COMBAT INFO", "", far_right_x, 250, combat_width, 40));
        try links.append(page.createLink("Hold LMB: Burst mode", "", far_right_x, 300, combat_width, combat_height));
        try links.append(page.createLink("Click LMB: Rhythm mode", "", far_right_x, 350, combat_width, combat_height));
        try links.append(page.createLink("RMB: Cast spell", "", far_right_x, 400, combat_width, combat_height));
        try links.append(page.createLink("Ctrl+RMB: Self-cast", "", far_right_x, 450, combat_width, combat_height));
        try links.append(page.createLink("Bullet lifetime: 4s", "", far_right_x, 500, combat_width, combat_height));
        
        // Bottom navigation
        const nav_y = 850.0;
        const nav_width = 200.0;
        const nav_height = 50.0;
        const nav_spacing = 50.0;
        const nav_center_x = screen_width / 2.0;
        
        try links.append(page.createLink(
            "Settings",
            "/settings",
            nav_center_x - nav_width - nav_spacing / 2.0,
            nav_y,
            nav_width,
            nav_height
        ));
        
        try links.append(page.createLink(
            "Statistics",
            "/stats",
            nav_center_x + nav_spacing / 2.0,
            nav_y,
            nav_width,
            nav_height
        ));
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