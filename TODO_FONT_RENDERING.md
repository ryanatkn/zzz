# TODO: Pure Zig TTF Font Rendering with SDL3 GPU

## 🎯 Goal
Get TTF font rendering working reliably in pure Zig with SDL3 GPU API, with clear text at all sizes (12pt-72pt).

## 🔴 Current Status: BROKEN
- **FPS counter works** but quality is poor at small sizes
- **Font grid test crashes** with UTF-8 validation errors  
- **Multiple renderers exist** but produce 0x0 or poor quality output
- **No comprehensive tests** - only 2 files have tests
- **Debugging is difficult** - no visual tools or test harnesses

## 📋 Priority Task List

### Phase 1: Establish Testing Foundation
```
[ ] Create test harness for individual components
    [ ] TTF parser test suite with known fonts
    [ ] Glyph extractor test with visual output
    [ ] Rasterizer test with bitmap verification
    [ ] Create test/fonts/ directory with sample TTFs
    
[ ] Add visual debugging tools
    [ ] Bitmap dumper to PNG files
    [ ] ASCII art renderer for quick visualization  
    [ ] Side-by-side comparison tool
    [ ] Coverage heatmap visualizer
```

### Phase 2: Module Extraction & Simplification
```
[ ] Extract reusable primitives to src/lib/core/
    [ ] bitmap_ops.zig - bitmap manipulation utilities
    [ ] fixed_point.zig - fixed-point math (16.16 format)
    [ ] bezier.zig - bezier curve utilities
    
[ ] Consolidate font modules
    [ ] Merge redundant renderer interfaces
    [ ] Single RenderStrategy enum -> direct renderer types
    [ ] Remove vtable indirection where not needed
```

### Phase 3: Fix Core Rendering Pipeline
```
[ ] Simple bitmap renderer (get this working first!)
    [ ] Fix winding rule implementation
    [ ] Verify point-in-polygon algorithm
    [ ] Test with simple shapes (rectangle, triangle)
    [ ] Add visual debugging output
    
[ ] TTF parser validation
    [ ] Verify glyph outline extraction
    [ ] Check coordinate system (TTF vs screen)
    [ ] Validate contour winding order
    [ ] Test with multiple font files
```

### Phase 4: GPU Integration
```
[ ] Fix texture creation pipeline
    [ ] Verify bitmap format (R8 vs RGBA8)
    [ ] Check texture upload/binding
    [ ] Fix coordinate mapping
    [ ] Add texture debugging/dumping
    
[ ] Font atlas optimization
    [ ] Dynamic packing algorithm
    [ ] Cache invalidation strategy
    [ ] Memory management
```

## 🧪 Testing Strategy

### 1. Unit Tests for Core Components
```zig
// src/lib/font/test_ttf_parser.zig
test "parse simple glyph" {
    const data = @embedFile("test/fonts/test_font.ttf");
    var parser = try TTFParser.init(allocator, data);
    const glyph = try parser.getGlyph('A');
    try expect(glyph.contours.len > 0);
}

test "rasterize rectangle" {
    const outline = createRectangleOutline(100, 100);
    const bitmap = try renderer.rasterize(outline, 24);
    try verifyBitmapFilled(bitmap, 0.8); // 80% coverage
}
```

### 2. Visual Regression Tests
```zig
// Render known text and compare with reference images
test "render hello world" {
    const bitmap = try renderText("Hello World", 24);
    try compareBitmapWithReference(bitmap, "test/reference/hello_24pt.png");
}
```

### 3. Performance Benchmarks
```zig
// Track rendering speed to catch regressions
test "benchmark glyph rendering" {
    const start = std.time.milliTimestamp();
    for (0..1000) |_| {
        _ = try renderer.renderGlyph('A', 24);
    }
    const elapsed = std.time.milliTimestamp() - start;
    try expect(elapsed < 100); // 100ms for 1000 glyphs
}
```

## 🔍 Debugging Tools

### 1. Bitmap Visualizer
```zig
// src/lib/debug/bitmap_viz.zig
pub fn dumpBitmapToAscii(bitmap: []const u8, width: u32, height: u32) void {
    for (0..height) |y| {
        for (0..width) |x| {
            const pixel = bitmap[y * width + x];
            const char = switch (pixel) {
                0 => ' ',
                1...63 => '.',
                64...127 => '+',
                128...191 => '*',
                192...255 => '#',
            };
            std.debug.print("{c}", .{char});
        }
        std.debug.print("\n", .{});
    }
}

pub fn saveBitmapToPNG(bitmap: []const u8, width: u32, height: u32, path: []const u8) !void {
    // Use stb_image_write or similar
}
```

