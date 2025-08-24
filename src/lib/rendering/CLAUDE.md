# Rendering System - AI Assistant Guide

## Domain: GPU Operations & Graphics Pipeline

**Purpose:** Handle all GPU-side rendering operations, from device management to draw calls.

## Core Responsibilities

### ✅ What rendering/ DOES:
- GPU device and command buffer management
- Shader compilation and pipeline creation
- Texture creation, upload, and sampling
- Uniform buffer management and pushing
- Render pass and frame management
- Primitive drawing (shapes, particles)
- Viewport and coordinate transformations

### ❌ What rendering/ DOES NOT do:
- Parse font files (that's font/)
- Layout text strings (that's text/)
- Manipulate bitmap pixels on CPU (that's image/)
- Manage game state or logic

## Key Modules

### Core Infrastructure (`core/`)
- `gpu.zig` - Main GPU renderer and device management
- `uniforms.zig` - GPU-aligned uniform structures
- `pipelines.zig` - Graphics pipeline creation
- `frame.zig` - Frame and render pass lifecycle
- `texture_formats.zig` - Texture format utilities (our new shared module)

### Drawing Operations (`primitives/`)
- Shape rendering (circles, rectangles)
- Particle systems
- Batch rendering optimizations

### Spatial Systems (`spatial/`)
- Coordinate transformations (world→screen→NDC)
- Viewport management
- Visibility culling

## Working with Textures

```zig
// Use shared texture utilities
const tex_format = texture_formats.TextureFormat.fontAtlasFormat();
const texture = try texture_formats.TextureCreation.createFontAtlasTexture(device, 2048, 2048);

// Upload data
try texture_formats.TextureTransfer.uploadToTexture(device, texture, data, width, height, 0, 0);
```

## Performance Guidelines

- Batch similar draw calls together
- Minimize pipeline state changes
- Use procedural vertex generation (SV_VertexID)
- Keep uniform structures GPU-aligned (extern struct)

## Common Patterns

```zig
// Begin frame → render pass → draw → end
const cmd = try frame.beginFrame(device, window);
const pass = try frame.beginRenderPass(cmd, window, bg_color);
// ... draw operations ...
c.sdl.SDL_EndGPURenderPass(pass);
_ = c.sdl.SDL_SubmitGPUCommandBuffer(cmd);
```

## Testing

Most rendering code requires SDL/GPU context, so tests are limited to:
- Data structure validation (uniforms.zig)
- Coordinate math (spatial/)
- Format utilities (texture_formats.zig)