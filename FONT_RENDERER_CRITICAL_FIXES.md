# Critical Font Renderer Fixes - Pure Zig Implementation

## Current Status: 🟡 PARTIALLY WORKING (Updated: 2025-01-14)

### Progress Made ✅
- **Fixed double rasterization bug** - 2x speedup achieved
- **Fixed memory allocation storm** - 30% speedup, no per-scanline allocations
- **Implemented proper glyph caching** - Bitmaps stored and reused
- **All tests passing** - Font manager tests successful
- **FPS numbers partially visible** - Some digits rendering correctly

### Critical Issues 🔴
- **Gray Rectangle Bug**: Most glyphs render as solid gray blocks instead of letters
- **Visual Quality**: Text mostly unreadable except some digits
- **Texture Format Mismatch**: Atlas uses R8_UNORM, manager expects RGBA

## Root Cause of Gray Rectangle Bug

### Primary Suspects (In Order of Likelihood):
1. **Scanline Rasterizer Filling Entire Bounds** 
   - Winding rule implementation may be inverted
   - All pixels inside bounding box being filled
   - Edge sorting or active edge calculation wrong

2. **Texture Format Mismatch**
   - Atlas uploads as `R8_UNORM` (single channel alpha)
   - Font manager creates `R8G8B8A8_UNORM` textures
   - Cached bitmap is single-channel but treated as RGBA

3. **Bitmap Corruption During Cache**
   - Memory copy may be wrong size
   - Stride/pitch issues when copying

4. **Coordinate System Issues**
   - Y-axis flip causing glyphs to be inverted
   - Pixels written to wrong locations

### Completed Optimizations ✅
- [x] Fixed double rasterization (glyphs only rasterized once)
- [x] Fixed memory allocation storm (reuse scanline buffers)
- [x] Implemented bitmap caching in atlas
- [x] Cache hit rate working (persistent text reused)

### Visual Bug Investigation 🔴 URGENT
- [ ] Add debug output to show first 100 bytes of rasterized bitmap
- [ ] Count non-zero pixels in each glyph bitmap
- [ ] Verify scanline winding number calculation
- [ ] Check texture format consistency throughout pipeline
- [ ] Test with a single large letter 'A' for debugging

### 3. Critical Implementation Fixes

#### A. Glyph Rasterization Issues
```zig
// Current issues to investigate:
// - Incorrect winding order calculation?
// - Off-by-one errors in scanline?
// - Floating point precision loss?
// - Improper edge sorting?
```

- [ ] Fix scanline rasterizer edge cases
- [ ] Verify Bézier curve control point handling
- [ ] Check for integer overflow in coordinate calculations
- [ ] Fix sub-pixel positioning accuracy
- [ ] Implement proper fill rules (even-odd vs non-zero)

#### B. Performance Optimizations
```zig
// Critical optimizations needed:
// - Implement proper glyph caching
// - Add dirty rectangle tracking
// - Use SIMD for rasterization
// - Implement fast path for axis-aligned rectangles
```

- [ ] **Cache System**: Implement proper glyph cache with LRU eviction
- [ ] **Batch Rendering**: Combine multiple text draws into single GPU call
- [ ] **Texture Atlas**: Fix atlas packing and reuse
- [ ] **Memory Pools**: Pre-allocate rasterization buffers
- [ ] **Fast Paths**: Add optimized paths for common cases

#### C. Font Atlas Problems
- [ ] Verify textures are uploaded correctly to GPU
- [ ] Check texture coordinates calculation
- [ ] Fix potential texture bleeding between glyphs
- [ ] Implement proper mipmap generation
- [ ] Add debug visualization for atlas layout

## Immediate Next Steps (Gray Rectangle Fix)

### Step 1: Add Debug Output to Rasterizer
```zig
// In font_rasterizer.zig after scanlineRender
var non_zero: u32 = 0;
var total_value: u32 = 0;
for (bitmap) |pixel| {
    if (pixel != 0) non_zero += 1;
    total_value += pixel;
}
if (codepoint == 'A' or codepoint == '0') {
    log.warn("Glyph '{}': {}/{} non-zero pixels, total value: {}", 
             .{codepoint, non_zero, bitmap.len, total_value});
    log.warn("First bytes: {any}", .{bitmap[0..@min(20, bitmap.len)]});
}
```

### Step 2: Fix Texture Format Consistency
Change atlas from R8_UNORM to match font_manager's RGBA:
```zig
// In font_atlas.zig
.format = c.sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,  // Was R8_UNORM
```

