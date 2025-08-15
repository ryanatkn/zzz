# Dealt - SDL3 Game Engine with Hex Game Implementation



A GPU-accelerated game engine built with Zig, SDL3 GPU API, and HLSL shaders, featuring the Hex 2D action RPG as a reference implementation.

Performance is a top priority, and we dont care about backwards compat - always try to get to the final best code.

## Environment

```bash
$ zig version
0.14.1
```

Dependencies: SDL3 (vendored), SDL_shadercross (HLSL→SPIRV/DXIL compilation), webref (vendored)

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
    │   ├── lib/                      # Engine library (capability-based organization)
    │   │   ├── README.md             # Engine architecture documentation
    │   │   ├── core/                 # Fundamental types and utilities
    │   │   │   ├── types.zig         # Core data types (Vec2, Color, Rectangle)
    │   │   │   ├── maths.zig         # Math utilities with vec2_ prefixed functions
    │   │   │   ├── colors.zig        # Centralized color system with utilities
    │   │   │   ├── collections.zig   # Navigation history and state management
    │   │   │   ├── viewport.zig      # Viewport interface for dependency inversion
    │   │   │   ├── result.zig        # Result(T, E) error handling pattern
    │   │   │   ├── pool.zig          # Object and resource pooling utilities
    │   │   │   └── id.zig            # ID generation and handle management
    │   │   ├── platform/             # System integration and platform abstraction
    │   │   │   ├── sdl.zig           # SDL3 C bindings
    │   │   │   ├── input.zig         # Input handling interface
    │   │   │   ├── window.zig        # Window and GPU device management
    │   │   │   └── resources.zig     # Resource initialization patterns
    │   │   ├── rendering/            # Graphics pipeline capabilities
    │   │   │   ├── interface.zig     # Renderer interface abstraction
    │   │   │   ├── gpu.zig           # Low-level GPU rendering with transparency
    │   │   │   ├── shaders.zig       # Shader compilation and management
    │   │   │   ├── camera.zig        # Camera system (fixed/follow modes)
    │   │   │   ├── modes.zig         # Rendering mode selection (immediate/persistent)
    │   │   │   └── drawing.zig       # High-level drawing utilities for UI
    │   │   ├── physics/              # Collision and spatial systems
    │   │   │   ├── collision.zig     # Generic collision detection
    │   │   │   └── shapes.zig        # Shape definitions (circle, rect, line, point)
    │   │   ├── reactive/             # Svelte 5 reactive system implementation
    │   │   ├── font/                 # TTF parsing and rasterization
    │   │   ├── text/                 # Text rendering and layout
    │   │   ├── vector/               # GPU-accelerated vector graphics
    │   │   ├── ui/                   # Reactive UI components
    │   │   ├── debug/                # Debug and development utilities
    │   │   ├── reactive.zig          # Reactive system barrel export
    │   │   └── ui.zig                # UI system barrel export
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

## Dependency Management

**Self-Contained Build System:** All dependencies are vendored and built from source with zero external requirements beyond standard system libraries.

**Vendored Libraries:**
- **SDL3**: Complete SDL3 library built from vendored source
- **webref**: Machine-readable references of terms defined in web browser specifications
- **Zero External Packages**: No `apt install` or `sudo` requirements

**Key Features:**
- **Idiomatic Zig Build**: Single root `build.zig` with consolidated compilation
- **Smart Fallbacks**: Graceful degradation when optional libraries unavailable
- **Platform Detection**: Automatic system library detection with fallback to dummy drivers
- **Clean Updates**: `scripts/update-deps.sh` with backup system and proper git cleanup

## Commands

