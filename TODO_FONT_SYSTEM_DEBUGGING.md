# Font System Debugging Guide

## System Overview

The font system is a pure Zig TTF renderer with SDL3 GPU integration. This guide covers debugging techniques, common issues, and solutions.

## Architecture Components

### Font Processing Pipeline
1. **TTF Parsing** → 2. **Glyph Extraction** → 3. **Rasterization** → 4. **Texture Creation** → 5. **GPU Rendering**

### Core Components
- **RasterizedGlyph Structure**: Contains both logical dimensions (f32) and bitmap dimensions (u32)
- **Coordinate Transform**: Provides NDC transformations for shader compatibility
- **Test Visualization**: Generates debug output in multiple coordinate spaces

### Coordinate Systems
- **TTF Space**: Y=0 at baseline, positive up (font units)
- **Bitmap Space**: Y=0 at top, positive down (pixels)
- **Screen Space**: Direct pixel positioning (Y=0 at top)
- **NDC Space**: Normalized Device Coordinates [-1,1], Y-flipped for GPU

## Test Output Organization

```
.zz/test-font/
├── baseline/    # Baseline alignment tests
│   ├── nopgy_orig.ppm      # Original bitmap coordinates
│   ├── nopgy_screen.ppm    # Screen space rendering (readable)
│   ├── nopgy_ndc.ppm       # NDC/shader space (Y-flipped)
│   └── nopgy_comparison.txt # Coordinate analysis
├── chars/       # Individual character analysis
│   ├── char{N}_orig.ppm    # Character bitmaps
│   ├── char{N}_screen.ppm  # Screen space versions
│   └── char{N}_analysis.txt # Pixel analysis
├── coord/       # Coordinate transformation validation
│   ├── accuracy.txt        # Round-trip accuracy (<0.001 error)
│   └── pattern_analysis.txt # Test pattern transformations
├── debug/       # Debug outputs (console logs)
└── full/        # Full alphabet composites
    ├── alphabet_orig.ppm    # Original bitmaps
    ├── alphabet_screen.ppm  # Normal readable text
    ├── alphabet_ndc.ppm     # Y-flipped (GPU input view)
    └── alphabet_comparison.txt # Coordinate space comparison
```

## Critical Architecture Fix: Bitmap Dimensions

### Problem Solved
Previous garbled output was caused by mismatch between bitmap allocation dimensions and indexing dimensions.

### RasterizedGlyph Structure
```zig
pub const RasterizedGlyph = struct {
    bitmap: []u8,
    width: f32,          // Logical dimensions for positioning
    height: f32,
    bitmap_width: u32,   // Actual bitmap dimensions for indexing
    bitmap_height: u32,
    bearing_x: f32,
    bearing_y: f32,
    advance: f32,
};
```

### Key Benefits
- **Eliminates indexing bugs**: Bitmap access uses correct dimensions
- **Clear separation**: Logical vs physical dimensions
- **Type safety**: u32 for array access, f32 for positioning
- **Future-proof**: Ready for subpixel rendering

## Test Commands

```bash
# Run all font tests with detailed output
zig build test -Dtest-filter="font"

# Specific test categories
zig build test -Dtest-filter="baseline"      # Baseline alignment
zig build test -Dtest-filter="coordinate"    # Coordinate transforms
zig build test -Dtest-filter="character"     # Character analysis

# Visual verification
zig build run  # Navigate to font test pages
```

## Understanding Test Output

### PPM File Types
- **_orig.ppm**: Original bitmap coordinates (direct rasterization)
- **_screen.ppm**: Screen space coordinates (readable, normal orientation)
- **_ndc.ppm**: Post-shader coordinate space (Y-flipped visualization)

### Expected Differences
- **Screen PPM**: Normal readable text (matches GPU texture input)
- **NDC PPM**: Upside-down text (visualizes post-shader coordinate space)
- **Coordinate Accuracy**: <0.001 pixel error in round-trip transformations

