# Browser System - Implementation Guide

## Current State

**Working:**
- ✅ Overlay rendering with rectangles
- ✅ Page routing to static paths
- ✅ Mouse click navigation between pages
- ✅ Backtick (`) key toggles menu
- ✅ ESC key closes menu
- ✅ Page interface with init/deinit/update/render lifecycle
- ✅ History navigation with back/forward
- ✅ Address bar showing current path
- ✅ Simple text rendering (basic ASCII letters)
- ✅ Button labels and link text
- ✅ SvelteKit-style routing (`+page.zig`, `+layout.zig`)
- ✅ Layout system with composition support
- ✅ "Back to Menu" buttons on all non-root pages

**Fixed:**
- ✅ History navigation (using SimpleHistory with fixed buffers)
- ✅ Back/forward mouse buttons working
- ✅ Navigation bar buttons working
- ✅ Rectangle rendering via gpu.drawRect
- ✅ SvelteKit migration complete

**Missing:**
- Dynamic routes (`[param]` folders)
- Form controls (inputs, sliders, checkboxes)
- Transitions between pages
- State persistence
- Full font support (only basic letters implemented)
- Nested layout composition (simplified for now)

## File Structure

```
src/browser/
├── browser.zig          # Main coordinator, event routing
├── router.zig           # SvelteKit-style routing with layout support
├── history.zig          # Navigation stack (deprecated, use simple_history)
├── simple_history.zig   # Fixed-buffer history implementation
├── renderer.zig         # UI rendering with rectangles and text
├── page.zig             # Page, Layout, and RenderSlot interfaces
├── DESIGN.md            # Architecture documentation
└── CLAUDE.md            # This file

src/routes/              # SvelteKit-style convention
├── +layout.zig          # Root layout (wraps all pages)
├── +page.zig            # Home page (/)
├── settings/
│   ├── +page.zig        # Settings index (/settings)
│   ├── video/
│   │   └── +page.zig    # Video settings (/settings/video)
│   └── audio/
│       └── +page.zig    # Audio settings (/settings/audio)
└── stats/
    └── +page.zig        # Statistics (/stats)
```

## SvelteKit Migration ✅ COMPLETE

The migration to SvelteKit-style routing is now complete:

**What's Implemented:**
- `+page.zig` convention for all pages
- `+layout.zig` for root layout (extensible to nested layouts)
- Layout and RenderSlot types in page.zig
- Router loads layouts alongside pages
- All pages follow new structure

**How It Works:**
```zig
// Router resolves path to page and collects layouts
"/settings/video" → 
  - Load: root +layout.zig
  - Load: settings/video/+page.zig
  - Render: layout wraps page via RenderSlot

// Each page exports a create function
pub fn create(allocator: std.mem.Allocator) !*page.Page

// Layouts can wrap content via slots
pub fn render(self: *const Layout, links: *ArrayList(Link), slot: *const RenderSlot) !void
```

**Current Limitations:**
- Nested layouts simplified (only root layout active)
- No dynamic routes yet (would need build-time generation)
- Manual route registration in router.zig

## Known Issues

1. **Hardcoded Screen Size**: Using 1920x1080 constants
   - Need: Get actual size from renderer
   - Blocked: Renderer doesn't expose screen_size

2. **Limited Text Rendering**: Only basic ASCII letters implemented
   - Missing: Numbers, special characters, lowercase variants
   - Current: Using simple rectangle-based letter drawing

## Quick Tasks

**Add More Text Characters:**
```zig
// In drawChar() add cases for:
'0'-'9' => // Numbers
'x', 'y', 'z' => // Missing letters
'(', ')', '[', ']' => // Brackets
```

**Get Screen Size:**
```zig
// Need in renderer.zig:
pub fn getScreenSize(self: *Renderer) Vec2 {
    return .{
        .x = self.gpu.screen_width,
        .y = self.gpu.screen_height
    };
}
```

## Usage

```bash
# Run game
zig build run

# Test browser
# 1. Press ` (backtick) to open menu
# 2. Click buttons to navigate
# 3. Use back/forward buttons or mouse buttons
# 4. Press ESC to close
```

## Navigation Features

- **Address Bar**: Shows current path (e.g., `/settings/video`)
- **Back/Forward**: Browser-style navigation with history
- **Mouse Buttons**: X1/X2 buttons for back/forward
- **Direct Links**: "Back to Menu" on all pages for quick return
- **Breadcrumb Navigation**: Settings pages have "Back to Settings" option

## Don't Touch

- `game.zig` integration (working)
- `controls.zig` event routing (working)  
- `main.zig` initialization (working)
- `simple_history.zig` fixed-buffer implementation (working)

## Next Steps

1. Add nested layout support (settings layout)
2. Implement form controls (sliders, checkboxes)
3. Add number/symbol rendering to text system
4. Consider dynamic route generation at build time
5. Add transition effects between pages

## Technical Notes

- **Layout Composition**: Currently simplified to root layout only
- **Route Registration**: Manual in router.zig due to Zig's compile-time constraints
- **Memory Management**: Fixed buffers for history to avoid allocator issues
- **Text Rendering**: Procedural using rectangles, no font files needed