# Browser System - Implementation Guide

## Current State

**Working:**
- ✅ Overlay rendering with rectangles and circles
- ✅ Page routing to static paths
- ✅ Mouse click navigation between pages
- ✅ Backtick (`) key toggles menu
- ✅ ESC key closes menu
- ✅ Page interface with init/deinit/update/render lifecycle
- ✅ History navigation with back/forward
- ✅ Address bar showing current path
- ✅ Simple text rendering (basic ASCII letters)
- ✅ Button labels and link text

**Fixed:**
- ✅ History navigation (using SimpleHistory with fixed buffers)
- ✅ Back/forward mouse buttons working
- ✅ Navigation bar buttons working
- ✅ Rectangle rendering via gpu.drawRect

**Missing:**
- SvelteKit-style routing (`+page.zig`, `+layout.zig`)
- Dynamic routes (`[param]` folders)
- Form controls (inputs, sliders, checkboxes)
- Transitions between pages
- State persistence
- Full font support (only basic letters implemented)

## File Structure

```
src/browser/
├── browser.zig      # Main coordinator, event routing
├── router.zig       # Static path → page mapping
├── history.zig      # Navigation stack (BROKEN)
├── renderer.zig     # UI rendering (circles only)
├── page.zig         # Page interface definition
├── DESIGN.md        # Target architecture (SvelteKit-style)
└── CLAUDE.md        # This file

src/routes/          # Current: simple .zig files
                     # Target: directories with +page.zig
```

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

## Migration to SvelteKit Style

**Current router.zig approach:**
```zig
if (std.mem.eql(u8, path, "/settings")) {
    self.current_page = try settings_page.create(self.allocator);
}
```

**Target approach (unknown implementation):**
- How to resolve `/settings/video` → `src/routes/settings/video/+page.zig`?
- How to collect parent layouts during resolution?
- How to handle dynamic routes at compile time?
- How to lazy-load pages (avoid importing all routes)?

## Usage

```bash
# Run game
zig build run

# Test browser
# 1. Press ` (backtick) to open
# 2. Click circles to navigate
# 3. Press ESC to close
```

## Don't Touch

- `game.zig` integration (working)
- `controls.zig` event routing (working)  
- `main.zig` initialization (working)

## Next Steps

1. Fix history allocator issue (try workarounds)
2. Add rectangle rendering support
3. Implement SvelteKit-style router
4. Add basic text rendering (even ASCII art)

## Unknown Territories

- **Text Rendering**: No font system in codebase. Options?
  - Distance field fonts (complex)
  - Bitmap fonts (need texture support)
  - Procedural 7-segment display (simple, fits aesthetic)

- **Dynamic Routing**: Zig has no runtime reflection
  - Comptime route table generation?
  - Build step to scan routes/ directory?
  - Manual route registration?

- **Layout Composition**: How to wrap pages in layouts?
  - Comptime layout chain building?
  - Runtime slot rendering?
  - Multiple render passes?