const std = @import("std");
const page = @import("../../browser/page.zig");
const types = @import("../../lib/types.zig");

const CharacterPage = struct {
    base: page.Page,
    
    pub fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        _ = self;
        _ = allocator;
    }
    
    pub fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
    
    pub fn update(self: *page.Page, dt: f32) void {
        _ = self;
        _ = dt;
    }
    
    pub fn render(self: *const page.Page, links: *std.ArrayList(page.Link)) !void {
        _ = self;
        
        // Character sheet header
        try links.append(page.createLink("CHARACTER", "", 760, 200, 400, 60));
        
        // Spell slots section
        try links.append(page.createLink("EQUIPPED SPELLS", "", 400, 300, 300, 40));
        
        // Row 1: Keys 1-4
        try links.append(page.createLink("1 LULL", "", 400, 350, 200, 40));
        try links.append(page.createLink("2 BLINK", "", 620, 350, 200, 40));
        try links.append(page.createLink("3 EMPTY", "", 840, 350, 200, 40));
        try links.append(page.createLink("4 EMPTY", "", 1060, 350, 200, 40));
        
        // Row 2: Keys Q E R F
        try links.append(page.createLink("Q EMPTY", "", 400, 400, 200, 40));
        try links.append(page.createLink("E EMPTY", "", 620, 400, 200, 40));
        try links.append(page.createLink("R EMPTY", "", 840, 400, 200, 40));
        try links.append(page.createLink("F EMPTY", "", 1060, 400, 200, 40));
        
        // Stats section
        try links.append(page.createLink("PLAYER STATS", "", 400, 500, 300, 40));
        try links.append(page.createLink("HEALTH FULL", "", 400, 550, 300, 40));
        try links.append(page.createLink("SPEED NORMAL", "", 400, 600, 300, 40));
        try links.append(page.createLink("BULLETS 6 MAX", "", 400, 650, 300, 40));
        try links.append(page.createLink("DAMAGE NORMAL", "", 400, 700, 300, 40));
        
        // Future upgrades section (comments)
        try links.append(page.createLink("UPGRADES", "", 800, 500, 300, 40));
        try links.append(page.createLink("BULLET RANGE", "", 800, 550, 300, 40));
        try links.append(page.createLink("MULTISHOT", "", 800, 600, 300, 40));
        try links.append(page.createLink("RECHARGE RATE", "", 800, 650, 300, 40));
        
        // Navigation
        try links.append(page.createLink("BACK TO MENU", "/", 760, 850, 400, 60));
    }
    
    pub fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const character_page: *CharacterPage = @fieldParentPtr("base", self);
        allocator.destroy(character_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const character_page = try allocator.create(CharacterPage);
    character_page.* = .{
        .base = .{
            .vtable = .{
                .init = CharacterPage.init,
                .deinit = CharacterPage.deinit,
                .update = CharacterPage.update,
                .render = CharacterPage.render,
                .destroy = CharacterPage.destroy,
            },
            .path = "/character",
            .title = "Character Sheet",
        },
    };
    return &character_page.base;
}