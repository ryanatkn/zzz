# Font System - AI Assistant Guide

## Quick Reference

Pure Zig TTF renderer with SDL3 GPU integration. Zero external dependencies.

## Key Concepts

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

- `rasterizer_core.zig:336-345` - RasterizedGlyph creation
- `rasterizer_core.zig:186-196` - RasterizedGlyph struct
- `test_visualization.zig:188-195` - Baseline guide rendering
- `coordinate_transform.zig:97-118` - NDC transformations

## Testing Checklist

When modifying font system:
- [ ] All characters have identical bearing_y values
- [ ] Baseline range is 0.0 pixels
- [ ] Coordinate accuracy < 0.001 pixel error
- [ ] alphabet_screen.ppm shows readable text
- [ ] alphabet_ndc.ppm shows Y-flipped text
- [ ] No bitmap indexing errors

## Common Pitfalls

- **Don't** mix logical (f32) and physical (u32) dimensions
- **Don't** calculate bearing_y from bounds.y_max
- **Don't** forget padding in bitmap allocation
- **Don't** use float dimensions for array indexing

## Performance Notes

- Pre-tessellate contours before rasterization
- Cache frequently used glyphs
- Use fixed-size pools for bitmaps
- Batch GPU texture uploads

## Debug Output

Test outputs in `.zz/test-font/`:
- `full/` - Complete alphabet tests
- `baseline/` - Alignment verification
- `coord/` - Transformation accuracy
- `chars/` - Individual character analysis

Check `alphabet_comparison.txt` for bearing_y consistency.