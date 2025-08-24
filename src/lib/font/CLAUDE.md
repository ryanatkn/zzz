# Font System Domain - AI Assistant Guide

## Domain Definition

**Font System Domain:** CPU-only font data operations and individual glyph processing.

### Core Responsibilities
- **TTF Parsing:** Load and parse TrueType font files
- **Glyph Extraction:** Extract individual character contours and metrics
- **Rasterization:** Convert vector glyphs to bitmap data (CPU-only)
- **Font Atlas:** Pack individual glyphs into texture atlases
- **Font Management:** Load fonts, manage font instances, provide glyph access
- **Font Metrics:** Line height, baseline, ascent, descent, kerning data

### Domain Boundaries

**✅ What font/ SHOULD do:**
- Load and parse TTF files
- Extract individual glyph data
- Rasterize single characters to bitmaps
- Provide font metrics (baseline, kerning, etc.)
- Manage font loading and caching
- CPU-only operations

**❌ What font/ should NOT do:**
- Text layout or multi-character strings
- GPU operations or texture rendering  
- UI-specific text formatting
- Screen positioning or alignment
- Text caching or optimization

**📡 Interface with text/ domain:**
```
font/ produces → individual rasterized glyphs
text/ consumes → glyphs to create rendered strings
```

## Key Technical Concepts

### Coordinate Systems
- **TTF Space:** Y=0 at baseline, positive up
- **Bitmap Space:** Y=0 at top, positive down  
- **Critical:** Always transform correctly between spaces

### Baseline Alignment Formula
```zig
// Consistent baseline positioning
const baseline_from_bottom = font_descender + 1.0;
.bearing_y = height_f - baseline_from_bottom;
```

### RasterizedGlyph Fields
- `bitmap_width/height` (u32) - For array indexing
- `width/height` (f32) - For positioning calculations
- `bearing_y` - Distance from baseline to bitmap top

## Domain Violation Prevention

### Common Violations to Avoid
1. **Importing from text/ domain** - Font should not depend on text rendering
2. **GPU operations** - Font should be CPU-only, platform-agnostic
3. **Text layout** - Multi-character operations belong in text/ domain
4. **UI formatting** - Screen positioning belongs in text/ domain

### Migration Notes
- `renderTextToTexture()` method moved to text/ domain (violates separation)
- Layout engine removed from FontManager (violates CPU-only rule)
- Any GPU texture operations should be in text/ domain

## Common Tasks

### Fix Baseline Alignment Issues
1. Check bearing_y calculation in `rasterizer_core.zig`
2. Ensure: `bearing_y = height_f - baseline_from_bottom`
3. Verify all characters report same bearing_y value

### Debug Garbled Output
1. Check bitmap dimensions match allocation
2. Verify using bitmap_width/height for indexing
3. Ensure width/height used only for positioning

### Add New Character Support
1. Update test character sets in `test.zig`
2. Add to visualization test suite
3. Verify baseline alignment consistency

### Test Font Changes
```bash
# Quick test
zig build test -Dtest-filter="font"

# Check output
ls -la .zz/test-font/full/alphabet_*.ppm
```

## Critical Files

- `manager.zig` - Font loading and management (CPU-only)
- `rasterizer_core.zig` - Glyph rasterization (individual characters)
- `ttf_parser.zig` - Font file parsing
- `font_atlas.zig` - Glyph packing and atlas management
- `font_metrics.zig` - Typographic metrics
- `coordinate_transform.zig` - Space transformations

## Testing Checklist

When modifying font system:
- [ ] All characters have identical bearing_y values
- [ ] Baseline range is 0.0 pixels
- [ ] Coordinate accuracy < 0.001 pixel error
- [ ] alphabet_screen.ppm shows readable text
- [ ] alphabet_ndc.ppm shows Y-flipped text
- [ ] No bitmap indexing errors
- [ ] No imports from text/ domain
- [ ] No GPU operations

## Common Pitfalls

- **Don't** mix logical (f32) and physical (u32) dimensions
- **Don't** calculate bearing_y from bounds.y_max
- **Don't** forget padding in bitmap allocation
- **Don't** use float dimensions for array indexing
- **Don't** import from text/ domain (creates circular dependency)
- **Don't** add GPU operations (breaks CPU-only rule)

## Performance Notes

- Pre-tessellate contours before rasterization
- Cache frequently used glyphs in font atlas
- Use fixed-size pools for bitmaps
- Keep operations CPU-only for testability

## Debug Output

Test outputs in `.zz/test-font/`:
- `full/` - Complete alphabet tests
- `baseline/` - Alignment verification
- `coord/` - Transformation accuracy
- `chars/` - Individual character analysis

Check `alphabet_comparison.txt` for bearing_y consistency.