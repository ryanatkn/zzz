# Shaders - AI Assistant Guide

> ⚠️ AI slop code and docs, is unstable and full of lies

HLSL shaders for procedural rendering. All visuals are generated algorithmically without texture assets.

## Quick Reference

**Language:** HLSL (High Level Shading Language)
**Compilation:** SDL_shadercross → SPIRV (Vulkan) + DXIL (D3D12)
**Pattern:** Procedural vertex generation using SV_VertexID

## Directory Structure

```
shaders/
├── source/                 # HLSL source files
│   ├── circle.hlsl        # Distance field circles
│   ├── rectangle.hlsl     # Rectangles with borders
│   ├── particle.hlsl      # Particle effects
│   ├── text.hlsl          # Bitmap text rendering
│   ├── text_sdf.hlsl      # SDF text rendering
│   └── triangle.hlsl      # Basic triangle test
├── compiled/              # Platform-specific bytecode
│   ├── vulkan/*.spv       # SPIRV for Vulkan
│   └── d3d12/*.dxil       # DXIL for Direct3D 12
└── compile_shaders.sh     # Compilation script
```

## Shader Patterns

### Procedural Vertex Generation
```hlsl
// Generate vertices from ID, no vertex buffer
VSOutput vs_main(uint vertex_id : SV_VertexID) {
    uint instance_id = vertex_id / 6;  // 6 verts per quad
    uint vert_in_quad = vertex_id % 6;
    
    // Generate quad positions procedurally
    float2 positions[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1), float2(1, -1), float2(1, 1)
    };
    
    float2 local_pos = positions[vert_in_quad];
    // ... transform to world space
}
```

### Distance Fields
```hlsl
// Anti-aliased circle using distance field
float4 ps_main(PSInput input) : SV_Target {
    float dist = length(input.uv - float2(0.5, 0.5));
    float alpha = 1.0 - smoothstep(0.48, 0.5, dist);
    return float4(input.color.rgb, input.color.a * alpha);
}
```

### Uniform Buffers
```hlsl
// CRITICAL: Use register(b0, space1) for vertex shaders
cbuffer FrameData : register(b0, space1) {
    float4x4 view_proj;
    float2 screen_size;
    float time;
    float _padding;
}
```

## Common Modifications

### Adding a New Shader
1. Create HLSL file in `source/`
2. Define vertex and pixel shaders
3. Run compilation script
4. Register in Zig code

### Modifying Existing Shader
1. Edit HLSL source
2. Run `./compile_shaders.sh`
3. Test with `zig build run`
4. Check both Vulkan and D3D12

### Compilation Commands
```bash
# Compile all shaders
cd src/shaders
./compile_shaders.sh

# Clean rebuild
./compile_shaders.sh clean

# Single shader (manual)
shadercross --input source/circle.hlsl --output compiled/vulkan/circle_vs.spv \
    --stage vertex --target spirv --entry vs_main
```

## Critical Requirements

### SDL3 GPU Patterns
- Push uniforms BEFORE `SDL_BeginGPURenderPass()`
- Vertex shaders use `register(b[n], space1)`
- Pixel shaders use `register(b[n], space0)`
- Avoid float4 arrays in cbuffers

### Coordinate Systems
- Screen space: (0,0) at top-left
- NDC: (-1,-1) to (1,1)
- Aspect ratio correction required

### Performance
- Minimize texture samples
- Use step/smoothstep over branching
- Precompute in vertex shader
- Pack data efficiently

## Shader Types

### Shape Shaders
- `circle.hlsl` - Distance field circles
- `rectangle.hlsl` - Rectangles with optional borders
- `simple_circle.hlsl` - Basic filled circles
- `simple_rectangle.hlsl` - Basic filled rectangles

### Particle Shaders
- `particle.hlsl` - Particle effects with additive blending
- `debug_circle.hlsl` - Debug visualization

### Text Shaders
- `text.hlsl` - Bitmap font rendering
- `text_sdf.hlsl` - Signed distance field text

### Test Shaders
- `triangle.hlsl` - Basic triangle for testing
- `triangle_uniforms.hlsl` - Uniform buffer testing

## Troubleshooting

### Shader Not Rendering
- Check uniform buffer binding
- Verify vertex generation logic
- Ensure pipeline state matches
- Check blend mode settings

### Compilation Errors
- Verify HLSL syntax
- Check entry point names
- Ensure shadercross is installed
- Review error messages carefully

### Platform Issues
- Test both Vulkan and D3D12
- Check platform-specific paths
- Verify bytecode format
- Use correct file extensions

## Best Practices

- Keep shaders simple and focused
- Use procedural generation
- Avoid texture dependencies
- Comment complex math
- Test on all platforms
- Profile GPU performance

## Related Documentation

- [GPU Performance](../../docs/gpu-performance.md) - Optimization
- [Shader Compilation](../../docs/hex/shader_compilation.mdz) - Details
- [Rendering](../lib/rendering/) - GPU pipeline