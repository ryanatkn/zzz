# HUD System - AI Assistant Guide

> ⚠️ AI slop code and docs, is unstable and full of lies

Transparent overlay system with SvelteKit-style routing. Provides in-game menu navigation without blocking gameplay view.

## Quick Reference

**Activation:** Press backtick (`) to toggle overlay
**Navigation:** Click links, use back/forward buttons, or ESC to close
**Status:** ✓ Fully functional with transparent rendering

## Working Features
- Transparent overlay with alpha blending
- SvelteKit-style routing (`+page.zig`, `+layout.zig`)
- History navigation with back/forward
- Address bar showing current path
- Mouse and keyboard controls
- Layout composition system

## Architecture

```
hud/
├── hud.zig              # Main HUD coordinator
├── router.zig           # SvelteKit-style routing
├── renderer.zig         # Transparent UI rendering
├── reactive_hud.zig     # Reactive HUD integration
├── page.zig             # Page/Layout interfaces
└── constants.zig        # UI constants
```

**Menu pages:** See [src/roots/menu/CLAUDE.md](../roots/menu/CLAUDE.md)

## Key Systems

### Router Pattern
```zig
// Path resolution
"/settings/video" →
  - Load root +layout.zig
  - Load settings/video/+page.zig
  - Render layout wrapping page
```

### Page Interface
```zig
pub fn create(allocator: Allocator) !*page.Page {
    // Return page with vtable
}
```

### Transparency
- Alpha blending for overlay effect
- Game world visible underneath
- Semi-transparent backgrounds

## Common Modifications

### Adding HUD Elements
1. Create component in `hud/`
2. Add to HUD.update() and render()
3. Use reactive patterns if needed
4. Test transparency with game running

### Modifying Router
1. Edit `router.zig` for new routes
2. Import page modules
3. Add path matching logic
4. Test navigation flow

### Styling Changes
1. Adjust alpha in `renderer.zig`
2. Modify colors in render functions
3. Update positioning constants
4. Test visibility over game

## Technical Notes

- Fixed 1920x1080 screen dimensions
- Manual route registration required
- Single root layout (no nesting)
- Basic ASCII text rendering only
- Alpha blending for transparency

## Related Documentation

- [Menu System](../roots/menu/CLAUDE.md) - Page implementations
- [Reactive UI](../lib/CLAUDE.md) - UI components
- [Architecture](./DESIGN.md) - System design

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