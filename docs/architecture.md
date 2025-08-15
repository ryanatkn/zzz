# Zzz Architecture

## Overview

Zzz uses a **capability-based architecture** that organizes modules by what they enable rather than what they are. This creates natural dependency flows while maintaining unrestricted module access.

## Architectural Principles

### 1. Capability-Based Organization
Modules are grouped by the capabilities they provide to the system:
- **Core**: Fundamental types and utilities everything depends on
- **Platform**: System integration and external interfaces
- **Rendering**: Graphics pipeline and visual capabilities
- **Physics**: Spatial reasoning and collision systems
- **Subsystems**: Advanced features built on core capabilities

### 2. No Arbitrary Restrictions
All modules can access any other module they need. The organization provides logical structure without enforcing rigid boundaries.

### 3. Dependency Direction
While not enforced, the natural dependency flow is:
```
Core → Platform → Rendering → Physics → Subsystems
```

## Directory Structure

```
src/lib/
├── core/           # Fundamental types and utilities
├── platform/       # System integration
├── rendering/      # Graphics pipeline
├── physics/        # Spatial systems
├── reactive/       # Reactive UI system
├── font/          # Font processing
├── text/          # Text rendering
├── vector/        # Vector graphics
├── ui/            # UI components
└── debug/         # Debug utilities
```

## Core Capabilities (`core/`)

The foundation layer providing basic types and utilities:

### types.zig
- `Vec2`: 2D vector type
- `Color`: RGBA color representation
- `Rectangle`: Axis-aligned rectangle

### maths.zig
- Vector operations (vec2_* prefixed functions)
- Distance calculations (prefer squared for performance)
- Transformations and interpolation

### colors.zig
- Color manipulation (darken, lighten)
- HSV conversion
- Theme utilities

### viewport.zig
- Viewport interface for dependency inversion
- Breaks circular dependencies between platform and rendering

### result.zig
- `Result(T, E)`: Rust-like error handling
- Comprehensive Result API with map, andThen, orElse

### pool.zig
- `ResourcePool`: Recharging resource pools (ammo, mana)
- `ObjectPool`: Fixed-size object recycling

### id.zig
- `ID(T)`: Type-safe entity IDs
- `IDGenerator`: Thread-safe ID generation
- `HandleSystem`: Sparse array with generation tracking
- `UUID`: RFC 4122 compliant UUIDs

## Platform Layer (`platform/`)

System integration and external interfaces:

### sdl.zig
- SDL3 C bindings
- Platform constants and enums

### input.zig
- `InputState`: Unified input handling
- Keyboard, mouse, controller support
- Uses viewport interface (no rendering dependency)

### window.zig
- `WindowGPU`: Window and GPU device management
- Platform-agnostic window creation

### resources.zig
- `PlatformResources`: Resource initialization
- `SharedFontManager`: Reference-counted fonts
- No rendering dependencies

## Rendering Pipeline (`rendering/`)

Complete graphics capabilities:

### interface.zig
- `RendererInterface`: Abstract drawing operations
- Implementation-agnostic API

### gpu.zig
- `SimpleGPURenderer`: SDL3 GPU backend
- Shader management
- Buffer handling

### shaders.zig
- `ShaderManager`: Shader compilation and caching
- HLSL to SPIRV/DXIL compilation

### camera.zig
- `Camera`: Fixed and follow modes
- World-to-screen transformations

### modes.zig
- Rendering mode selection (immediate vs persistent)
- Performance guidelines

### drawing.zig
- High-level UI drawing utilities
- Panels, buttons, overlays

## Physics System (`physics/`)

Collision detection and spatial reasoning:

### shapes.zig
- `Circle`, `Rectangle`, `Point`, `LineSegment`
- Shape operations (contains, overlaps, intersection)
- Bounding box calculations

### collision.zig
- Generic collision detection
- Shape-to-shape collision functions
- `CollisionResult` with penetration data

## Advanced Subsystems

### Reactive System (`reactive/`)
Complete Svelte 5 implementation:
- Signals, derived values, effects
- Automatic dependency tracking
- Push-pull reactivity

### Font System (`font/`)
Pure Zig font rendering:
- TTF parsing
- Rasterization
- Atlas management

### Text Rendering (`text/`)
- Dual-mode rendering (bitmap/SDF)
- Layout algorithms
- Caching strategies

### Vector Graphics (`vector/`)
- Bezier curve rendering
- GPU-accelerated paths
- Glyph caching

### UI Components (`ui/`)
- Reactive components
- Layout systems
- Debug overlays

## Import Patterns

### Direct Capability Imports
```zig
const types = @import("../lib/core/types.zig");
const input = @import("../lib/platform/input.zig");
const camera = @import("../lib/rendering/camera.zig");
```

### Barrel Imports for Subsystems
```zig
const reactive = @import("../lib/reactive.zig");
const ui = @import("../lib/ui.zig");
```

## Dependency Management

### Breaking Circular Dependencies
The architecture uses several patterns to avoid circular dependencies:

1. **Viewport Interface**: `core/viewport.zig` provides an interface that allows platform/input to work with rendering/camera without direct dependency

2. **Resource Separation**: Platform resources don't depend on specific renderer implementations

3. **Shape Extraction**: Physics shapes are separate from collision detection

### Natural Layering
While not enforced, the natural dependency flow prevents most circular dependencies:
- Core depends on nothing
- Platform depends only on core
- Rendering depends on core and platform
- Physics depends on core
- Subsystems can depend on any lower layer

## Performance Considerations

### Memory Management
- Fixed-size pools for frequently allocated objects
- Handle systems for stable references
- Minimal allocations in hot paths

### GPU Optimization
- Batch similar operations
- Minimize state changes
- Procedural vertex generation
- Distance field rendering

### Cache Efficiency
- Data-oriented design
- Squared distance calculations
- Persistent vs immediate rendering modes

## Extension Guidelines

### Adding New Capabilities
1. Identify the capability category
2. Create module in appropriate directory
3. Follow existing patterns for that capability
4. Update barrel exports if needed

### Creating New Games
1. Import capabilities as needed
2. No restrictions on cross-module access
3. Use barrel imports for convenience
4. Follow Hex game as reference

## Design Rationale

### Why Capability-Based?
- **Clear Purpose**: Each directory has a clear capability it provides
- **Natural Organization**: Modules naturally group by function
- **Flexible Access**: No artificial barriers between modules
- **Scalable**: New capabilities slot in naturally

### Why Not Traditional Layers?
- Rigid layers create artificial restrictions
- Real systems need cross-cutting concerns
- Performance often requires breaking layers
- Capability organization is more intuitive

## Migration from Flat Structure

The refactoring from flat to capability-based organization:

### Before (Flat)
```
lib/
├── types.zig
├── maths.zig
├── renderer.zig
├── input.zig
└── ...
```

### After (Capability-Based)
```
lib/
├── core/
│   └── types.zig
├── platform/
│   └── input.zig
├── rendering/
│   └── interface.zig
└── ...
```

### Benefits Realized
- Clearer module relationships
- Easier to find functionality
- Natural dependency flows
- Better scalability
- No breaking changes for users