```bash
# Standard Zig workflow
$ zig build              # Build (includes automatic shader compilation)
$ zig build run          # Build and run

# Dependency management
$ zig build update-deps  # Update vendored SDL dependencies  
$ zig build check-deps   # Check dependency status (CI-friendly)
$ zig build list-deps    # List all dependencies and their status

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
- **Reactive System:** Complete Svelte 5 implementation with full rune support ✅

**Reactive System:**
- **Status:** ✅ Complete Svelte 5 implementation with full rune support
- **Core APIs:** 
  - `$state`: `signal.get()`, `signal.set()`, `signal.peek()`, `signal.snapshot()`
  - `$state.raw`: `signalRaw()` for non-reactive state optimization
  - `$derived`: `derived.get()`, `derived.peek()`, `derived.snapshot()`
  - `$effect`: `createEffect()`, `createEffectPre()`, `isTracking()`, `createEffectRoot()`
- **Advanced Features:** 
  - Push-pull reactivity with lazy evaluation
  - Automatic dependency tracking with cleanup
  - Effect timing control (pre-effects, tracking detection)
  - Manual effect scopes with lifecycle management
- **Performance:** Batching, caching (95% hit rate), minimal recomputation
- **UI Integration:** ReactiveComponent base class, reactive HUD system, reactive text rendering
- **Proven Benefits:** FPS text rendering optimized, 20+ tests passing, zero breaking changes

**Rendering Architecture (dual mode system):**
- **Immediate Mode:** Create, use, destroy each frame - for rapidly changing content
- **Persistent Mode:** Create once, reuse until changed - for stable content (eliminates FPS flashing)
- **Auto Mode Selection:** `rendering_modes.zig` provides guidelines based on change frequency
- **Performance Proven:** FPS counter no longer flashes, 95%+ cache hit rate for persistent text
- **Core Components:** `persistent_text.zig`, `text_renderer.zig` (dual mode), reusable UI components

**Development Principles:**
- Procedural generation over static assets
- Camera system integration for all rendering
- Modular architecture with clean component separation
- Zone-based world design with travel metaphors
- Constants extracted for easy tuning and upgrades

**Workflow with root TODO_*.md docs:**
- **Active TODO docs** should be placed in root directory with `TODO_*.md` prefix and caps like TODO_FOO.md or TODO_BAR.md for high visibility
- **Completed TODO docs** should be **updated in place** with completion status, not moved
  - Update title: `# TODO: Task Name` → `# ✅ COMPLETED: Task Name`
  - Add completion date and final status summary
  - Keep file in root to show what major work has been accomplished
- **Permanent docs** (README.md, CLAUDE.md) remain unprefixed in root
- **Only archive to `docs/archive/`** when TODO docs become stale or superseded
- **Always commit todo docs** to git both during work and after completion
- This workflow ensures completed work remains visible while tracking major accomplishments

## Notes to LLMs

- Game is fully functional - focus on performance and gameplay improvements
- Prioritize procedural generation and performance over asset-based approaches
- Focus on code-driven visuals and algorithmic generation
- Test frequently with `zig build run` to ensure each step works
- Less is more - avoid over-engineering
- Performance is a top priority - always optimize for the final best code
- When working with shaders, follow the SDL3 GPU patterns documented here
- The entity system is NOT an ECS - it's simple arrays with direct function calls

**Debug Logging Guidelines:**
- **CRITICAL**: Use log throttling to prevent spam - see `src/lib/debug/log_throttle.zig`
- **Available Throttle Methods**:
  - `logOnce()` - Log message only once ever
  - `logPeriodic()` - Log at most once per time period (e.g., every 5 seconds)
  - `logOnChange()` - Log only when value changes
  - `logThrottled()` - General throttling with customizable rate
- **Usage Pattern**:
  ```zig
  const log_throttle = @import("../debug/log_throttle.zig");
  // Instead of: std.log.info("Processing glyph {}", .{glyph_id});
  // Use: log_throttle.logPeriodic("glyph_process", 5000, "Processing glyph {}", .{glyph_id});
  ```
- **Why This Matters**: Font system can generate 500,000+ log lines in 2 minutes without throttling
- **Already Converted**: text/renderer.zig, text/cache.zig, fps_counter.zig, menu_text.zig, game_renderer.zig
- **Needs Conversion**: Font grid test system, HUD modules, any new diagnostic code

