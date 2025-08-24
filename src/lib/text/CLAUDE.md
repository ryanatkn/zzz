# Text System - AI Assistant Guide

## Domain: String Rendering & Text Layout

**Purpose:** Render complete text strings to screen using glyphs from font system.

## Core Responsibilities

### ✅ What text/ DOES:
- Render text strings to GPU
- Handle text layout and positioning
- Word wrapping and multi-line text
- Text caching for performance
- Manage rendering strategies (bitmap, SDF, vertex)
- Screen-space text positioning

### ❌ What text/ DOES NOT do:
- Parse font files (that's font/)
- Rasterize individual glyphs (that's font/)
- Low-level GPU operations (that's rendering/)
- CPU bitmap manipulation (that's image/)

## Key Modules

### Core Components
- `renderer.zig` - Main text rendering interface
- `cache.zig` - Persistent text texture caching
- `layout.zig` - Text layout and line breaking
- `primitives.zig` - Text rendering primitives

### Rendering Strategies (`renderers/`)
- `texture_renderer.zig` - Bitmap/atlas-based rendering
- `vertex_renderer.zig` - Direct vertex rendering
- `interface.zig` - Common renderer interface

## Working with Text

```zig
// Render immediate text (changes frequently)
const texture = try text_primitives.createTextTexture("FPS: 60", 14.0, .bitmap, Color.white());
text_renderer.queueTextTexture(texture.texture, pos, texture.width, texture.height, color);

// Render persistent text (stable content)
try text_renderer.queuePersistentText("Menu Title", pos, font_mgr, .sans, 24.0, Color.white());
try text_renderer.drawQueuedText(cmd_buffer, render_pass);
```

## Caching Strategy

Choose based on update frequency:
- **Immediate mode**: Text changes >10 times/sec
- **Persistent mode**: Text changes <5 times/sec

```zig
// Check cache performance
const stats = persistent_text_system.getStatistics();
std.log.info("Cache hit rate: {d}%", .{stats.hit_rate * 100});
```

## Integration with Font System

Text system requests glyphs from font system:
```zig
// Text asks font for glyph
const glyph = try font_manager.getGlyph('A');
// Text composes glyphs into strings
try renderString("Hello", glyphs);
```

## Performance Guidelines

- Batch text draws together
- Use persistent caching for stable text
- Choose appropriate rendering strategy:
  - Bitmap: <16px, UI text
  - SDF: ≥16px, scalable text
  - Vertex: Large text, highest quality

## Testing

```bash
zig build test -Dtest-filter="text"
```