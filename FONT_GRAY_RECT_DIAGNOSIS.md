# Font Gray Rectangle Bug - Diagnosis Summary

## Current Status
- **Rasterization works**: Glyphs are correctly rasterized with proper non-zero pixel counts
- **Caching works**: Bitmaps are cached and reused successfully  
- **Performance improved**: 2x speedup from fixes
- **Visual bug remains**: All text appears as solid gray rectangles

## Evidence Gathered

### 1. Rasterization is Correct ✅
```
Glyph 'F' (70): 430/1410 non-zero pixels (30% fill rate - correct for a letter)
Glyph '0' (48): 698/1960 non-zero pixels (35% fill rate - correct for a number)
```
The fill rates are reasonable for actual letter shapes, not solid rectangles.

### 2. Edge Generation Works ✅
- 'F' has 5 edges (after filtering horizontals)
- '0' has 36 edges (appropriate for a curved glyph)
- Edge counts match expected complexity

### 3. Bitmap Data is Valid ✅
- First non-zero pixels found at reasonable offsets
- Continuous runs of 255 values indicate proper scanline filling
- Pattern suggests actual letter shapes, not solid blocks

## Root Cause Analysis

### Most Likely Cause: Texture Upload Format Mismatch 🔴

The atlas uploads single-channel (R8_UNORM) data but the shader might expect RGBA:
- Atlas texture format: `SDL_GPU_TEXTUREFORMAT_R8_UNORM` (line 71 in font_atlas.zig)
- Manager texture format: `SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM` (line 288 in font_manager.zig)
- This mismatch could cause the GPU to interpret alpha as solid gray

### Secondary Possibilities:

1. **Shader Sampling Issue**: The text shader might be sampling the wrong channel
2. **Texture Coordinates**: UV coordinates might be wrong, causing all glyphs to sample the same solid area
3. **Blend Mode**: Alpha blending might be disabled or configured incorrectly

## Recommended Fix

### Step 1: Unify Texture Formats
Change atlas to use RGBA format to match the rest of the pipeline:
```zig
// In font_atlas.zig line 71
.format = c.sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,  // Was R8_UNORM
```

### Step 2: Update Upload Logic
Expand single-channel bitmap to RGBA during upload:
```zig
// When uploading to atlas, convert R8 to RGBA
for (bitmap) |alpha| {
    rgba_buffer[i*4 + 0] = 255;  // R
    rgba_buffer[i*4 + 1] = 255;  // G  
    rgba_buffer[i*4 + 2] = 255;  // B
    rgba_buffer[i*4 + 3] = alpha; // A
}
```

### Step 3: Verify Shader
Check that the text shader samples the alpha channel correctly:
```hlsl
float4 texColor = texture.Sample(sampler, uv);
outputColor = float4(color.rgb, color.a * texColor.a);  // Use alpha channel
```

## Testing Strategy

1. **Isolate the issue**: Create a simple test that renders a single glyph
2. **Check texture data**: Dump the texture to verify it contains the glyph
3. **Test shader**: Use a solid color texture to verify shader works
4. **Compare formats**: Test both R8 and RGBA formats to see difference

## Files to Check
- `src/lib/font_atlas.zig` - Texture format and upload
- `src/shaders/source/text.hlsl` - How alpha is sampled
- `src/lib/text_renderer.zig` - Blend mode configuration
- `src/lib/simple_gpu_renderer.zig` - Text rendering pipeline setup