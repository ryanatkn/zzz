# Zzz Engine Library

> ⚠️ AI slop code and docs, is unstable and full of lies

Core engine providing GPU-accelerated rendering, reactive UI, and game systems with zero external dependencies.

## Architecture Overview

**Organization:** Capability-based - modules grouped by what they enable, not what they are
**Philosophy:** Performance-first, procedural generation, GPU-driven design
**Dependencies:** Zero external packages - all vendored and self-contained

For detailed architecture documentation, see [docs/architecture.md](../../docs/architecture.md)

## Directory Structure

### Core Capabilities (`core/`)
Fundamental types and utilities:
- **types.zig** - Vec2, Color, Rectangle
- **colors.zig** - Color manipulation, HSV, theming
- **viewport.zig** - Dependency inversion interface
- **result.zig** - Result(T, E) error handling
- **pool.zig** - Resource and object pooling
- **id.zig** - Type-safe IDs, handle systems

### Platform Layer (`platform/`)
System integration:
- **sdl.zig** - SDL3 C bindings
- **input.zig** - Unified input handling
- **window.zig** - Window and GPU device management
- **resources.zig** - Resource initialization

### Rendering Pipeline (`rendering/`)
GPU graphics capabilities:
- **interface.zig** - Abstract renderer interface
- **gpu.zig** - SDL3 GPU backend
- **shaders.zig** - HLSL compilation and caching
- **camera.zig** - Fixed/follow camera modes
- **modes.zig** - Immediate vs persistent rendering
- **drawing.zig** - High-level UI utilities

### Physics System (`physics/`)
Collision and spatial reasoning:
- **collision.zig** - Shape-to-shape collision
- **shapes.zig** - Circle, Rectangle, Line, Point
- **queries.zig** - Spatial queries (planned)

### Game Systems (`game/`)
Core game infrastructure:
- **ecs.zig** - Entity Component System (simplified)
- **zone.zig** - Zone-based world system
- **events/** - Pub/sub event system
- **state/** - State management and caching
- **control/** - Lock-free AI control interface
- **persistence/** - Save/load system

### Advanced Subsystems

#### Reactive System (`reactive/`)
Complete Svelte 5 implementation:
- Signal-based state management
- Derived values with lazy evaluation
- Effects with lifecycle control
- 95%+ cache hit rate

#### Font System (`font/`)
Pure Zig TTF rendering:
- Complete TTF parser
- CPU rasterization
- GPU atlas generation
- Zero dependencies

#### Text Rendering (`text/`)
- Dual-mode: bitmap and SDF
- Advanced layout algorithms
- Persistent caching

#### Vector Graphics (`vector/`)
- GPU-accelerated Bezier curves
- Path tessellation
- Glyph caching

#### UI Components (`ui/`)
- Reactive components
- FPS counter, debug overlay
- Layout systems

#### Debug Tools (`debug/`)
- Composable logging
- Performance profiling
- Visual debugging

## Key Systems

### Reactive System
```zig
// Svelte 5 compatible reactivity
const count = signal(0);
const doubled = derived(&count, |c| c.get() * 2);
const effect = createEffect(&count, |c| {
    updateUI(c.get());
});
```

### GPU Rendering
```zig
// Procedural vertex generation
// No vertex buffers, use SV_VertexID
// Distance fields for anti-aliasing
// Batched instanced rendering
```

### AI Control
```zig
// Lock-free ring buffer
// Memory-mapped interface
// ~50ns per command
game.initAIControl(allocator);
```

## Import Patterns

### Direct Capability Imports
```zig
// From game code
const types = @import("../lib/core/types.zig");
const input = @import("../lib/platform/input.zig");
const camera = @import("../lib/game/camera/camera.zig");
```

### Barrel Imports
```zig
// Complete subsystems
const reactive = @import("../lib/reactive/mod.zig");
const ui = @import("../lib/ui.zig");
```

### Within Library
```zig
// Same capability
const types = @import("types.zig");

// Cross-capability
const sdl = @import("../platform/sdl.zig");
```

## Usage Guidelines

### Creating New Capabilities
1. Identify capability category
2. Create module in appropriate directory
3. Follow existing patterns
4. Update barrel exports if needed
5. Add tests in same file

### Creating New Games
1. Create directory in `src/yourgame/`
2. Import capabilities as needed
3. Follow Hex patterns as reference
4. No cross-module restrictions

### Performance Requirements
- Zero allocations in hot paths
- Squared distances for comparisons
- Procedural generation over assets
- Batch GPU operations
- Fixed-size pools

## Testing

```bash
# Run all tests (includes lib tests)
zig build test

# Run specific test patterns
zig build test -Dtest-filter="reactive"  # Reactive system tests
zig build test -Dtest-filter="font"      # Font rendering tests

# Show detailed test summary  
zig build test --summary all

# Visual tests
zig build run  # Navigate to test pages
```

## Common Tasks

### Adding a Core Type
- Place in `core/types.zig` or new file
- Use `extern struct` for GPU compatibility
- Add tests in same file

### Creating UI Component
- Extend `ReactiveComponent` base
- Place in `ui/` directory
- Use reactive primitives
- See `fps_counter.zig` example

### Adding Rendering Feature
- Implement `RendererInterface`
- Use procedural vertex generation
- Follow SDL3 GPU patterns
- Test with all backends

## Performance Characteristics

- **Reactive System:** 95%+ cache hit rate
- **AI Control:** ~50ns per command
- **Text Rendering:** Dual-mode with caching
- **GPU Pipeline:** Batched, instanced rendering
- **Memory:** Fixed pools, minimal allocations
- **Target:** 60 FPS with 1000+ entities

## Documentation

- **AI Assistant Guide:** [CLAUDE.md](./CLAUDE.md)
- **Architecture:** [docs/architecture.md](../../docs/architecture.md)
- **GPU Performance:** [docs/gpu-performance.md](../../docs/gpu-performance.md)
- **Development:** [docs/development-workflow.md](../../docs/development-workflow.md)

## Philosophy

- **Performance First:** Always optimize for final code
- **Procedural Generation:** Algorithms over assets
- **Zero Dependencies:** Everything vendored
- **GPU-Driven:** Leverage GPU for everything
- **Capability-Based:** Organize by function