**Library Import Guidelines:**
- **Capability-based imports**: Import from specific capability directories
- **Core modules** (`core/`): types, maths, colors, viewport, result, pool, id
- **Platform modules** (`platform/`): sdl, input, window, resources
- **Rendering modules** (`rendering/`): interface, gpu, shaders, camera, modes, drawing
- **Physics modules** (`physics/`): collision, shapes
- **Barrel imports**: Use `reactive.zig` and `ui.zig` for complete subsystems
- **Apply DRY principles**: Prefer shared utilities over duplicate code
- **Import examples**:
  ```zig
  const types = @import("../lib/core/types.zig");
  const input = @import("../lib/platform/input.zig");
  const camera = @import("../lib/rendering/camera.zig");
  const collision = @import("../lib/physics/collision.zig");
  const reactive = @import("../lib/reactive.zig"); // Barrel import
  ```

**Reactive System Guidelines:**
- **System is production ready** ✅ - full Svelte 5 compliance with proven performance
- **Use ReactiveComponent base class** - for UI components with automatic lifecycle
- **Choose the right primitive:**
  - `signal()` for reactive state that triggers effects ($state)
  - `signalRaw()` for non-reactive state optimization ($state.raw)  
  - `derived()` for computed values with automatic tracking ($derived)
  - `snapshot()` for static copies to external APIs ($state.snapshot)
- **Effect control:**
  - `createEffect()` for standard reactive side effects ($effect)
  - `createEffectPre()` for pre-update timing ($effect.pre)
  - `createEffectRoot()` for manual lifecycle management ($effect.root)
  - `isTracking()` for runtime tracking detection ($effect.tracking)
- **Performance patterns:**
  - Use `peek()` for debugging/conditional logic (avoids dependencies)
  - Batch multiple updates for automatic optimization  
  - Raw signals for high-frequency non-reactive data
  - Snapshots for integration with external libraries
- **Proven benefits:** 20+ tests, zero breaking changes, Svelte 5 semantic compliance

**Rendering Mode Guidelines:**
- **Choose Immediate Mode when:** Content changes >10 times/sec (particle counts, debug values)
- **Choose Persistent Mode when:** Content changes <5 times/sec (FPS counter, UI labels, menus)
- **Use Auto-Selection:** `rendering_modes.recommendModeByRate(changes_per_second)` 
- **UI Components Available:** `fps_counter.zig`, `debug_overlay.zig`, `reactive_label.zig`
- **Performance Examples:** FPS (persistent, 2-3 changes/sec), Mouse coords (immediate, 60/sec)
- **Decision Tree:** Static text → persistent, Debug values → immediate, User actions → persistent

**General Guidelines:**
- Do what has been asked; nothing more, nothing less
- Prefer `rg` and never `sed` (Bash(rg ...))
- NEVER create files unless they're absolutely necessary for achieving your goal
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files (*.md) or README files unless explicitly requested

## Documentation Lifecycle Pattern

**Established Pattern for Active Development:**
1. **Active Work** → Root directory MD files for current tasks (`REACTIVE_UI_STATUS.md`)
2. **Fully Complete Work** → Move to `docs/archive/` only when entirely finished (`REACTIVE_API_GUIDE.md`)  
3. **New APIs/Features** → Create dedicated guides in root for active development
4. **Keep Root Clean** → Only current/active documentation in root directory

**Important:** Files are archived only when fully complete, not after each session. Git history provides sufficient granularity for tracking progress.

**This Workflow Ensures:**
- Active work is highly visible to developers and AI assistants
- Documentation stays in root until work is entirely finished
- Git history tracks incremental changes and progress
- Root directory focuses on current priorities without premature archival
- memorize this perspective: a scalable lib directory can look like, for a system that exposes all modules 
  to all other modules without arbitrary restrictions.