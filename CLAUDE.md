# Dealt - SDL3 Game Engine with Hex Game Implementation



A GPU-accelerated game engine built with Zig, SDL3 GPU API, and HLSL shaders, featuring the Hex 2D action RPG as a reference implementation.

Performance is a top priority, and we dont care about backwards compat - always try to get to the final best code.

## Environment

```bash
$ zig version
0.14.1
```

Dependencies: SDL3 (auto-fetched), SDL_shadercross (HLSL→SPIRV/DXIL compilation)

## Design Philosophy

**Procedural-First Approach:**
- All visuals generated algorithmically - no texture or sprite assets
- Shapes, effects, and animations defined entirely in code and shaders
- Distance field techniques for high-quality anti-aliased primitives
- Mathematical beauty over static content

**GPU-First Architecture:**
- SDL3 GPU API with Vulkan/D3D12 backends
- Procedural vertex generation (no vertex buffers)
- Distance field shaders for anti-aliased primitives
- Camera system with fixed/follow modes

**Performance-Focused:**
- GPU instancing, batching, minimal state changes
- Cache-friendly data structures
- Fixed-size memory pools
- Squared distance calculations

## Project Structure

```
└── .
    ├── .git [...]
    ├── .zig-cache [...]
    ├── src/                          # Source code directory
    │   ├── lib/                      # Engine library (shared components)
    │   │   ├── README.md             # Engine architecture documentation
    │   │   ├── c.zig                 # SDL3 C bindings
    │   │   ├── camera.zig            # Camera system (fixed/follow modes)
    │   │   ├── input.zig             # Input handling interface
    │   │   ├── maths.zig             # Math utilities and vector operations
    │   │   ├── renderer.zig          # Renderer interface abstraction
    │   │   ├── simple_gpu_renderer.zig # Low-level GPU rendering with transparency
    │   │   ├── history.zig           # Navigation history utility
    │   │   └── types.zig             # Core data types (Vec2, Color, etc)
    │   ├── hex/                      # Hex game implementation
    │   │   ├── behaviors.zig         # Entity behavior updates
    │   │   ├── borders.zig           # Border rendering system
    │   │   ├── combat.zig            # Combat system with bullet pool
    │   │   ├── constants.zig         # Game constants and configuration
    │   │   ├── controls.zig          # Control mapping and handling
    │   │   ├── effects.zig           # Visual effects system with AoE
    │   │   ├── entities.zig          # Zone-based world and entity system
    │   │   ├── game.zig              # Main game state management
    │   │   ├── game_data.zon         # Data-driven zone configuration
    │   │   ├── game_renderer.zig     # Game-specific renderer implementation
    │   │   ├── hud.zig               # HUD system (FPS counter, UI)
    │   │   ├── loader.zig            # ZON data loading and parsing
    │   │   ├── main.zig              # Game entry point and loop
    │   │   ├── physics.zig           # Collision detection and physics
    │   │   ├── player.zig            # Player controller with modifiers
    │   │   ├── portals.zig           # Portal system for zone travel
    │   │   └── spells.zig            # Spell system (8 slots, cooldowns)
    │   ├── hud/                      # HUD overlay system (transparent)
    │   │   ├── hud.zig               # Main HUD coordinator
    │   │   ├── renderer.zig          # HUD UI renderer with transparency
    │   │   ├── router.zig            # SvelteKit-style routing
    │   │   └── page.zig              # Page interface definitions
    │   ├── menu/                     # Menu pages (SvelteKit-style)
    │   │   ├── +layout.zig           # Root layout
    │   │   ├── +page.zig             # Home page
    │   │   ├── character/            # Character sheet page
    │   │   ├── settings/             # Settings pages
    │   │   └── stats/                # Statistics pages
    │   ├── shaders/                  # HLSL shader sources
    │   │   ├── compiled/             # Platform-specific bytecode
    │   │   ├── source/               # HLSL source files
    │   │   └── compile_shaders.sh    # Compilation script
    │   └── docs/                     # Technical documentation
    │       ├── ecs.md                # Entity system architecture
    │       ├── gpu.md                # SDL3 GPU API patterns
    │       └── shader_compilation.md # HLSL compilation workflow
    ├── zig-out [...]                 # Build output directory
    ├── .gitignore                    # Git ignore patterns
    ├── CLAUDE.md                     # This file - AI assistant documentation
    ├── README.md                     # User-facing documentation
    ├── build.zig                     # Zig build configuration
    ├── build.zig.zon                 # Package manifest and dependencies
    └── zz.zon                        # zz tool configuration
```

**Status:** ✓ Complete game engine with clean architecture separation

## Commands

```bash
# Standard Zig workflow
$ zig build              # Build (includes automatic shader compilation)
$ zig build run          # Build and run

# Shader-specific commands
$ zig build shaders          # Compile shaders only
$ zig build clean-shaders    # Clean and rebuild all shaders

# Cross-compilation
$ zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast  # Windows build
$ zig build -Doptimize=ReleaseFast                          # Release build

# Help and options
$ zig build --help       # Show all build options
```

## Quick Start