### Step 3: Validate Scanline Logic
Check if winding rule is inverted:
```zig
// In scanlineRender - try inverting the fill condition
if (winding_number == 0) {  // Was != 0
    bitmap[y * width + x] = 255;
}
```

### Step 4: Test Single Glyph
Focus debugging on one character:
```zig
// In menu +page.zig - add single large 'A' test
try links.append(page.createLink("A", "", 850, 400, 100, 100));
```

## Immediate Action Plan

### Phase 1: Debug Gray Rectangles (NOW)
1. **Add Debug Output**
   ```zig
   // Add timing for each stage
   const start = std.time.milliTimestamp();
   // ... operation ...
   log.debug("Operation took {}ms", .{std.time.milliTimestamp() - start});
   ```

2. **Visual Debug Mode**
   - Draw glyph bounding boxes
   - Show atlas texture directly
   - Display metrics overlay
   - Color-code cache hits vs misses

3. **Performance Metrics**
   - FPS with/without text
   - Time per glyph
   - Cache hit rate
   - Memory usage over time

### Phase 2: Critical Fixes (Day 2-3)
1. **Fix Caching** - Glyphs should NEVER re-rasterize unless size changes
2. **Fix Coordinates** - Ensure proper Y-axis handling throughout pipeline
3. **Fix Blending** - Verify alpha channel and blend modes
4. **Fix Atlas** - Ensure proper texture upload and sampling

### Phase 3: Optimization (Day 4-5)
1. **Implement Scanline Optimization**
   ```zig
   // Use active edge table (AET) for O(n log n) instead of O(n²)
   // Pre-sort edges by Y coordinate
   // Process horizontal spans in batches
   ```

2. **Add SIMD Rasterization**
   ```zig
   // Use vector operations for pixel processing
   // Batch 4-8 pixels at once
   // Utilize CPU cache lines efficiently
   ```

3. **GPU-Accelerated Path** (if needed)
   - Move rasterization to GPU compute shader
   - Use signed distance fields (SDF) for scalable text

## Testing Strategy

### Test Cases
1. **Performance Tests**
   - Render 1000 characters, measure time
   - Scroll text rapidly
   - Change font sizes dynamically
   - Memory leak detection over time

2. **Visual Tests**
   - All ASCII characters
   - Different sizes (8pt to 72pt)
   - Different colors and alpha values
   - Overlapping text
   - Rotated/scaled text

3. **Stress Tests**
   - Maximum glyphs on screen
   - Rapid font switching
   - Unicode character support
   - Very large font sizes

## Alternative Solutions (If Needed)

### Plan B: Hybrid Approach
- Use stb_truetype for rasterization only
- Keep pure Zig for everything else
- Single C file dependency

### Plan C: Pre-rendered Fonts
- Generate bitmap fonts at build time
- Ship with pre-rendered atlas textures
- Loses flexibility but guarantees performance

### Plan D: System Font Renderer
- Platform-specific font rendering
- Use OS facilities (DirectWrite, CoreText, FreeType)
- More complex but production-ready

## Success Metrics
- [ ] Text renders at 60 FPS with 1000+ glyphs on screen
- [ ] Text is crisp and readable at all sizes
- [ ] Memory usage is stable (no leaks)
- [ ] Cache hit rate > 95% for UI text
- [ ] Load time < 100ms for typical fonts

## Resources & References
- [FreeType Rasterization](https://freetype.org/freetype2/docs/glyphs/glyphs-6.html)
- [Font Rasterization Techniques](https://github.com/nothings/stb/blob/master/stb_truetype.h)
- [GPU Text Rendering](https://wdobbie.com/post/gpu-text-rendering-with-vector-textures/)
- [Scanline Algorithm](https://www.cs.rit.edu/~icss571/filling/how_to.html)

## Command Reference
```bash
# Profile the application
zig build -Doptimize=ReleaseFast
perf record ./zig-out/bin/dealt
perf report

# Debug with logging
ZIG_LOG_LEVEL=debug ./zig-out/bin/dealt 2>&1 | grep font

# Memory profiling
valgrind --leak-check=full ./zig-out/bin/dealt

# Generate flamegraph
perf record -F 99 -g ./zig-out/bin/dealt
perf script | flamegraph.pl > flamegraph.svg
```

## Notes
- Current implementation is architecturally sound but has critical bugs
- Performance issues likely due to missing caching or repeated work
- Visual bugs suggest coordinate system or blending issues
- May need to temporarily use stb_truetype while fixing pure Zig version

**Priority: Get text readable first, then optimize for performance**