# Browser System Design

## Overview

The browser system provides an in-game overlay menu with SvelteKit-style filesystem-based routing. It renders over the game world (which continues running) and allows navigation between different "pages" for settings, stats, and other UI.

## Architecture

### Core Components

- **browser.zig** - Main browser state and coordination
- **router.zig** - Path resolution and page loading
- **history.zig** - Navigation history stack with back/forward
- **renderer.zig** - UI rendering over game world
- **page.zig** - Page interface and helpers

## Routing Conventions (SvelteKit-style)

### File Structure

Every route is a directory containing:
- **+page.zig** - The page component (required)
- **+layout.zig** - Layout wrapper (optional, inherited by child routes)
- **+error.zig** - Error boundary (optional)

### Route Examples

```
src/routes/
├── +layout.zig              # Root layout (wraps all pages)
├── +page.zig                # Home page (/)
├── settings/
│   ├── +layout.zig         # Settings layout (/settings)
│   ├── +page.zig           # Settings index (/settings)
│   ├── video/
│   │   └── +page.zig       # Video settings (/settings/video)
│   └── audio/
│       └── +page.zig       # Audio settings (/settings/audio)
├── stats/
│   └── +page.zig           # Statistics (/stats)
└── inventory/
    ├── +page.zig           # Inventory (/inventory)
    └── [item]/             # Dynamic route
        └── +page.zig       # Item details (/inventory/sword)
```

### Path Resolution

1. Router receives path like `/settings/video`
2. Looks for `src/routes/settings/video/+page.zig`
3. Collects layouts from root down: `/+layout.zig`, `/settings/+layout.zig`
4. Renders page within nested layouts

### Dynamic Routes

- `[param]` folders match single segments: `/inventory/[item]` → `/inventory/sword`
- `[...rest]` matches remaining path: `/docs/[...path]` → `/docs/guides/intro`
- Parameters passed to page via `params` field

## Page Interface

```zig
// +page.zig
const std = @import("std");
const browser = @import("browser");

pub const Page = struct {
    // Page metadata
    pub const meta = .{
        .title = "Settings",
        .preload = true,  // Load before navigation completes
    };
    
    // Instance data
    data: PageData,
    
    // Lifecycle hooks
    pub fn load(params: browser.Params, parent: ?*anyopaque) !PageData {
        // Load data before rendering
    }
    
    pub fn init(self: *Page, data: PageData) !void {
        // Initialize page instance
    }
    
    pub fn deinit(self: *Page) void {
        // Cleanup
    }
    
    pub fn update(self: *Page, dt: f32) void {
        // Update logic (60 FPS)
    }
    
    pub fn render(self: *const Page, ctx: *browser.RenderContext) !void {
        // Render page content
        try ctx.link("Back", "/");
        try ctx.text("Current Settings");
    }
    
    pub fn handleEvent(self: *Page, event: browser.Event) !bool {
        // Handle page-specific events
        return false; // Return true if handled
    }
};
```

## Layout Interface

```zig
// +layout.zig
pub const Layout = struct {
    pub const meta = .{
        .reset = false,  // Don't reset on navigation within layout
    };
    
    children: *browser.Slot,
    
    pub fn init(self: *Layout) !void {
        // Setup layout
    }
    
    pub fn render(self: *const Layout, ctx: *browser.RenderContext) !void {
        // Render layout chrome
        try ctx.text("Game Menu");
        
        // Render child page/layout
        try self.children.render(ctx);
        
        // Render footer
        try ctx.text("Press ESC to close");
    }
};
```

## Navigation

### Programmatic Navigation

```zig
// Navigate to new page
try browser.goto("/settings/video");

// Navigate with replace (no history entry)
try browser.goto("/", .{ .replace = true });

// Go back/forward
browser.back();
browser.forward();
```

### Link Rendering

```zig
// In render function
try ctx.link("Settings", "/settings");

// With styling
try ctx.link("Settings", "/settings", .{
    .class = "primary",
    .prefetch = true,
});
```

## Rendering Context

The `RenderContext` provides UI primitives that work with the procedural renderer:

```zig
pub const RenderContext = struct {
    // Layout
    fn beginRow(self: *RenderContext) void;
    fn beginColumn(self: *RenderContext) void;
    fn spacing(self: *RenderContext, pixels: f32) void;
    
    // Elements
    fn text(self: *RenderContext, str: []const u8) !void;
    fn link(self: *RenderContext, label: []const u8, path: []const u8) !void;
    fn button(self: *RenderContext, label: []const u8) !bool;
    fn slider(self: *RenderContext, value: *f32, min: f32, max: f32) !bool;
    fn checkbox(self: *RenderContext, value: *bool) !bool;
    
    // Shapes (procedural)
    fn circle(self: *RenderContext, radius: f32, color: Color) void;
    fn rect(self: *RenderContext, size: Vec2, color: Color) void;
};
```

## State Management

### Global State

Browser maintains global state accessible from all pages:

```zig
browser.state.get("username");
browser.state.set("volume", 0.8);
```

### Page State

Pages can maintain local state that persists during navigation:

```zig
// Page returns to same state when navigating back
pub fn saveState(self: *Page) ![]const u8 {
    return try serialize(self.data);
}

pub fn restoreState(self: *Page, state: []const u8) !void {
    self.data = try deserialize(state);
}
```

## Hot Keys

Pages can register hotkeys active only when visible:

```zig
pub fn init(self: *Page) !void {
    try browser.registerHotkey(.{ .key = .S, .ctrl = true }, "save");
}

pub fn handleEvent(self: *Page, event: browser.Event) !bool {
    switch (event) {
        .hotkey => |h| if (std.mem.eql(u8, h, "save")) {
            try self.save();
            return true;
        },
        else => {},
    }
    return false;
}
```

## Transitions

Simple fade/slide transitions between pages:

```zig
pub const meta = .{
    .transition = .{
        .in = .{ .fade = 150 },   // 150ms fade in
        .out = .{ .slide_left = 100 }, // 100ms slide out
    },
};
```

## Error Handling

Each route can have an `+error.zig` for error boundaries:

```zig
// +error.zig
pub const ErrorPage = struct {
    pub fn render(self: *const ErrorPage, ctx: *browser.RenderContext, err: anyerror) !void {
        try ctx.text("Error occurred:");
        try ctx.text(@errorName(err));
        try ctx.link("Go Home", "/");
    }
};
```

## Implementation Notes

### Current Limitations

1. **No text rendering** - Using circles/shapes as placeholders
2. **No rectangle shader** - Need to add rectangle rendering to GPU pipeline
3. **History disabled** - Allocator issue with string duplication
4. **No dynamic routes** - Static routing only for now
5. **No transitions** - Instant page changes

### Future Enhancements

1. **Text rendering** - Distance field fonts or bitmap fonts
2. **Form controls** - Input fields, dropdowns, etc.
3. **Nested routers** - Multiple router instances for modals
4. **Prefetching** - Load adjacent pages in background
5. **Persistence** - Save/load menu state to disk

### Performance Considerations

- Pages are lazily loaded (comptime imports)
- Layouts cached and reused during navigation
- Render calls batched to minimize GPU state changes
- Event handling stops at first handler (no bubbling)

## Usage Example

```zig
// Create a new page
// src/routes/inventory/+page.zig

const std = @import("std");
const browser = @import("../../../browser/browser.zig");

pub const Page = struct {
    items: []const Item,
    selected: ?usize,
    
    pub const meta = .{
        .title = "Inventory",
    };
    
    pub fn init(self: *Page) !void {
        self.items = try loadItems();
        self.selected = null;
    }
    
    pub fn render(self: *const Page, ctx: *browser.RenderContext) !void {
        try ctx.text("Inventory");
        
        ctx.beginColumn();
        defer ctx.end();
        
        for (self.items, 0..) |item, i| {
            const selected = self.selected == i;
            if (try ctx.button(item.name)) {
                self.selected = i;
            }
        }
        
        if (self.selected) |idx| {
            ctx.spacing(20);
            try ctx.text(self.items[idx].description);
            if (try ctx.button("Use")) {
                try useItem(self.items[idx]);
            }
        }
    }
};
```

## Testing

Routes can be tested in isolation:

```zig
test "settings page renders" {
    var page = try Page.init(testing.allocator);
    defer page.deinit();
    
    var ctx = TestRenderContext.init();
    try page.render(&ctx);
    
    try testing.expect(ctx.hasLink("/"));
    try testing.expect(ctx.hasText("Settings"));
}
```