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