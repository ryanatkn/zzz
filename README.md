# Dealt - SDL3 Game Engine with Hex Example Game

A GPU-accelerated game engine built with Zig, SDL3 GPU API, and HLSL shaders. Featuring the Hex 2D action RPG as a showcase implementation with pure algorithmic graphics and no texture assets.

## Quick Start

```bash
# Check Zig version
zig version  # Requires 0.14.1+

# Build and run (shaders compile automatically)
zig build run    # Build and launch game

# Manual shader compilation (if needed)
zig build shaders                    # Compile shaders only
zig build clean-shaders             # Clean rebuild shaders
```

## Architecture

**Dealt Engine** provides the core SDL3 framework and rendering infrastructure in `src/lib/`, while **Hex** demonstrates the engine capabilities as a complete game implementation in `src/hex/`.

## Features

### Engine Capabilities (src/lib/)
- **SDL3 GPU API**: Cross-platform rendering with Vulkan/D3D12
- **Camera System**: Fixed and follow modes with smooth transitions
- **Input Handling**: Unified keyboard/mouse input processing
- **Renderer Interface**: Clean abstraction for drawing operations
- **Math Utilities**: Optimized vector math and collision helpers

### Hex Game Showcase (src/hex/)
- **Movement**: WASD direct control + Shift to walk + Ctrl+mouse movement
- **Combat**: Left-click shooting with burst/rhythm mechanics  
- **Spells**: 8-slot spell system with targeted/self-cast modes
- **World**: Zone-based travel system with portals between areas
- **Respawn**: Lifestone checkpoints with persistent attunement
- **Effects**: GPU-accelerated visual effects with AoE indicators

### Technical Highlights
- **GPU-First**: SDL3 GPU API with Vulkan/D3D12 backends
- **Procedural Rendering**: No textures - pure algorithmic shape generation
- **Distance Fields**: Anti-aliased primitives via shader mathematics
- **Data-Driven**: Zone configuration through ZON files
- **Clean Architecture**: Engine/game separation for reusability

## Game Controls

### Movement
- **WASD**: Direct movement
- **Shift + Move**: Walk mode (slower)
- **Ctrl + Left-click**: Move to mouse position

### Combat
- **Left-click**: Fire bullets (burst/rhythm mode)
  - Hold for automatic rhythm shooting
  - Click for burst shots
  - 6-bullet pool with 2/sec recharge
- **Right-click**: Cast active spell at target
- **Ctrl + Right-click**: Self-cast active spell

### Spells
- **Number Keys 1-4**: Select spell slots 1-4
- **Q, E, R, F**: Select spell slots 5-8
  - **Slot 1 - Lull**: Reduces enemy aggro by 80% in target area (12s)
  - **Slot 2 - Blink**: Teleport to location (dungeon only)
  - **Slots 3-8**: Available for future spells

