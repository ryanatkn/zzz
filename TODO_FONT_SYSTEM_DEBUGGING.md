# Font System Debugging Guide

## System Overview

The font system is a pure Zig TTF renderer with SDL3 GPU integration. This guide covers debugging techniques, common issues, and solutions.

## Architecture Components

### Font Processing Pipeline
1. **TTF Parsing** → 2. **Glyph Extraction** → 3. **Rasterization** → 4. **Texture Creation** → 5. **GPU Rendering**

### Coordinate Systems
- **TTF Space**: Y=0 at baseline, positive up (font units)
- **Bitmap Space**: Y=0 at top, positive down (pixels)
- **GPU/NDC Space**: X,Y in [-1,1], requires Y-flip

## Debugging Infrastructure

### Test Output Organization
```
.zz/test-font/
├── baseline/    # Baseline alignment tests
│   ├── nopgy_orig.ppm      # Original bitmap coordinates
│   ├── nopgy_screen.ppm    # Screen space rendering
│   ├── nopgy_ndc.ppm       # NDC/shader space
│   └── nopgy_comparison.txt # Coordinate analysis
├── chars/       # Individual character analysis
│   ├── char{N}_orig.ppm    # Character bitmaps
│   └── char{N}_screen.ppm  # Screen space versions
├── coord/       # Coordinate transformation
│   ├── accuracy.txt        # Round-trip accuracy
│   └── pattern_analysis.txt # Test pattern analysis
├── debug/       # Debug outputs (mostly stdout)
└── full/        # Full alphabet composites
    ├── alphabet_orig.ppm
    ├── alphabet_screen.ppm
    ├── alphabet_ndc.ppm
    └── alphabet_comparison.txt
```

### Test Commands
```bash
# Run all font tests with detailed output
zig build test -Dtest-filter="font"

# Specific test categories
zig build test -Dtest-filter="baseline"      # Baseline alignment
zig build test -Dtest-filter="pixel"         # Pixel-level analysis
zig build test -Dtest-filter="coordinate"    # Coordinate transforms
zig build test -Dtest-filter="bearing"       # Bearing calculations
zig build test -Dtest-filter="character"     # Character analysis

# Visual verification
zig build run  # Navigate to font test pages
```

## Common Issues and Solutions

### Issue: Descender Character Cutoff

**Symptoms:**
- Characters with descenders (g, j, p, q, y) cut off at bottom
- Inconsistent baseline alignment between character types

**Root Cause:**
- Bitmap coordinate system created inconsistent baseline positioning
- Different characters had different `bearing_y` values

**Solution Applied:**
```zig
// Normalized bitmap height (rasterizer_core.zig)
const font_ascender = metrics.ascender * scale;
const font_descender = -metrics.descender * scale;
const total_font_height = font_ascender + font_descender;
const height_f = @max(bounds.height() + 2.0, total_font_height + 2.0);

// Consistent baseline positioning
const baseline_from_bottom = font_descender + 1.0;
const bitmap_y_from_bottom = height - 1.0 - y;
const pixel_y = bitmap_y_from_bottom - baseline_from_bottom;

// Updated bearing_y calculation
bearing_y = baseline_from_bottom + bounds.y_max;
```

### Issue: Coordinate Transformation Illegibility

**Symptoms:**
- Test output bitmaps were microscopic and illegible
- Characters stretched across entire screen width

**Root Cause:**
- Incorrect scaling treated small glyphs as full-screen elements
- Disconnected from working font rasterization system

**Solution Applied:**
```zig
// Font-aware scaling (coordinate_transform.zig)
const font_display_scale: f32 = 4.0;  // 4x for visibility
const base_screen_x: f32 = target_screen_width * 0.25;
const base_screen_y: f32 = target_screen_height * 0.4;

const screen_x = base_screen_x + (bitmap_x * font_display_scale);
const screen_y = base_screen_y + (bitmap_y * font_display_scale);
```

### Issue: Text Cutoff at Top/Bottom

**Symptoms:**
- Tall characters (capitals, b, d, f, h) cut off at top
- Descenders cut off at bottom of texture

**Root Cause:**
- Texture height calculation didn't account for full glyph height
- GPU textures were too small to contain characters

