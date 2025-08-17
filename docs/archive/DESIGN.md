# Zzz Game Engine - Design Document

> ⚠️ AI slop code and docs, is unstable and full of lies

## Architecture Overview

**Pure Zig SDL3 GPU-based game engine with procedural rendering and reactive UI system.**

### Core Principles
- **GPU-First**: All rendering via SDL3 GPU API (Vulkan/D3D12)
- **Procedural**: No texture assets, algorithmic generation only
- **Performance**: 60+ FPS, minimal allocations, cache-friendly
- **Modular**: Capability-based library organization

## System Architecture

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   Game Logic    │  │   Reactive UI   │  │  Font Rendering │
│   (hex/)        │  │   (lib/ui/)     │  │   (lib/font/)   │
└─────────┬───────┘  └─────────┬───────┘  └─────────┬───────┘
          │                    │                    │
          └────────────────────┼────────────────────┘
                               │
                    ┌─────────┴───────┐
                    │   Engine Core   │
                    │   (lib/core/)   │
                    └─────────┬───────┘
                              │
                    ┌─────────┴───────┐
                    │   SDL3 GPU      │
                    │ (lib/platform/) │
                    └─────────────────┘
```

## Key Systems

### 1. Rendering Pipeline
- **GPU Shaders**: HLSL compiled to SPIRV/DXIL
- **Procedural Geometry**: SV_VertexID-based vertex generation
- **Distance Fields**: Anti-aliased primitives without textures
- **Text Rendering**: TTF parsing + rasterization to GPU textures

### 2. Reactive System (Svelte 5 Implementation)
- **Signals**: `$state` - mutable reactive state
- **Derived**: `$derived` - computed values with auto-tracking
- **Effects**: `$effect` - side effects with cleanup
- **Components**: Lifecycle-managed UI elements

### 3. Game Architecture
- **ECS-like**: Simple arrays + direct function calls
- **Zone System**: World divided into interconnected zones
- **Component Systems**: Combat, spells, physics, effects
- **Data-Driven**: ZON file configuration

### 4. Logging System
- **Compositional**: Compile-time output/filter/formatter composition
- **Configurable**: Central config + optional runtime overrides
- **Categorized**: GameLogger, UILogger, RenderLogger, FontLogger
- **Performance**: Zero runtime overhead, throttled output

## Module Organization

```
src/
├── lib/                    # Engine library
│   ├── core/              # Types, math, colors, memory
│   ├── platform/          # SDL3 bindings, input, window
│   ├── rendering/         # GPU, shaders, camera, drawing
│   ├── physics/           # Collision, shapes
│   ├── font/              # TTF parsing, rasterization
│   ├── text/              # Text rendering, caching
│   ├── reactive/          # Svelte 5 reactive system
│   ├── ui/                # UI components, layouts
│   ├── debug/             # Logging, profiling tools
│   └── vector/            # Vector graphics, bezier curves
├── hex/                   # Hex game implementation
├── hud/                   # Transparent HUD overlay
├── menu/                  # SvelteKit-style pages
└── shaders/               # HLSL shader sources
```

## Performance Strategy

### Rendering
- **Batch Operations**: Minimize draw calls and state changes
- **Instance Data**: GPU buffers for per-object data
- **Persistent/Immediate Modes**: Choose based on change frequency
- **Memory Pools**: Fixed-size allocations, avoid fragmentation

### Reactive System
- **Lazy Evaluation**: Compute only when accessed
- **Dependency Tracking**: Automatic, minimal overhead
- **Batched Updates**: Group changes for efficiency
- **Cache Optimization**: 95%+ hit rate for text rendering

### Font Rendering
- **Atlas Caching**: Reuse rasterized glyphs
- **LRU Management**: Evict least-used glyphs
- **Multiple Strategies**: Bitmap, SDF, oversampling
- **Circuit Breakers**: Prevent infinite retry loops

## Data Flow

### Game Loop
```
Input → Game Logic → Rendering → Present
  ↓         ↓           ↓
Events → Reactive → GPU Commands
```

### Reactive Updates
```
State Change → Derive → Effect → DOM/GPU Update
     ↓           ↓        ↓
  Signal → Computed → Side Effect
```

### Font Pipeline
```
Text → Font Manager → Glyph Cache → Atlas → GPU Texture
  ↓         ↓            ↓         ↓        ↓
UTF-8 → TTF Parse → Rasterize → Pack → Render
```

## Memory Management

### Allocation Strategy
- **Arena Allocators**: For temporary/scoped data
- **Pool Allocators**: For fixed-size objects
- **Global Allocator**: For persistent engine state
- **Stack Allocation**: For small, short-lived data

### Ownership Model
- **Single Owner**: Clear ownership hierarchy
- **Borrowing**: Const/mutable references
- **RAII**: Automatic cleanup via defer
- **No GC**: Explicit memory management

## Error Handling

### Result Types
- **Result(T, E)**: Explicit error handling
- **Optional**: For nullable values
- **Panic**: For unrecoverable errors
- **Error Propagation**: Via try/catch

### Debugging
- **Logging Throttle**: Prevent spam
- **Debug Overlays**: Real-time metrics
- **Visual Debugging**: ASCII art, heatmaps
- **Validation Layers**: GPU debugging

## Configuration

### Compile-Time
- **Const Configuration**: Performance-critical settings
- **Comptime Composition**: Zero-cost abstractions
- **Feature Flags**: Optional subsystems

### Runtime
- **ZON Files**: Human-readable configuration
- **Hot Reload**: Development productivity
- **User Preferences**: Persistent settings

## Testing Strategy

### Unit Tests
- **Pure Functions**: Math, algorithms
- **Component Tests**: Individual modules
- **Integration Tests**: System interactions

### Visual Tests
- **Reference Images**: Regression detection
- **Interactive Tests**: Manual verification
- **Performance Tests**: Frame time monitoring

## Development Workflow

### Tools
- **Zig Build**: Single build system
- **HLSL Compilation**: Automatic shader builds
- **Hot Reload**: Fast iteration
- **Debug Tools**: Profiling, visualization

### Code Quality
- **Idiomatic Zig**: Language best practices
- **DRY Principles**: Shared utilities
- **Clean Architecture**: Clear boundaries
- **Documentation**: Inline and external

## Success Metrics

### Performance
- **60+ FPS**: Consistent frame rate
- **<16ms Frame Time**: 60 FPS budget
- **<100MB Memory**: Reasonable footprint
- **95%+ Cache Hit**: Text rendering efficiency

### Quality
- **Readable Text**: All font sizes 12pt-72pt
- **No Crashes**: Stable operation
- **Clean Code**: Maintainable architecture
- **Fast Builds**: <5s incremental builds

## Future Roadmap

### Short Term
- Font rendering quality improvements
- Enhanced reactive UI components
- Performance monitoring integration

### Medium Term
- Vector graphics showcase
- Advanced animation system
- Multi-platform support

### Long Term
- Editor/tooling integration
- Asset pipeline
- Scripting system integration