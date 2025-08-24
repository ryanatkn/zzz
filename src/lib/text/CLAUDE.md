# Text System Domain - AI Assistant Guide

## Domain Definition

**Text System Domain:** GPU-focused text rendering, layout, and optimization for strings and paragraphs.

### Core Responsibilities
- **GPU Text Rendering:** SDL3 GPU pipelines for drawing text
- **Text Layout:** Multi-line text, word wrapping, alignment
- **String Processing:** Handle full strings and paragraphs (not individual glyphs)
- **Text Caching:** Persistent texture caching for performance optimization
- **Rendering Methods:** SDF, bitmap, oversampled anti-aliasing
- **Screen Integration:** Positioning, alignment, screen coordinate mapping

### Domain Boundaries

**✅ What text/ SHOULD do:**
- Render complete strings to GPU textures
- Handle text layout and multi-line formatting
- Manage text caching and optimization
- Provide SDF and bitmap rendering modes
- Handle screen positioning and alignment
- GPU texture operations and shaders

**❌ What text/ should NOT do:**
- Parse TTF files or load fonts
- Rasterize individual glyphs
- Font metrics calculation
- Font loading or management

**📡 Interface with font/ domain:**
```
text/ requests → individual glyph bitmaps from font/
font/ provides → rasterized glyph data for text/ to compose
```

## Architecture Overview

### Core Components

- **`renderer.zig`** - Main text rendering pipeline with GPU integration
- **`cache.zig`** - Persistent texture caching system
- **`layout.zig`** - Text layout and multi-line formatting
- **`primitives.zig`** - Core text rendering methods (bitmap, SDF, oversampled)
- **`sdf_renderer.zig`** - Signed Distance Field text rendering
- **`alignment.zig`** - Text positioning and alignment utilities
- **`multi_renderer.zig`** - Comparison grid for testing different methods

### Rendering Pipeline

```
String Input → Font Glyphs → Text Layout → GPU Texture → Screen Rendering
     ↓              ↓             ↓            ↓            ↓
[text/layout] [font/manager] [text/layout] [text/cache] [text/renderer]
```

## Key Technical Concepts

### Rendering Methods

**When to use each method:**
- **Bitmap:** Font size < 16px, high-frequency updates, simple text
- **SDF:** Font size >= 16px, scalable text, effects needed
- **Oversampled:** High-quality static text, when bitmap isn't sharp enough
- **Cached:** Stable text that changes <5 times per second

### Caching Strategies

**Immediate Mode:**
- Text changes >10 times per second
- Dynamic content (coordinates, counters)
- Create → Use → Destroy each frame

**Persistent Mode:**
- Text changes <5 times per second  
- Static content (UI labels, FPS display)
- Create once → Reuse until changed

### GPU Integration

**Shader Pipeline:**
- Vertex shader: Procedural quad generation (no vertex buffers)
- Fragment shader: Text texture sampling with color application
- Uniforms: Screen size, position, color, SDF parameters

**Texture Management:**
- RGBA format for colored text
- Alpha channel for transparency
- Proper GPU memory lifecycle

## Common Tasks

### Re-enable Debug Text
```zig
// For FPS display (updates 2-3 times/sec) - use persistent mode
try text_renderer.queuePersistentText("FPS: 60", position, font_manager, .sans, 14.0, Color.white());

// For coordinates (updates 60 times/sec) - use immediate mode
const coord_texture = try text_primitives.createTextTexture(coord_text, 12.0, .bitmap, Color.yellow());
text_renderer.queueTextTexture(coord_texture.texture, position, coord_texture.width, coord_texture.height, Color.yellow());
```

### Choose Rendering Method
```zig
// Small UI text
const method = if (font_size < 16.0) .bitmap else .sdf;

// High-quality static text
const method = if (is_static_text) .oversampled_2x else .bitmap;

// Frequently changing text
const method = if (changes_per_second > 10) .bitmap else .cached;
```

### Performance Optimization
```zig
// Batch multiple text draws
text_renderer.queuePersistentText("Label 1", pos1, font_manager, .sans, 14.0, color);
text_renderer.queuePersistentText("Label 2", pos2, font_manager, .sans, 14.0, color);
try text_renderer.drawQueuedText(cmd_buffer, render_pass); // Single draw call
```

## Integration Patterns

### With Font System
```zig
// Correct: Text requests glyphs from font system
const glyph_texture = try font_manager.rasterizeGlyph('A', font_size);
// Then text system composes glyphs into strings

// Incorrect: Font system doing text layout
// Font should not know about multi-character text
```

### With Game Systems
```zig
// HUD text - persistent mode
const hud_renderer = @import("../text/renderer.zig");
try hud_renderer.queuePersistentText("Health: 100", pos, font_mgr, .sans, 16.0, Color.red());

// Debug coordinates - immediate mode  
const coord_text = try std.fmt.bufPrint(buffer, "({d}, {d})", .{player.x, player.y});
const coord_texture = try text_primitives.createTextTexture(coord_text, 12.0, .bitmap, Color.white());
```

## Current Migration Status

### ✅ Working Systems
- Text rendering pipeline (renderer.zig)
- Persistent caching system (cache.zig)
- Multiple rendering methods (primitives.zig)
- SDF rendering capability (sdf_renderer.zig)

### 🔄 In Progress
- Moving `renderTextToTexture()` from font/ domain to text/ domain
- Integration with layout engine for proper text composition

### 📋 Needed
- Re-enable debug text displays (FPS, coordinates, AI mode)
- Proper integration between font glyphs and text composition
- Performance optimization guidelines implementation

## Performance Guidelines

### Memory Management
- Use persistent caching for stable text (UI labels, FPS)
- Use immediate mode for dynamic text (coordinates, counters)
- Batch multiple text draws together
- Release textures when no longer needed

### GPU Optimization
- Minimize texture switches
- Use appropriate rendering method for content type
- Batch similar text properties together
- Avoid unnecessary GPU texture uploads

### Cache Efficiency
- Cache hit rate should be >90% for persistent text
- Cache misses indicate improper mode selection
- Monitor cache memory usage
- Clear cache when switching scenes/contexts

## Testing

```bash
# Test text rendering
zig build test -Dtest-filter="text"

# Test specific rendering methods
zig build test -Dtest-filter="text_primitives"

# Visual text comparison
zig build run  # Navigate to text comparison grid in menu
```

## Common Pitfalls

- **Don't** implement font parsing in text domain
- **Don't** rasterize individual glyphs in text domain
- **Don't** use immediate mode for stable text (causes flashing)
- **Don't** use persistent mode for rapidly changing text (causes cache bloat)
- **Don't** forget to handle GPU texture lifecycle
- **Don't** mix bitmap and SDF without considering performance

## Debug Tools

### Text Comparison Grid
```zig
// Available in multi_renderer.zig
var multi_renderer = MultiTextRenderer.init(allocator, device, text_renderer, font_manager);
try multi_renderer.createComparisonGrid("Test", font_sizes, start_pos, spacing);
```

### Cache Statistics
```zig
const cache_stats = persistent_text_system.getStatistics();
std.log.info("Cache hit rate: {d}%", .{cache_stats.hit_rate * 100});
```

### Rendering Performance
```zig
const text_stats = try text_primitives.calculateTextStats(texture, text);
std.log.info("Render time: {}us, Quality: {d}%", .{text_stats.render_time_us, text_stats.overall_score});
```