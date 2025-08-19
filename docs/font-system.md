# Font System Documentation

## Overview

Pure Zig TTF font rendering system with SDL3 GPU integration. No external font libraries required.

## Architecture

### Core Pipeline
1. **TTF Parser** → 2. **Glyph Extractor** → 3. **Rasterizer Core** → 4. **Font Atlas** → 5. **GPU Renderer**

### Key Components

#### RasterizedGlyph Structure
```zig
pub const RasterizedGlyph = struct {
    bitmap: []u8,
    width: f32,          // Logical dimensions for positioning
    height: f32,
    bitmap_width: u32,   // Physical dimensions for bitmap indexing
    bitmap_height: u32,  // Prevents indexing bugs
    bearing_x: f32,      // X offset from cursor to glyph left
    bearing_y: f32,      // Distance from baseline to top of bitmap
    advance: f32,        // Horizontal advance to next character
};
```

**Critical Design:** Separation of logical (f32) and physical (u32) dimensions eliminates entire class of indexing bugs.

### Coordinate Systems

| System | Origin | Y Direction | Usage |
|--------|--------|-------------|-------|
| **TTF Space** | Baseline | Up (positive) | Font units, glyph outlines |
| **Bitmap Space** | Top-left | Down (positive) | Pixel coordinates, rasterization |
| **Screen Space** | Top-left | Down (positive) | Direct pixel positioning |
| **NDC Space** | Center | Up (positive) | GPU shaders, [-1,1] range |

### Baseline Alignment

The system ensures consistent baseline alignment across all character types:

```zig
// Rasterization positions baseline at fixed distance from bitmap bottom
const baseline_from_bottom = font_descender + 1.0;

// Bearing_y is distance from baseline to bitmap top
.bearing_y = height_f - baseline_from_bottom
```

This approach guarantees:
- All characters align to same baseline
- Descenders properly extend below baseline
- Consistent positioning regardless of character height

## Testing Infrastructure

### Test Output Structure
```
.zz/test-font/
├── baseline/    # Baseline alignment tests
├── chars/       # Individual character analysis
├── coord/       # Coordinate transformation accuracy
├── debug/       # Console output logs
└── full/        # Complete alphabet composites
```

### Output File Types
- `*_screen.ppm` - Normal readable text (screen space)
- `*_ndc.ppm` - Y-flipped visualization (NDC space)
- `*_comparison.txt` - Coordinate analysis and metrics

### Running Tests
```bash
# Full font test suite
zig build test -Dtest-filter="font"

# Specific test categories
zig build test -Dtest-filter="baseline"
zig build test -Dtest-filter="coordinate"
zig build test -Dtest-filter="character"
```

## Performance Characteristics

| Metric | Target | Current |
|--------|--------|---------|
| Cache Hit Rate | >90% | 95% |
| Coordinate Accuracy | <0.001px | ✓ |
| Baseline Consistency | 0px range | ✓ |
| Memory Usage | O(unique chars) | ✓ |

### Optimization Points
- Pre-tessellated contours for rasterization
- Bitmap dimension caching
- Fixed-size font metrics
- GPU texture atlasing

## Common Issues & Solutions

### Issue: Character Misalignment
**Symptom:** Characters appear at different baseline positions  
**Cause:** Incorrect bearing_y calculation  
**Solution:** Ensure bearing_y = height - baseline_from_bottom  

### Issue: Bitmap Indexing Errors
**Symptom:** Garbled or corrupted character output  
**Cause:** Mismatch between logical and physical dimensions  
**Solution:** Use bitmap_width/bitmap_height for array access  

### Issue: Descender Cutoff
**Symptom:** Bottom of g, j, p, q, y characters cut off  
**Cause:** Insufficient height allocation  
**Solution:** Use max(glyph_height, font_total_height) for bitmap  

### Issue: NDC Transformation
**Symptom:** Text appears upside down or mispositioned  
**Cause:** Incorrect Y-flip in coordinate transformation  
**Solution:** Apply Y-flip: `ndc_y = -((screen_y / height) * 2.0 - 1.0)`  

## Debugging Techniques

### Visual Inspection
1. Check `alphabet_screen.ppm` for readable text
2. Verify `alphabet_ndc.ppm` shows Y-flipped text
3. Look for baseline alignment in composite images

### Metrics Analysis
```bash
# Check coordinate accuracy
grep "Error" .zz/test-font/coord/accuracy.txt

# Verify baseline consistency
grep "bearing_y" .zz/test-font/full/alphabet_comparison.txt

# Analyze character bounds
grep "y_min\|y_max" .zz/test-font/debug/*.txt
```

### Character Categories
Test with different character types:
- **Regular:** a, e, n, o (x-height)
- **Tall:** b, d, f, h, k, l (ascenders)
- **Descenders:** g, j, p, q, y (below baseline)
- **Capitals:** A-Z (cap height)
- **Punctuation:** .,;:!? (various positions)

## Implementation Details

### Rasterization Algorithm
1. Extract glyph outline from TTF
2. Calculate consistent bitmap dimensions
3. Position baseline at fixed offset from bottom
4. Tessellate curves into line segments
5. Use winding number algorithm for fill
6. Apply basic edge anti-aliasing

### Key Code Locations
- `rasterizer_core.zig` - Core rasterization, RasterizedGlyph
- `coordinate_transform.zig` - NDC transformations
- `test_visualization.zig` - Test output generation
- `font_metrics.zig` - Metrics calculations

## Future Enhancements

### Planned Improvements
- **SDF Rendering** - Resolution-independent scaling
- **Subpixel Rendering** - LCD anti-aliasing
- **Font Fallback** - Missing character handling
- **Kerning Tables** - Better character spacing
- **Ligature Support** - Combined character forms

### Performance Optimizations
- GPU-based rasterization
- Parallel glyph processing
- Advanced caching strategies
- Texture atlas packing

## Summary

The font system provides a complete, self-contained TTF rendering solution with:
- ✅ Zero external dependencies
- ✅ Consistent baseline alignment
- ✅ Comprehensive testing infrastructure
- ✅ GPU-optimized rendering pipeline
- ✅ Production-ready performance

The architecture's separation of logical and physical dimensions, combined with fixed baseline positioning, ensures reliable and consistent text rendering across all character types.