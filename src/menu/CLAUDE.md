# Menu System - AI Assistant Guide

> ⚠️ AI slop code and docs, is unstable and full of lies

SvelteKit-style routing system for in-game menus. Pages are defined by `+page.zig` files with filesystem-based routing.

## Quick Reference

**Pattern:** SvelteKit-style filesystem routing
**Activation:** Press backtick (`) in game
**Navigation:** Click links or use back/forward buttons

## Directory Structure

```
menu/
├── +layout.zig          # Root layout wrapper
├── +page.zig            # Home page (/)
├── settings/            # Settings submenu
│   ├── +page.zig        # Settings index
│   ├── video/+page.zig  # Video settings
│   ├── audio/+page.zig  # Audio settings  
│   └── fonts/+page.zig  # Font settings
├── stats/+page.zig      # Game statistics
├── character/+page.zig  # Character sheet
├── font_grid_test/      # Font testing
└── vector_test/         # Vector graphics test
```

## Routing Convention

### Path Resolution
- URL path maps directly to filesystem structure
- `/` → `src/routes/+page.zig`
- `/settings` → `src/routes/settings/+page.zig`
- `/settings/video` → `src/routes/settings/video/+page.zig`

### File Naming
- `+page.zig` - Required page component
- `+layout.zig` - Optional layout wrapper (inherited by children)
- Future: `+error.zig` - Error boundary (not yet implemented)

## Page Structure

Every `+page.zig` must export a `create` function that returns a Page pointer:

```zig
const std = @import("std");
const page = @import("../browser/page.zig");

const MyPage = struct {
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
        
        // Define layout constants
        const screen_width = 1920.0;
        const screen_height = 1080.0;
        const center_x = screen_width / 2.0;
        const start_y = screen_height * 0.3;
        const link_height = 50.0;
        const link_width = 300.0;
        const link_spacing = 20.0;
        
        // Add navigation links
        try links.append(page.createLink(
            "Link Text",
            "/target/path",
            center_x - link_width / 2.0,
            start_y,
            link_width,
            link_height
        ));
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const my_page = try allocator.create(MyPage);
    my_page.* = .{
        .base = .{
            .vtable = .{
                .init = MyPage.init,
                .deinit = MyPage.deinit,
                .update = MyPage.update,
                .render = MyPage.render,
            },
            .path = "/my-path",
            .title = "My Page Title",
        },
    };
    return &my_page.base;
}
```

## Layout Structure

Layouts wrap child pages with shared UI:

```zig
const std = @import("std");
const page = @import("../browser/page.zig");

const MyLayout = struct {
    base: page.Layout,
    
    fn init(self: *page.Layout, allocator: std.mem.Allocator) !void {
        _ = self;
        _ = allocator;
    }
    
    fn deinit(self: *page.Layout, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
    
    fn render(self: *const page.Layout, links: *std.ArrayList(page.Link), slot: *const page.RenderSlot) !void {
        _ = self;
        
        // Render header/navigation
        // ...
        
        // Render child content
        try slot.render(links);
        
        // Render footer
        // ...
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Layout {
    const layout = try allocator.create(MyLayout);
    layout.* = .{
        .base = .{
            .vtable = .{
                .init = MyLayout.init,
                .deinit = MyLayout.deinit,
                .render = MyLayout.render,
            },
            .path = "/",
        },
    };
    return &layout.base;
}
```

## Navigation Patterns

### Standard Navigation Links
All non-root pages should include a "Back to Menu" button:
```zig
try links.append(page.createLink(
    "Back to Menu",
    "/",
    center_x - link_width / 2.0,
    start_y + (link_height + link_spacing) * 5,
    link_width,
    link_height
));
```

### Hierarchical Navigation
Settings pages include both parent and root navigation:
```zig
// Back to parent
try links.append(page.createLink(
    "Back to Settings",
    "/settings",
    x, y, width, height
));

// Back to root
try links.append(page.createLink(
    "Back to Menu",
    "/",
    x, y2, width, height
));
```

## Adding New Pages

### Step 1: Create Directory Structure
```bash
mkdir -p src/routes/inventory
```

### Step 2: Create +page.zig
```zig
// src/routes/inventory/+page.zig
const std = @import("std");
const page = @import("../../browser/page.zig");

// ... page implementation ...

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    // ... create and return page ...
}
```

### Step 3: Register Route in Router
Edit `src/browser/router.zig` and add:
```zig
} else if (std.mem.eql(u8, path, "/inventory")) {
    const layout = try root_layout.create(self.allocator);
    try layout.init(self.allocator);
    try self.current_layouts.append(layout);
    
    self.current_page = try inventory_page.create(self.allocator);
```

Don't forget to import the page at the top:
```zig
const inventory_page = @import("../routes/inventory/+page.zig");
```

## Current Pages

### Home (`/`)
- Main menu with links to all sections
- Entry point when browser opens

### Settings (`/settings`)
- Settings submenu
- Links to video and audio settings
- Back to menu button

### Video Settings (`/settings/video`)
- Placeholder for video configuration
- Back to settings and menu buttons

### Audio Settings (`/settings/audio`)
- Placeholder for audio configuration
- Back to settings and menu buttons

### Statistics (`/stats`)
- Placeholder for game statistics
- Back to menu button

## Key Patterns

### Page Creation
```zig
pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const my_page = try allocator.create(MyPage);
    my_page.* = .{
        .base = .{
            .vtable = .{ ... },
            .path = "/my-path",
            .title = "My Page",
        },
    };
    return &my_page.base;
}
```

### Adding Links
```zig
try links.append(page.createLink(
    "Link Text",
    "/target/path",
    x, y, width, height
));
```

## Common Tasks

### Adding a New Page
1. Create directory: `mkdir -p menu/newpage`
2. Create `+page.zig` with Page interface
3. Register in `src/hud/router.zig`
4. Add navigation links from parent pages

### Modifying Layout
1. Edit `+layout.zig` for shared UI
2. Use slot.render() to inject child content
3. Test with all child pages

### Testing Pages
```bash
zig build run
# Press ` to open menu
# Navigate to test page
```

## Technical Notes

- Manual route registration (no auto-discovery)
- Compile-time imports required
- Fixed 1920x1080 screen dimensions
- No dynamic routes or parameters
- Single root layout (no nesting)

## Related Documentation

- [HUD System](../hud/CLAUDE.md) - Browser implementation
- [Reactive UI](../lib/CLAUDE.md) - UI components
- [Development Workflow](../../docs/development-workflow.md)