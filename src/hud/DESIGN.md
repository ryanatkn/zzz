# Browser System Design

## Overview

The browser system provides an in-game overlay menu with SvelteKit-style filesystem-based routing. It renders over the game world (which continues running) and allows navigation between different "pages" for settings, stats, and other UI.

## Current Implementation Status

### ✅ Completed
- SvelteKit-style routing with `+page.zig` and `+layout.zig` files
- Basic layout system with RenderSlot composition
- Navigation history with back/forward support
- Address bar showing current path
- Mouse and keyboard navigation
- Rectangle-based UI rendering
- Simple text rendering using procedural rectangles
- "Back to Menu" quick navigation on all pages

### 🚧 Simplified/In Progress
- Layout composition (only root layout active currently)
- Dynamic routes (not implemented, would need build-time generation)
- Form controls (sliders, checkboxes not yet implemented)

### ❌ Not Implemented
- Transitions between pages
- State persistence
- Error boundaries (`+error.zig`)
- Prefetching
- Full font support

## Architecture

### Core Components

- **browser.zig** - Main browser state and coordination
- **router.zig** - Path resolution and page/layout loading
- **simple_history.zig** - Fixed-buffer navigation history (replaces history.zig)
- **renderer.zig** - UI rendering with rectangles and text
- **page.zig** - Page, Layout, and RenderSlot interfaces

## Routing Conventions (SvelteKit-style)

### Current File Structure

```
src/routes/
├── +layout.zig              # Root layout (wraps all pages)
├── +page.zig                # Home page (/)
├── settings/
│   ├── +page.zig           # Settings index (/settings)
│   ├── video/
│   │   └── +page.zig       # Video settings (/settings/video)
│   └── audio/
│       └── +page.zig       # Audio settings (/settings/audio)
└── stats/
    └── +page.zig           # Statistics (/stats)
```

### Path Resolution (Current Implementation)

1. Router receives path like `/settings/video`
2. Manual route matching in router.zig
3. Loads root layout (`+layout.zig`)
4. Loads target page (`settings/video/+page.zig`)
5. Renders page (layout composition simplified for now)

### Future: Dynamic Routes

When implemented, would support:
- `[param]` folders match single segments: `/inventory/[item]` → `/inventory/sword`
- `[...rest]` matches remaining path: `/docs/[...path]` → `/docs/guides/intro`
- Parameters passed to page via `params` field

## Current Page Interface

```zig
// +page.zig
const std = @import("std");
const page = @import("../../browser/page.zig");

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
        // Add links for navigation
        try links.append(page.createLink(
            "Settings",
            "/settings",
            x, y, width, height
        ));
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    // Factory function to create page instance
}
```

## Current Layout Interface

```zig
// +layout.zig
const std = @import("std");
const page = @import("../browser/page.zig");

const RootLayout = struct {
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
        // Render layout chrome (header, etc.)
        
        // Render child content
        try slot.render(links);
        
        // Render layout footer
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Layout {
    // Factory function to create layout instance
}
```

## Navigation

### Current Implementation

```zig
// Router handles navigation
try browser.router.navigate("/settings/video");

// History provides back/forward
browser.history.back();
browser.history.forward();
```

### User Interactions
- Click on rendered links
- Back/forward buttons in navigation bar
- Mouse X1/X2 buttons for back/forward
- Backtick (`) key to open browser
- ESC to close browser

## Rendering System

### Current Approach
- Rectangle-based rendering using GPU
- Procedural text using small rectangles
- Links rendered as clickable rectangles with hover states

### BrowserRenderer Methods
```zig
renderOverlay()      // Semi-transparent background
renderNavigationBar() // Back/forward buttons and address bar
renderPage()         // Page content via links
renderLinks()        // Interactive link buttons
drawSimpleText()     // Basic ASCII text rendering
drawChar()           // Individual character rendering
```

## State Management

### Current Limitations
- No persistent state between sessions
- Pages recreated on each navigation
- History limited to path strings only

### Future Enhancements
- Page state preservation during navigation
- Global state store accessible from all pages
- Settings persistence to disk

## Implementation Notes

### Technical Decisions

1. **Fixed Buffers for History** - Avoids allocator issues with SimpleHistory
2. **Manual Route Registration** - Due to Zig's compile-time constraints
3. **Simplified Layout Composition** - Full nesting deferred for simplicity
4. **Procedural Text** - No font files needed, fits game's aesthetic

### Known Issues

1. **Hardcoded Screen Size** - Using 1920x1080 constants
2. **Limited Character Set** - Only basic ASCII letters implemented
3. **No Form Controls** - Text and buttons only currently

### Performance Considerations

- Pages loaded at compile-time (no runtime loading)
- Minimal allocations using fixed buffers where possible
- Rectangle batching for efficient GPU rendering
- Game continues running underneath overlay

## Future Roadmap

### Phase 1: Polish Current Implementation ✅
- [x] Complete SvelteKit migration
- [x] Add "Back to Menu" navigation
- [x] Document current state

### Phase 2: Enhanced Features
- [ ] Add number and symbol rendering
- [ ] Implement nested layout composition
- [ ] Add transition effects
- [ ] Create settings layout for shared UI

### Phase 3: Advanced Controls
- [ ] Slider controls for settings
- [ ] Checkbox/toggle controls
- [ ] Text input fields
- [ ] Dropdown menus

### Phase 4: Dynamic Features
- [ ] Build-time route generation
- [ ] Dynamic route parameters
- [ ] Error boundaries
- [ ] State persistence

## Testing Approach

Routes can be tested independently:
```zig
test "navigation works" {
    var router = Router.init(allocator);
    defer router.deinit();
    
    try router.navigate("/settings");
    try testing.expect(router.getCurrentPage() != null);
}
```

## Usage Guidelines

1. **Creating New Pages**: Add `+page.zig` in appropriate directory
2. **Adding Layouts**: Create `+layout.zig` to wrap child pages
3. **Navigation Links**: Use `page.createLink()` in render functions
4. **Quick Navigation**: Include "Back to Menu" on all non-root pages
5. **Path Convention**: Use lowercase, hyphenated paths (`/my-page`)