### 2. Glyph Outline Visualizer
```zig
// src/lib/debug/outline_viz.zig
pub fn drawOutlineToSVG(outline: GlyphOutline, path: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    
    try file.writeAll("<svg>\n");
    for (outline.contours) |contour| {
        try file.writeAll("  <path d=\"");
        // Write SVG path commands
        try file.writeAll("\" />\n");
    }
    try file.writeAll("</svg>\n");
}
```

### 3. Real-time Debug Overlay
```zig
// Show rendering metrics on screen
pub fn renderDebugOverlay(renderer: *Renderer) void {
    renderer.drawText("Glyphs cached: {}", .{cache.count});
    renderer.drawText("Render time: {}ms", .{last_render_time});
    renderer.drawText("Cache hits: {}%", .{cache_hit_rate});
}
```

## 🏗️ Architecture Simplification

### Current (Too Complex)
```
FontManager -> MultiStrategyRenderer -> VTable -> RendererImpl -> Rasterizer
```

### Proposed (Direct)
```
FontManager -> SimpleBitmapRenderer -> Rasterizer
            -> (Optional) SDFRenderer for small sizes
```

### Key Principles
1. **Start simple** - Get basic bitmap rendering working first
2. **Test early** - Add tests before features
3. **Visual debugging** - See what's happening at each step
4. **Incremental progress** - One working renderer > five broken ones

## 📊 Success Metrics

### Minimum Viable Product
- [ ] Render "Hello World" at 24pt clearly
- [ ] Support A-Z, a-z, 0-9 characters
- [ ] No crashes or memory leaks
- [ ] 60 FPS with 100+ glyphs on screen

### Quality Goals
- [ ] Clear text at 12pt-72pt sizes
- [ ] Proper anti-aliasing
- [ ] Correct kerning/spacing
- [ ] Support for common fonts (Arial, Times, etc.)

### Performance Goals
- [ ] < 1ms to render a glyph
- [ ] < 100MB memory for font cache
- [ ] 95%+ cache hit rate

## 🚀 Implementation Order

### Week 1: Foundation
1. Set up test infrastructure
2. Create bitmap debugging tools
3. Write TTF parser tests
4. Fix simple bitmap renderer

### Week 2: Core Rendering
1. Fix winding rule algorithm
2. Implement proper anti-aliasing
3. Add visual regression tests
4. Optimize hot paths

### Week 3: GPU Integration
1. Fix texture upload pipeline
2. Implement font atlas
3. Add cache management
4. Performance optimization

### Week 4: Polish
1. Add remaining character support
2. Implement kerning
3. Add SDF fallback for small sizes
4. Documentation and examples

## 🔧 Useful Commands

```bash
# Run font tests
zig test src/lib/font/test_all.zig

# Visual debugging
zig build run -- --debug-fonts

# Benchmark
zig build -Doptimize=ReleaseFast benchmark

# Generate test bitmaps
zig run src/tools/gen_font_tests.zig
```

## 📚 Resources

### Reference Implementations
- FreeType: `src/.ss/freetype/` - algorithms and techniques
- stb_truetype: Single-file TTF rasterizer
- fontdue: Rust font rasterizer

### Key Algorithms
- **Scanline rasterization**: FreeType's ftgrays.c
- **Bezier tessellation**: Adaptive subdivision
- **Anti-aliasing**: Area coverage calculation
- **SDF generation**: Distance field from outline

## ⚠️ Known Issues to Fix

1. **UTF-8 validation errors** - String handling in font grid test
2. **0x0 bitmap generation** - Config initialization (partially fixed)
3. **Poor quality at small sizes** - Precision/rounding errors
4. **Memory leaks** - Vulkan resources not freed
5. **Infinite loops** - UTF-8 validation causing hangs

## 💡 Quick Wins

1. **Remove font grid test complexity** - Start with single renderer
2. **Add PNG dump** - See actual bitmap output
3. **Use test font** - Known simple font for testing
4. **Disable problematic renderers** - Focus on one that works
5. **Add progress logging** - Track where it fails

## 🎯 Definition of Done

- [ ] Font rendering works at all common sizes
- [ ] Comprehensive test suite passes
- [ ] Visual debugging tools available
- [ ] Performance meets targets
- [ ] No memory leaks or crashes
- [ ] Clear documentation with examples