### What Each Output Represents
- **GPU Input**: Normal readable bitmap textures (shown in _screen.ppm)
- **Shader Processing**: Y-flip happens in vertex shader during NDC conversion
- **NDC Visualization**: Shows coordinate space after shader transformation (_ndc.ppm)
- **Purpose**: Debug coordinate transformation issues in shaders

### Text Analysis Files
- **accuracy.txt**: Coordinate transformation precision verification
- **comparison.txt**: Side-by-side coordinate space analysis
- **pattern_analysis.txt**: Bitmap transformation validation

## Common Issues and Solutions

### Issue: Garbled Font Output ✅ SOLVED
**Symptoms**: Characters appear as random pixels, unreadable output
**Root Cause**: Bitmap allocated with ceiling dimensions but indexed with float dimensions
**Solution**: Added explicit bitmap_width/bitmap_height fields to RasterizedGlyph

### Issue: NDC Output Identical to Screen
**Symptoms**: alphabet_ndc.ppm looks the same as alphabet_screen.ppm
**Root Cause**: Round-trip transformation cancels out Y-flip
**Solution**: Direct Y-flip transformation shows actual GPU input

### Issue: Character Alignment Problems
**Symptoms**: Inconsistent baseline between characters
**Solution**: Use consistent baseline positioning with bearing_y calculations

### Issue: Coordinate Precision Errors
**Symptoms**: Characters drift or misalign after transformation
**Verification**: Check accuracy.txt for errors >0.001

## Debugging Techniques

### 1. Visual Inspection
- Compare screen vs NDC PPM files
- Screen should be readable, NDC should be Y-flipped
- Look for pixel-perfect alignment in similar characters

### 2. Coordinate Verification
```bash
# Check transformation accuracy
grep "Error" .zz/test-font/coord/accuracy.txt | sort -nk8
# All errors should be <0.001
```

### 3. Character Type Testing
Test different character categories:
- **Regular**: a, e, n, o (baseline characters)
- **Descenders**: g, j, p, q, y (below baseline)
- **Capitals**: A, B, C (cap height)
- **Tall**: b, d, f, h, k, l (ascender height)

### 4. Bitmap Dimension Validation
```zig
// In tests, verify dimensions match
assert(glyph.bitmap.len == glyph.bitmap_width * glyph.bitmap_height);
```

## Performance Monitoring

### Key Metrics
- **Cache hit rate**: >95% for UI text rendering
- **Bitmap allocation**: No dimension mismatches
- **Coordinate accuracy**: <0.001 pixel error
- **Memory usage**: Scales with unique character set

### Critical Code Locations
- `rasterizer_core.zig:186-196` - RasterizedGlyph definition
- `coordinate_transform.zig:97-118` - NDC Y-flip transformation
- `test_visualization.zig:162-163` - Bitmap dimension usage

## Validation Checklist

### For New Changes
- [ ] Run `zig build test -Dtest-filter="font"`
- [ ] Check alphabet_screen.ppm is readable
- [ ] Verify alphabet_ndc.ppm is Y-flipped
- [ ] Confirm coordinate accuracy <0.001
- [ ] Test multiple character types
- [ ] Validate bitmap dimension consistency

### For Debugging New Issues
1. **Reproduce** the issue with specific characters
2. **Check** PPM output files for visual clues
3. **Examine** coordinate accuracy in accuracy.txt
4. **Verify** bitmap dimensions match allocation
5. **Compare** with working characters
6. **Test** both screen and NDC coordinate spaces

## Architecture Notes

### Separation of Concerns
- **Engine (lib/)**: Provides coordinate transformation interfaces
- **Font System**: Implements TTF parsing and rasterization
- **Test System**: Validates output across coordinate spaces

### Design Principles
- **Type Safety**: Separate logical and physical dimensions
- **Visual Debugging**: Multiple coordinate space outputs
- **Precision Verification**: Automated accuracy testing
- **Performance Focus**: Efficient bitmap handling

This guide provides comprehensive debugging tools for the font system's coordinate transformations and bitmap handling.