# Routes Directory - SvelteKit-Style Pages

## Overview

This directory contains all browser system pages following SvelteKit conventions. Each route is defined by `+page.zig` files, with optional `+layout.zig` files for shared UI.

## Directory Structure

```
src/routes/
├── +layout.zig          # Root layout - wraps all pages
├── +page.zig            # Home page (/)
├── settings/
│   ├── +page.zig        # Settings menu (/settings)
│   ├── video/
│   │   └── +page.zig    # Video settings (/settings/video)
│   └── audio/
│       └── +page.zig    # Audio settings (/settings/audio)
└── stats/
    └── +page.zig        # Game statistics (/stats)
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

## Limitations

### Current Implementation
- Manual route registration required (no automatic discovery)
- Only root layout active (nested layouts simplified)
- No dynamic routes (`[param]` folders not supported)
- No error boundaries
- No state persistence between navigations

### Technical Constraints
- Zig requires compile-time imports (no dynamic loading)
- Types must be known at compile-time (no runtime reflection)
- Fixed screen dimensions (1920x1080)

## Best Practices

1. **Always include "Back to Menu"** - Users should be able to return home quickly
2. **Use consistent positioning** - Center links horizontally, space vertically
3. **Keep pages simple** - Focus on navigation, not complex UI
4. **Test navigation paths** - Ensure all links work bidirectionally
5. **Follow naming conventions** - Use lowercase, hyphenated paths

## Future Enhancements

### Planned Features
- Nested layout composition
- Build-time route generation
- Dynamic route parameters
- Form controls (sliders, checkboxes)
- State persistence
- Transition effects

### Potential Pages
- `/inventory` - Item management
- `/map` - World map viewer
- `/achievements` - Achievement tracking
- `/controls` - Key binding configuration
- `/about` - Game information