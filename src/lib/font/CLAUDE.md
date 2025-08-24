# Font System - AI Assistant Guide

## Domain: Font Parsing & CPU Glyph Operations

**Purpose:** Parse TTF files and provide individual glyph data. CPU-only, no GPU operations.

## Core Responsibilities

### ✅ What font/ DOES:
- Parse TTF font files
- Extract glyph contours and metrics
- Rasterize individual glyphs to bitmaps (CPU)
- Manage font atlas packing
- Calculate font metrics (ascender, descender, line height)
- Provide glyph advance and kerning data

### ❌ What font/ DOES NOT do:
- Render text strings (that's text/)
- GPU texture operations (that's rendering/)
- Text layout or word wrapping (that's text/)
- Draw to screen (that's rendering/)

## Key Modules

### Core Components (`core/`)
- `ttf_parser.zig` - TTF file format parsing
- `glyph_extractor.zig` - Extract glyph contours
- `metrics.zig` - Font metrics calculations
- `types.zig` - Font-specific types
- `curve_utils.zig` - Bezier curve handling

### Rendering Strategies (`strategies/`)
- **bitmap/** - Traditional rasterization
  - `rasterizer.zig` - CPU glyph rasterization
  - `atlas.zig` - Glyph packing into texture atlas
- **sdf/** - Signed distance fields
- **vertex/** - Direct triangulation

### Main Interface
- `manager.zig` - Font loading and management

## Working with Fonts

```zig
// Load font (CPU only)
const font_id = try font_manager.loadFont(.sans, 16.0);

// Get glyph metrics (no rendering)
const metrics = try font_manager.getGlyphMetrics('A');

// Rasterize single glyph (CPU bitmap)
const bitmap = try rasterizer.rasterizeGlyph('A', 0, 0);
defer allocator.free(bitmap.bitmap);
```

## Atlas Management

The font atlas (`strategies/bitmap/atlas.zig`) packs glyphs but uses rendering/ utilities for GPU operations:

```zig
// Atlas creates GPU texture using rendering utilities
const texture = try texture_formats.TextureCreation.createFontAtlasTexture(device, 2048, 2048);

// Upload uses shared utilities
try texture_formats.TextureTransfer.uploadToTexture(device, texture, bitmap, width, height, x, y);
```

## Baseline Alignment

Critical for correct text rendering:
```zig
const baseline_from_bottom = font_descender + 1.0;
bearing_y = height - baseline_from_bottom;
```

## Testing

```bash
zig build test -Dtest-filter="font"
```

Font tests are CPU-only and don't require GPU context.