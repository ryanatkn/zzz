# Image System - AI Assistant Guide

## Domain: CPU Bitmap & Pixel Operations

**Purpose:** CPU-based image processing and bitmap manipulation. No GPU operations.

## Core Responsibilities

### ✅ What image/ DOES:
- Create and manipulate bitmaps in memory
- Convert between pixel formats (grayscale → RGBA)
- Provide pixel-level access and modification
- Generate test patterns (checkerboard, gradients)
- Save/load simple image formats (PGM)
- Calculate coverage and statistics

### ❌ What image/ DOES NOT do:
- GPU texture operations (that's rendering/)
- Font rasterization (that's font/)
- Text rendering (that's text/)
- Direct screen drawing (that's rendering/)

## Key Module

### `bitmap.zig` - Core Bitmap Utilities

**Data Structures:**
- `Bitmap` - Basic bitmap with pixel access
- `Coverage` - Coverage level constants and conversions

**Utilities:**
- `Convert` - Format conversion operations
  - `grayscaleToRGBA()` - Convert single channel to RGBA
  - `createRGBABitmap()` - Allocate RGBA buffer
  - `setRGBAPixel()` - Set individual RGBA pixels
  - `fillWithWhiteCoverage()` - Common font pattern

- `Visualizer` - Debug and inspection tools
  - `toAsciiArt()` - Console visualization
  - `calculateCoverage()` - Coverage statistics
  - `saveToPGM()` - Export to portable graymap

- `TestPatterns` - Generate test bitmaps
  - `createCheckerboard()`
  - `createGradient()`

## Working with Bitmaps

```zig
// Create RGBA bitmap
const bitmap = try Convert.createRGBABitmap(allocator, 256, 256);
defer allocator.free(bitmap);

// Set pixels using shared utilities
Convert.setRGBAPixel(bitmap, pixel_index, 255, 128, 64, 255);

// Convert grayscale to RGBA for GPU upload
const rgba = try Convert.grayscaleToRGBA(allocator, gray_data, width, height);
defer allocator.free(rgba);
```

## Integration with Rendering

Image provides CPU bitmaps that rendering uploads to GPU:
```zig
// Image creates bitmap (CPU)
const bitmap = try image.Convert.createRGBABitmap(allocator, 512, 512);

// Rendering uploads to GPU
try texture_formats.TextureTransfer.uploadToTexture(device, texture, bitmap, 512, 512, 0, 0);
```

## Testing & Debugging

```zig
// Visualize bitmap in console
Visualizer.toAsciiArt(bitmap_data, width, height);

// Check coverage
const coverage = Visualizer.calculateCoverage(bitmap_data);
std.debug.print("Coverage: {d}%\n", .{coverage});

// Export for inspection
try Visualizer.saveToPGM(bitmap_data, width, height, "debug.pgm");
```

## Performance Notes

- All operations are CPU-only
- No allocations in pixel operations
- Direct memory access for speed
- Use texture_formats utilities for GPU integration