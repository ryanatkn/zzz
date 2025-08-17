# GPU Performance Strategy

> ⚠️ AI slop code and docs, is unstable and full of lies

## Rendering Pipeline

### Draw Call Optimization
- **Minimize draw calls:** Batch similar primitives using instanced rendering
- **Reduce state changes:** Group by pipeline, then by uniform data, then by vertex data
- **Procedural generation:** Generate geometry in vertex shaders to reduce bandwidth
- **Distance field rendering:** High-quality circles/shapes without textures

### Memory & Bandwidth
- **Triple buffering:** Cycle GPU buffers to avoid CPU/GPU synchronization stalls
- **Uniform buffers:** Small frame-constant data (camera, time, screen size)
- **Instance buffers:** Large per-object data (positions, colors, radii)
- **Align data structures:** Use `extern struct` for GPU compatibility

### Shader Optimization
- **Minimize branching:** Use `step()`, `mix()`, `smoothstep()` instead of if/else
- **Precompute in CPU:** Pass complex calculations as uniforms, not recalculate per-pixel
- **Pack data efficiently:** RGBA colors as float4, positions as Vec2, etc.

### Algorithm Focus
- Replace CPU collision detection with GPU parallel approaches where beneficial
- Use squared distances to avoid expensive sqrt operations
- Batch entities by type/behavior for SIMD-friendly processing

## Procedural Rendering Patterns

The engine uses procedural vertex generation extensively to minimize bandwidth:

```hlsl
// Example: Generate quad vertices from SV_VertexID
float2 GetQuadVertex(uint vertexID) {
    uint quad_index = vertexID / 6;
    uint vertex_in_quad = vertexID % 6;
    // Generate vertices procedurally...
}
```

Key patterns:
- Use `SV_VertexID` instead of vertex buffers for basic shapes
- Generate vertices in vertex shader from instance data
- Minimize vertex attribute requirements

## SDL3 GPU Critical Requirements

### Shader Requirements
- Vertex shaders: `register(b[n], space1)` for uniform buffers
- Push uniforms BEFORE `SDL_BeginGPURenderPass()`
- Avoid float4 arrays in HLSL cbuffers (use individual floats)
- Screen→NDC coordinate conversion with aspect ratio correction

### Pipeline State
- Start with minimal state, add complexity incrementally
- Follow SDL3 BasicTriangle pattern for pipeline creation
- Use procedural vertex generation to avoid vertex buffer setup

## Performance Benchmarks

Target performance metrics:
- 60 FPS with 1000+ entities
- <2ms GPU frame time for typical scenes
- 95%+ cache hit rate for persistent rendering
- ~50ns per AI command processing

## Rendering Mode Selection

Choose rendering mode based on update frequency:
- **Immediate Mode:** Content changes >10 times/sec (particles, debug values)
- **Persistent Mode:** Content changes <5 times/sec (UI, HUD, menus)
- Use `rendering_modes.recommendModeByRate(changes_per_second)` for auto-selection

## Visual Effects Optimization

### Particle Systems
- Use additive blending for performance
- Pool particle instances to avoid allocations
- Batch all particles of same type in single draw call
- Limit to 256 simultaneous effects

### Distance Fields
- High-quality anti-aliased shapes without textures
- Single sample per pixel with smooth edges
- Combine multiple shapes in single shader pass

## Future Optimizations

Planned performance improvements:
- GPU-based frustum culling
- Compute shader particle systems
- Indirect drawing for dynamic batching
- GPU-driven rendering pipeline