**Core Controls:**
- **Movement:** WASD + Shift (walk) + Ctrl+mouse
- **Combat:** Left-click shoot (burst/rhythm), Right-click cast spell  
- **Spells:** 1-4, Q, E, R, F select slots
- **System:** Space pause, R respawn, Y reset, ESC quit
- **HUD:** ` (backtick) toggle transparent menu overlay

**Key Features:**
- **Combat System:** 6-bullet pool with 2/sec recharge, burst & rhythm modes
- **Spell System:** 8 slots, targeted/self-cast, visual AoE indicators
- **Effects:** GPU-accelerated particles with gameplay integration
- **World:** Zone-based travel with persistent lifestone checkpoints
- **HUD System:** Transparent overlay menu with world visible underneath
- **Rendering:** Pure procedural generation, no texture assets

## GPU Performance Strategy

**Rendering Pipeline:**
- **Minimize draw calls:** Batch similar primitives using instanced rendering
- **Reduce state changes:** Group by pipeline, then by uniform data, then by vertex data
- **Procedural generation:** Generate geometry in vertex shaders to reduce bandwidth
- **Distance field rendering:** High-quality circles/shapes without textures

**Memory & Bandwidth:**
- **Triple buffering:** Cycle GPU buffers to avoid CPU/GPU synchronization stalls
- **Uniform buffers:** Small frame-constant data (camera, time, screen size)
- **Instance buffers:** Large per-object data (positions, colors, radii)
- **Align data structures:** Use `extern struct` for GPU compatibility

**Shader Optimization:**
- **Minimize branching:** Use `step()`, `mix()`, `smoothstep()` instead of if/else
- **Precompute in CPU:** Pass complex calculations as uniforms, not recalculate per-pixel
- **Pack data efficiently:** RGBA colors as float4, positions as Vec2, etc.

**Algorithm Focus:**
- Replace CPU collision detection with GPU parallel approaches where beneficial
- Use squared distances to avoid expensive sqrt operations
- Batch entities by type/behavior for SIMD-friendly processing

## GPU Development Notes

**Working Features:**
- ✓ Complete GPU rendering pipeline with camera system
- ✓ HLSL shaders for procedural shapes and effects
- ✓ Zone-based world with portal travel system
- ✓ Advanced combat with burst/rhythm shooting mechanics
- ✓ 8-slot spell system with cooldowns and AoE effects
- ✓ Full gameplay loop with lifestone persistence
- ✓ Character sheet and transparent HUD system
- ✓ Data-driven zone configuration via ZON files

**Key Success Factors:**
- **Procedural vertex generation:** Use `SV_VertexID` instead of vertex buffers for basic shapes
- **Minimal state:** Start with no uniforms, no vertex input, hardcoded data in shaders
- **Follow SDL3 BasicTriangle pattern:** Proven working approach for pipeline creation

**Architecture Highlights:**
- Zone system: Merged environmental properties with entity storage
- Travel metaphor: Players travel between zones via portals
- Camera modes: Fixed (overworld) vs follow (dungeons)
- Procedural rendering: All visuals generated algorithmically

## Game Design

**Zone System:**
- Zones combine environmental properties with entity storage
- Travel between zones via portals (travel metaphor, not "scene changes")
- Each zone has its own camera mode and scale settings
- Units renamed from "enemies" for flexible AI (friendly/neutral/hostile)
- Camera-aware movement bounds (fixed mode only)
- Persistent lifestone attunement across sessions

**Combat System:**
- **Bullet Pool:** 6 bullets max, 2/sec recharge rate
- **Shooting Modes:** Hold for rhythm (150ms intervals), click for burst
- **Bullet Lifetime:** 4-second travel limit (upgradeable)
- **Future:** Multi-shot, damage, range upgrades

**Spell System:**
- **8 Spell Slots:** Mapped to 1-4, Q, E, R, F keys
- **Targeting:** Click to cast at location, Ctrl+click for self-cast
- **Current Spells:**
  - **Lull:** 150-radius AoE, reduces aggro to 20% for 12 seconds
  - **Blink:** 200-unit teleport (dungeon only), 3-second cooldown
- **Visual Feedback:** Area indicators show exact effect zones

## Technical Implementation

**GPU Performance:**
- Batch draw calls, minimize render passes and state changes
- Use procedural vertex generation (SV_VertexID) to reduce bandwidth
- Distance field shaders for anti-aliased shapes without textures
- Visual effects use additive blending for performance

**SDL3 GPU Critical Requirements:**
- Vertex shaders: `register(b[n], space1)` for uniform buffers
- Push uniforms BEFORE `SDL_BeginGPURenderPass()`
- Avoid float4 arrays in HLSL cbuffers (use individual floats)
- Screen→NDC coordinate conversion with aspect ratio correction

**System Architecture:**
- **Input System:** Unified helpers for modifiers (Ctrl, Shift)
- **Spell System:** Modular with per-spell cooldowns and effects
- **Combat System:** Bullet pool with recharge mechanics
- **Effect System:** 256 simultaneous effects with lifecycle management
- **Browser System:** SvelteKit-style routing for UI pages

**Development Principles:**
- Procedural generation over static assets
- Camera system integration for all rendering
- Modular architecture with clean component separation
- Zone-based world design with travel metaphors
- Constants extracted for easy tuning and upgrades

## Notes to LLMs

- Game is fully functional - focus on performance and gameplay improvements
- Prioritize procedural generation and performance over asset-based approaches
- Focus on code-driven visuals and algorithmic generation
- Test frequently with `zig build run` to ensure each step works
- Less is more - avoid over-engineering
- Performance is a top priority - always optimize for the final best code
- When working with shaders, follow the SDL3 GPU patterns documented here
- The entity system is NOT an ECS - it's simple arrays with direct function calls
- Do what has been asked; nothing more, nothing less
- Prefer `rg` and never `sed` (Bash(rg ...))
- NEVER create files unless they're absolutely necessary for achieving your goal
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files (*.md) or README files unless explicitly requested