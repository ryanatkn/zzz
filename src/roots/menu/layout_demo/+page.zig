const std = @import("std");
const page = @import("../../../lib/browser/page.zig");
const constants = @import("../../../lib/browser/constants.zig");
const layout = @import("../../../lib/layout/mod.zig");
const math = @import("../../../lib/math/mod.zig");
const colors = @import("../../../lib/core/colors.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Color = colors.Color;
const LayoutEngine = layout.LayoutEngine;

pub const LayoutDemoPage = struct {
    base: page.Page,
    initialized: bool,

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const demo_page: *LayoutDemoPage = @fieldParentPtr("base", self);
        demo_page.initialized = true;
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
        const screen_height = constants.SCREEN.BASE_HEIGHT;
        _ = self;

        // Page header
        try links.append(page.createTextElement("LAYOUT SYSTEM DEMO", 200, 30, 500, 50));
        try links.append(page.createTextElement("Systematic demonstration of layout primitives with code examples", 200, 70, 800, 30));

        // Layout demo areas
        const demo_start_y: f32 = 120;
        const demo_height: f32 = 140;
        const demo_spacing: f32 = 20;
        var current_y: f32 = demo_start_y;

        // 1. Block Layout Demo
        try renderBlockLayoutDemo(links, current_y, arena);
        current_y += demo_height + demo_spacing;

        // 2. Flexbox Layout Demo
        try renderFlexLayoutDemo(links, current_y, arena);
        current_y += demo_height + demo_spacing;

        // 3. Absolute Positioning Demo
        try renderAbsoluteLayoutDemo(links, current_y, arena);
        current_y += demo_height + demo_spacing;

        // 4. Box Model Demo
        try renderBoxModelDemo(links, current_y, arena);
        current_y += demo_height + demo_spacing;

        // 5. Constraints Demo
        try renderConstraintsDemo(links, current_y, arena);

        // Navigation
        const nav_y = screen_height - 80.0;
        try links.append(page.createLink("Back to Menu", "/", 200, nav_y, 200, 50));
        try links.append(page.createLink("Font Test", "/font-grid-test", 430, nav_y, 200, 50));
    }

    fn renderBlockLayoutDemo(links: *std.ArrayList(page.Link), start_y: f32, arena: std.mem.Allocator) !void {
        // Title
        try links.append(page.createTextElement("1. BLOCK LAYOUT - Vertical stacking with margin collapse", 200, start_y, 800, 30));

        // Visual demo area
        const demo_x: f32 = 200;
        const demo_y: f32 = start_y + 35;
        const visual_width: f32 = 400;

        // Simulate 3 block elements with margins
        try links.append(page.createLink("Block 1 (margin: 10px)", "#", demo_x, demo_y, 300, 30));
        try links.append(page.createLink("Block 2 (margin: 15px)", "#", demo_x, demo_y + 45, 250, 30));
        try links.append(page.createLink("Block 3 (margin: 8px)", "#", demo_x, demo_y + 85, 350, 30));

        // Code example
        const code_x: f32 = demo_x + visual_width + 50;
        try links.append(page.createTextElement("Code:", code_x, demo_y, 200, 20));

        const code_text = try std.fmt.allocPrint(arena,
            \\const config = BlockLayout.Config{{
            \\    .block_spacing = 0,
            \\    .collapse_margins = true,
            \\    .block_align = .start,
            \\}};
            \\elements[0].margin = Spacing.uniform(10);
            \\elements[1].margin = Spacing.uniform(15);
            \\elements[2].margin = Spacing.uniform(8);
        , .{});

        try links.append(page.createTextElement(code_text, code_x, demo_y + 20, 500, 80));
    }

    fn renderFlexLayoutDemo(links: *std.ArrayList(page.Link), start_y: f32, arena: std.mem.Allocator) !void {
        // Title
        try links.append(page.createTextElement("2. FLEXBOX LAYOUT - Flexible container with alignment", 200, start_y, 800, 30));

        // Visual demo area - show flex row with space-between
        const demo_x: f32 = 200;
        const demo_y: f32 = start_y + 35;
        const visual_width: f32 = 400;

        // Simulate flex items with space-between
        try links.append(page.createLink("Item 1", "#", demo_x, demo_y, 80, 40));
        try links.append(page.createLink("Item 2", "#", demo_x + 160, demo_y, 80, 40));
        try links.append(page.createLink("Item 3", "#", demo_x + 320, demo_y, 80, 40));

        // Show column direction example below
        try links.append(page.createLink("Col 1", "#", demo_x, demo_y + 50, 120, 25));
        try links.append(page.createLink("Col 2", "#", demo_x, demo_y + 80, 120, 25));

        // Code example
        const code_x: f32 = demo_x + visual_width + 50;
        try links.append(page.createTextElement("Code:", code_x, demo_y, 200, 20));

        const code_text = try std.fmt.allocPrint(arena,
            \\// Row direction with space-between
            \\const config = FlexLayout.Config{{
            \\    .direction = .row,
            \\    .justify_content = .space_between,
            \\    .align_items = .center,
            \\    .wrap = .no_wrap,
            \\}};
            \\// Column direction
            \\config.direction = .column;
            \\config.justify_content = .start;
        , .{});

        try links.append(page.createTextElement(code_text, code_x, demo_y + 20, 500, 80));
    }

    fn renderAbsoluteLayoutDemo(links: *std.ArrayList(page.Link), start_y: f32, arena: std.mem.Allocator) !void {
        // Title
        try links.append(page.createTextElement("3. ABSOLUTE POSITIONING - Precise coordinate placement", 200, start_y, 800, 30));

        // Visual demo area
        const demo_x: f32 = 200;
        const demo_y: f32 = start_y + 35;
        const visual_width: f32 = 400;

        // Show positioned elements at specific coordinates
        try links.append(page.createLink("Top-Left", "#", demo_x, demo_y, 80, 30));
        try links.append(page.createLink("Center", "#", demo_x + 160, demo_y + 40, 80, 30));
        try links.append(page.createLink("Bottom-Right", "#", demo_x + 320, demo_y + 80, 80, 30));

        // Code example
        const code_x: f32 = demo_x + visual_width + 50;
        try links.append(page.createTextElement("Code:", code_x, demo_y, 200, 20));

        const code_text = try std.fmt.allocPrint(arena,
            \\elements[0].position = PositionSpec{{
            \\    .top = 0, .left = 0,
            \\}};
            \\elements[1].position = PositionSpec{{
            \\    .top = 40, .left = 160,
            \\}};
            \\elements[2].position = PositionSpec{{
            \\    .bottom = 0, .right = 0,
            \\}};
        , .{});

        try links.append(page.createTextElement(code_text, code_x, demo_y + 20, 500, 80));
    }

    fn renderBoxModelDemo(links: *std.ArrayList(page.Link), start_y: f32, arena: std.mem.Allocator) !void {
        // Title
        try links.append(page.createTextElement("4. BOX MODEL - Content, padding, border, margin areas", 200, start_y, 800, 30));

        // Visual demo - nested boxes to show box model layers
        const demo_x: f32 = 200;
        const demo_y: f32 = start_y + 35;
        const visual_width: f32 = 400;

        // Outer box (margin area)
        try links.append(page.createLink("margin", "#", demo_x, demo_y, 200, 100));
        // Inner boxes to represent the layers
        try links.append(page.createLink("border", "#", demo_x + 10, demo_y + 10, 180, 80));
        try links.append(page.createLink("padding", "#", demo_x + 20, demo_y + 20, 160, 60));
        try links.append(page.createLink("content", "#", demo_x + 30, demo_y + 30, 140, 40));

        // Code example
        const code_x: f32 = demo_x + visual_width + 50;
        try links.append(page.createTextElement("Code:", code_x, demo_y, 200, 20));

        const code_text = try std.fmt.allocPrint(arena,
            \\const box = BoxModel{{
            \\    .position = Vec2{{ .x = 50, .y = 50 }},
            \\    .size = Vec2{{ .x = 140, .y = 40 }},
            \\    .padding = Spacing.uniform(10),
            \\    .border = Spacing.uniform(5), 
            \\    .margin = Spacing.uniform(10),
            \\    .sizing_mode = .content_box,
            \\}};
        , .{});

        try links.append(page.createTextElement(code_text, code_x, demo_y + 20, 500, 80));
    }

    fn renderConstraintsDemo(links: *std.ArrayList(page.Link), start_y: f32, arena: std.mem.Allocator) !void {
        // Title
        try links.append(page.createTextElement("5. CONSTRAINTS - Min/max sizing and aspect ratios", 200, start_y, 800, 30));

        // Visual demo
        const demo_x: f32 = 200;
        const demo_y: f32 = start_y + 35;
        const visual_width: f32 = 400;

        // Show different constraint examples
        try links.append(page.createLink("Min Width: 100px", "#", demo_x, demo_y, 150, 30));
        try links.append(page.createLink("Max Height: 40px", "#", demo_x, demo_y + 40, 200, 35));
        try links.append(page.createLink("Aspect 2:1", "#", demo_x, demo_y + 80, 100, 50));

        // Code example
        const code_x: f32 = demo_x + visual_width + 50;
        try links.append(page.createTextElement("Code:", code_x, demo_y, 200, 20));

        const code_text = try std.fmt.allocPrint(arena,
            \\const constraints = Constraints{{
            \\    .min_width = 100,
            \\    .max_width = 300,
            \\    .min_height = 30,
            \\    .max_height = 40,
            \\    .aspect_ratio = 2.0, // 2:1 ratio
            \\}};
            \\
            \\const constrained_size = 
            \\    constraints.constrain(requested_size);
        , .{});

        try links.append(page.createTextElement(code_text, code_x, demo_y + 20, 500, 80));
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const demo_page: *LayoutDemoPage = @fieldParentPtr("base", self);
        allocator.destroy(demo_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const demo_page = try allocator.create(LayoutDemoPage);
    demo_page.* = .{
        .base = .{
            .vtable = .{
                .init = LayoutDemoPage.init,
                .deinit = LayoutDemoPage.deinit,
                .update = LayoutDemoPage.update,
                .render = LayoutDemoPage.render,
                .destroy = LayoutDemoPage.destroy,
            },
            .path = "/layout-demo",
            .title = "Layout System Demo",
        },
        .initialized = false,
    };
    return &demo_page.base;
}
