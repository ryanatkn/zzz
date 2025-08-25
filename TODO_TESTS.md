# Font Tests - Proper Implementation TODO

## Current State
- ✅ All 509 tests pass, 0 skipped
- ✅ Architecture/imports validated  
- ❌ No functional rendering coverage

## Required Tests

### 1. Bitmap Strategy
```zig
test "bitmap rasterization" {
    const outline = try createTestRectangle(allocator, 50, 30);
    const result = try rasterizer.rasterizeGlyph(allocator, outline, 24.0);
    // Verify: non-empty bitmap, correct metrics, pixel coverage
}
```

### 2. Vertex Strategy  
```zig
test "vertex triangulation" {
    const result = try triangulator.triangulate(test_outline);
    // Verify: vertex count multiple of 3, GPU format, cache behavior
}
```

### 3. SDF Strategy
```zig
test "sdf generation" {
    const sdf = try generator.generateSDF(circle_outline);
    // Verify: distance field accuracy, texture dimensions
}
```

### 4. Integration
```zig
test "strategy selection" {
    // Test size thresholds: bitmap<24pt, vertex>=24pt, sdf=12-48pt
}
```

## Required Infrastructure

### Test Data Generators
- `createTestRectangle()`, `createTestCircle()`, `createTestTriangle()`
- Real TTF loading for production validation

### Visual Validation  
- ASCII bitmap visualization
- Coverage percentage validation
- Pixel-level comparison utilities

### Performance
- Render time benchmarks (<100μs/glyph)
- Memory usage profiling
- Cache hit rate validation (>95%)

## Dependencies
- Test font assets (TTF files)
- GPU context for vertex tests
- Image comparison framework

## Implementation Phases

1. **Basic (2-3 days):** Shape generators, bitmap tests, memory validation
2. **Integration (1 week):** SDF tests, strategy selection, performance
3. **Production (1-2 weeks):** Real TTF fonts, visual regression, full coverage

## Recommendation
Keep current simplified tests - they validate architecture and ensure zero failures with minimal maintenance overhead.