### System
- **Space**: Pause/unpause game
- **R**: Respawn when dead (spell slot 7 when alive)
- **T**: Reset current zone units
- **Y**: Full game reset (including lifestones)
- **Backtick (`)**: Open system menu/character sheet
- **ESC**: Quit game
- **Mouse Wheel**: Zoom in/out

### Visual Elements
- **Blue Circle**: Player character
- **Red Circles**: Enemy units (bright = aggro, dim = passive)
- **Green Rectangles**: Solid obstacles
- **Orange Rectangles**: Deadly hazards
- **Purple Circles**: Zone portals
- **Cyan Circles**: Lifestone checkpoints
- **Purple/Blue Areas**: Spell effect zones (Lull)

## Project Structure

```
dealt/
├── src/
│   ├── lib/                     # Engine library (shared components)
│   │   ├── camera.zig           # Camera system
│   │   ├── input.zig            # Input handling
│   │   ├── maths.zig            # Math utilities
│   │   ├── renderer.zig         # Renderer interface
│   │   ├── simple_gpu_renderer.zig # GPU backend
│   │   └── types.zig            # Core data types
│   ├── hex/                     # Hex game implementation
│   │   ├── main.zig             # Game entry point
│   │   ├── game.zig             # Game state management
│   │   ├── game_renderer.zig    # Game-specific rendering
│   │   ├── entities.zig         # Entity system
│   │   ├── behaviors.zig        # Entity behaviors
│   │   ├── combat.zig           # Combat & bullet pool system
│   │   ├── spells.zig           # Spell system implementation
│   │   ├── physics.zig          # Collision detection
│   │   ├── player.zig           # Player controller
│   │   ├── effects.zig          # Visual effects system
│   │   └── game_data.zon        # Zone configuration
│   ├── browser/                 # Browser/menu system
│   │   └── browser.zig          # Menu implementation
│   ├── routes/                  # Menu pages (SvelteKit-style)
│   │   ├── +page.zig            # Home page
│   │   ├── character/           # Character sheet
│   │   ├── settings/            # Settings pages
│   │   └── stats/               # Statistics
│   ├── shaders/                 # HLSL shaders
│   │   ├── source/              # Shader sources
│   │   └── compiled/            # Platform bytecode
│   └── docs/                    # Technical documentation
├── build.zig                    # Build configuration
├── build.zig.zon                # Package manifest
├── README.md                    # This file
└── CLAUDE.md                    # AI assistant documentation
```

For complete technical documentation and development guidelines, see **[CLAUDE.md](./CLAUDE.md)**.

## Documentation

### Engine Documentation
- [Engine Architecture](./src/lib/README.md) - Engine/game separation and usage
- [Entity System](./src/docs/ecs.md) - Entity storage and update patterns
- [GPU API Reference](./src/docs/gpu.md) - SDL3 GPU API usage
- [Shader Compilation](./src/docs/shader_compilation.md) - HLSL workflow

## Building from Source

```bash
# Standard workflow
zig build              # Build the game
zig build run          # Build and run

# Shader compilation
zig build shaders          # Compile shaders only
zig build clean-shaders    # Clean rebuild all shaders

# Cross-compilation
zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast  # Windows release
zig build -Doptimize=ReleaseFast                          # Native release
```

## Creating New Games

The Dealt engine is designed for creating new games. To start a new game:

1. **Create game directory**: `src/mygame/`
2. **Import engine components**: Use `@import("../lib/types.zig")` etc.
3. **Implement game logic**: Follow Hex patterns as reference
4. **Update build.zig**: Add your game as a new executable

Example structure:
```zig
// src/mygame/main.zig
const lib = struct {
    const types = @import("../lib/types.zig");
    const camera = @import("../lib/camera.zig");
    const renderer = @import("../lib/renderer.zig");
};

// Your game implementation using engine components
```

## Technical Details

### GPU Rendering Pipeline

**Shader Requirements:**
- Vertex shaders: `register(b[n], space1)` for uniforms
- Fragment shaders: `register(b[n], space0)`
- Procedural vertex generation via `SV_VertexID`
- Distance field techniques for anti-aliasing

### Performance Optimizations

**GPU Strategies:**
- Batch by shape type (circles, rectangles)
- Minimize pipeline state changes
- Use distance fields for anti-aliasing
- Procedural generation reduces bandwidth

**CPU Strategies:**
- Fixed-size memory pools
- Squared distance calculations
- Cache-friendly data structures
- Zone-based spatial partitioning

## Requirements

### System Requirements
- **Zig**: 0.14.1 or newer
- **GPU**: Vulkan 1.0 or DirectX 12 support
- **OS**: Windows 10+, Linux, macOS 10.14+
- **RAM**: 256MB minimum

### Dependencies
- **SDL3**: Window management and GPU API (auto-fetched)
- **SDL_shadercross**: HLSL compilation (for development)

## Contributing

Contributions are welcome! The engine prioritizes:
- Performance over backward compatibility
- Procedural generation over asset loading
- Clean architecture and separation of concerns
- GPU-first rendering approaches

## License

See LICENSE file in project root.

## Credits

Built with:
- [Zig](https://ziglang.org/) - Systems programming language
- [SDL3](https://libsdl.org/) - Cross-platform GPU API
- [SDL_shadercross](https://github.com/libsdl-org/SDL_shadercross) - Shader compilation