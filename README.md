# Zzz

> ⚠️ AI slop code and docs, may be unstable and bad

Zzz is a GUI in Zig written by Claude Code and designed by people.
For the companion CLI see [zz](https://github.com/ryanatkn/zz)
and [ztack.net](https://www.ztack.net/) for a web+ stack.

> status: vibe-engineered slop level 1

## Quick start

```bash
# Check Zig version
zig version  # Requires 0.14.1+

# Build and run the Hex demo (shaders compile automatically)
zig build run
```

## What it does

Zzz is a graphics and media programming environment that generates all visuals through code and mathematics - no texture or sprite assets. It provides a framework for building creative tools, games, and interactive applications with procedural content generation.

The library (`src/lib/`) provides core graphics and media capabilities with a capability-based architecture. The included Hex action RPG (`src/hex/`) demonstrates these capabilities as a complete game with zone-based worlds, reactive UI, and GPU-accelerated effects running at 60+ FPS.

## Architecture

### Engine capabilities (src/lib/)
- **Core primitives**: types, math, colors, viewport, result handling, object pools, ID generation
- **Platform layer**: SDL3 integration, input handling, window management, resource loading
- **Rendering system**: GPU backend, camera, shaders, drawing utilities, render modes
- **Physics system**: collision detection, shape definitions (circle, rectangle, line, point)
- **Reactive UI**: complete Svelte 5 implementation with signals, effects, and derived state
- **Font & text**: pure Zig TTF parsing, rasterization, SDF rendering, layout
- **Vector graphics**: GPU-accelerated Bezier curves, path rendering, glyph caching
- **Component system**: reactive UI components with automatic lifecycle management
- **AI control**: lock-free memory-mapped input injection for external control

## Hex demo controls

### Movement
- **WASD**: direct movement
- **Shift + Move**: walk mode (slower)
- **Ctrl + Left-click**: move to mouse position

### Combat
- **Left-click**: fire bullets (burst/rhythm mode)
  - hold for automatic rhythm shooting
  - click for burst shots
  - 6-bullet pool with 2/sec recharge
- **Right-click**: cast active spell at target
- **Ctrl + Right-click**: self-cast active spell

### Spells
- **Number Keys 1-4**: select spell slots 1-4
- **Q, E, R, F**: select spell slots 5-8
  - **Slot 1 - Lull**: reduces enemy aggro by 80% in target area (12s)
  - **Slot 2 - Blink**: teleport to location (dungeon only)

### System
- **Space**: pause/unpause game
- **R**: respawn when dead
- **T**: reset current zone units
- **Y**: full game reset
- **G**: toggle AI control mode
- **Backtick (`)**: toggle transparent HUD overlay
- **ESC**: quit game
- **Mouse Wheel**: zoom in/out

### Visual elements
- **Blue Circle**: player character
- **Red Circles**: enemy units (bright = aggro, dim = passive)
- **Green Rectangles**: solid obstacles
- **Orange Rectangles**: deadly hazards
- **Purple Circles**: zone portals
- **Cyan Circles**: lifestone checkpoints
- **Purple/Blue Areas**: spell effect zones

## Project structure

For technical docs and development guidelines, see **[CLAUDE.md](./CLAUDE.md)**.

## Documentation

- [Framework Architecture](./src/lib/README.md) - capability-based organization
- [GPU Programming Guide](./src/docs/gpu.md) - SDL3 GPU API usage
- [Shader Development](./src/docs/shader_compilation.md) - HLSL workflow
- [Reactive Programming](./src/lib/reactive.zig) - Svelte 5 implementation
- [Application Patterns](./src/docs/ecs.md) - entity systems and architecture

## Building from source

```bash
# Standard workflow
zig build              # build the game
zig build run          # build and run

# Shader compilation
zig build shaders          # compile shaders only
zig build clean-shaders    # clean rebuild all shaders

# Cross-compilation
zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast  # Windows release
zig build -Doptimize=ReleaseFast                          # native release
```

## AI Control

The game includes a high-performance AI control system that allows external programs to control the game:

1. **Enable AI mode**: Press `G` in-game to toggle AI control
2. **Run controller**: Use the provided Python example or write your own controller
3. **Protocol**: Binary commands via memory-mapped file (`.ai_commands`)

Example usage:
```bash
# Start the game
zig build run

# In game, press G to enable AI control

# In another terminal, run the Python controller
python3 ai_control_example.py
```

The AI control system uses a lock-free ring buffer for ultra-low latency (~50ns per command) with zero allocations during runtime. 

Available controllers:
- **Python**: `ai_control_example.py` - Command-line controller
- **TypeScript**: `ai_control_example.ts` - Node.js/Deno controller  
- **Web UI**: `ai_control_example.svelte` - Visual control interface (run `npm install && npm run dev`)

See [AI_CONTROL_WEB.md](./AI_CONTROL_WEB.md) for web interface documentation.

## Creating new applications

Zzz is designed for creating games, creative tools, and interactive applications:

1. Create project directory: `src/myapp/`
2. Import library components from `src/lib/`
3. Implement your application (follow Hex patterns as reference)
4. Update build.zig with new executable

Example:
```zig
// src/myapp/main.zig
const std = @import("std");

// Import from capability directories
const types = @import("../lib/core/types.zig");
const maths = @import("../lib/core/maths.zig");
const input = @import("../lib/platform/input.zig");
const camera = @import("../lib/rendering/camera.zig");
const collision = @import("../lib/physics/collision.zig");

// Or use barrel imports for subsystems
const reactive = @import("../lib/reactive.zig");
const ui = @import("../lib/ui.zig");
```

## Technical details

### GPU rendering
- Vertex shaders: `register(b[n], space1)` for uniforms
- Fragment shaders: `register(b[n], space0)`
- Procedural vertex generation via `SV_VertexID`
- Distance field techniques for anti-aliasing

### Performance
- Batch by shape type
- Minimize pipeline state changes
- Fixed-size memory pools
- Zone-based spatial partitioning

## System requirements

- **Zig**: 0.14.1 or newer
- **GPU**: Vulkan 1.0 or DirectX 12 support
- **OS**: Windows 10+, Linux, macOS 10.14+
- **RAM**: 256MB minimum

### Dependencies (automatically managed)
- **SDL3**: cross-platform window management and GPU API
- **SDL_shadercross**: HLSL shader compilation
- **webref**: machine-readable references of terms defined in web browser specifications

## Contributing

Issues and discussions are welcome, but reviewing code is time consuming,
so I will likely reject many well-meaning PRs, and re-implement if I agree with the idea.
So if you don't mind the rejection and just care about getting the change in,
PRs are very much encouraged! They are excellent for concrete discussion.
Not every PR needs an issue but it's usually
preferred to reference one or more issues and discussions.

## License

See LICENSE file in project root.

## Credits

Built with (see [./deps](./deps)):
- [Zig](https://ziglang.org/) - systems programming language
- [SDL3](https://libsdl.org/) - cross-platform GPU API
- [SDL_shadercross](https://github.com/libsdl-org/SDL_shadercross) - shader compilation
- [Claude Code](https://claude.ai/code) - AI-powered development