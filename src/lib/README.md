# Dealt Engine Library

Core engine components providing SDL3-based rendering and framework functionality.

## Architecture

The `src/lib/` directory contains the engine-level components that are shared across different game implementations. This separation ensures clean architecture and reusability.

### Engine vs Game Separation

**Engine Layer (`src/lib/`):**
- Core types and data structures (`types.zig`)
- SDL3 integration and C bindings (`c.zig`)
- Camera system with fixed/follow modes (`camera.zig`)
- Input handling and processing (`input.zig`)
- Mathematical utilities (`maths.zig`)
- Low-level GPU renderer (`simple_gpu_renderer.zig`)
- Renderer interface for drawing operations (`renderer.zig`)
- Font and text rendering subsystem (`font_*.zig`, `text_*.zig`)
- Vector graphics and curve primitives (`vector_*.zig`, `curve_*.zig`, `gpu_vector_renderer.zig`)
- Reactive UI components (`ui/`, `reactive/`)
- Collision detection and physics (`collision.zig`)
- Resource management utilities (`resource_manager.zig`)

**Game Layer (`src/hex/` and similar):**
- Game-specific logic (entities, behaviors, combat)
- Game state management
- Game-specific rendering implementations
- Content and data definitions

### Key Components

#### Core Types (`types.zig`)
```zig
pub const Vec2 = struct { x: f32, y: f32 };
pub const Color = struct { r: u8, g: u8, b: u8, a: u8 };
pub const Rectangle = struct { x: f32, y: f32, w: f32, h: f32 };
```

#### Renderer Interface (`renderer.zig`)
Provides a clean interface for drawing operations that different renderers can implement:
```zig
const interface = lib_renderer.createInterface(&my_renderer);
interface.drawRect(cmd_buffer, render_pass, pos, size, color);
interface.drawCircle(cmd_buffer, render_pass, pos, radius, color);
```

#### Camera System (`camera.zig`)
Supports different camera modes for various game scenarios:
- **Fixed**: Shows entire world with adjustable zoom (e.g., overworld)
- **Follow**: Tracks player position with adjustable zoom (e.g., dungeons)

#### GPU Renderer (`simple_gpu_renderer.zig`)
Low-level SDL3 GPU rendering implementation:
- Shader management and compilation
- Procedural vertex generation
- Distance field rendering for anti-aliased shapes
- Buffer management and command submission
- Vector graphics integration with unified API

#### Font and Text Rendering Subsystem
Comprehensive pure Zig font rendering system:
- **Font Processing** (`font/`) - Low-level font operations
  - **TTF Parser** (`font/ttf_parser.zig`) - TTF file format parsing
  - **Rasterizer Core** (`font/rasterizer_core.zig`) - Glyph bitmap generation
  - **Font Atlas** (`font/font_atlas.zig`) - GPU texture atlas management
  - **Font Manager** (`font/manager.zig`) - Font loading and management
- **Text Rendering** (`text/`) - High-level text operations
  - **Text Renderer** (`text/renderer.zig`) - Dual-mode text rendering (bitmap/SDF)
  - **Text Layout** (`text/layout.zig`) - Advanced text positioning and alignment

#### Vector Graphics System
GPU-accelerated vector graphics with mathematical precision:
- **Vector Graphics** (`vector/`) - Mathematical curve operations
  - **Vector Paths** (`vector/path.zig`) - Bezier curve primitives and operations  
  - **GPU Vector Renderer** (`vector/gpu_renderer.zig`) - GPU-accelerated vector drawing
  - **Glyph Cache** (`vector/glyph_cache.zig`) - Advanced LRU caching system
- **Font Supporting Systems**
  - **Curve Tessellation** (`font/curve_tessellation.zig`) - Adaptive curve-to-line conversion
  - **SDF Renderer** (`text/sdf_renderer.zig`) - Signed Distance Field generation
  - **Font Metrics** (`font/font_metrics.zig`) - Comprehensive text measurement

```zig
// Vector graphics usage
try renderer.drawQuadraticCurve(cmd_buffer, render_pass, curve, color, 2.0);
try renderer.drawVectorCircle(cmd_buffer, render_pass, center, radius, color, 32);
renderer.setVectorQuality(.high);
```

## Usage Guidelines

### Creating New Games

1. **Use engine components**: Import from `../lib/` for core functionality
2. **Implement game logic**: Create game-specific files in your game directory
3. **Extend interfaces**: Implement renderer interfaces for custom drawing
4. **Follow patterns**: Use existing games like Hex as reference

### Engine Dependencies

Games should primarily depend on:
- `types.zig` for core data structures
- `camera.zig` for viewport management
- `input.zig` for user input handling
- `renderer.zig` for drawing interfaces

Avoid importing game-specific components from engine code to maintain clean separation.

### Rendering Architecture

```
Game Renderer (src/hex/game_renderer.zig)
    ↓ implements
Renderer Interface (src/lib/renderer.zig)
    ↓ uses
Simple GPU Renderer (src/lib/simple_gpu_renderer.zig)
    ↓ uses
SDL3 GPU API (src/lib/c.zig)
```

## Adding New Engine Features

1. **Identify scope**: Determine if feature belongs in engine or game layer
2. **Update interfaces**: Extend renderer interface if needed for drawing
3. **Maintain compatibility**: Ensure existing games continue to work
4. **Document changes**: Update this README and main documentation

## Performance Notes

- Engine prioritizes performance over backward compatibility
- Use squared distances for calculations when possible
- Leverage GPU instancing and batching in rendering
- Cache-friendly data structures preferred
- Fixed-size memory pools for allocation-heavy operations