**Solution Applied:**
```zig
// Texture padding (layout.zig)
const ascender_padding = line_height * 0.5;
const descender_padding = line_height * 0.3;
const total_height = cursor_y + line_height + ascender_padding + descender_padding;

// Baseline positioning
const glyph_y = cursor_y + rasterizer.metrics.getBaselineOffset() - bearing_y;
```

## Debugging Techniques

### 1. Pixel-Level Analysis
Use `test/pixel_analysis.zig` to examine bitmap structure:
```
- First/last ink rows
- Empty space distribution
- Baseline position verification
- Bearing calculations
```

### 2. Character Type Comparison
Test different character categories:
- **Regular**: a, e, n, o (x-height characters)
- **Descenders**: g, j, p, q, y (extend below baseline)
- **Capitals**: A, B, C, etc. (cap height)
- **Tall**: b, d, f, h, k, l (ascender height)

### 3. Coordinate Verification
```zig
// Test round-trip accuracy
const ndc = screenToNDC(screen_x, screen_y, width, height);
const back = ndcToScreen(ndc.x, ndc.y, width, height);
const error = @sqrt((back.x - screen_x)² + (back.y - screen_y)²);
// Error should be < 0.001
```

### 4. Visual Debugging
- Generate PPM files for visual inspection
- Use ASCII art representation in terminal
- Compare original vs transformed coordinates
- Check alignment across character types

## Key Metrics to Monitor

### Font Metrics
```
Scale factor: 0.021333 (for 16pt at 96 DPI)
Ascender: 992 units (21.2 px)
Descender: -310 units (-6.6 px)
Line height: 27.78 px
Baseline offset: 21.16 px
```

### Bitmap Metrics
- **Consistent empty rows**: All chars should have ~11 empty rows at top
- **Baseline position**: Should be at row ~22.4 for all characters
- **First ink distance**: ~11.4 pixels from top for aligned characters

### Performance Metrics
- **Cache hit rate**: Should be >95% for UI text
- **Rasterization time**: First render slow, cached fast
- **Memory usage**: Scales with unique text strings

## Critical Code Locations

### Baseline Alignment
- `rasterizer_core.zig:108-118` - Normalized bitmap height
- `rasterizer_core.zig:142-155` - Baseline positioning
- `rasterizer_core.zig:175` - bearing_y calculation

### Texture Management
- `layout.zig:79` - Cursor starting position
- `layout.zig:129` - Glyph Y positioning
- `layout.zig:157-161` - Texture height calculation

### Coordinate Systems
- `coordinate_transform.zig:42-53` - Font-aware scaling
- `coordinate_transform.zig:13-23` - Core coordinate integration

## Validation Checklist

### For New Changes
- [ ] Run full font test suite
- [ ] Check baseline alignment across character types
- [ ] Verify no clipping at texture boundaries
- [ ] Test coordinate transformations
- [ ] Examine pixel-level bitmap structure
- [ ] Generate visual output for inspection

### For Debugging Issues
1. **Identify character type** causing the issue
2. **Extract metrics** (bearing_y, bounds, bitmap size)
3. **Trace positioning** through the pipeline
4. **Compare** with working characters
5. **Verify** coordinate transformations
6. **Check** texture boundaries

## Understanding Test Output

### PPM Files
- **_orig.ppm**: Original bitmap coordinates (GPU input)
- **_screen.ppm**: Screen space coordinates
- **_ndc.ppm**: NDC/shader space (what GPU sees)

### Text Analysis Files
- **accuracy.txt**: Coordinate round-trip verification
- **comparison.txt**: Side-by-side coordinate analysis
- **pattern_analysis.txt**: Test pattern transformations

### Debug Output (stdout)
- Character metrics and bounds
- Pixel content analysis
- Baseline positioning calculations
- Coordinate transformation details

## Future Debugging Improvements

1. **Automated validation** - Script to verify alignment
2. **Visual diff tools** - Compare bitmaps between runs
3. **Performance profiling** - Identify bottlenecks
4. **Memory tracking** - Detect leaks and excessive allocation
5. **Regression testing** - Catch breaking changes

This debugging guide provides comprehensive tools and techniques for maintaining and improving the font rendering system.