# Hex project prompt

> `zz prompt CLAUDE.md README.md "src/**/*.zig" "src/**/*.hlsl" "src/**/*.sh" > hex_project_prompt.md`

<File path="CLAUDE.md">

````md
# Hex - GPU-Accelerated 2D Action RPG

A procedurally-rendered 2D topdown action RPG built with Zig, SDL3 GPU API, and HLSL shaders.

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
    │   ├── docs/                     # Technical documentation
    │   │   ├── ecs.md                # Entity system architecture (no ECS abstractions)
    │   │   ├── gpu.md                # SDL3 GPU API reference and patterns
    │   │   ├── prompt_generation_guide.md # LLM prompt generation with zz tool
    │   │   └── shader_compilation.md # HLSL compilation workflow
    │   ├── shaders/
    │   │   ├── compiled/             # Platform-specific bytecode (SPIRV/DXIL)
    │   │   │   ├── d3d12/ [...]      # DXIL bytecode for Windows
    │   │   │   └── vulkan/ [...]     # SPIRV bytecode for Linux/macOS
    │   │   ├── source/               # HLSL shader sources
    │   │   │   ├── circle.hlsl           # Standard circle rendering shader
    │   │   │   ├── debug_circle.hlsl     # Debug circle with orbital animation
    │   │   │   ├── effect.hlsl           # Visual effects shader
    │   │   │   ├── rectangle.hlsl        # Rectangle rendering shader
    │   │   │   ├── simple_circle.hlsl    # Basic circle distance field shader
    │   │   │   ├── simple_rectangle.hlsl # Basic rectangle shader
    │   │   │   ├── triangle.hlsl         # Triangle rendering shader
    │   │   │   └── triangle_uniforms.hlsl# Triangle with uniform data test
    │   │   └── compile_shaders.sh    # Automated HLSL→SPIRV/DXIL compilation
    │   ├── behaviors.zig             # Entity behavior updates (player, units, bullets)
    │   ├── borders.zig               # Border rendering system
    │   ├── camera.zig                # Viewport camera system (fixed/follow modes)
    │   ├── combat.zig                # Combat system (bullets, damage, death)
    │   ├── constants.zig             # Game constants and configuration
    │   ├── controls.zig              # Control mapping and handling
    │   ├── effects.zig               # Visual effects system
    │   ├── entities.zig              # Zone-based world and entity system
    │   ├── game.zig                  # Main game state management and update loop
    │   ├── game_data.zon             # Data-driven zone configuration
    │   ├── hud.zig                   # HUD system (FPS counter, UI elements)
    │   ├── input.zig                 # Input handling (keyboard, mouse)
    │   ├── loader.zig                # ZON data loading and parsing
    │   ├── main.zig                  # SDL3 application entry point and game loop
    │   ├── maths.zig                 # Mathematical utilities and vector operations
    │   ├── physics.zig               # Collision detection and physics
    │   ├── player.zig                # Player controller and movement logic
    │   ├── portals.zig               # Portal system for zone travel
    │   ├── renderer.zig              # GPU renderer with camera integration
    │   ├── simple_gpu_renderer.zig  # Clean GPU rendering backend
    │   └── types.zig                 # Shared data types (GPU-compatible structs)
    ├── zig-out [...]                 # Build output directory
    ├── .gitignore                    # Git ignore patterns
    ├── CLAUDE.md                     # This file - AI assistant documentation
    ├── README.md                     # User-facing documentation
    ├── build.zig                     # Zig build configuration
    ├── build.zig.zon                 # Package manifest and dependencies
    ├── hex_project_prompt.md         # Generated LLM prompt
    └── zz.zon                        # zz tool configuration
```

**Status:** ✅ Complete GPU-accelerated game with zone-based world

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

**Controls:** Mouse/WASD movement, right-click fire, Space pause, R respawn, ESC quit

**Features:**
- Procedural distance-field rendering for all shapes
- GPU-accelerated visual effects system
- Zone-based world with portal travel between areas
- Data-driven configuration via ZON files
- Complete gameplay: combat, lifestones, unit AI

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
- ✅ Complete GPU rendering pipeline with camera system
- ✅ HLSL shaders for procedural shapes and effects
- ✅ Zone-based world with portal travel system
- ✅ Full gameplay loop with combat and respawn mechanics
- ✅ Data-driven zone configuration via ZON files

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
- Persistent state across death/respawn cycles

## Technical Implementation

**GPU Performance:**
- Batch draw calls, minimize render passes and state changes
- Use procedural vertex generation (SV_VertexID) to reduce bandwidth
- Distance field shaders for anti-aliased shapes without textures

**SDL3 GPU Critical Requirements:**
- Vertex shaders: `register(b[n], space1)` for uniform buffers
- Push uniforms BEFORE `SDL_BeginGPURenderPass()`
- Avoid float4 arrays in HLSL cbuffers (use individual floats)
- Screen→NDC coordinate conversion with aspect ratio correction

**Development Principles:**
- Procedural generation over static assets
- Camera system integration for all rendering
- Modular architecture with clean component separation
- Zone-based world design with travel metaphors

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
- NEVER create files unless they're absolutely necessary for achieving your goal
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files (*.md) or README files unless explicitly requested
````

</File>


<File path="README.md">

````md
# Hex - GPU-Accelerated 2D Action RPG

A procedurally-rendered 2D top-down action RPG built with Zig, SDL3 GPU API, and HLSL shaders. Pure algorithmic graphics with no texture assets.

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

## Features

### Core Gameplay
- **Movement**: Mouse hold-to-move + WASD direct control
- **Combat**: Right-click projectile firing with collision detection  
- **World**: Zone-based travel system with portals between areas
- **Respawn**: Lifestone checkpoints and R key instant respawn
- **Camera**: Fixed (overworld) and follow (dungeon) modes

### Technical Highlights
- **GPU-First**: SDL3 GPU API with Vulkan/D3D12 backends
- **Procedural Rendering**: No textures - pure algorithmic shape generation
- **Distance Fields**: Anti-aliased primitives via shader mathematics
- **Data-Driven**: Zone configuration through ZON files
- **Cross-Platform**: SPIRV for Vulkan, DXIL for D3D12, and in the future MoltenVK for Metal

## Game Controls

### Movement & Actions
- **Hold Left Mouse**: Move toward cursor
- **WASD**: Direct movement
- **Right Click**: Fire projectile
- **Space**: Pause game
- **R**: Respawn at lifestone
- **ESC**: Quit

### Visual Elements
- **Blue Circle**: Player character
- **Red Circles**: Enemy units
- **Green Rectangles**: Solid obstacles
- **Orange Rectangles**: Deadly hazards
- **Purple Circles**: Zone portals
- **Cyan Circles**: Lifestone checkpoints

## Architecture

### Module Structure

```
hex/
├── src/
│   ├── docs/                    # Technical documentation [...]
│   ├── shaders/
│   │   ├── source/              # HLSL shader sources
│   │   ├── compiled/            # Platform-specific bytecode [...]
│   │   │   ├── vulkan/          # SPIRV files [...]
│   │   │   └── d3d12/           # DXIL files [...]
│   │   └── compile_shaders.sh  # Build script
│   ├── game_data.zon           # Zone configuration data
│   ├── main.zig                # SDL3 entry point
│   ├── game.zig                # Core game loop
│   ├── entities.zig            # Entity storage system
│   ├── behaviors.zig           # Update logic
│   ├── physics.zig             # Collision detection
│   ├── renderer.zig            # GPU rendering pipeline
│   ├── camera.zig              # Viewport management
│   └── types.zig               # Shared data structures
├── zz.zon                      # zz tool configuration
└── hex_project_prompt.md       # Generated LLM prompt
```

For complete technical documentation and development guidelines, see **[CLAUDE.md](./CLAUDE.md)**.

### Documentation

- [Entity System Architecture](./src/docs/ecs.md) - Entity storage and update patterns
- [GPU API Reference](./src/docs/gpu.md) - SDL3 GPU API usage and patterns  
- [Shader Compilation Guide](./src/docs/shader_compilation.md) - HLSL compilation workflow
- [Prompt Generation Guide](./src/docs/prompt_generation_guide.md) - LLM prompt creation with zz tool

### Design Philosophy

**Procedural-First Approach:**
- All visuals generated algorithmically
- Shapes and effects defined in code and shaders
- Mathematical beauty over static content
- No sprite or texture dependencies

**Performance-Focused:**
- Minimal draw calls via batching
- Procedural vertex generation (no buffers)
- GPU-aligned data structures
- Camera-aware culling

**Clean Architecture:**
- Explicit entity pools (no ECS abstractions)
- Direct function calls (no dynamic dispatch)
- Fixed-size arrays (no runtime allocation)
- Zone-based world organization

## Development

### Building from Source

```bash
# Standard Zig workflow (shaders compile automatically)
zig build              # Build the game
zig build run          # Build and run
./hex                  # Simple wrapper around 'zig build run'

# Shader-specific commands
zig build shaders          # Compile shaders only
zig build clean-shaders    # Clean and rebuild all shaders

# Cross-compilation and optimization
zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast  # Windows release
zig build -Doptimize=ReleaseFast                          # Native release
zig build -Duse-llvm                                       # Use LLVM backend
```

### Shader Development

Shaders are written in HLSL and compiled automatically during build. Manual compilation:

```bash
# Compile shaders (integrated into build system)
zig build shaders          # Incremental build (only changed shaders)
zig build clean-shaders    # Clean rebuild (all shaders)
```

**Platform Support:**
- **Windows**: DXIL via D3D12
- **Linux/Steam Deck**: SPIRV via Vulkan
- **macOS/iOS**: SPIRV via Vulkan + MoltenVK (not implemented)
- **Android**: SPIRV via Vulkan

### Debug Mode

Enable GPU debug visualizations:

```zig
// In main.zig
const DEBUG_MODE = true;  // Shows shader test patterns
```

## Technical Details

### GPU Rendering Pipeline

**Shader Requirements:**
- Vertex shaders: `register(b[n], space1)` for uniforms
- Fragment shaders: `register(b[n], space0)`
- Avoid `float4` arrays in cbuffers (use individual floats)
- Procedural vertex generation via `SV_VertexID`

**Command Buffer Order:**
1. Push uniform data (camera, transforms)
2. Begin render pass
3. Bind pipeline and draw primitives
4. End pass and submit

**Coordinate Systems:**
- Screen space: (0,0) top-left
- NDC space: (-1,-1) bottom-left to (1,1) top-right
- Aspect ratio correction in shaders

### Entity System

**Storage Pattern:**
```zig
World {
    player: Player
    bullets: [MAX_BULLETS]Bullet
    zones: [MAX_ZONES]Zone {
        units: [MAX_UNITS]Unit
        obstacles: [MAX_OBSTACLES]Obstacle
        portals: [MAX_PORTALS]Portal
        lifestones: [MAX_LIFESTONES]Lifestone
    }
}
```

**Key Features:**
- Fixed-size pools (no dynamic allocation)
- Contiguous arrays (cache-friendly)
- Explicit types (no abstractions)
- Zone-based organization

### Performance Optimizations

**GPU Strategies:**
- Batch by shape type (circles, rectangles)
- Minimize pipeline state changes
- Use distance fields for anti-aliasing
- Procedural generation reduces bandwidth

**CPU Strategies:**
- Short-circuit dead entities
- Squared distance calculations
- Zone-based spatial partitioning
- Fixed-size memory pools

## Requirements

### System Requirements
- **Zig**: 0.14.1 or newer
- **GPU**: Vulkan 1.0 or DirectX 12 support
- **OS**: Windows 10+, Linux, macOS 10.14+
- **RAM**: 256MB minimum

### Dependencies
- **SDL3**: Window management and GPU API (auto-fetched)
- **SDL_shadercross**: HLSL compilation (for development)
- **MoltenVK**: Vulkan→Metal translation (macOS/iOS, optional and not implemented)

## Extending the Game

### Adding New Entity Types
1. Define struct in `entities.zig`
2. Add update function to `behaviors.zig`
3. Implement collision in `physics.zig`
4. Add rendering to `renderer.zig`
5. Update zone loader if data-driven

### Creating New Zones
1. Edit `game_data.zon` configuration
2. Define zone properties and entities
3. Set camera mode and scale
4. Configure portal connections

### Writing Custom Shaders
1. Create HLSL in `src/shaders/source/`
2. Follow uniform buffer conventions
3. Compile with `./src/shaders/compile_shaders.sh`
4. Load in renderer pipeline

## Performance Tips

- **Development**: Use debug builds for better errors
- **Testing**: Enable `DEBUG_MODE` for GPU visualizations
- **Production**: Use `ReleaseFast` for maximum speed
- **Profiling**: Tools like RenderDoc for GPU analysis

## License

See LICENSE file in project root.

## Credits

Built with:
- [Zig](https://ziglang.org/) - Systems programming language
- [SDL3](https://libsdl.org/) - Cross-platform GPU API
- [SDL_shadercross](https://github.com/libsdl-org/SDL_shadercross) - Shader compilation
````

</File>


<File path="src/maths.zig">

```zig
const std = @import("std");

const types = @import("types.zig");

const Vec2 = types.Vec2;

pub fn normalizeVector(v: Vec2) Vec2 {
    const length = @sqrt(v.x * v.x + v.y * v.y);
    if (length > 0) {
        return Vec2{ .x = v.x / length, .y = v.y / length };
    }
    return Vec2{ .x = 0, .y = 0 };
}

pub fn distance(a: Vec2, b: Vec2) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    return @sqrt(dx * dx + dy * dy);
}

pub fn distanceSquared(a: Vec2, b: Vec2) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    return dx * dx + dy * dy;
}

pub fn clampVector(v: Vec2, min: Vec2, max: Vec2) Vec2 {
    return Vec2{
        .x = std.math.clamp(v.x, min.x, max.x),
        .y = std.math.clamp(v.y, min.y, max.y),
    };
}

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

pub fn lerpVector(a: Vec2, b: Vec2, t: f32) Vec2 {
    return Vec2{
        .x = lerp(a.x, b.x, t),
        .y = lerp(a.y, b.y, t),
    };
}

```

</File>


<File path="src/input.zig">

```zig
const std = @import("std");

const c = @import("c.zig");

const types = @import("types.zig");
const camera = @import("camera.zig");

const Vec2 = types.Vec2;

pub const InputState = struct {
    keys_down: std.StaticBitSet(512),
    mouse_pos: Vec2,
    left_mouse_held: bool,
    right_mouse_held: bool,

    const Self = @This();

    pub fn init() Self {
        return .{
            .keys_down = std.StaticBitSet(512).initEmpty(),
            .mouse_pos = Vec2{ .x = 0, .y = 0 },
            .left_mouse_held = false,
            .right_mouse_held = false,
        };
    }

    pub fn handleKeyDown(self: *Self, scancode: c_uint) void {
        self.keys_down.set(@intCast(scancode));
    }

    pub fn handleKeyUp(self: *Self, scancode: c_uint) void {
        self.keys_down.unset(@intCast(scancode));
    }

    pub fn handleMouseMotion(self: *Self, x: f32, y: f32) void {
        self.mouse_pos.x = x;
        self.mouse_pos.y = y;
    }

    pub fn handleMouseButtonDown(self: *Self, button: u8) void {
        switch (button) {
            c.sdl.SDL_BUTTON_LEFT => self.left_mouse_held = true,
            c.sdl.SDL_BUTTON_RIGHT => self.right_mouse_held = true,
            else => {},
        }
    }

    pub fn handleMouseButtonUp(self: *Self, button: u8) void {
        switch (button) {
            c.sdl.SDL_BUTTON_LEFT => self.left_mouse_held = false,
            c.sdl.SDL_BUTTON_RIGHT => self.right_mouse_held = false,
            else => {},
        }
    }

    pub fn isKeyDown(self: *const Self, scancode: c_uint) bool {
        return self.keys_down.isSet(@intCast(scancode));
    }

    pub fn isLeftMouseHeld(self: *const Self) bool {
        return self.left_mouse_held;
    }

    pub fn isRightMouseHeld(self: *const Self) bool {
        return self.right_mouse_held;
    }

    pub fn getMousePos(self: *const Self) Vec2 {
        return self.mouse_pos;
    }

    pub fn getWorldMousePos(self: *const Self, cam: *const camera.Camera) Vec2 {
        return cam.screenToWorld(self.mouse_pos);
    }

    pub fn getMovementVector(self: *const Self) Vec2 {
        var velocity = Vec2{ .x = 0, .y = 0 };

        if (self.isKeyDown(c.sdl.SDL_SCANCODE_W)) {
            velocity.y -= 1.0;
        }
        if (self.isKeyDown(c.sdl.SDL_SCANCODE_S)) {
            velocity.y += 1.0;
        }
        if (self.isKeyDown(c.sdl.SDL_SCANCODE_A)) {
            velocity.x -= 1.0;
        }
        if (self.isKeyDown(c.sdl.SDL_SCANCODE_D)) {
            velocity.x += 1.0;
        }

        const length = @sqrt(velocity.x * velocity.x + velocity.y * velocity.y);
        if (length > 0) {
            velocity.x /= length;
            velocity.y /= length;
        }

        return velocity;
    }

    pub fn clearMouseHold(self: *Self) void {
        self.left_mouse_held = false;
        self.right_mouse_held = false;
    }
};

```

</File>


<File path="src/main.zig">

```zig
const std = @import("std");

const c = @import("c.zig");

const constants = @import("constants.zig");
const entities = @import("entities.zig");
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const renderer = @import("renderer.zig");
const loader = @import("loader.zig");
const types = @import("types.zig");
const hud = @import("hud.zig");
const input = @import("input.zig");
const game_controller = @import("game.zig");
const combat = @import("combat.zig");
const player_controller = @import("player.zig");
const portals = @import("portals.zig");
const maths = @import("maths.zig");
const controls = @import("controls.zig");

const window_w = @as(u32, @intFromFloat(constants.SCREEN_WIDTH));
const window_h = @as(u32, @intFromFloat(constants.SCREEN_HEIGHT));
const Vec2 = types.Vec2;
const Color = types.Color;
const World = entities.World;
const Renderer = renderer.Renderer;
const GameState = game_controller.GameState;
const Hud = hud.Hud;

// Test mode for debugging - change to enable debug tests
const DEBUG_MODE = false; // Set to true to run debug tests instead of game

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try run(gpa.allocator());
}

pub fn run(allocator: std.mem.Allocator) !void {
    app_err.reset();

    // Store allocator globally for use in SDL callbacks
    global_allocator = allocator;

    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(c.sdl.SDL_RunApp(empty_argv.len, @ptrCast(&empty_argv), sdlMainC, null))));
    if (app_err.load()) |err| {
        return err;
    }
    if (status != 0) {
        return error.SdlAppError;
    }
}

var fully_initialized = false;
var window: *c.sdl.SDL_Window = undefined;
var game_renderer: Renderer = undefined;
var game_state: GameState = undefined;
var game_hud: Hud = undefined;
var global_allocator: std.mem.Allocator = undefined;

// Timing
var last_time: u64 = 0;

fn sdlAppInit(appstate: ?*?*anyopaque, argv: [][*:0]u8) !c.sdl.SDL_AppResult {
    _ = appstate;
    _ = argv;

    try errify(c.sdl.SDL_Init(c.sdl.SDL_INIT_VIDEO));

    // Create window hidden initially
    window = c.sdl.SDL_CreateWindow("Hex GPU Game", window_w, window_h, c.sdl.SDL_WINDOW_RESIZABLE | c.sdl.SDL_WINDOW_HIDDEN) orelse {
        return error.SdlError;
    };
    errdefer c.sdl.SDL_DestroyWindow(window);

    if (DEBUG_MODE) {
        // Debug mode - no GPU renderer needed
        fully_initialized = true;
        return c.sdl.SDL_APP_CONTINUE;
    }

    // Initialize renderer
    game_renderer = try Renderer.init(global_allocator, window);

    // Initialize game state
    game_state = GameState.init();

    // Initialize HUD
    game_hud = Hud.init();

    // Load game data
    loader.loadGameData(global_allocator, &game_state.world) catch |err| {
        std.debug.print("Failed to load game data from ZON file: {}\n", .{err});
        std.debug.print("Please check that game_data.zon exists and is valid\n", .{});
        return err;
    };

    // Initialize ambient effects for starting zone
    game_state.effect_system.refreshAmbientEffects(&game_state.world);

    // Show window after initialization
    _ = c.sdl.SDL_ShowWindow(window);

    last_time = c.sdl.SDL_GetPerformanceCounter();

    fully_initialized = true;
    std.debug.print("Hex GPU game initialized successfully\n", .{});
    std.debug.print("Controls: Hold mouse to move, WASD for direct movement, Space to pause, ESC to quit\n", .{});
    std.debug.print("Portal interaction: Walk into portals to travel between zones\n", .{});
    return c.sdl.SDL_APP_CONTINUE;
}

fn sdlAppIterate(appstate: ?*anyopaque) !c.sdl.SDL_AppResult {
    _ = appstate;

    if (game_state.shouldQuit()) {
        return c.sdl.SDL_APP_SUCCESS;
    }

    if (DEBUG_MODE) {
        // Debug mode - no tests available
        return c.sdl.SDL_APP_SUCCESS;
    } else {
        // Game mode - run actual game
        try runGameLoop();
    }

    return c.sdl.SDL_APP_CONTINUE;
}

fn sdlAppEvent(appstate: ?*anyopaque, event: *c.sdl.SDL_Event) !c.sdl.SDL_AppResult {
    _ = appstate;
    return controls.handleSDLEvent(&game_state, &game_renderer, &game_hud, event);
}

fn sdlAppQuit(appstate: ?*anyopaque, result: anyerror!c.sdl.SDL_AppResult) void {
    _ = appstate;
    _ = result catch {};

    if (fully_initialized) {
        if (!DEBUG_MODE) {
            game_renderer.deinit();
            loader.deinit(); // Clean up ZON data memory
        }
        c.sdl.SDL_DestroyWindow(window);
        fully_initialized = false;
    }
}

// Game loop functions
fn runGameLoop() !void {
    // Calculate delta time
    const current_time = c.sdl.SDL_GetPerformanceCounter();
    const frequency = c.sdl.SDL_GetPerformanceFrequency();
    const delta_ticks = current_time - last_time;
    const deltaTime: f32 = @as(f32, @floatFromInt(delta_ticks)) / @as(f32, @floatFromInt(frequency));
    last_time = current_time;

    // Update HUD system
    game_hud.updateFPS(current_time, frequency);

    // Update camera before game logic (for correct mouse coordinate transformation)
    game_renderer.updateCamera(&game_state.world);

    // Update game state
    game_controller.updateGame(&game_state, &game_renderer.camera, deltaTime);

    // Render
    try renderGame();
}

fn renderGame() !void {
    const zone = game_state.world.getCurrentZone();

    // Begin GPU frame
    const cmd_buffer = try game_renderer.beginFrame(window);
    const render_pass = try game_renderer.beginRenderPass(cmd_buffer, window, zone.background_color);

    // Render all entities
    game_renderer.renderZone(cmd_buffer, render_pass, &game_state.world);

    // Render visual effects
    game_renderer.renderEffects(cmd_buffer, render_pass, &game_state.effect_system);

    // Draw HUD
    if (game_hud.visible) {
        game_renderer.drawFPS(cmd_buffer, render_pass, game_hud.fps_counter);
    }

    // Draw state borders with stacking support and iris wipe effect
    game_renderer.drawBorders(cmd_buffer, render_pass, &game_state);

    game_renderer.endRenderPass(render_pass);
    game_renderer.endFrame(cmd_buffer);
}

// SDL boilerplate
inline fn errify(value: anytype) error{SdlError}!switch (@typeInfo(@TypeOf(value))) {
    .bool => void,
    .pointer, .optional => @TypeOf(value.?),
    .int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@typeInfo(@TypeOf(value))) {
        .bool => if (!value) error.SdlError,
        .pointer, .optional => value orelse error.SdlError,
        .int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    };
}

// SDL main callbacks
fn sdlMainC(argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    _ = argc;
    _ = argv;
    return c.sdl.SDL_EnterAppMainCallbacks(0, null, sdlAppInitC, sdlAppIterateC, sdlAppEventC, sdlAppQuitC);
}

fn sdlAppInitC(appstate: ?*?*anyopaque, argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c.sdl.SDL_AppResult {
    _ = argc;
    _ = argv;
    const empty_slice: [][*:0]u8 = &.{};
    return sdlAppInit(appstate.?, empty_slice) catch |err| app_err.store(err);
}

fn sdlAppIterateC(appstate: ?*anyopaque) callconv(.c) c.sdl.SDL_AppResult {
    return sdlAppIterate(appstate) catch |err| app_err.store(err);
}

fn sdlAppEventC(appstate: ?*anyopaque, event: ?*c.sdl.SDL_Event) callconv(.c) c.sdl.SDL_AppResult {
    return sdlAppEvent(appstate, event.?) catch |err| app_err.store(err);
}

fn sdlAppQuitC(appstate: ?*anyopaque, result: c.sdl.SDL_AppResult) callconv(.c) void {
    sdlAppQuit(appstate, app_err.load() orelse result);
}

var app_err: ErrorStore = .{};

const ErrorStore = struct {
    const status_not_stored = 0;
    const status_storing = 1;
    const status_stored = 2;

    status: c.sdl.SDL_AtomicInt = .{},
    err: anyerror = undefined,
    trace_index: usize = undefined,
    trace_addrs: [32]usize = undefined,

    fn reset(es: *ErrorStore) void {
        _ = c.sdl.SDL_SetAtomicInt(&es.status, status_not_stored);
    }

    fn store(es: *ErrorStore, err: anyerror) c.sdl.SDL_AppResult {
        if (c.sdl.SDL_CompareAndSwapAtomicInt(&es.status, status_not_stored, status_storing)) {
            es.err = err;
            if (@errorReturnTrace()) |src_trace| {
                es.trace_index = src_trace.index;
                const len = @min(es.trace_addrs.len, src_trace.instruction_addresses.len);
                @memcpy(es.trace_addrs[0..len], src_trace.instruction_addresses[0..len]);
            }
            _ = c.sdl.SDL_SetAtomicInt(&es.status, status_stored);
        }
        return c.sdl.SDL_APP_FAILURE;
    }

    fn load(es: *ErrorStore) ?anyerror {
        if (c.sdl.SDL_GetAtomicInt(&es.status) != status_stored) return null;
        if (@errorReturnTrace()) |dst_trace| {
            dst_trace.index = es.trace_index;
            const len = @min(dst_trace.instruction_addresses.len, es.trace_addrs.len);
            @memcpy(dst_trace.instruction_addresses[0..len], es.trace_addrs[0..len]);
        }
        return es.err;
    }
};

```

</File>


<File path="src/combat.zig">

```zig
const std = @import("std");

const types = @import("types.zig");
const entities = @import("entities.zig");
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const effects = @import("effects.zig");
const constants = @import("constants.zig");

const Vec2 = types.Vec2;
const World = entities.World;
const Player = entities.Player;

pub fn fireBullet(world: *World, target_pos: Vec2) void {
    if (!world.player.alive) return;

    if (world.findInactiveBullet()) |bullet| {
        behaviors.fireBullet(bullet, world.player.pos, target_pos);
    }
}

pub fn fireBulletAtMouse(world: *World, mouse_pos: Vec2) void {
    fireBullet(world, mouse_pos);
}

pub fn respawnPlayer(game_state: anytype) void {
    const world = &game_state.world;
    const effect_system = &game_state.effect_system;
    const nearest = physics.findNearestAttunedLifestone(world, world.player.pos);

    var respawn_pos: Vec2 = undefined;

    if (nearest) |result| {
        if (result.zone_index != world.current_zone) {
            game_state.travelToZone(result.zone_index);
            std.debug.print("Traveling to zone {} for nearest lifestone\n", .{result.zone_index});
        }
        respawn_pos = result.pos;
    } else {
        if (world.current_zone != 0) {
            game_state.travelToZone(0);
            std.debug.print("No lifestones found, returning to overworld spawn\n", .{});
        }
        respawn_pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y };
    }

    // Common respawn logic
    behaviors.respawnPlayer(&world.player, respawn_pos);
    effect_system.addPlayerSpawnEffect(respawn_pos, world.player.radius);
    std.debug.print("Player respawned!\n", .{});
}

pub fn handlePlayerDeath(player: *Player) void {
    behaviors.killPlayer(player);
    std.debug.print("Player died! Press R or click to respawn\n", .{});
}

pub fn handlePlayerDeathOnHazard(player: *Player) void {
    behaviors.killPlayer(player);
    std.debug.print("Player died on hazard! Press R or click to respawn\n", .{});
}

pub fn handleUnitDeath(unit: *entities.Unit) void {
    behaviors.killUnit(unit);
    std.debug.print("Unit defeated!\n", .{});
}

pub fn handleUnitDeathOnHazard(unit: *entities.Unit) void {
    behaviors.killUnit(unit);
    std.debug.print("Unit died on hazard!\n", .{});
}

```

</File>


<File path="src/camera.zig">

```zig
const std = @import("std");

const types = @import("types.zig");
const constants = @import("constants.zig");

const Vec2 = types.Vec2;

pub const Camera = struct {
    // Screen dimensions (pixels)
    screen_width: f32,
    screen_height: f32,

    // World view bounds
    view_x: f32, // Left edge of view in world space
    view_y: f32, // Top edge of view in world space
    view_width: f32, // Width of view in world units
    view_height: f32, // Height of view in world units

    // Visual scale (zoom level)
    scale: f32,

    const Self = @This();

    pub fn init(screen_w: f32, screen_h: f32) Self {
        return .{
            .screen_width = screen_w,
            .screen_height = screen_h,
            .view_x = 0.0,
            .view_y = 0.0,
            .view_width = screen_w,
            .view_height = screen_h,
            .scale = 1.0,
        };
    }

    // Fixed camera - shows entire world with adjustable zoom
    pub fn setupFixed(self: *Self, scale: f32) void {
        self.scale = scale;
        // View always encompasses entire world
        self.view_x = 0.0;
        self.view_y = 0.0;
        self.view_width = constants.SCREEN_WIDTH;
        self.view_height = constants.SCREEN_HEIGHT;
    }

    // Follow camera - tracks player position with adjustable zoom
    pub fn setupFollow(self: *Self, player_pos: Vec2, scale: f32) void {
        self.scale = scale;
        // Zoom affects view size (inverse relationship)
        self.view_width = self.screen_width / self.scale;
        self.view_height = self.screen_height / self.scale;
        // Center view on player
        self.view_x = player_pos.x - self.view_width / 2.0;
        self.view_y = player_pos.y - self.view_height / 2.0;
    }

    // Convert world position to screen position
    pub fn worldToScreen(self: *const Self, world_pos: Vec2) Vec2 {
        // Normalize to view space [0,1]
        const norm_x = (world_pos.x - self.view_x) / self.view_width;
        const norm_y = (world_pos.y - self.view_y) / self.view_height;
        // Map to screen pixels
        return Vec2{
            .x = norm_x * self.screen_width,
            .y = norm_y * self.screen_height,
        };
    }

    // Convert world size to screen size (for radii, dimensions)
    pub fn worldSizeToScreen(self: *const Self, world_size: f32) f32 {
        return (world_size / self.view_width) * self.screen_width;
    }

    // Convert screen position to world position (for mouse input)
    pub fn screenToWorld(self: *const Self, screen_pos: Vec2) Vec2 {
        // Normalize from screen space [0,1]
        const norm_x = screen_pos.x / self.screen_width;
        const norm_y = screen_pos.y / self.screen_height;
        // Map to world coordinates
        return Vec2{
            .x = norm_x * self.view_width + self.view_x,
            .y = norm_y * self.view_height + self.view_y,
        };
    }
};

```

</File>


<File path="src/controls.zig">

```zig
const std = @import("std");

const c = @import("c.zig");

const types = @import("types.zig");
const constants = @import("constants.zig");
const game_controller = @import("game.zig");
const renderer = @import("renderer.zig");
const hud = @import("hud.zig");
const combat = @import("combat.zig");

const Vec2 = types.Vec2;
const GameState = game_controller.GameState;
const Renderer = renderer.Renderer;
const Hud = hud.Hud;

pub fn handleSDLEvent(
    game_state: *GameState,
    game_renderer: *Renderer,
    game_hud: *Hud,
    event: *c.sdl.SDL_Event,
) !c.sdl.SDL_AppResult {
    switch (event.type) {
        c.sdl.SDL_EVENT_QUIT => {
            game_state.requestQuit();
            return c.sdl.SDL_APP_SUCCESS;
        },
        c.sdl.SDL_EVENT_KEY_DOWN => {
            game_state.input_state.handleKeyDown(event.key.scancode);
            switch (event.key.scancode) {
                c.sdl.SDL_SCANCODE_ESCAPE => {
                    game_state.requestQuit();
                    return c.sdl.SDL_APP_SUCCESS;
                },
                c.sdl.SDL_SCANCODE_GRAVE => { // Backtick key - toggle HUD
                    game_hud.toggle();
                },
                c.sdl.SDL_SCANCODE_R => { // R key - respawn/reset
                    game_controller.handleRespawn(game_state);
                },
                c.sdl.SDL_SCANCODE_SPACE => { // Space key - pause toggle
                    game_state.togglePause();
                },
                c.sdl.SDL_SCANCODE_T => { // T key - reset current zone units
                    game_state.resetZone();
                },
                c.sdl.SDL_SCANCODE_Y => { // Y key - full game reset
                    game_state.resetGame();
                },
                // Effect testing hotkeys
                c.sdl.SDL_SCANCODE_0 => { // 0 - Player spawn effect
                    game_state.effect_system.addPlayerSpawnEffect(game_state.world.player.pos, game_state.world.player.radius);
                },
                c.sdl.SDL_SCANCODE_9 => { // 9 - Portal travel effect
                    game_state.effect_system.addPortalTravelEffect(game_state.world.player.pos, game_state.world.player.radius);
                },
                c.sdl.SDL_SCANCODE_8 => { // 8 - Portal ripple effect
                    game_state.effect_system.addPortalRippleEffect(game_state.world.player.pos, game_state.world.player.radius * 2.0);
                },
                c.sdl.SDL_SCANCODE_7 => { // 7 - Lifestone glow effect (attuned)
                    game_state.effect_system.addLifestoneGlowEffect(game_state.world.player.pos, game_state.world.player.radius * 1.5, true);
                },
                c.sdl.SDL_SCANCODE_6 => { // 6 - Lifestone glow effect (not attuned)
                    game_state.effect_system.addLifestoneGlowEffect(game_state.world.player.pos, game_state.world.player.radius * 1.5, false);
                },
                else => {},
            }
        },
        c.sdl.SDL_EVENT_KEY_UP => {
            game_state.input_state.handleKeyUp(event.key.scancode);
        },
        c.sdl.SDL_EVENT_MOUSE_MOTION => {
            game_state.input_state.handleMouseMotion(event.motion.x, event.motion.y);
        },
        c.sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
            game_state.input_state.handleMouseButtonDown(event.button.button);
            switch (event.button.button) {
                c.sdl.SDL_BUTTON_LEFT => {
                    if (!game_state.world.player.alive) {
                        game_controller.handleRespawn(game_state);
                    }
                },
                c.sdl.SDL_BUTTON_RIGHT => {
                    game_controller.handleFireBullet(game_state, &game_renderer.camera);
                },
                else => {},
            }
        },
        c.sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
            game_state.input_state.handleMouseButtonUp(event.button.button);
        },
        c.sdl.SDL_EVENT_MOUSE_WHEEL => {
            // Mouse wheel zoom
            const current_zone = game_state.world.getCurrentZoneMut();
            const zoom_factor = 1.1; // 10% zoom per wheel tick

            if (event.wheel.y > 0) {
                // Zoom in (scroll up)
                current_zone.camera_scale = @min(10.0, current_zone.camera_scale * zoom_factor);
            } else if (event.wheel.y < 0) {
                // Zoom out (scroll down)
                current_zone.camera_scale = @max(0.1, current_zone.camera_scale / zoom_factor);
            }
        },
        else => {},
    }

    return c.sdl.SDL_APP_CONTINUE;
}

```

</File>


<File path="src/renderer.zig">

```zig
const std = @import("std");

const c = @import("c.zig");

const entities = @import("entities.zig");
const types = @import("types.zig");
const simple_gpu_renderer = @import("simple_gpu_renderer.zig");
const camera = @import("camera.zig");
const borders = @import("borders.zig");
const constants = @import("constants.zig");
const effects = @import("effects.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
const SimpleGPURenderer = simple_gpu_renderer.SimpleGPURenderer;

pub const Renderer = struct {
    gpu: SimpleGPURenderer,
    camera: camera.Camera,

    pub fn init(allocator: std.mem.Allocator, window: *c.sdl.SDL_Window) !Renderer {
        return .{
            .gpu = try SimpleGPURenderer.init(allocator, window),
            .camera = camera.Camera.init(constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT),
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.gpu.deinit();
    }

    // Begin a new frame
    pub fn beginFrame(self: *Renderer, window: *c.sdl.SDL_Window) !*c.sdl.SDL_GPUCommandBuffer {
        return try self.gpu.beginFrame(window);
    }

    // Begin render pass
    pub fn beginRenderPass(self: *Renderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, window: *c.sdl.SDL_Window, bg_color: Color) !*c.sdl.SDL_GPURenderPass {
        return try self.gpu.beginRenderPass(cmd_buffer, window, bg_color);
    }

    // End render pass
    pub fn endRenderPass(self: *Renderer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        self.gpu.endRenderPass(render_pass);
    }

    // End frame
    pub fn endFrame(self: *Renderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer) void {
        self.gpu.endFrame(cmd_buffer);
    }

    // Update camera based on current zone (call before game logic update)
    pub fn updateCamera(self: *Renderer, world: *const entities.World) void {
        // Ensure camera has current screen dimensions (in case window resized)
        if (self.camera.screen_width != self.gpu.screen_width or
            self.camera.screen_height != self.gpu.screen_height)
        {
            self.camera.screen_width = self.gpu.screen_width;
            self.camera.screen_height = self.gpu.screen_height;
        }

        const zone = world.getCurrentZone();
        switch (zone.camera_mode) {
            .fixed => self.camera.setupFixed(zone.camera_scale),
            .follow => self.camera.setupFollow(world.player.pos, zone.camera_scale),
        }
    }

    // Render all entities in a zone
    pub fn renderZone(self: *Renderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, world: *const entities.World) void {
        const zone = world.getCurrentZone();

        // Draw all rectangles first (obstacles)
        self.renderObstacles(cmd_buffer, render_pass, zone);

        // Then draw all circles (player, enemies, bullets, etc)
        self.renderCircles(cmd_buffer, render_pass, world);
    }

    // Render all obstacles (rectangles)
    fn renderObstacles(self: *Renderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, zone: *const entities.Zone) void {
        for (0..zone.obstacle_count) |i| {
            const obstacle = &zone.obstacles[i];
            if (obstacle.active) {
                const screen_pos = self.camera.worldToScreen(obstacle.pos);
                const screen_size = Vec2{
                    .x = self.camera.worldSizeToScreen(obstacle.size.x),
                    .y = self.camera.worldSizeToScreen(obstacle.size.y),
                };
                self.gpu.drawRect(cmd_buffer, render_pass, screen_pos, screen_size, obstacle.color);
            }
        }
    }

    // Helper to render a single circular entity
    fn renderCircleEntity(self: *Renderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color) void {
        const screen_pos = self.camera.worldToScreen(pos);
        const screen_radius = self.camera.worldSizeToScreen(radius);
        self.gpu.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, color);
    }

    // Render all circular entities
    fn renderCircles(self: *Renderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, world: *const entities.World) void {
        const zone = world.getCurrentZone();

        // Draw player
        const player = &world.player;
        self.renderCircleEntity(cmd_buffer, render_pass, player.pos, player.radius, player.color);

        // Draw bullets
        for (0..entities.MAX_BULLETS) |i| {
            const bullet = &world.bullets[i];
            if (bullet.active) {
                self.renderCircleEntity(cmd_buffer, render_pass, bullet.pos, bullet.radius, bullet.color);
            }
        }

        // Draw lifestones
        for (0..zone.lifestone_count) |i| {
            const lifestone = &zone.lifestones[i];
            if (lifestone.active) {
                self.renderCircleEntity(cmd_buffer, render_pass, lifestone.pos, lifestone.radius, lifestone.color);
            }
        }

        // Draw portals
        for (0..zone.portal_count) |i| {
            const portal = &zone.portals[i];
            if (portal.active) {
                self.renderCircleEntity(cmd_buffer, render_pass, portal.pos, portal.radius, portal.color);
            }
        }

        // Draw units
        for (0..zone.unit_count) |i| {
            const unit = &zone.units[i];
            if (unit.active) {
                self.renderCircleEntity(cmd_buffer, render_pass, unit.pos, unit.radius, unit.color);
            }
        }
    }

    // Render visual effects
    pub fn renderEffects(self: *Renderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, effect_system: *const effects.EffectSystem) void {
        const active_effects = effect_system.getActiveEffects();

        // Get current time for shader animations
        const current_time = c.sdl.SDL_GetPerformanceCounter();
        const frequency = c.sdl.SDL_GetPerformanceFrequency();
        const time_sec = @as(f32, @floatFromInt(current_time)) / @as(f32, @floatFromInt(frequency));

        for (active_effects) |effect| {
            const screen_pos = self.camera.worldToScreen(effect.pos);
            const current_radius = effect.getCurrentRadius(); // Use dynamic radius for ping growth
            const screen_radius = self.camera.worldSizeToScreen(current_radius);
            const color = effect.getColor();
            const intensity = effect.getCurrentIntensity();

            self.gpu.drawEffect(cmd_buffer, render_pass, screen_pos, screen_radius, color, intensity, time_sec);
        }
    }

    // Draw border system with stacking support
    pub fn drawBorders(self: *Renderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, game_state: anytype) void {
        var border_stack = borders.BorderStack.init();

        // Iris wipe effect (highest priority - renders over everything)
        if (game_state.iris_wipe_active) {
            const current_time = c.sdl.SDL_GetPerformanceCounter();
            const frequency = c.sdl.SDL_GetPerformanceFrequency();
            const elapsed_sec = @as(f32, @floatFromInt(current_time - game_state.iris_wipe_start_time)) / @as(f32, @floatFromInt(frequency));
            const wipe_duration = borders.IRIS_WIPE_DURATION;

            if (elapsed_sec < wipe_duration) {
                const progress = elapsed_sec / wipe_duration; // 0.0 to 1.0
                // Strong ease-out curve: fast at start, very slow at end
                const eased_progress = 1.0 - (1.0 - progress) * (1.0 - progress) * (1.0 - progress) * (1.0 - progress); // Quartic ease-out
                const shrink_factor = 1.0 - eased_progress; // 1.0 to 0.0 (shrinking with strong ease-out)

                // Create iris wipe bands using existing game colors
                const wipe_colors = [_]Color{
                    Color{ .r = 100, .g = 150, .b = 255, .a = 255 }, // BLUE_BRIGHT
                    Color{ .r = 80, .g = 220, .b = 80, .a = 255 }, // GREEN_BRIGHT
                    Color{ .r = 255, .g = 220, .b = 80, .a = 255 }, // YELLOW_BRIGHT
                    Color{ .r = 255, .g = 180, .b = 80, .a = 255 }, // ORANGE_BRIGHT
                    Color{ .r = 180, .g = 100, .b = 240, .a = 255 }, // PURPLE_BRIGHT
                    Color{ .r = 0, .g = 200, .b = 200, .a = 255 }, // CYAN
                };

                for (wipe_colors) |wipe_color| {
                    const max_width = borders.IRIS_WIPE_BAND_WIDTH;
                    const current_width = max_width * shrink_factor;

                    if (current_width > 0.5) { // Only render if visible
                        border_stack.pushStatic(current_width, wipe_color);
                    }
                }
            } else {
                // End iris wipe
                @constCast(game_state).iris_wipe_active = false;
            }
        }

        // Game state borders (lower priority)
        if (game_state.isPaused()) {
            // Animated paused border: base 6px + 4px pulse amplitude
            border_stack.pushAnimated(6.0, borders.GOLD_YELLOW_COLORS, 1.5, 4.0);
        }

        if (!game_state.world.player.alive) {
            // Animated dead border: base 9px + 5px pulse amplitude
            border_stack.pushAnimated(9.0, borders.RED_COLORS, 1.2, 5.0);
        }

        // Render all borders with automatic offset calculation based on current animated widths
        var current_offset: f32 = 0;

        for (0..border_stack.count) |i| {
            const spec = &border_stack.specs[i];
            const current_width = spec.getCurrentWidth();
            const current_color = spec.getCurrentColor();

            self.drawBorderWithOffset(cmd_buffer, render_pass, current_color, current_width, current_offset);
            current_offset += current_width;
        }
    }

    // Helper method for border system integration
    pub fn drawBorderWithOffset(self: *Renderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, color: Color, width: f32, offset: f32) void {
        const rects = borders.calculateBorderRects(width, offset);
        for (rects) |rect| {
            self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = rect.x, .y = rect.y }, Vec2{ .x = rect.w, .y = rect.h }, color);
        }
    }

    // Simple HUD rendering
    pub fn drawFPS(self: *Renderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, fps: u32) void {
        const WHITE = Color{ .r = 230, .g = 230, .b = 230, .a = 255 };
        const fps_x = 1840.0;
        const fps_y = 1060.0;

        // Simple 2-digit FPS display
        const tens = (fps / 10) % 10;
        const ones = fps % 10;

        // Draw tens digit
        if (tens > 0) {
            self.drawDigit(cmd_buffer, render_pass, @intCast(tens), fps_x, fps_y, WHITE);
        }

        // Draw ones digit
        self.drawDigit(cmd_buffer, render_pass, @intCast(ones), fps_x + 12.0, fps_y, WHITE);
    }

    fn drawDigit(self: *Renderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, digit: u8, x: f32, y: f32, color: Color) void {
        if (digit > 9) return;

        // Simple 3x5 digit patterns
        const patterns = [_][15]bool{
            .{ true, true, true, true, false, true, true, false, true, true, false, true, true, true, true }, // 0
            .{ false, true, false, false, true, false, false, true, false, false, true, false, false, true, false }, // 1
            .{ true, true, true, false, false, true, true, true, true, true, false, false, true, true, true }, // 2
            .{ true, true, true, false, false, true, true, true, true, false, false, true, true, true, true }, // 3
            .{ true, false, true, true, false, true, true, true, true, false, false, true, false, false, true }, // 4
            .{ true, true, true, true, false, false, true, true, true, false, false, true, true, true, true }, // 5
            .{ true, true, true, true, false, false, true, true, true, true, false, true, true, true, true }, // 6
            .{ true, true, true, false, false, true, false, false, true, false, false, true, false, false, true }, // 7
            .{ true, true, true, true, false, true, true, true, true, true, false, true, true, true, true }, // 8
            .{ true, true, true, true, false, true, true, true, true, false, false, true, true, true, true }, // 9
        };

        const pattern = patterns[digit];
        for (0..5) |row| {
            for (0..3) |col| {
                if (pattern[row * 3 + col]) {
                    const px = x + @as(f32, @floatFromInt(col)) * 2.0;
                    const py = y + @as(f32, @floatFromInt(row)) * 2.0;
                    self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = px, .y = py }, Vec2{ .x = 1.5, .y = 1.5 }, color);
                }
            }
        }
    }
};

```

</File>


<File path="src/entities.zig">

```zig
const std = @import("std");

const types = @import("types.zig");
const constants = @import("constants.zig");

const Vec2 = types.Vec2;
const Color = types.Color;

// Game constants
pub const MAX_UNITS = 12;
pub const MAX_OBSTACLES = 50;
pub const MAX_BULLETS = 20;
pub const MAX_PORTALS = 6;
pub const MAX_LIFESTONES = 13;

// Player entity - special, only one
pub const Player = struct {
    pos: Vec2,
    vel: Vec2,
    radius: f32,
    color: Color,
    alive: bool,

    pub fn init() Player {
        return .{
            .pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y },
            .vel = Vec2{ .x = 0, .y = 0 },
            .radius = constants.PLAYER_RADIUS,
            .color = constants.COLOR_PLAYER_ALIVE,
            .alive = true,
        };
    }
};

// Unit entity (enemies, neutrals, allies)
pub const Unit = struct {
    pos: Vec2,
    vel: Vec2,
    home_pos: Vec2, // Original spawn position for return behavior
    radius: f32,
    color: Color,
    alive: bool,
    active: bool,

    pub fn init(x: f32, y: f32, radius: f32) Unit {
        return .{
            .pos = Vec2{ .x = x, .y = y },
            .vel = Vec2{ .x = 0, .y = 0 },
            .home_pos = Vec2{ .x = x, .y = y },
            .radius = radius,
            .color = constants.COLOR_UNIT_DEFAULT,
            .alive = true,
            .active = true,
        };
    }
};

// Obstacle entity (rectangles)
pub const Obstacle = struct {
    pos: Vec2,
    size: Vec2,
    color: Color,
    is_deadly: bool,
    active: bool,

    pub fn init(x: f32, y: f32, width: f32, height: f32, is_deadly: bool) Obstacle {
        return .{
            .pos = Vec2{ .x = x, .y = y },
            .size = Vec2{ .x = width, .y = height },
            .color = if (is_deadly)
                constants.COLOR_OBSTACLE_DEADLY
            else
                constants.COLOR_OBSTACLE_BLOCKING,
            .is_deadly = is_deadly,
            .active = true,
        };
    }
};

// Bullet entity
pub const Bullet = struct {
    pos: Vec2,
    vel: Vec2,
    radius: f32,
    color: Color,
    active: bool,

    pub fn init() Bullet {
        return .{
            .pos = Vec2{ .x = 0, .y = 0 },
            .vel = Vec2{ .x = 0, .y = 0 },
            .radius = constants.BULLET_RADIUS,
            .color = constants.COLOR_BULLET,
            .active = false,
        };
    }
};

// Portal entity - gateway to travel between zones
pub const Portal = struct {
    pos: Vec2,
    radius: f32,
    color: Color,
    destination_zone: u8,
    active: bool,

    pub fn init(x: f32, y: f32, radius: f32, destination: u8) Portal {
        return .{
            .pos = Vec2{ .x = x, .y = y },
            .radius = radius,
            .color = constants.COLOR_PORTAL,
            .destination_zone = destination,
            .active = true,
        };
    }
};

// Lifestone entity
pub const Lifestone = struct {
    pos: Vec2,
    radius: f32,
    color: Color,
    attuned: bool,
    active: bool,

    pub fn init(x: f32, y: f32, radius: f32, pre_attuned: bool) Lifestone {
        return .{
            .pos = Vec2{ .x = x, .y = y },
            .radius = radius,
            .color = if (pre_attuned)
                constants.COLOR_LIFESTONE_ATTUNED
            else
                constants.COLOR_LIFESTONE_UNATTUNED,
            .attuned = pre_attuned,
            .active = true,
        };
    }
};

// Camera modes
pub const CameraMode = enum {
    fixed,
    follow,
};

// Zone - a distinct area of the game world with its own entities and environment
pub const Zone = struct {
    // Environmental properties
    name: []const u8,
    background_color: Color,
    camera_mode: CameraMode,
    camera_scale: f32, // Zoom level for this zone (1.0 = default, <1.0 = zoomed out, >1.0 = zoomed in)

    // Entity pools with counts
    units: [MAX_UNITS]Unit,
    unit_count: usize,

    obstacles: [MAX_OBSTACLES]Obstacle,
    obstacle_count: usize,

    portals: [MAX_PORTALS]Portal,
    portal_count: usize,

    lifestones: [MAX_LIFESTONES]Lifestone,
    lifestone_count: usize,

    // Original state for reset functionality
    original_units: [MAX_UNITS]Unit,
    original_unit_count: usize,

    pub fn init(name: []const u8, bg_color: Color, cam_mode: CameraMode, scale: f32) Zone {
        return .{
            .name = name,
            .background_color = bg_color,
            .camera_mode = cam_mode,
            .camera_scale = scale,
            .units = std.mem.zeroes([MAX_UNITS]Unit),
            .unit_count = 0,
            .obstacles = std.mem.zeroes([MAX_OBSTACLES]Obstacle),
            .obstacle_count = 0,
            .portals = std.mem.zeroes([MAX_PORTALS]Portal),
            .portal_count = 0,
            .lifestones = std.mem.zeroes([MAX_LIFESTONES]Lifestone),
            .lifestone_count = 0,
            .original_units = std.mem.zeroes([MAX_UNITS]Unit),
            .original_unit_count = 0,
        };
    }

    pub fn addUnit(self: *Zone, unit: Unit) void {
        if (self.unit_count < MAX_UNITS) {
            self.units[self.unit_count] = unit;
            self.unit_count += 1;
        }
    }

    pub fn addObstacle(self: *Zone, obstacle: Obstacle) void {
        if (self.obstacle_count < MAX_OBSTACLES) {
            self.obstacles[self.obstacle_count] = obstacle;
            self.obstacle_count += 1;
        }
    }

    pub fn addPortal(self: *Zone, portal: Portal) void {
        if (self.portal_count < MAX_PORTALS) {
            self.portals[self.portal_count] = portal;
            self.portal_count += 1;
        }
    }

    pub fn addLifestone(self: *Zone, lifestone: Lifestone) void {
        if (self.lifestone_count < MAX_LIFESTONES) {
            self.lifestones[self.lifestone_count] = lifestone;
            self.lifestone_count += 1;
        }
    }

    pub fn resetUnits(self: *Zone) void {
        for (0..self.unit_count) |i| {
            // Reset velocity to stop aggro movement - units will walk home naturally
            self.units[i].vel = Vec2{ .x = 0, .y = 0 };
            // Don't reset position or alive status - preserve death state and let them walk home
        }
    }

    pub fn resetUnitsToOriginal(self: *Zone) void {
        // Restore units from original state (bulk copy)
        self.units = self.original_units;
        self.unit_count = self.original_unit_count;
    }
};

// World state - contains all game zones and entities
pub const World = struct {
    // Player is special
    player: Player,
    player_start_pos: Vec2, // Original spawn position for full reset

    // Global bullet pool (persists across zone travel)
    bullets: [MAX_BULLETS]Bullet,

    // Zones the player can travel between
    zones: [7]Zone, // Overworld + 6 dungeons
    current_zone: usize,

    pub fn init() World {
        var world = World{
            .player = Player.init(),
            .player_start_pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y },
            .bullets = undefined,
            .zones = undefined,
            .current_zone = 0,
        };

        // Initialize bullets
        for (0..MAX_BULLETS) |i| {
            world.bullets[i] = Bullet.init();
        }

        // Zones will be loaded from ZON data
        return world;
    }

    pub fn getCurrentZone(self: *const World) *const Zone {
        return &self.zones[self.current_zone];
    }

    pub fn getCurrentZoneMut(self: *World) *Zone {
        return &self.zones[self.current_zone];
    }

    pub fn findInactiveBullet(self: *World) ?*Bullet {
        for (0..MAX_BULLETS) |i| {
            if (!self.bullets[i].active) {
                return &self.bullets[i];
            }
        }
        return null;
    }

    pub fn resetCurrentZone(self: *World) void {
        // Reset units in current zone to their original spawn state
        self.zones[self.current_zone].resetUnitsToOriginal();
    }

    pub fn resetAllZones(self: *World) void {
        // Reset all zones to their original state
        for (0..self.zones.len) |i| {
            self.zones[i].resetUnitsToOriginal();
        }
        // Clear all bullets
        for (0..MAX_BULLETS) |i| {
            self.bullets[i].active = false;
        }
    }
};

```

</File>


<File path="src/effects.zig">

```zig
const std = @import("std");

const c = @import("c.zig");

const types = @import("types.zig");
const constants = @import("constants.zig");

const Vec2 = types.Vec2;
const Color = types.Color;

pub const MAX_EFFECTS = 256; // Increased pool for multiple simultaneous effects

pub const EffectType = enum {
    player_spawn, // Dramatic ping when player respawns
    portal_travel, // Multiple pings when player travels through portal
    portal_ripple, // Subtle ripples emanating from portal
    portal_ambient, // Continuous pulsing field around portals
    portal_middle, // Medium layer with different timing between outer and inner
    portal_inner, // Faster, smaller inner aura around portals
    lifestone_glow, // Gentle glow around lifestones
    lifestone_inner, // Faster inner aura inside lifestone glow
};

pub const Effect = struct {
    pos: Vec2,
    radius: f32,
    effect_type: EffectType,
    active: bool,
    start_time: u64,
    duration: f32, // 0.0 = permanent
    intensity: f32,

    pub fn init(pos: Vec2, radius: f32, effect_type: EffectType, duration: f32) Effect {
        return .{
            .pos = pos,
            .radius = radius,
            .effect_type = effect_type,
            .active = true,
            .start_time = c.sdl.SDL_GetPerformanceCounter(),
            .duration = duration,
            .intensity = 1.0,
        };
    }

    pub fn isActive(self: *const Effect) bool {
        if (!self.active) return false;
        if (self.duration == 0.0) return true; // Permanent effect

        const current_time = c.sdl.SDL_GetPerformanceCounter();
        // Check if effect has started yet (handle delayed effects)
        if (current_time < self.start_time) return true; // Not started yet, but active

        const frequency = c.sdl.SDL_GetPerformanceFrequency();
        const elapsed_sec = @as(f32, @floatFromInt(current_time - self.start_time)) / @as(f32, @floatFromInt(frequency));
        return elapsed_sec < self.duration;
    }

    pub fn getElapsed(self: *const Effect) f32 {
        const current_time = c.sdl.SDL_GetPerformanceCounter();
        // If effect hasn't started yet, return 0 elapsed time
        if (current_time < self.start_time) return 0.0;

        const frequency = c.sdl.SDL_GetPerformanceFrequency();
        return @as(f32, @floatFromInt(current_time - self.start_time)) / @as(f32, @floatFromInt(frequency));
    }

    fn getPulse(elapsed: f32, frequency: f32, phase_offset: f32) f32 {
        return (std.math.sin(elapsed * frequency + phase_offset) + 1.0) * 0.5; // 0.0 to 1.0
    }

    pub fn getCurrentRadius(self: *const Effect) f32 {
        const elapsed = self.getElapsed();

        switch (self.effect_type) {
            .player_spawn => {
                // Grow continuously for full duration, synced with fade out
                if (self.duration > 0.0) {
                    const progress = elapsed / self.duration; // 0.0 to 1.0
                    // Grow from 20% to 300% size over full duration for dramatic expanding ring
                    return self.radius * (0.2 + progress * 2.8); // 20% → 300% size
                }
                return self.radius;
            },
            .portal_travel => {
                // Different growth rates based on effect intensity
                if (self.duration > 0.0) {
                    const progress = elapsed / self.duration;
                    if (self.intensity >= 0.9) {
                        // First ping: fast, dramatic growth (intensity = 1.0)
                        return self.radius * (0.3 + progress * 3.7); // 30% → 400% size - much bigger!
                    } else if (self.intensity >= 0.7 and self.intensity < 0.8) {
                        // NEW slow-growing ring (intensity = 0.7)
                        return self.radius * (0.5 + progress * 4.5); // 50% → 500% size over 3.5 seconds - good as is
                    } else if (self.intensity >= 0.8 and self.intensity < 0.9) {
                        // Small marker ping (intensity = 0.8)
                        return self.radius * (0.2 + progress * 2.8); // 20% → 300% size - much bigger!
                    } else {
                        // Large expansion (intensity = 0.5)
                        return self.radius * (0.4 + progress * 4.1); // 40% → 450% size - much bigger!
                    }
                }
                return self.radius;
            },
            .portal_ripple => {
                // Subtle growing ripple rings
                if (self.duration > 0.0) {
                    const progress = elapsed / self.duration;
                    // Small growth outward from portal edge
                    return self.radius * (1.0 + progress * 0.8); // 100% → 180% size - much smaller growth
                }
                return self.radius;
            },
            .portal_ambient => {
                // Subtle size pulse for ambient effects
                const pulse = getPulse(elapsed, 0.5, 0.0);
                return self.radius * (0.9 + pulse * 0.2); // 90% to 110% size
            },
            .portal_middle => {
                // Medium size pulse with phase offset for staggered timing
                const pulse = getPulse(elapsed, 0.65, 2.1);
                return self.radius * (0.85 + pulse * 0.4); // 85% to 125% size
            },
            .portal_inner => {
                // Faster size pulse with different phase offset
                const pulse = getPulse(elapsed, 0.8, 4.2);
                return self.radius * (0.9 + pulse * 0.8); // 90% to 170% size (much larger growth)
            },
            .lifestone_glow => {
                // Very gentle size pulse for lifestone glow
                const pulse = getPulse(elapsed, 0.7, 0.0);
                return self.radius * (0.92 + pulse * 0.16); // 92% to 108% size
            },
            .lifestone_inner => {
                // Significantly faster inner aura pulse
                const pulse = getPulse(elapsed, 2.8, 1.5); // Much faster speed (2.8 vs 0.7), phase offset
                return self.radius * (0.88 + pulse * 0.24); // 88% to 112% size (more variation)
            },
        }
    }

    pub fn getCurrentIntensity(self: *const Effect) f32 {
        const elapsed = self.getElapsed();

        switch (self.effect_type) {
            .player_spawn => {
                // Quick fade out over 3 seconds for dramatic ping with lower starting intensity
                if (self.duration > 0.0) {
                    const progress = elapsed / self.duration; // 0.0 to 1.0
                    const fade = 1.0 - (progress * progress); // Quadratic fade out
                    return @max(0.0, fade * self.intensity * 0.4); // Start at 40% intensity for transparency
                }
                return self.intensity * 0.4;
            },
            .portal_travel => {
                // Quick fade over 1.5 seconds with transparency
                if (self.duration > 0.0) {
                    const fade = 1.0 - (elapsed / self.duration);
                    return @max(0.0, fade * self.intensity * 0.5); // 50% intensity for transparency
                }
                return self.intensity * 0.5;
            },
            .portal_ripple => {
                // Ripple fade like ping
                if (self.duration > 0.0) {
                    const progress = elapsed / self.duration;
                    const fade = 1.0 - (progress * progress); // Quadratic fade
                    return @max(0.0, fade * self.intensity * 0.6); // 60% max intensity for visibility
                }
                return self.intensity * 0.6;
            },
            .portal_ambient => {
                // Gentle but visible pulse for ambient effects
                const pulse = getPulse(elapsed, 0.6, 0.0);
                return (0.22 + pulse * 0.03) * self.intensity; // 0.22 to 0.25 range
            },
            .portal_middle => {
                // Medium pulse for middle portal layer with phase offset
                const pulse = getPulse(elapsed, 0.78, 1.8);
                return (0.20 + pulse * 0.04) * self.intensity; // 0.20 to 0.24 range
            },
            .portal_inner => {
                // Faster pulse for inner portal aura with phase offset
                const pulse = getPulse(elapsed, 0.96, 3.5);
                return (0.18 + pulse * 0.05) * self.intensity; // 0.18 to 0.23 range
            },
            .lifestone_glow => {
                // Gentle pulse for lifestone auras
                const pulse = getPulse(elapsed, 0.8, 0.0);
                return (0.38 + pulse * 0.07) * self.intensity;
            },
            .lifestone_inner => {
                // Faster, lower intensity inner aura
                const pulse = getPulse(elapsed, 2.8, 1.5); // Same fast speed as radius
                return (0.38 + pulse * 0.08) * self.intensity; // 0.18 to 0.26 range (lower max, min ~1 when scaled)
            },
        }
    }

    pub fn getColor(self: *const Effect) Color {
        const intensity = self.getCurrentIntensity();

        switch (self.effect_type) {
            .player_spawn => {
                // Bright blue/white for dramatic effect
                return Color{
                    .r = @min(255, @as(u8, @intFromFloat(100.0 + intensity * 155.0))),
                    .g = @min(255, @as(u8, @intFromFloat(150.0 + intensity * 105.0))),
                    .b = 255,
                    .a = @as(u8, @intFromFloat(@min(255.0, 255.0 * intensity))),
                };
            },
            .portal_travel => {
                // Different colors for first vs second ping
                if (self.intensity > 0.8) {
                    // First ping: bright blue-white (fast and bright)
                    return Color{
                        .r = @min(255, @as(u8, @intFromFloat(120.0 + intensity * 135.0))),
                        .g = @min(255, @as(u8, @intFromFloat(160.0 + intensity * 95.0))),
                        .b = 255,
                        .a = @as(u8, @intFromFloat(@min(255.0, 200.0 * intensity))),
                    };
                } else {
                    // Second ping: softer blue-cyan (slower and larger)
                    return Color{
                        .r = @as(u8, @intFromFloat(@min(255.0, 80.0 + intensity * 120.0))),
                        .g = @as(u8, @intFromFloat(@min(255.0, 180.0 + intensity * 75.0))),
                        .b = 255,
                        .a = @as(u8, @intFromFloat(@min(255.0, 160.0 * intensity))),
                    };
                }
            },
            .portal_ripple => {
                // Bright portal purple for visibility
                return Color{
                    .r = 255,
                    .g = @as(u8, @intFromFloat(@min(255.0, 50.0 + intensity * 100.0))),
                    .b = 255,
                    .a = @as(u8, @intFromFloat(@min(255.0, 200.0 * intensity))),
                };
            },
            .portal_ambient => {
                // Brighter purple for better visibility at low alpha
                return Color{
                    .r = 255,
                    .g = @as(u8, @intFromFloat(@min(255.0, 180.0 * intensity))),
                    .b = 255,
                    .a = @as(u8, @intFromFloat(@min(255.0, 255.0 * intensity))),
                };
            },
            .portal_middle => {
                // Medium purple between outer and inner layers
                return Color{
                    .r = 255,
                    .g = @as(u8, @intFromFloat(@min(255.0, 150.0 * intensity))),
                    .b = 255,
                    .a = @as(u8, @intFromFloat(@min(255.0, 255.0 * intensity))),
                };
            },
            .portal_inner => {
                // Slightly different purple for inner aura (more magenta)
                return Color{
                    .r = 255,
                    .g = @as(u8, @intFromFloat(@min(255.0, 120.0 * intensity))),
                    .b = 255,
                    .a = @as(u8, @intFromFloat(@min(255.0, 255.0 * intensity))),
                };
            },
            .lifestone_glow => {
                // Cyan for lifestones
                return Color{
                    .r = @as(u8, @intFromFloat(@min(255.0, 50.0 * intensity))),
                    .g = @as(u8, @intFromFloat(@min(255.0, 220.0 * intensity))),
                    .b = @as(u8, @intFromFloat(@min(255.0, 220.0 * intensity))),
                    .a = @as(u8, @intFromFloat(@min(255.0, 150.0 * intensity))),
                };
            },
            .lifestone_inner => {
                // Brighter cyan/white for inner lifestone aura
                return Color{
                    .r = @as(u8, @intFromFloat(@min(255.0, 80.0 * intensity))),
                    .g = @as(u8, @intFromFloat(@min(255.0, 240.0 * intensity))),
                    .b = @as(u8, @intFromFloat(@min(255.0, 255.0 * intensity))),
                    .a = @as(u8, @intFromFloat(@min(255.0, 180.0 * intensity))),
                };
            },
        }
    }
};

pub const EffectSystem = struct {
    effects: [MAX_EFFECTS]Effect,
    count: usize,

    const Self = @This();

    pub fn init() Self {
        return .{
            .effects = undefined,
            .count = 0,
        };
    }

    pub fn clear(self: *Self) void {
        self.count = 0;
    }

    pub fn addEffect(self: *Self, pos: Vec2, radius: f32, effect_type: EffectType, duration: f32) void {
        if (self.count >= MAX_EFFECTS) {
            std.debug.print("WARNING: Effect pool full! ({} effects)\n", .{MAX_EFFECTS});
            return;
        }

        self.effects[self.count] = Effect.init(pos, radius, effect_type, duration);
        self.count += 1;

        // Debug warning when approaching limit
        if (self.count > MAX_EFFECTS * 3 / 4) {
            std.debug.print("Effect pool usage high: {}/{}\n", .{ self.count, MAX_EFFECTS });
        }
    }

    pub fn update(self: *Self) void {
        // Remove expired effects
        var write_index: usize = 0;
        for (0..self.count) |read_index| {
            if (self.effects[read_index].isActive()) {
                if (write_index != read_index) {
                    self.effects[write_index] = self.effects[read_index];
                }
                write_index += 1;
            }
        }
        self.count = write_index;
    }

    pub fn getActiveEffects(self: *const Self) []const Effect {
        return self.effects[0..self.count];
    }

    // Effect creation methods for different gameplay events
    pub fn addPlayerSpawnEffect(self: *Self, pos: Vec2, player_radius: f32) void {
        // Dramatic staggered ring expansion mimicking old visuals system
        // Multiple waves with varied timing for less uniformity and better visual drama
        const ring_configs = [_]struct { delay: f32, duration: f32, size_mult: f32, intensity: f32 }{
            .{ .delay = 0.0, .duration = 0.8, .size_mult = 1.4, .intensity = 1.0 },
            .{ .delay = 0.1, .duration = 2.4, .size_mult = 1.8, .intensity = 0.4 },
            .{ .delay = 0.15, .duration = 1.2, .size_mult = 1.2, .intensity = 0.7 },
            .{ .delay = 0.25, .duration = 2.0, .size_mult = 3.4, .intensity = 0.5 },
            .{ .delay = 0.3, .duration = 2.2, .size_mult = 1.4, .intensity = 0.5 },
            .{ .delay = 0.4, .duration = 1.4, .size_mult = 2.4, .intensity = 0.3 },
        };

        for (ring_configs) |config| {
            self.addEffect(pos, player_radius * config.size_mult, .player_spawn, config.duration);
            if (self.count > 0) {
                // Customize the effect we just added
                var effect = &self.effects[self.count - 1];
                effect.start_time += @as(u64, @intFromFloat(config.delay * @as(f32, @floatFromInt(c.sdl.SDL_GetPerformanceFrequency()))));
                effect.intensity = config.intensity;
            }
        }
    }

    pub fn addPortalTravelEffect(self: *Self, pos: Vec2, player_radius: f32) void {
        // Multiple staggered pings when traveling through portals - distinct from spawn
        const ring_configs = [_]struct { delay: f32, duration: f32, size_mult: f32, intensity: f32 }{
            .{ .delay = 0.0, .duration = 0.8, .size_mult = 1.8, .intensity = 1.0 }, // Initial bright ping - perfect as is
            .{ .delay = 0.1, .duration = 3.5, .size_mult = 0.8, .intensity = 0.7 }, // Slow ring - bigger base like first
            .{ .delay = 0.35, .duration = 1.5, .size_mult = 0.2, .intensity = 0.5 }, // Large expansion - bigger base
            .{ .delay = 0.55, .duration = 1.0, .size_mult = 0.8, .intensity = 0.8 }, // Location marker - bigger base
        };

        for (ring_configs) |config| {
            self.addEffect(pos, player_radius * config.size_mult, .portal_travel, config.duration);
            if (self.count > 0) {
                // Customize the effect we just added
                var effect = &self.effects[self.count - 1];
                effect.start_time += @as(u64, @intFromFloat(config.delay * @as(f32, @floatFromInt(c.sdl.SDL_GetPerformanceFrequency()))));
                effect.intensity = config.intensity;
            }
        }
    }

    pub fn addPortalRippleEffect(self: *Self, pos: Vec2, portal_radius: f32) void {
        // Subtle ripples emanating from portal
        const ripple_configs = [_]struct { delay: f32, duration: f32, size_mult: f32, intensity: f32 }{
            .{ .delay = 0.0, .duration = 1.5, .size_mult = 1.4, .intensity = 0.5 }, // First ripple - small, quick
            .{ .delay = 0.2, .duration = 1.25, .size_mult = 1.6, .intensity = 0.4 }, // Second ripple
        };

        for (ripple_configs) |config| {
            if (self.count >= MAX_EFFECTS) break;

            self.effects[self.count] = Effect.init(pos, portal_radius * config.size_mult, .portal_ripple, config.duration);
            self.effects[self.count].start_time += @as(u64, @intFromFloat(config.delay * @as(f32, @floatFromInt(c.sdl.SDL_GetPerformanceFrequency()))));
            self.effects[self.count].intensity = config.intensity;
            self.count += 1;
        }
    }

    pub fn addPortalAmbientEffect(self: *Self, pos: Vec2, portal_radius: f32) void {
        // Triple-layer persistent aura around portals with different timings
        self.addEffect(pos, portal_radius * 1.44, .portal_ambient, 0.0); // Outer gentle pulse
        self.addEffect(pos, portal_radius * 1.32, .portal_middle, 0.0); // Middle layer with different timing
        self.addEffect(pos, portal_radius * 1.2, .portal_inner, 0.0); // Inner dynamic pulse
    }

    pub fn addLifestoneGlowEffect(self: *Self, pos: Vec2, lifestone_radius: f32, attuned: bool) void {
        self.addLifestoneGlowEffectParts(pos, lifestone_radius, true, attuned);
    }

    pub fn addLifestoneInnerEffectOnly(self: *Self, pos: Vec2, lifestone_radius: f32) void {
        // Add only the inner effect for newly attuned lifestones
        self.addLifestoneGlowEffectParts(pos, lifestone_radius, false, true);
    }

    fn addLifestoneGlowEffectParts(self: *Self, pos: Vec2, lifestone_radius: f32, add_outer: bool, attuned: bool) void {
        // Outer lifestone glow (always present when add_outer is true)
        if (add_outer) {
            self.addEffect(pos, lifestone_radius * 1.8, .lifestone_glow, 0.0);
        }

        // Inner lifestone aura - only for attuned lifestones
        if (attuned) {
            self.addEffect(pos, lifestone_radius * 1.4, .lifestone_inner, 0.0);
        }
    }

    // Rebuild persistent ambient effects when traveling between zones
    pub fn refreshAmbientEffects(self: *Self, world: anytype) void {
        // Clear existing ambient effects while preserving temporary ones
        var write_index: usize = 0;
        for (0..self.count) |read_index| {
            const effect = &self.effects[read_index];
            if (effect.effect_type != .portal_ambient and effect.effect_type != .portal_middle and effect.effect_type != .portal_inner and effect.effect_type != .lifestone_glow and effect.effect_type != .lifestone_inner) {
                if (write_index != read_index) {
                    self.effects[write_index] = self.effects[read_index];
                }
                write_index += 1;
            }
        }
        self.count = write_index;

        // Create ambient effects for current zone entities
        const zone = world.getCurrentZone();

        // Add auras around active portals
        for (0..zone.portal_count) |i| {
            const portal = &zone.portals[i];
            if (portal.active) {
                self.addPortalAmbientEffect(portal.pos, portal.radius);
            }
        }

        // Add glows around active lifestones
        for (0..zone.lifestone_count) |i| {
            const lifestone = &zone.lifestones[i];
            if (lifestone.active) {
                self.addLifestoneGlowEffect(lifestone.pos, lifestone.radius, lifestone.attuned);
            }
        }
    }
};

```

</File>


<File path="src/game.zig">

```zig
const std = @import("std");

const c = @import("c.zig");

const types = @import("types.zig");
const entities = @import("entities.zig");
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const input = @import("input.zig");
const player_controller = @import("player.zig");
const combat = @import("combat.zig");
const portals = @import("portals.zig");
const camera = @import("camera.zig");
const effects = @import("effects.zig");

const Vec2 = types.Vec2;
const World = entities.World;
const InputState = input.InputState;

pub const GameState = struct {
    world: World,
    input_state: InputState,
    game_paused: bool,
    quit_requested: bool,

    // Visual effects system
    effect_system: effects.EffectSystem,

    // Iris wipe effect for resurrection
    iris_wipe_active: bool,
    iris_wipe_start_time: u64,

    const Self = @This();

    pub fn init() Self {
        return .{
            .world = World.init(),
            .input_state = InputState.init(),
            .game_paused = false,
            .quit_requested = false,
            .effect_system = effects.EffectSystem.init(),
            .iris_wipe_active = false,
            .iris_wipe_start_time = 0,
        };
    }

    pub fn travelToZone(self: *Self, destination_zone: usize) void {
        if (destination_zone < self.world.zones.len) {
            self.world.current_zone = destination_zone;
            self.world.zones[destination_zone].resetUnits();
            // Clear bullets on zone travel
            for (0..entities.MAX_BULLETS) |i| {
                self.world.bullets[i].active = false;
            }
            // Clear ALL effects on zone travel to prevent persistence
            self.effect_system.clear();
            // Rebuild ambient effects for new zone
            self.effect_system.refreshAmbientEffects(&self.world);
        }
    }

    pub fn togglePause(self: *Self) void {
        self.game_paused = !self.game_paused;
        if (self.game_paused) {
            std.debug.print("Game paused\n", .{});
        } else {
            std.debug.print("Game resumed\n", .{});
        }
    }

    pub fn requestQuit(self: *Self) void {
        self.quit_requested = true;
    }

    pub fn shouldQuit(self: *const Self) bool {
        return self.quit_requested;
    }

    pub fn isPaused(self: *const Self) bool {
        return self.game_paused;
    }

    pub fn resetZone(self: *Self) void {
        // Reset units in current zone to their original spawn state
        self.world.resetCurrentZone();
        std.debug.print("Zone units reset to original state\n", .{});
    }

    pub fn resetGame(self: *Self) void {
        // Reset player to starting position and state
        self.world.player.pos = self.world.player_start_pos;
        self.world.player.vel = types.Vec2{ .x = 0, .y = 0 };
        self.world.player.alive = true;
        self.world.player.color = @import("constants.zig").COLOR_PLAYER_ALIVE;

        // Reset to starting zone
        if (self.world.current_zone != 0) {
            self.travelToZone(0);
        }

        // Reset all zones
        self.world.resetAllZones();

        // Clear effects for clean slate
        self.effect_system.clear();
        self.effect_system.refreshAmbientEffects(&self.world);

        std.debug.print("Full game reset\n", .{});
    }
};

pub fn updateGame(game_state: *GameState, cam: *const camera.Camera, deltaTime: f32) void {
    if (game_state.game_paused) return;

    const world = &game_state.world;
    const input_state = &game_state.input_state;

    if (world.player.alive) {
        player_controller.updatePlayer(&world.player, input_state, world.getCurrentZone(), cam, deltaTime);
    }

    for (0..entities.MAX_BULLETS) |i| {
        behaviors.updateBullet(&world.bullets[i], deltaTime);
    }

    const zone = world.getCurrentZoneMut();
    for (0..zone.unit_count) |i| {
        const unit = &zone.units[i];

        if (!unit.active or !unit.alive) continue;

        const old_pos = unit.pos;
        behaviors.updateUnit(unit, world.player.pos, world.player.alive, deltaTime);

        for (0..zone.obstacle_count) |j| {
            const obstacle = &zone.obstacles[j];
            if (!obstacle.active) continue;

            if (physics.checkCircleRectCollision(unit.pos, unit.radius, obstacle.pos, obstacle.size)) {
                if (obstacle.is_deadly) {
                    combat.handleUnitDeathOnHazard(unit);
                } else {
                    unit.pos = old_pos;
                }
                break;
            }
        }
    }

    checkCollisions(game_state);

    // Update visual effects
    game_state.effect_system.update();
}

pub fn checkCollisions(game_state: *GameState) void {
    const world = &game_state.world;
    const zone = world.getCurrentZoneMut();
    const player = &world.player;

    physics.processBulletCollisions(world);

    if (!player.alive) return;

    if (portals.checkPortalCollisions(game_state)) {
        return;
    }

    for (0..zone.unit_count) |i| {
        if (physics.checkPlayerUnitCollision(player, &zone.units[i])) {
            combat.handlePlayerDeath(player);
            return;
        }
    }

    for (0..zone.lifestone_count) |i| {
        if (!zone.lifestones[i].attuned and physics.checkPlayerLifestoneCollision(player, &zone.lifestones[i])) {
            behaviors.attuneLifestone(&zone.lifestones[i]);
            std.debug.print("Lifestone attuned!\n", .{});
            // Add inner effect for newly attuned lifestone
            // TODO more declaratively?
            game_state.effect_system.addLifestoneInnerEffectOnly(zone.lifestones[i].pos, zone.lifestones[i].radius);
        }
    }

    if (physics.collidesWithDeadlyObstacle(player.pos, player.radius, zone)) {
        combat.handlePlayerDeathOnHazard(player);
    }
}

pub fn handleFireBullet(game_state: *GameState, cam: *const camera.Camera) void {
    if (game_state.world.player.alive and !game_state.game_paused) {
        const world_mouse_pos = game_state.input_state.getWorldMousePos(cam);
        combat.fireBulletAtMouse(&game_state.world, world_mouse_pos);
    }
}

pub fn handleRespawn(game_state: *GameState) void {
    // Start iris wipe effect
    game_state.iris_wipe_active = true;
    game_state.iris_wipe_start_time = c.sdl.SDL_GetPerformanceCounter();

    combat.respawnPlayer(game_state);
}

```

</File>


<File path="src/c.zig">

```zig
// Centralized C library imports to prevent type mismatches across modules
// All C imports should be added here to maintain type consistency

// SDL3 - Core graphics, input, and windowing
pub const sdl = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});

// Future C libraries can be added here as separate constants:
// pub const opengl = @cImport({ @cInclude("GL/gl.h"); });
// pub const curl = @cImport({ @cInclude("curl/curl.h"); });

```

</File>


<File path="src/constants.zig">

```zig
const types = @import("types.zig");

// Screen/Window dimensions
pub const SCREEN_WIDTH = 1920.0;
pub const SCREEN_HEIGHT = 1080.0;
pub const SCREEN_CENTER_X = SCREEN_WIDTH / 2.0;
pub const SCREEN_CENTER_Y = SCREEN_HEIGHT / 2.0;

// Movement and gameplay constants
pub const PLAYER_SPEED = 600.0;
pub const PLAYER_RADIUS = 20.0;
pub const UNIT_SPEED = 80.0;
pub const UNIT_AGGRO_RANGE = 300.0;
pub const UNIT_WALK_SPEED = UNIT_SPEED * 0.333; // 1/3 speed when returning home
pub const UNIT_HOME_TOLERANCE = 2.0; // Distance tolerance for "at home" check
pub const BULLET_SPEED = 400.0;
pub const BULLET_RADIUS = 5.0;
pub const PORTAL_SPAWN_OFFSET = 10.0; // Extra distance when spawning near portals

// Color constants
pub const COLOR_PLAYER_ALIVE = types.Color{ .r = 0, .g = 70, .b = 200, .a = 255 }; // BLUE
pub const COLOR_UNIT_DEFAULT = types.Color{ .r = 100, .g = 100, .b = 100, .a = 255 }; // GRAY (default unit color)
pub const COLOR_UNIT_AGGRO = types.Color{ .r = 200, .g = 30, .b = 30, .a = 255 }; // RED (aggro)
pub const COLOR_UNIT_NON_AGGRO = types.Color{ .r = 120, .g = 60, .b = 60, .a = 255 }; // DIMMED RED (non-aggro)
pub const COLOR_OBSTACLE_DEADLY = types.Color{ .r = 200, .g = 100, .b = 0, .a = 255 }; // ORANGE (deadly)
pub const COLOR_OBSTACLE_BLOCKING = types.Color{ .r = 0, .g = 140, .b = 0, .a = 255 }; // GREEN (blocking)
pub const COLOR_BULLET = types.Color{ .r = 220, .g = 160, .b = 0, .a = 255 }; // YELLOW
pub const COLOR_PORTAL = types.Color{ .r = 120, .g = 30, .b = 160, .a = 255 }; // PURPLE
pub const COLOR_LIFESTONE_ATTUNED = types.Color{ .r = 0, .g = 200, .b = 200, .a = 255 }; // CYAN (attuned)
pub const COLOR_LIFESTONE_UNATTUNED = types.Color{ .r = 0, .g = 100, .b = 100, .a = 255 }; // CYAN_FADED (unattuned)
pub const COLOR_DEAD = types.Color{ .r = 100, .g = 100, .b = 100, .a = 255 }; // GRAY

```

</File>


<File path="src/behaviors.zig">

```zig
const std = @import("std");

const entities = @import("entities.zig");
const types = @import("types.zig");
const constants = @import("constants.zig");

const Vec2 = types.Vec2;
const Player = entities.Player;
const Unit = entities.Unit;
const Bullet = entities.Bullet;
const World = entities.World;

// Update player based on input with camera-aware bounds
pub fn updatePlayer(player: *Player, vel: Vec2, dt: f32, use_screen_bounds: bool) void {
    if (!player.alive) return;

    player.vel = vel;
    player.pos.x += vel.x * dt;
    player.pos.y += vel.y * dt;

    // Apply bounds based on camera mode
    if (use_screen_bounds) {
        // Fixed camera (overworld) - keep player in visible area
        player.pos.x = std.math.clamp(player.pos.x, player.radius, constants.SCREEN_WIDTH - player.radius);
        player.pos.y = std.math.clamp(player.pos.y, player.radius, constants.SCREEN_HEIGHT - player.radius);
    }
    // Follow camera (dungeons) - no bounds, terrain collision handles this
}

// Update unit - chase player or return home
pub fn updateUnit(unit: *Unit, player_pos: Vec2, player_alive: bool, dt: f32) void {
    var velocity = Vec2{ .x = 0, .y = 0 };

    if (player_alive) {
        const dx_player = player_pos.x - unit.pos.x;
        const dy_player = player_pos.y - unit.pos.y;
        const dist_sq_to_player = dx_player * dx_player + dy_player * dy_player;
        const aggro_range_sq = constants.UNIT_AGGRO_RANGE * constants.UNIT_AGGRO_RANGE;
        const min_dist_sq = (unit.radius + constants.PLAYER_RADIUS) * (unit.radius + constants.PLAYER_RADIUS);

        if (dist_sq_to_player < aggro_range_sq and dist_sq_to_player > min_dist_sq) {
            // Chase player (aggro state)
            const distance_to_player = @sqrt(dist_sq_to_player);
            velocity.x = (dx_player / distance_to_player) * constants.UNIT_SPEED;
            velocity.y = (dy_player / distance_to_player) * constants.UNIT_SPEED;
            // Set aggro color - bright red
            unit.color = constants.COLOR_UNIT_AGGRO;
        } else {
            // Return home (non-aggro state)
            velocity = calculateReturnHomeVelocity(unit);
            // Set non-aggro color - dimmed reddish (similar to lifestone dimmed color)
            unit.color = constants.COLOR_UNIT_NON_AGGRO;
        }
    } else {
        // Player dead - return home (non-aggro state)
        velocity = calculateReturnHomeVelocity(unit);
        // Set non-aggro color - dimmed reddish (similar to lifestone dimmed color)
        unit.color = constants.COLOR_UNIT_NON_AGGRO;
    }

    // Apply velocity
    unit.vel = velocity;
    unit.pos.x += velocity.x * dt;
    unit.pos.y += velocity.y * dt;
}

// Calculate velocity for unit returning home
fn calculateReturnHomeVelocity(unit: *const Unit) Vec2 {
    const dx = unit.home_pos.x - unit.pos.x;
    const dy = unit.home_pos.y - unit.pos.y;
    const dist_sq = dx * dx + dy * dy;

    // Use squared distance to avoid sqrt when possible
    const tolerance_sq = constants.UNIT_HOME_TOLERANCE * constants.UNIT_HOME_TOLERANCE;
    if (dist_sq <= tolerance_sq) {
        return Vec2{ .x = 0, .y = 0 };
    }

    const distance = @sqrt(dist_sq);
    return Vec2{
        .x = (dx / distance) * constants.UNIT_WALK_SPEED,
        .y = (dy / distance) * constants.UNIT_WALK_SPEED,
    };
}

// Update bullet position
pub fn updateBullet(bullet: *Bullet, dt: f32) void {
    if (!bullet.active) return;

    bullet.pos.x += bullet.vel.x * dt;
    bullet.pos.y += bullet.vel.y * dt;

    // Deactivate if off screen
    if (bullet.pos.x < 0 or bullet.pos.x > constants.SCREEN_WIDTH or
        bullet.pos.y < 0 or bullet.pos.y > constants.SCREEN_HEIGHT)
    {
        bullet.active = false;
    }
}

// Fire a bullet from source position toward target
pub fn fireBullet(bullet: *Bullet, source_pos: Vec2, target_pos: Vec2) void {
    const direction = Vec2{
        .x = target_pos.x - source_pos.x,
        .y = target_pos.y - source_pos.y,
    };

    const length = @sqrt(direction.x * direction.x + direction.y * direction.y);
    if (length > 0) {
        bullet.pos = source_pos;
        bullet.vel.x = (direction.x / length) * constants.BULLET_SPEED;
        bullet.vel.y = (direction.y / length) * constants.BULLET_SPEED;
        bullet.active = true;
    }
}

// Kill player
pub fn killPlayer(player: *Player) void {
    player.alive = false;
    player.color = constants.COLOR_DEAD;
}

// Respawn player at position
pub fn respawnPlayer(player: *Player, pos: Vec2) void {
    player.pos = pos;
    player.alive = true;
    player.color = constants.COLOR_PLAYER_ALIVE;
}

// Kill unit
pub fn killUnit(unit: *Unit) void {
    unit.alive = false;
    unit.color = constants.COLOR_DEAD;
}

// Attune lifestone
pub fn attuneLifestone(lifestone: *entities.Lifestone) void {
    if (!lifestone.attuned) {
        lifestone.attuned = true;
        lifestone.color = constants.COLOR_LIFESTONE_ATTUNED;
    }
}

```

</File>


<File path="src/physics.zig">

```zig
const std = @import("std");

const entities = @import("entities.zig");
const types = @import("types.zig");

const Vec2 = types.Vec2;

// Check circle-circle collision
pub fn checkCircleCollision(pos1: Vec2, radius1: f32, pos2: Vec2, radius2: f32) bool {
    const dx = pos1.x - pos2.x;
    const dy = pos1.y - pos2.y;
    const distance_sq = dx * dx + dy * dy;
    const radius_sum = radius1 + radius2;
    return distance_sq < radius_sum * radius_sum;
}

// Check circle-rectangle collision
pub fn checkCircleRectCollision(circle_pos: Vec2, circle_radius: f32, rect_pos: Vec2, rect_size: Vec2) bool {
    const closest_x = std.math.clamp(circle_pos.x, rect_pos.x, rect_pos.x + rect_size.x);
    const closest_y = std.math.clamp(circle_pos.y, rect_pos.y, rect_pos.y + rect_size.y);

    const dx = circle_pos.x - closest_x;
    const dy = circle_pos.y - closest_y;

    return dx * dx + dy * dy < circle_radius * circle_radius;
}

// Check player-unit collision
pub fn checkPlayerUnitCollision(player: *const entities.Player, unit: *const entities.Unit) bool {
    if (!player.alive or !unit.active or !unit.alive) return false;
    return checkCircleCollision(player.pos, player.radius, unit.pos, unit.radius);
}

// Check bullet-unit collision
pub fn checkBulletUnitCollision(bullet: *const entities.Bullet, unit: *const entities.Unit) bool {
    if (!bullet.active or !unit.active or !unit.alive) return false;
    return checkCircleCollision(bullet.pos, bullet.radius, unit.pos, unit.radius);
}

// Check player-obstacle collision
pub fn checkPlayerObstacleCollision(player: *const entities.Player, obstacle: *const entities.Obstacle) bool {
    if (!player.alive or !obstacle.active) return false;
    return checkCircleRectCollision(player.pos, player.radius, obstacle.pos, obstacle.size);
}

// Check unit-obstacle collision
pub fn checkUnitObstacleCollision(unit: *const entities.Unit, obstacle: *const entities.Obstacle) bool {
    if (!unit.active or !obstacle.active) return false;
    return checkCircleRectCollision(unit.pos, unit.radius, obstacle.pos, obstacle.size);
}

// Check player-portal collision
pub fn checkPlayerPortalCollision(player: *const entities.Player, portal: *const entities.Portal) bool {
    if (!player.alive or !portal.active) return false;
    return checkCircleCollision(player.pos, player.radius, portal.pos, portal.radius);
}

// Check player-lifestone collision
pub fn checkPlayerLifestoneCollision(player: *const entities.Player, lifestone: *const entities.Lifestone) bool {
    if (!player.alive or !lifestone.active) return false;
    return checkCircleCollision(player.pos, player.radius, lifestone.pos, lifestone.radius);
}

// Process all collisions for a zone
pub fn processCollisions(world: *entities.World) void {
    const zone = world.getCurrentZone();
    const player = &world.player;

    // Skip player collisions if dead
    if (!player.alive) return;

    // Player-Unit collisions
    for (0..zone.unit_count) |i| {
        if (checkPlayerUnitCollision(player, &zone.units[i])) {
            // Player dies on unit contact
            return; // Caller should handle player death
        }
    }

    // Player-Obstacle collisions (handled in movement to prevent penetration)
    // These are checked before movement is applied

    // Player-Portal collisions
    for (0..zone.portal_count) |i| {
        if (checkPlayerPortalCollision(player, &zone.portals[i])) {
            // Portal collision detected - caller handles zone travel
            return;
        }
    }

    // Player-Lifestone collisions
    for (0..zone.lifestone_count) |i| {
        if (checkPlayerLifestoneCollision(player, &zone.lifestones[i])) {
            if (!zone.lifestones[i].attuned) {
                // Lifestone collision detected - caller handles attunement
                return;
            }
        }
    }
}

// Process bullet collisions
pub fn processBulletCollisions(world: *entities.World) void {
    const zone = world.getCurrentZoneMut();

    for (0..entities.MAX_BULLETS) |i| {
        if (!world.bullets[i].active) continue;

        const bullet = &world.bullets[i];

        // Check collision with obstacles first (bullets destroyed on contact)
        for (0..zone.obstacle_count) |j| {
            const obstacle = &zone.obstacles[j];
            if (!obstacle.active) continue;

            if (checkCircleRectCollision(bullet.pos, bullet.radius, obstacle.pos, obstacle.size)) {
                bullet.active = false;
                break; // Bullet destroyed, no need to check other collisions
            }
        }

        // If bullet still active, check collision with units
        if (!bullet.active) continue;

        for (0..zone.unit_count) |j| {
            const unit = &zone.units[j];
            // Skip dead/inactive units before expensive collision check
            if (!unit.active or !unit.alive) continue;

            if (checkCircleCollision(bullet.pos, bullet.radius, unit.pos, unit.radius)) {
                bullet.active = false;
                unit.alive = false;
                unit.color = .{ .r = 100, .g = 100, .b = 100, .a = 255 }; // GRAY
                break; // Bullet can only hit one unit
            }
        }
    }
}

// Check if position would collide with any blocking obstacle
pub fn wouldCollideWithObstacle(pos: Vec2, radius: f32, zone: *const entities.Zone) bool {
    for (0..zone.obstacle_count) |i| {
        const obstacle = &zone.obstacles[i];
        if (!obstacle.active or obstacle.is_deadly) continue; // Only check blocking obstacles

        if (checkCircleRectCollision(pos, radius, obstacle.pos, obstacle.size)) {
            return true;
        }
    }
    return false;
}

// Check if position collides with deadly obstacle
pub fn collidesWithDeadlyObstacle(pos: Vec2, radius: f32, zone: *const entities.Zone) bool {
    for (0..zone.obstacle_count) |i| {
        const obstacle = &zone.obstacles[i];
        if (!obstacle.active or !obstacle.is_deadly) continue; // Only check deadly obstacles

        if (checkCircleRectCollision(pos, radius, obstacle.pos, obstacle.size)) {
            return true;
        }
    }
    return false;
}

// Find nearest attuned lifestone across all zones
pub const LifestoneResult = struct {
    zone_index: usize,
    pos: Vec2,
};

pub fn findNearestAttunedLifestone(world: *const entities.World, current_pos: Vec2) ?LifestoneResult {
    // First check current zone
    const current_zone = world.getCurrentZone();
    var nearest_distance: f32 = std.math.floatMax(f32);
    var nearest_lifestone: ?LifestoneResult = null;

    for (0..current_zone.lifestone_count) |i| {
        const lifestone = &current_zone.lifestones[i];
        if (!lifestone.active or !lifestone.attuned) continue;

        const dx = current_pos.x - lifestone.pos.x;
        const dy = current_pos.y - lifestone.pos.y;
        const distance = dx * dx + dy * dy;

        if (distance < nearest_distance) {
            nearest_distance = distance;
            nearest_lifestone = LifestoneResult{
                .zone_index = world.current_zone,
                .pos = lifestone.pos,
            };
        }
    }

    // If found in current zone, return it
    if (nearest_lifestone != null) {
        return nearest_lifestone;
    }

    // Otherwise, search other zones with distance penalty
    for (0..world.zones.len) |zone_idx| {
        if (zone_idx == world.current_zone) continue;

        const zone = &world.zones[zone_idx];
        for (0..zone.lifestone_count) |i| {
            const lifestone = &zone.lifestones[i];
            if (!lifestone.active or !lifestone.attuned) continue;

            // Add penalty for being in different zone
            const dx = current_pos.x - lifestone.pos.x;
            const dy = current_pos.y - lifestone.pos.y;
            const distance = (dx * dx + dy * dy) + 1000000.0; // Large penalty

            if (distance < nearest_distance) {
                nearest_distance = distance;
                nearest_lifestone = LifestoneResult{
                    .zone_index = zone_idx,
                    .pos = lifestone.pos,
                };
            }
        }
    }

    return nearest_lifestone;
}

```

</File>


<File path="src/simple_gpu_renderer.zig">

```zig
const std = @import("std");

const c = @import("c.zig");

const types = @import("types.zig");

const Vec2 = types.Vec2;
const Color = types.Color;

// Circle uniform buffer - color components split to avoid HLSL array packing issues
const CircleUniforms = extern struct {
    screen_size: [2]f32, // 8 bytes
    circle_center: [2]f32, // 8 bytes
    circle_radius: f32, // 4 bytes
    circle_color_r: f32, // 4 bytes
    circle_color_g: f32, // 4 bytes
    circle_color_b: f32, // 4 bytes
    circle_color_a: f32, // 4 bytes
    _padding: f32, // 4 bytes (16-byte alignment)
    // Total: 40 bytes
};

// Rectangle uniform buffer - color components split to avoid HLSL array packing issues
const RectUniforms = extern struct {
    screen_size: [2]f32, // 8 bytes
    rect_position: [2]f32, // 8 bytes
    rect_size: [2]f32, // 8 bytes
    rect_color_r: f32, // 4 bytes
    rect_color_g: f32, // 4 bytes
    rect_color_b: f32, // 4 bytes
    rect_color_a: f32, // 4 bytes
    // Total: 40 bytes
};

// Effect uniform buffer for GPU-based visual effects
const EffectUniforms = extern struct {
    screen_size: [2]f32, // 8 bytes
    center: [2]f32, // 8 bytes
    radius: f32, // 4 bytes
    color_r: f32, // 4 bytes
    color_g: f32, // 4 bytes
    color_b: f32, // 4 bytes
    color_a: f32, // 4 bytes
    intensity: f32, // 4 bytes
    time: f32, // 4 bytes (for animations)
    _padding: [3]f32, // 12 bytes (16-byte alignment)
    // Total: 64 bytes
};

pub const SimpleGPURenderer = struct {
    allocator: std.mem.Allocator,
    device: *c.sdl.SDL_GPUDevice,
    window: *c.sdl.SDL_Window,

    // Circle rendering
    circle_vs: *c.sdl.SDL_GPUShader,
    circle_ps: *c.sdl.SDL_GPUShader,
    circle_pipeline: *c.sdl.SDL_GPUGraphicsPipeline,

    // Rectangle rendering
    rect_vs: *c.sdl.SDL_GPUShader,
    rect_ps: *c.sdl.SDL_GPUShader,
    rect_pipeline: *c.sdl.SDL_GPUGraphicsPipeline,

    // Effect rendering
    effect_vs: *c.sdl.SDL_GPUShader,
    effect_ps: *c.sdl.SDL_GPUShader,
    effect_pipeline: *c.sdl.SDL_GPUGraphicsPipeline,

    // Current frame data
    screen_width: f32,
    screen_height: f32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, window: *c.sdl.SDL_Window) !Self {
        std.debug.print("Creating simple GPU device...\n", .{});

        const device = c.sdl.SDL_CreateGPUDevice(c.sdl.SDL_GPU_SHADERFORMAT_SPIRV | c.sdl.SDL_GPU_SHADERFORMAT_DXIL, false, // debug mode off
            null // auto-select backend
        ) orelse {
            std.debug.print("Failed to create GPU device\n", .{});
            return error.GPUDeviceCreationFailed;
        };

        if (!c.sdl.SDL_ClaimWindowForGPUDevice(device, window)) {
            std.debug.print("Failed to claim window for GPU device\n", .{});
            c.sdl.SDL_DestroyGPUDevice(device);
            return error.WindowClaimFailed;
        }

        std.debug.print("GPU device created successfully\n", .{});

        var self = Self{
            .allocator = allocator,
            .device = device,
            .window = window,
            .circle_vs = undefined,
            .circle_ps = undefined,
            .circle_pipeline = undefined,
            .rect_vs = undefined,
            .rect_ps = undefined,
            .rect_pipeline = undefined,
            .effect_vs = undefined,
            .effect_ps = undefined,
            .effect_pipeline = undefined,
            .screen_width = 1920.0,
            .screen_height = 1080.0,
        };

        try self.createShaders();
        try self.createPipelines();

        // Show window now that GPU is set up
        _ = c.sdl.SDL_ShowWindow(window);

        return self;
    }

    pub fn deinit(self: *Self) void {
        c.sdl.SDL_ReleaseGPUGraphicsPipeline(self.device, self.circle_pipeline);
        c.sdl.SDL_ReleaseGPUGraphicsPipeline(self.device, self.rect_pipeline);
        c.sdl.SDL_ReleaseGPUGraphicsPipeline(self.device, self.effect_pipeline);
        c.sdl.SDL_ReleaseGPUShader(self.device, self.circle_vs);
        c.sdl.SDL_ReleaseGPUShader(self.device, self.circle_ps);
        c.sdl.SDL_ReleaseGPUShader(self.device, self.rect_vs);
        c.sdl.SDL_ReleaseGPUShader(self.device, self.rect_ps);
        c.sdl.SDL_ReleaseGPUShader(self.device, self.effect_vs);
        c.sdl.SDL_ReleaseGPUShader(self.device, self.effect_ps);
        c.sdl.SDL_DestroyGPUDevice(self.device);
    }

    fn createShaders(self: *Self) !void {
        std.debug.print("Loading simple GPU shaders...\n", .{});

        // Load simple circle shaders
        const circle_vs_spv = @embedFile("shaders/compiled/vulkan/simple_circle_vs.spv");
        const circle_ps_spv = @embedFile("shaders/compiled/vulkan/simple_circle_ps.spv");

        const circle_vs_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = circle_vs_spv.len,
            .code = @ptrCast(circle_vs_spv.ptr),
            .entrypoint = "vs_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_VERTEX,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 1, // Circle shader uses uniforms
        };

        self.circle_vs = c.sdl.SDL_CreateGPUShader(self.device, &circle_vs_info) orelse {
            std.debug.print("Failed to create circle vertex shader: {s}\n", .{c.sdl.SDL_GetError()});
            return error.VertexShaderFailed;
        };

        const circle_ps_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = circle_ps_spv.len,
            .code = @ptrCast(circle_ps_spv.ptr),
            .entrypoint = "ps_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 0, // Fragment shader doesn't use uniforms directly
        };

        self.circle_ps = c.sdl.SDL_CreateGPUShader(self.device, &circle_ps_info) orelse {
            std.debug.print("Failed to create circle fragment shader\n", .{});
            return error.FragmentShaderFailed;
        };

        // Load rectangle shaders
        const rect_vs_spv = @embedFile("shaders/compiled/vulkan/simple_rectangle_vs.spv");
        const rect_ps_spv = @embedFile("shaders/compiled/vulkan/simple_rectangle_ps.spv");

        const rect_vs_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = rect_vs_spv.len,
            .code = @ptrCast(rect_vs_spv.ptr),
            .entrypoint = "vs_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_VERTEX,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 1, // Rectangle shader uses uniforms
        };

        self.rect_vs = c.sdl.SDL_CreateGPUShader(self.device, &rect_vs_info) orelse {
            std.debug.print("Failed to create rectangle vertex shader\n", .{});
            return error.VertexShaderFailed;
        };

        const rect_ps_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = rect_ps_spv.len,
            .code = @ptrCast(rect_ps_spv.ptr),
            .entrypoint = "ps_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 0, // Fragment shader doesn't need uniforms
        };

        self.rect_ps = c.sdl.SDL_CreateGPUShader(self.device, &rect_ps_info) orelse {
            std.debug.print("Failed to create rectangle fragment shader\n", .{});
            return error.FragmentShaderFailed;
        };

        // Load effect shaders
        const effect_vs_spv = @embedFile("shaders/compiled/vulkan/effect_vs.spv");
        const effect_ps_spv = @embedFile("shaders/compiled/vulkan/effect_ps.spv");

        const effect_vs_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = effect_vs_spv.len,
            .code = @ptrCast(effect_vs_spv.ptr),
            .entrypoint = "vs_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_VERTEX,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 1, // Effect shader uses uniforms
        };

        self.effect_vs = c.sdl.SDL_CreateGPUShader(self.device, &effect_vs_info) orelse {
            std.debug.print("Failed to create effect vertex shader\n", .{});
            return error.VertexShaderFailed;
        };

        const effect_ps_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = effect_ps_spv.len,
            .code = @ptrCast(effect_ps_spv.ptr),
            .entrypoint = "ps_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 0, // Fragment shader doesn't need uniforms
        };

        self.effect_ps = c.sdl.SDL_CreateGPUShader(self.device, &effect_ps_info) orelse {
            std.debug.print("Failed to create effect fragment shader\n", .{});
            return error.FragmentShaderFailed;
        };

        std.debug.print("Simple GPU shaders loaded successfully\n", .{});
    }

    fn createPipelines(self: *Self) !void {
        std.debug.print("Creating simple graphics pipelines...\n", .{});

        // Get the actual swapchain texture format (usually B8G8R8A8 on most systems)
        const swapchain_format = c.sdl.SDL_GetGPUSwapchainTextureFormat(self.device, self.window);

        // No vertex input - completely procedural like test cases
        const vertex_input_state = c.sdl.SDL_GPUVertexInputState{
            .vertex_buffer_descriptions = null,
            .num_vertex_buffers = 0,
            .vertex_attributes = null,
            .num_vertex_attributes = 0,
        };

        const rasterizer_state = c.sdl.SDL_GPURasterizerState{
            .fill_mode = c.sdl.SDL_GPU_FILLMODE_FILL,
            .cull_mode = c.sdl.SDL_GPU_CULLMODE_NONE,
            .front_face = c.sdl.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,
            .depth_bias_constant_factor = 0.0,
            .depth_bias_clamp = 0.0,
            .depth_bias_slope_factor = 0.0,
            .enable_depth_bias = false,
        };

        const multisample_state = c.sdl.SDL_GPUMultisampleState{
            .sample_count = c.sdl.SDL_GPU_SAMPLECOUNT_1,
            .sample_mask = 0xFFFFFFFF,
            .enable_mask = false,
        };

        // Alpha blending for smooth circles - use actual swapchain format
        const alpha_blend_state = c.sdl.SDL_GPUColorTargetDescription{
            .format = swapchain_format,
            .blend_state = .{
                .src_color_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_SRC_ALPHA,
                .dst_color_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
                .color_blend_op = c.sdl.SDL_GPU_BLENDOP_ADD,
                .src_alpha_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ONE,
                .dst_alpha_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ZERO,
                .alpha_blend_op = c.sdl.SDL_GPU_BLENDOP_ADD,
                .color_write_mask = c.sdl.SDL_GPU_COLORCOMPONENT_R | c.sdl.SDL_GPU_COLORCOMPONENT_G | c.sdl.SDL_GPU_COLORCOMPONENT_B | c.sdl.SDL_GPU_COLORCOMPONENT_A,
                .enable_blend = true,
                .enable_color_write_mask = false,
            },
        };

        // No blending for solid rectangles - use actual swapchain format
        const solid_blend_state = c.sdl.SDL_GPUColorTargetDescription{
            .format = swapchain_format,
            .blend_state = .{
                .src_color_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ONE,
                .dst_color_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ZERO,
                .color_blend_op = c.sdl.SDL_GPU_BLENDOP_ADD,
                .src_alpha_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ONE,
                .dst_alpha_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ZERO,
                .alpha_blend_op = c.sdl.SDL_GPU_BLENDOP_ADD,
                .color_write_mask = c.sdl.SDL_GPU_COLORCOMPONENT_R | c.sdl.SDL_GPU_COLORCOMPONENT_G | c.sdl.SDL_GPU_COLORCOMPONENT_B | c.sdl.SDL_GPU_COLORCOMPONENT_A,
                .enable_blend = false,
                .enable_color_write_mask = false,
            },
        };

        const circle_target_info = c.sdl.SDL_GPUGraphicsPipelineTargetInfo{
            .color_target_descriptions = &alpha_blend_state,
            .num_color_targets = 1,
            .depth_stencil_format = c.sdl.SDL_GPU_TEXTUREFORMAT_INVALID,
            .has_depth_stencil_target = false,
        };

        const rect_target_info = c.sdl.SDL_GPUGraphicsPipelineTargetInfo{
            .color_target_descriptions = &solid_blend_state,
            .num_color_targets = 1,
            .depth_stencil_format = c.sdl.SDL_GPU_TEXTUREFORMAT_INVALID,
            .has_depth_stencil_target = false,
        };

        // Create circle pipeline
        const circle_create_info = c.sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = self.circle_vs,
            .fragment_shader = self.circle_ps,
            .vertex_input_state = vertex_input_state,
            .primitive_type = c.sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizer_state,
            .multisample_state = multisample_state,
            .target_info = circle_target_info,
        };

        self.circle_pipeline = c.sdl.SDL_CreateGPUGraphicsPipeline(self.device, &circle_create_info) orelse {
            std.debug.print("Failed to create circle graphics pipeline\n", .{});
            std.debug.print("SDL Error: {s}\n", .{c.sdl.SDL_GetError()});
            return error.PipelineCreationFailed;
        };

        // Create rectangle pipeline
        const rect_create_info = c.sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = self.rect_vs,
            .fragment_shader = self.rect_ps,
            .vertex_input_state = vertex_input_state,
            .primitive_type = c.sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizer_state,
            .multisample_state = multisample_state,
            .target_info = rect_target_info,
        };

        self.rect_pipeline = c.sdl.SDL_CreateGPUGraphicsPipeline(self.device, &rect_create_info) orelse {
            std.debug.print("Failed to create rectangle graphics pipeline\n", .{});
            std.debug.print("SDL Error: {s}\n", .{c.sdl.SDL_GetError()});
            return error.PipelineCreationFailed;
        };

        // Create effect pipeline (needs alpha blending for visual effects)
        const effect_target_info = c.sdl.SDL_GPUGraphicsPipelineTargetInfo{
            .color_target_descriptions = &alpha_blend_state,
            .num_color_targets = 1,
            .depth_stencil_format = c.sdl.SDL_GPU_TEXTUREFORMAT_INVALID,
            .has_depth_stencil_target = false,
        };

        const effect_create_info = c.sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = self.effect_vs,
            .fragment_shader = self.effect_ps,
            .vertex_input_state = vertex_input_state,
            .primitive_type = c.sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizer_state,
            .multisample_state = multisample_state,
            .target_info = effect_target_info,
        };

        self.effect_pipeline = c.sdl.SDL_CreateGPUGraphicsPipeline(self.device, &effect_create_info) orelse {
            std.debug.print("Failed to create effect graphics pipeline\n", .{});
            std.debug.print("SDL Error: {s}\n", .{c.sdl.SDL_GetError()});
            return error.PipelineCreationFailed;
        };

        std.debug.print("Simple graphics pipelines created successfully!\n", .{});
    }

    // Begin frame and get command buffer ready for rendering
    pub fn beginFrame(self: *Self, window: *c.sdl.SDL_Window) !*c.sdl.SDL_GPUCommandBuffer {
        // Update screen size
        var window_w: c_int = undefined;
        var window_h: c_int = undefined;
        _ = c.sdl.SDL_GetWindowSize(window, &window_w, &window_h);
        self.screen_width = @floatFromInt(window_w);
        self.screen_height = @floatFromInt(window_h);

        // Acquire command buffer
        const cmd_buffer = c.sdl.SDL_AcquireGPUCommandBuffer(self.device) orelse {
            return error.CommandBufferFailed;
        };

        return cmd_buffer;
    }

    // Start a render pass with the given background color
    pub fn beginRenderPass(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, window: *c.sdl.SDL_Window, bg_color: Color) !*c.sdl.SDL_GPURenderPass {
        _ = self;
        // Acquire swapchain texture
        var swapchain_texture: ?*c.sdl.SDL_GPUTexture = null;
        if (!c.sdl.SDL_WaitAndAcquireGPUSwapchainTexture(cmd_buffer, window, &swapchain_texture, null, null)) {
            return error.SwapchainFailed;
        }

        if (swapchain_texture) |texture| {
            const color_target_info = c.sdl.SDL_GPUColorTargetInfo{
                .texture = texture,
                .clear_color = .{ .r = @as(f32, @floatFromInt(bg_color.r)) / 255.0, .g = @as(f32, @floatFromInt(bg_color.g)) / 255.0, .b = @as(f32, @floatFromInt(bg_color.b)) / 255.0, .a = 1.0 },
                .load_op = c.sdl.SDL_GPU_LOADOP_CLEAR,
                .store_op = c.sdl.SDL_GPU_STOREOP_STORE,
                .cycle = false,
            };

            const render_pass = c.sdl.SDL_BeginGPURenderPass(cmd_buffer, &color_target_info, 1, null) orelse {
                return error.RenderPassFailed;
            };

            return render_pass;
        }

        return error.SwapchainFailed;
    }

    // Draw a single circle with distance field anti-aliasing
    pub fn drawCircle(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color) void {
        // Prepare uniform data
        const uniform_data = CircleUniforms{
            .screen_size = [2]f32{ self.screen_width, self.screen_height },
            .circle_center = [2]f32{ pos.x, pos.y },
            .circle_radius = radius,
            .circle_color_r = @as(f32, @floatFromInt(color.r)) / 255.0,
            .circle_color_g = @as(f32, @floatFromInt(color.g)) / 255.0,
            .circle_color_b = @as(f32, @floatFromInt(color.b)) / 255.0,
            .circle_color_a = @as(f32, @floatFromInt(color.a)) / 255.0,
            ._padding = 0.0,
        };

        // Push uniform data BEFORE binding pipeline
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(CircleUniforms));

        // Bind pipeline and draw
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.circle_pipeline);
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
    }

    // Draw a single rectangle
    pub fn drawRect(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, size: Vec2, color: Color) void {
        // Prepare uniform data - swap R and B for BGR swapchain format
        const uniform_data = RectUniforms{
            .screen_size = [2]f32{ self.screen_width, self.screen_height },
            .rect_position = [2]f32{ pos.x, pos.y },
            .rect_size = [2]f32{ size.x, size.y },
            .rect_color_r = @as(f32, @floatFromInt(color.r)) / 255.0,
            .rect_color_g = @as(f32, @floatFromInt(color.g)) / 255.0,
            .rect_color_b = @as(f32, @floatFromInt(color.b)) / 255.0,
            .rect_color_a = @as(f32, @floatFromInt(color.a)) / 255.0,
        };

        // Push uniform data BEFORE binding pipeline (critical for SDL3 GPU)
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(RectUniforms));

        // Bind pipeline and draw
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.rect_pipeline);
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad (2 triangles)
    }

    // Draw a visual effect with animated rings and pulsing
    pub fn drawEffect(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color, intensity: f32, time: f32) void {
        // Prepare uniform data for effect shader
        const uniform_data = EffectUniforms{
            .screen_size = [2]f32{ self.screen_width, self.screen_height },
            .center = [2]f32{ pos.x, pos.y },
            .radius = radius,
            .color_r = @as(f32, @floatFromInt(color.r)) / 255.0,
            .color_g = @as(f32, @floatFromInt(color.g)) / 255.0,
            .color_b = @as(f32, @floatFromInt(color.b)) / 255.0,
            .color_a = @as(f32, @floatFromInt(color.a)) / 255.0,
            .intensity = intensity,
            .time = time,
            ._padding = [3]f32{ 0.0, 0.0, 0.0 },
        };

        // Push uniform data BEFORE binding pipeline
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(EffectUniforms));

        // Bind effect pipeline and draw with alpha blending
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.effect_pipeline);
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for larger quad (effects need more space)
    }

    // End render pass
    pub fn endRenderPass(self: *Self, render_pass: *c.sdl.SDL_GPURenderPass) void {
        _ = self;
        c.sdl.SDL_EndGPURenderPass(render_pass);
    }

    // End frame and submit
    pub fn endFrame(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer) void {
        _ = self;
        _ = c.sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer);
    }

    // Transform world coordinates to screen coordinates (placeholder for now)
    pub fn worldToScreen(self: *Self, world_pos: Vec2) Vec2 {
        _ = self;
        return world_pos; // For now, assume world coordinates = screen coordinates
    }

    // Set render color (compatibility function - not needed for GPU but game expects it)
    pub fn setRenderColor(self: *Self, color: Color) void {
        _ = self;
        _ = color;
        // No-op for GPU rendering - color is passed per primitive
    }

    // Draw pixel (fallback for HUD text - draw as tiny rectangle)
    pub fn drawPixel(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, x: f32, y: f32, color: Color) void {
        self.drawRect(cmd_buffer, render_pass, Vec2{ .x = x, .y = y }, Vec2{ .x = 1.0, .y = 1.0 }, color);
    }
};

```

</File>


<File path="src/portals.zig">

```zig
const std = @import("std");

const types = @import("types.zig");
const entities = @import("entities.zig");
const behaviors = @import("behaviors.zig");
const maths = @import("maths.zig");
const physics = @import("physics.zig");
const player_controller = @import("player.zig");
const input = @import("input.zig");
const constants = @import("constants.zig");
const effects = @import("effects.zig");

const Vec2 = types.Vec2;
const World = entities.World;
const Portal = entities.Portal;
const Player = entities.Player;

pub fn handlePortalTravel(game_state: anytype, portal: *const Portal) void {
    const world = &game_state.world;
    const effect_system = &game_state.effect_system;
    game_state.input_state.clearMouseHold();

    const movement_direction = player_controller.getPlayerMovementDirection(&world.player);

    const origin_zone = world.current_zone;
    const destination_zone = portal.destination_zone;
    game_state.travelToZone(destination_zone);

    std.debug.print("Portal travel! Entering zone {} from zone {}\n", .{ destination_zone, origin_zone });

    const new_zone = &world.zones[destination_zone];
    for (0..new_zone.portal_count) |i| {
        const return_portal = &new_zone.portals[i];
        if (return_portal.active and return_portal.destination_zone == origin_zone) {
            const offset_distance = return_portal.radius + world.player.radius + constants.PORTAL_SPAWN_OFFSET;

            if (movement_direction.x != 0 or movement_direction.y != 0) {
                world.player.pos = Vec2{
                    .x = return_portal.pos.x + movement_direction.x * offset_distance,
                    .y = return_portal.pos.y + movement_direction.y * offset_distance,
                };
            } else {
                world.player.pos = Vec2{
                    .x = return_portal.pos.x,
                    .y = return_portal.pos.y + offset_distance,
                };
            }

            world.player.pos.x = std.math.clamp(world.player.pos.x, world.player.radius, constants.SCREEN_WIDTH - world.player.radius);
            world.player.pos.y = std.math.clamp(world.player.pos.y, world.player.radius, constants.SCREEN_HEIGHT - world.player.radius);

            // Add portal travel effect on the player
            effect_system.addPortalTravelEffect(world.player.pos, world.player.radius);

            // Add portal ripple effect on the portal itself in the new zone
            effect_system.addPortalRippleEffect(return_portal.pos, return_portal.radius);
            return;
        }
    }

    world.player.pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y };

    // Add portal travel effect for fallback spawn
    effect_system.addPortalTravelEffect(world.player.pos, world.player.radius);
}

pub fn checkPortalCollisions(game_state: anytype) bool {
    const world = &game_state.world;
    const zone = world.getCurrentZone();
    const player = &world.player;

    if (!player.alive) return false;

    for (0..zone.portal_count) |i| {
        if (physics.checkPlayerPortalCollision(player, &zone.portals[i])) {
            handlePortalTravel(game_state, &zone.portals[i]);
            return true;
        }
    }

    return false;
}

```

</File>


<File path="src/borders.zig">

```zig
const std = @import("std");
const math = std.math;

const c = @import("c.zig");

const types = @import("types.zig");
const Color = types.Color;
const constants = @import("constants.zig");

// Border animation constants
const ASPECT_RATIO = 16.0 / 9.0;
const BORDER_PULSE_PAUSED = 1.5;
const BORDER_PULSE_DEAD = 1.2;

// Screen constants for border calculations
const SCREEN_WIDTH = constants.SCREEN_WIDTH;
const SCREEN_HEIGHT = constants.SCREEN_HEIGHT;

// Iris wipe constants
pub const IRIS_WIPE_DURATION = 2.5; // Increased from 1.5 seconds
pub const IRIS_WIPE_BAND_COUNT = 6;
pub const IRIS_WIPE_BAND_WIDTH = 30.0; // Increased from 12.0 pixels

// Color constants for borders
const BLUE_BRIGHT = Color{ .r = 100, .g = 150, .b = 255, .a = 255 };
const GREEN_BRIGHT = Color{ .r = 80, .g = 220, .b = 80, .a = 255 };
const PURPLE_BRIGHT = Color{ .r = 180, .g = 100, .b = 240, .a = 255 };
const RED_BRIGHT = Color{ .r = 255, .g = 100, .b = 100, .a = 255 };
const YELLOW_BRIGHT = Color{ .r = 255, .g = 220, .b = 80, .a = 255 };
const ORANGE_BRIGHT = Color{ .r = 255, .g = 180, .b = 80, .a = 255 };
const CYAN = Color{ .r = 0, .g = 200, .b = 200, .a = 255 };

// Border color definitions for cycling
pub const BorderColorPair = struct {
    dark: struct { r: f32, g: f32, b: f32 },
    bright: struct { r: f32, g: f32, b: f32 },
};

pub const GOLD_YELLOW_COLORS = BorderColorPair{
    .dark = .{ .r = 200.0, .g = 150.0, .b = 10.0 },
    .bright = .{ .r = 255.0, .g = 240.0, .b = 0.0 },
};

pub const RED_COLORS = BorderColorPair{
    .dark = .{ .r = 180.0, .g = 40.0, .b = 40.0 },
    .bright = .{ .r = 255.0, .g = 30.0, .b = 30.0 },
};

pub const GREEN_COLORS = BorderColorPair{
    .dark = .{ .r = 20.0, .g = 160.0, .b = 20.0 },
    .bright = .{ .r = 50.0, .g = 220.0, .b = 80.0 },
};

// Border system for declarative stacked borders
const MAX_BORDER_LAYERS = 8;

pub const BorderSpec = struct {
    base_width: f32,
    base_color: Color,
    color_pair: ?BorderColorPair, // null = static color, value = animated color
    pulse_freq: ?f32, // null = no pulse, value = pulse frequency
    pulse_amplitude: f32, // how much the pulse changes the width

    pub fn getCurrentWidth(self: *const BorderSpec) f32 {
        if (self.pulse_freq) |freq| {
            const pulse = calculateAnimationPulse(freq);
            return self.base_width + pulse * self.pulse_amplitude;
        } else {
            return self.base_width;
        }
    }

    pub fn getMaxWidth(self: *const BorderSpec) f32 {
        // Maximum possible width this border could reach
        return self.base_width + self.pulse_amplitude;
    }

    pub fn getCurrentColor(self: *const BorderSpec) Color {
        if (self.color_pair) |colors| {
            const pulse = calculateAnimationPulse(self.pulse_freq orelse 4.0);
            const hue_cycle = calculateColorCycle();
            const intensity = 0.7 + pulse * 0.3;
            return interpolateColor(colors, hue_cycle, intensity);
        } else {
            return self.base_color;
        }
    }
};

pub const BorderStack = struct {
    specs: [MAX_BORDER_LAYERS]BorderSpec,
    count: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .specs = undefined,
            .count = 0,
        };
    }

    pub fn clear(self: *Self) void {
        self.count = 0;
    }

    pub fn push(self: *Self, base_width: f32, base_color: Color, color_pair: ?BorderColorPair, pulse_freq: ?f32, pulse_amplitude: f32) void {
        if (self.count < MAX_BORDER_LAYERS) {
            self.specs[self.count] = BorderSpec{
                .base_width = base_width,
                .base_color = base_color,
                .color_pair = color_pair,
                .pulse_freq = pulse_freq,
                .pulse_amplitude = pulse_amplitude,
            };
            self.count += 1;
        }
    }

    pub fn pushStatic(self: *Self, width: f32, color: Color) void {
        self.push(width, color, null, null, 0.0);
    }

    pub fn pushAnimated(self: *Self, base_width: f32, color_pair: BorderColorPair, pulse_freq: f32, pulse_amplitude: f32) void {
        // Use the dark color from the pair as base color
        const base_color = Color{
            .r = @intFromFloat(color_pair.dark.r),
            .g = @intFromFloat(color_pair.dark.g),
            .b = @intFromFloat(color_pair.dark.b),
            .a = 255,
        };
        self.push(base_width, base_color, color_pair, pulse_freq, pulse_amplitude);
    }

    pub fn render(self: *const Self, game_state: anytype) void {
        // Calculate cumulative offset based on current animated widths
        var current_offset: f32 = 0;

        for (0..self.count) |i| {
            const spec = &self.specs[i];
            const current_width = spec.getCurrentWidth();
            const current_color = spec.getCurrentColor();

            game_state.drawBorderWithOffset(current_color, current_width, current_offset);
            current_offset += current_width;
        }
    }
};

// Animation utility functions
fn calculateAnimationPulse(frequency: f32) f32 {
    const current_time_ms = @as(f32, @floatFromInt(c.sdl.SDL_GetTicks()));
    const current_time_sec = current_time_ms / 1000.0;
    return (math.sin(current_time_sec * frequency) + 1.0) * 0.5;
}

fn calculateColorCycle() f32 {
    const COLOR_CYCLE_FREQ = 4.0;
    const current_time_ms = @as(f32, @floatFromInt(c.sdl.SDL_GetTicks()));
    const current_time_sec = current_time_ms / 1000.0;
    return (math.sin(current_time_sec * COLOR_CYCLE_FREQ) + 1.0) * 0.5;
}

// Color interpolation utility for border system
fn interpolateColor(color_pair: BorderColorPair, t: f32, intensity: f32) Color {
    return Color{
        .r = @intFromFloat((color_pair.dark.r + (color_pair.bright.r - color_pair.dark.r) * t) * intensity),
        .g = @intFromFloat((color_pair.dark.g + (color_pair.bright.g - color_pair.dark.g) * t) * intensity),
        .b = @intFromFloat((color_pair.dark.b + (color_pair.bright.b - color_pair.dark.b) * t) * intensity),
        .a = 255,
    };
}

// Border rectangle calculations
pub const BorderRect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

pub fn calculateBorderRects(width: f32, offset: f32) [4]BorderRect {
    // Calculate border rectangles INSIDE the remaining space after accounting for outer borders
    const inner_x = offset;
    const inner_y = offset;
    const inner_width = SCREEN_WIDTH - (offset * 2);
    const inner_height = SCREEN_HEIGHT - (offset * 2);

    // Return 4 rectangles that form the border around the inner area
    return [4]BorderRect{
        // Top
        BorderRect{ .x = inner_x, .y = inner_y, .w = inner_width, .h = width },
        // Bottom
        BorderRect{ .x = inner_x, .y = inner_y + inner_height - width, .w = inner_width, .h = width },
        // Left
        BorderRect{ .x = inner_x, .y = inner_y + width, .w = width, .h = inner_height - (width * 2) },
        // Right
        BorderRect{ .x = inner_x + inner_width - width, .y = inner_y + width, .w = width, .h = inner_height - (width * 2) },
    };
}

pub fn drawScreenBorder(game_state: anytype) void {
    var border_stack = BorderStack.init();

    // Iris wipe effect (highest priority - renders over everything)
    if (game_state.iris_wipe_active) {
        const current_time = c.sdl.SDL_GetPerformanceCounter();
        const frequency = c.sdl.SDL_GetPerformanceFrequency();
        const elapsed_sec = @as(f32, @floatFromInt(current_time - game_state.iris_wipe_start_time)) / @as(f32, @floatFromInt(frequency));
        const wipe_duration = IRIS_WIPE_DURATION;

        if (elapsed_sec < wipe_duration) {
            const progress = elapsed_sec / wipe_duration; // 0.0 to 1.0
            // Strong ease-out curve: fast at start, very slow at end
            const eased_progress = 1.0 - (1.0 - progress) * (1.0 - progress) * (1.0 - progress) * (1.0 - progress); // Quartic ease-out
            const shrink_factor = 1.0 - eased_progress; // 1.0 to 0.0 (shrinking with strong ease-out)

            // Create iris wipe bands using existing game colors
            const wipe_colors = [_]Color{
                BLUE_BRIGHT,   GREEN_BRIGHT,  YELLOW_BRIGHT,
                ORANGE_BRIGHT, PURPLE_BRIGHT, CYAN,
            };
            comptime std.debug.assert(wipe_colors.len == IRIS_WIPE_BAND_COUNT);

            for (0..wipe_colors.len) |i| {
                const wipe_color = wipe_colors[i];
                const max_width = IRIS_WIPE_BAND_WIDTH;
                const current_width = max_width * shrink_factor;

                if (current_width > 0.5) { // Only render if visible
                    border_stack.pushStatic(current_width, wipe_color);
                }
            }
        } else {
            // End iris wipe
            game_state.iris_wipe_active = false;
        }
    }

    // Game state borders (lower priority)
    if (game_state.isPaused()) {
        // Animated paused border: base 6px + 4px pulse amplitude
        border_stack.pushAnimated(6.0, GOLD_YELLOW_COLORS, BORDER_PULSE_PAUSED, 4.0);
    }

    if (!game_state.world.player.alive) {
        // Animated dead border: base 9px + 5px pulse amplitude
        border_stack.pushAnimated(9.0, RED_COLORS, BORDER_PULSE_DEAD, 5.0);
    }

    // Render all borders with automatic offset calculation based on current animated widths
    border_stack.render(game_state);
}

```

</File>


<File path="src/hud.zig">

```zig
const std = @import("std");

const c = @import("c.zig");

const types = @import("types.zig");

const Color = types.Color;

// HUD system now uses GPU-based rendering through the renderer
// Old bitmap digit constants removed - see renderer.zig for current implementation

pub const Hud = struct {
    // FPS tracking with SDL high-resolution timers
    fps_counter: u32,
    fps_frames: u32,
    fps_last_time: u64,

    // HUD visibility toggle
    visible: bool,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .fps_counter = 60, // Start with reasonable default
            .fps_frames = 0,
            .fps_last_time = c.sdl.SDL_GetPerformanceCounter(),
            .visible = true, // Start visible
        };
    }

    pub fn toggle(self: *Self) void {
        self.visible = !self.visible;
    }

    pub fn updateFPS(self: *Self, current_time: u64, frequency: u64) void {
        self.fps_frames += 1;
        const elapsed_ticks = current_time - self.fps_last_time;

        // Update FPS counter every second
        if (elapsed_ticks >= frequency) { // 1 second has passed
            self.fps_counter = self.fps_frames;
            self.fps_frames = 0;
            self.fps_last_time = current_time;
        }
    }

    // Note: Rendering is now handled directly by the renderer.drawFPS() method
    // The old render() method with bitmap digits has been replaced by the GPU renderer's
    // more efficient digit drawing system
};

```

</File>


<File path="src/loader.zig">

```zig
const std = @import("std");

const entities = @import("entities.zig");
const types = @import("types.zig");

const Vec2 = types.Vec2;
const Color = types.Color;

// Global arena for ZON data that persists for game lifetime
var game_data_arena: ?std.heap.ArenaAllocator = null;

// Clean up game data memory
pub fn deinit() void {
    if (game_data_arena) |*arena| {
        arena.deinit();
        game_data_arena = null;
    }
}

// Load game data from ZON file
pub fn loadGameData(allocator: std.mem.Allocator, world: *entities.World) !void {
    // Load game data from ZON file
    const gameDataFile = @embedFile("game_data.zon");

    // Initialize arena if not already done
    if (game_data_arena == null) {
        game_data_arena = std.heap.ArenaAllocator.init(allocator);
    }
    const arena_allocator = game_data_arena.?.allocator();

    // Convert to null-terminated string for ZON parser
    const gameDataNullTerm = try arena_allocator.dupeZ(u8, gameDataFile);

    const game_data = std.zon.parse.fromSlice(GameData, arena_allocator, gameDataNullTerm, null, .{}) catch |err| {
        std.debug.print("Failed to parse ZON file: {}\n", .{err});
        std.debug.print("This is likely due to a mismatch between the ZON file structure and the expected GameData struct\n", .{});
        return err;
    };

    // Set player start position
    world.player.pos = Vec2{
        .x = game_data.player_start.position.x,
        .y = game_data.player_start.position.y,
    };
    world.player.radius = game_data.player_start.radius;
    // Store original spawn position for full reset
    world.player_start_pos = world.player.pos;

    // Load each zone
    for (game_data.zones, 0..) |zone_data, i| {
        // Initialize zone with basic data (scale will be set in loadZone)
        world.zones[i] = entities.Zone.init("", types.Color{ .r = 0, .g = 0, .b = 0, .a = 255 }, entities.CameraMode.follow, 1.0);
        // Then load detailed data
        loadZone(&world.zones[i], zone_data);
    }
}

// Load a single zone from ZON data
fn loadZone(zone: *entities.Zone, data: ZoneData) void {
    // Set zone properties - use static strings to avoid allocation
    if (std.mem.eql(u8, data.name, "Overworld")) {
        zone.name = "Overworld";
    } else if (std.mem.indexOf(u8, data.name, "Southeast") != null) {
        zone.name = "Southeast Dungeon";
    } else if (std.mem.indexOf(u8, data.name, "Southwest") != null) {
        zone.name = "Southwest Dungeon";
    } else if (std.mem.indexOf(u8, data.name, "West") != null) {
        zone.name = "West Dungeon";
    } else if (std.mem.indexOf(u8, data.name, "Northwest") != null) {
        zone.name = "Northwest Dungeon";
    } else if (std.mem.indexOf(u8, data.name, "Northeast") != null) {
        zone.name = "Northeast Dungeon";
    } else if (std.mem.indexOf(u8, data.name, "East") != null) {
        zone.name = "East Dungeon";
    } else {
        zone.name = "Unknown";
    }

    zone.background_color = Color{
        .r = data.background_color.r,
        .g = data.background_color.g,
        .b = data.background_color.b,
        .a = 255,
    };

    // Set camera mode for this zone
    if (std.mem.eql(u8, data.camera_mode, "fixed")) {
        zone.camera_mode = entities.CameraMode.fixed;
    } else {
        zone.camera_mode = entities.CameraMode.follow;
    }

    // Set camera scale (default to 1.0 if not specified)
    zone.camera_scale = data.camera_scale orelse 1.0;

    // Load obstacles
    if (data.obstacles) |obstacles| {
        for (obstacles) |obstacle_data| {
            const is_deadly = std.mem.eql(u8, obstacle_data.type, "deadly");
            const obstacle = entities.Obstacle.init(
                obstacle_data.position.x,
                obstacle_data.position.y,
                obstacle_data.size.x,
                obstacle_data.size.y,
                is_deadly,
            );
            zone.addObstacle(obstacle);
        }
    }

    // Load units
    if (data.units) |units| {
        for (units) |unit_data| {
            const unit = entities.Unit.init(
                unit_data.position.x,
                unit_data.position.y,
                unit_data.radius,
            );
            zone.addUnit(unit);
            // Also store in original units for reset functionality
            if (zone.original_unit_count < entities.MAX_UNITS) {
                zone.original_units[zone.original_unit_count] = unit;
                zone.original_unit_count += 1;
            }
        }
    }

    // Load portals
    if (data.portals) |portals| {
        for (portals) |portal_data| {
            const portal = entities.Portal.init(
                portal_data.position.x,
                portal_data.position.y,
                portal_data.radius,
                portal_data.destination,
            );
            zone.addPortal(portal);
        }
    }

    // Load lifestones
    if (data.lifestones) |lifestones| {
        for (lifestones) |lifestone_data| {
            // First lifestone in overworld (zone 0) is pre-attuned
            const pre_attuned = (zone.lifestone_count == 0 and std.mem.eql(u8, data.name, "Overworld"));
            const lifestone = entities.Lifestone.init(
                lifestone_data.position.x,
                lifestone_data.position.y,
                lifestone_data.radius,
                pre_attuned,
            );
            zone.addLifestone(lifestone);
        }
    }
}

// ZON data structures
const GameData = struct {
    screen_width: f32,
    screen_height: f32,
    player_start: struct {
        zone: u8,
        position: struct { x: f32, y: f32 },
        radius: f32,
    },
    zones: []const ZoneData,
};

const ZoneData = struct {
    name: []const u8,
    background_color: struct { r: u8, g: u8, b: u8 },
    camera_mode: []const u8,
    camera_scale: ?f32 = null, // Optional camera scale with default value
    obstacles: ?[]const struct {
        position: struct { x: f32, y: f32 },
        size: struct { x: f32, y: f32 },
        type: []const u8,
    },
    units: ?[]const struct {
        position: struct { x: f32, y: f32 },
        radius: f32,
    },
    portals: ?[]const struct {
        position: struct { x: f32, y: f32 },
        radius: f32,
        destination: u8,
        shape: []const u8,
    },
    lifestones: ?[]const struct {
        position: struct { x: f32, y: f32 },
        radius: f32,
    },
};

```

</File>


<File path="src/player.zig">

```zig
const std = @import("std");

const types = @import("types.zig");
const entities = @import("entities.zig");
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const input = @import("input.zig");
const maths = @import("maths.zig");
const camera = @import("camera.zig");
const constants = @import("constants.zig");

const Vec2 = types.Vec2;
const Player = entities.Player;
const Zone = entities.Zone;
const InputState = input.InputState;

pub fn updatePlayer(player: *Player, input_state: *const InputState, zone: *const Zone, cam: *const camera.Camera, deltaTime: f32) void {
    if (!player.alive) return;

    var keyboard_velocity = Vec2{ .x = 0, .y = 0 };
    var mouse_velocity = Vec2{ .x = 0, .y = 0 };

    const movement = input_state.getMovementVector();
    keyboard_velocity.x = movement.x * constants.PLAYER_SPEED;
    keyboard_velocity.y = movement.y * constants.PLAYER_SPEED;

    if (input_state.isLeftMouseHeld()) {
        const world_mouse_pos = input_state.getWorldMousePos(cam);
        const dx = world_mouse_pos.x - player.pos.x;
        const dy = world_mouse_pos.y - player.pos.y;
        const distance_sq = dx * dx + dy * dy;
        const radius_sq = player.radius * player.radius;

        if (distance_sq > radius_sq) {
            const distance = @sqrt(distance_sq);
            const dir_x = dx / distance;
            const dir_y = dy / distance;
            mouse_velocity.x = dir_x * constants.PLAYER_SPEED;
            mouse_velocity.y = dir_y * constants.PLAYER_SPEED;
        }
    }

    var velocity: Vec2 = undefined;
    if (input_state.isLeftMouseHeld() and (mouse_velocity.x != 0 or mouse_velocity.y != 0)) {
        velocity = mouse_velocity;
    } else {
        velocity = keyboard_velocity;
    }

    const old_pos = player.pos;

    // Use screen bounds only in fixed camera mode (overworld)
    const use_screen_bounds = (zone.camera_mode == entities.CameraMode.fixed);
    behaviors.updatePlayer(player, velocity, deltaTime, use_screen_bounds);

    if (physics.wouldCollideWithObstacle(player.pos, player.radius, zone)) {
        player.pos = old_pos;
    }
}

pub fn getPlayerMovementDirection(player: *const Player) Vec2 {
    return maths.normalizeVector(player.vel);
}

```

</File>


<File path="src/types.zig">

```zig
pub const Vec2 = extern struct { x: f32, y: f32 };
pub const Color = extern struct { r: u8, g: u8, b: u8, a: u8 };

```

</File>


<File path="src/shaders/source/triangle_uniforms.hlsl">

```hlsl
// Triangle shader with uniform buffer support
// SDL3 GPU API requires vertex shader uniforms at (b[n], space1)
cbuffer FrameUniforms : register(b0, space1) {
    float2 screen_size;
    float time;
    float _padding;
};

// Vertex shader input (just vertex ID)
struct VertexInput {
    uint vertex_id : SV_VertexID;
};

// Vertex to pixel shader
struct VertexOutput {
    float4 position : SV_Position;
    float4 color : COLOR0;
};

// Generate triangle vertices procedurally with time-based animation
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    
    // Base triangle positions in NDC space
    float2 positions[3] = {
        float2(0.0, 0.5),   // top
        float2(-0.5, -0.5), // bottom-left
        float2(0.5, -0.5)   // bottom-right
    };
    
    // Calculate color intensity based on screen aspect ratio and time
    float screen_ratio = screen_size.x / screen_size.y; 
    float base_intensity = screen_ratio / 2.0; 
    
    // Time-based pulsing animation
    float time_pulse = sin(time * 2.0) * 0.3 + 0.7; 
    float final_intensity = base_intensity * time_pulse;
    
    float4 colors[3] = {
        float4(final_intensity, 0.0, 0.0, 1.0),     // Red
        float4(0.0, final_intensity, 0.0, 1.0),     // Green  
        float4(0.0, 0.0, final_intensity, 1.0)      // Blue
    };
    
    uint vertex_index = input.vertex_id % 3;
    
    // Use base triangle positions
    float2 pos = positions[vertex_index];
    
    output.position = float4(pos, 0.0, 1.0);
    output.color = colors[vertex_index];
    
    return output;
}

float4 ps_main(VertexOutput input) : SV_Target {
    return input.color;
}
```

</File>


<File path="src/shaders/source/circle.hlsl">

```hlsl
// Circle rendering with distance field anti-aliasing
// Compile with: dxc -T vs_6_0 -E vs_main circle.hlsl -Fo circle_vs.dxil
// Compile with: dxc -T ps_6_0 -E ps_main circle.hlsl -Fo circle_ps.dxil

// Per-frame uniforms
cbuffer FrameUniforms : register(b0) {
    float2 screen_size;
    float4 camera_transform; // [offset_x, offset_y, zoom, rotation]
    float time;
    float _padding;
};

// Per-instance vertex data
struct InstanceInput {
    float2 center : POSITION0;
    float radius : POSITION1;
    float4 color : COLOR0;
};

// Vertex shader input (quad corners)
struct VertexInput {
    float2 position : POSITION;
    uint vertex_id : SV_VertexID;
    uint instance_id : SV_InstanceID;
};

// Vertex to pixel shader
struct VertexOutput {
    float4 position : SV_Position;
    float2 local_pos : TEXCOORD0;
    float4 color : COLOR0;
    float radius : TEXCOORD1;
};

// Quad vertices for instancing (corners of unit square)
static const float2 quad_positions[4] = {
    float2(-1.0, -1.0),
    float2( 1.0, -1.0),
    float2( 1.0,  1.0),
    float2(-1.0,  1.0)
};

VertexOutput vs_main(VertexInput input, InstanceInput instance) {
    VertexOutput output;
    
    // Get quad corner position
    float2 quad_corner = quad_positions[input.vertex_id];
    
    // Transform instance center through camera
    float2 screen_center = instance.center;
    screen_center = (screen_center - camera_transform.xy) * camera_transform.z;
    screen_center += screen_size * 0.5;
    
    // Scale quad by radius and convert to NDC
    float2 world_pos = screen_center + quad_corner * instance.radius;
    output.position = float4(
        (world_pos.x / screen_size.x) * 2.0 - 1.0,
        1.0 - (world_pos.y / screen_size.y) * 2.0,
        0.0,
        1.0
    );
    
    // Pass through data for pixel shader
    output.local_pos = quad_corner;
    output.color = instance.color;
    output.radius = instance.radius; // Pass actual radius for proper AA calculation
    
    return output;
}

float4 ps_main(VertexOutput input) : SV_Target {
    // High-precision distance from center of quad in local space
    float2 precise_pos = input.local_pos;
    float dist = length(precise_pos);
    
    // Screen-space derivative-based anti-aliasing for stable edges
    float delta = length(fwidth(precise_pos));
    float edge_softness = delta * 0.7; // Smooth transition based on screen pixel size
    
    // Expand circle slightly beyond mathematical boundary for smoother edges
    float circle_radius = 0.98; // Slightly smaller than 1.0 to allow AA expansion
    float alpha = 1.0 - smoothstep(circle_radius - edge_softness, circle_radius + edge_softness, dist);
    
    // Conservative discard threshold
    if (alpha < 0.01) discard;
    
    // Apply instance color with calculated alpha
    return float4(input.color.rgb, input.color.a * alpha);
}
```

</File>


<File path="src/shaders/source/effect.hlsl">

```hlsl
// Visual effects with animated distance fields and additive blending
// Compile with: dxc -T vs_6_0 -E vs_main effect.hlsl -Fo effect_vs.dxil  
// Compile with: dxc -T ps_6_0 -E ps_main effect.hlsl -Fo effect_ps.dxil

// Effect uniforms - simplified to match other shaders
cbuffer EffectUniforms : register(b0, space1) {
    float2 screen_size;
    float2 center;
    float radius;
    float color_r;
    float color_g;
    float color_b;
    float color_a;
    float intensity;
    float time;
    float3 _padding;
};

// Vertex shader input
struct VertexInput {
    uint vertex_id : SV_VertexID;
};

// Vertex to pixel shader
struct VertexOutput {
    float4 position : SV_Position;
    float2 local_pos : TEXCOORD0;
    float4 color : COLOR0;
    float radius : TEXCOORD1;
    float intensity : TEXCOORD2;
    float2 world_center : TEXCOORD3;
};

// Quad vertices generated procedurally (no static array needed)

VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    
    // Generate quad corner from vertex ID (same as simple_circle shader)
    float2 quad_corner;
    uint tri = input.vertex_id / 3;  // Triangle index (0 or 1)
    uint vert = input.vertex_id % 3; // Vertex in triangle (0, 1, 2)
    
    // First triangle: (0,0), (1,0), (0,1)
    // Second triangle: (0,1), (1,0), (1,1)
    if (tri == 0) {
        if (vert == 0) quad_corner = float2(-1.0, -1.0);      // bottom-left
        else if (vert == 1) quad_corner = float2(1.0, -1.0);  // bottom-right
        else quad_corner = float2(-1.0, 1.0);                 // top-left
    } else {
        if (vert == 0) quad_corner = float2(-1.0, 1.0);       // top-left
        else if (vert == 1) quad_corner = float2(1.0, -1.0);  // bottom-right
        else quad_corner = float2(1.0, 1.0);                  // top-right
    }
    
    // Convert effect position from screen coordinates to NDC (same as simple_circle)
    float aspect_ratio = screen_size.x / screen_size.y;
    
    // Convert center from screen coordinates to NDC
    float2 ndc_center = float2(
        (center.x / screen_size.x) * 2.0 - 1.0,  // X: 0->width becomes -1->+1
        -((center.y / screen_size.y) * 2.0 - 1.0) // Y: 0->height becomes +1->-1 (flip Y)
    );
    
    // Convert radius from screen pixels to NDC space with precise aspect correction
    float ndc_radius = (radius / screen_size.y) * 2.0; // Use Y for consistent scaling
    float2 aspect_correction = float2(1.0 / aspect_ratio, 1.0); // Precise aspect ratio correction
    
    // Generate final position: center + scaled quad corner
    float2 ndc_pos = ndc_center + quad_corner * ndc_radius * aspect_correction;
    
    output.position = float4(ndc_pos, 0.0, 1.0);
    output.local_pos = quad_corner; // Keep original local pos for distance field
    output.color = float4(color_r, color_g, color_b, color_a);
    output.radius = radius;
    output.intensity = intensity;
    output.world_center = center;
    
    return output;
}

float4 ps_main(VertexOutput input) : SV_Target {
    // High-precision distance from center in local space
    float2 precise_pos = input.local_pos;
    float dist = length(precise_pos);
    
    // Screen-space derivative-based anti-aliasing for stable effect edges
    float delta = length(fwidth(precise_pos));
    float edge_softness = delta * 0.8; // Slightly softer for effects
    
    // Expand effect slightly beyond mathematical boundary for smoother edges
    float circle_radius = 0.97; // Even softer expansion for effects
    float alpha = 1.0 - smoothstep(circle_radius - edge_softness, circle_radius + edge_softness, dist);
    
    // Conservative discard threshold
    if (alpha < 0.01) discard;
    
    // Apply effect intensity and shader boosts with proper alpha clamping
    float final_intensity = input.intensity * 2.0; // 2x intensity boost
    float3 bright_color = input.color.rgb * 2.0; // 2x color boost
    float final_alpha = min(1.0, alpha * input.color.a * final_intensity); // Clamp alpha to 1.0
    
    return float4(bright_color, final_alpha);
}
```

</File>


<File path="src/shaders/source/triangle.hlsl">

```hlsl
// Minimal triangle test shader - procedural triangle generation
// This is based on SDL3's BasicTriangle example but simplified further

// Vertex shader input (just vertex ID)
struct VertexInput {
    uint vertex_id : SV_VertexID;
};

// Vertex to pixel shader
struct VertexOutput {
    float4 position : SV_Position;
    float4 color : COLOR0;
};

// Generate triangle vertices procedurally
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    
    // Hardcoded triangle positions in NDC space
    float2 positions[3] = {
        float2(0.0, 0.5),   // top
        float2(-0.5, -0.5), // bottom-left
        float2(0.5, -0.5)   // bottom-right
    };
    
    // Simple colors for each vertex
    float4 colors[3] = {
        float4(1.0, 0.0, 0.0, 1.0), // red
        float4(0.0, 1.0, 0.0, 1.0), // green
        float4(0.0, 0.0, 1.0, 1.0)  // blue
    };
    
    uint vertex_index = input.vertex_id % 3;
    
    output.position = float4(positions[vertex_index], 0.0, 1.0);
    output.color = colors[vertex_index];
    
    return output;
}

float4 ps_main(VertexOutput input) : SV_Target {
    return input.color;
}
```

</File>


<File path="src/shaders/source/simple_circle.hlsl">

```hlsl
// Circle rendering with distance field anti-aliasing
cbuffer CircleUniforms : register(b0, space1) {
    float2 screen_size;      // Screen dimensions for NDC conversion
    float2 circle_center;    // Circle position in screen coordinates
    float circle_radius;     // Circle radius in pixels
    float circle_color_r;    // Color components split to avoid
    float circle_color_g;    // HLSL array packing issues that
    float circle_color_b;    // caused color channel corruption
    float circle_color_a;    // Alpha channel
    float _padding;          // 16-byte alignment padding
};

// Vertex shader input (just vertex ID)
struct VertexInput {
    uint vertex_id : SV_VertexID;
};

// Vertex to pixel shader
struct VertexOutput {
    float4 position : SV_Position;
    float2 local_pos : TEXCOORD0;
    float4 color : COLOR0;
};

// Generate quad vertices procedurally
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    
    // Generate quad corner from vertex ID (6 vertices for 2 triangles)
    float2 quad_corner;
    uint tri = input.vertex_id / 3;  // Triangle index (0 or 1)
    uint vert = input.vertex_id % 3; // Vertex in triangle (0, 1, 2)
    
    // First triangle: (0,0), (1,0), (0,1)
    // Second triangle: (0,1), (1,0), (1,1)
    if (tri == 0) {
        if (vert == 0) quad_corner = float2(-1.0, -1.0);      // bottom-left
        else if (vert == 1) quad_corner = float2(1.0, -1.0);  // bottom-right
        else quad_corner = float2(-1.0, 1.0);                 // top-left
    } else {
        if (vert == 0) quad_corner = float2(-1.0, 1.0);       // top-left
        else if (vert == 1) quad_corner = float2(1.0, -1.0);  // bottom-right
        else quad_corner = float2(1.0, 1.0);                  // top-right
    }
    
    // Convert circle position from screen coordinates to NDC with aspect ratio correction
    float aspect_ratio = screen_size.x / screen_size.y;
    
    // Convert circle center from screen coordinates to NDC
    float2 ndc_center = float2(
        (circle_center.x / screen_size.x) * 2.0 - 1.0,  // X: 0->width becomes -1->+1
        -((circle_center.y / screen_size.y) * 2.0 - 1.0) // Y: 0->height becomes +1->-1 (flip Y)
    );
    
    // Convert radius from screen pixels to NDC space with aspect correction
    float ndc_radius = (circle_radius / screen_size.y) * 2.0; // Use Y for consistent scaling
    float2 aspect_correction = float2(1.0 / aspect_ratio, 1.0); // Compress X for circular shape
    
    // Generate final position: center + scaled quad corner
    float2 ndc_pos = ndc_center + quad_corner * ndc_radius * aspect_correction;
    
    output.position = float4(ndc_pos, 0.0, 1.0);
    
    output.local_pos = quad_corner;
    output.color = float4(circle_color_r, circle_color_g, circle_color_b, circle_color_a);
    return output;
}

float4 ps_main(VertexOutput input) : SV_Target {
    // High-precision distance from center of quad in local space
    float2 precise_pos = input.local_pos;
    float dist = length(precise_pos);
    
    // Screen-space derivative-based anti-aliasing for stable edges
    float delta = length(fwidth(precise_pos));
    float edge_softness = delta * 0.7; // Smooth transition based on screen pixel size
    
    // Expand circle slightly beyond mathematical boundary for smoother edges
    float circle_radius = 0.98; // Slightly smaller than 1.0 to allow AA expansion
    float alpha = 1.0 - smoothstep(circle_radius - edge_softness, circle_radius + edge_softness, dist);
    
    // Conservative discard threshold
    if (alpha < 0.01) discard;
    
    return float4(input.color.rgb, alpha * input.color.a);
}
```

</File>


<File path="src/shaders/source/rectangle.hlsl">

```hlsl
// Rectangle rendering with pixel-perfect edges
// Compile with: dxc -T vs_6_0 -E vs_main rectangle.hlsl -Fo rectangle_vs.dxil
// Compile with: dxc -T ps_6_0 -E ps_main rectangle.hlsl -Fo rectangle_ps.dxil

// Per-frame uniforms
cbuffer FrameUniforms : register(b0) {
    float2 screen_size;
    float4 camera_transform; // [offset_x, offset_y, zoom, rotation]
    float time;
    float _padding;
};

// Per-instance vertex data
struct InstanceInput {
    float2 position : POSITION0;
    float2 size : POSITION1;
    float4 color : COLOR0;
};

// Vertex shader input
struct VertexInput {
    float2 position : POSITION;
    uint vertex_id : SV_VertexID;
    uint instance_id : SV_InstanceID;
};

// Vertex to pixel shader
struct VertexOutput {
    float4 position : SV_Position;
    float4 color : COLOR0;
};

// Quad vertices for instancing
static const float2 quad_positions[4] = {
    float2(0.0, 0.0), // Top-left
    float2(1.0, 0.0), // Top-right  
    float2(1.0, 1.0), // Bottom-right
    float2(0.0, 1.0)  // Bottom-left
};

VertexOutput vs_main(VertexInput input, InstanceInput instance) {
    VertexOutput output;
    
    // Get quad corner position (0,0 to 1,1)
    float2 quad_corner = quad_positions[input.vertex_id];
    
    // Scale by instance size and offset by position
    float2 world_pos = instance.position + quad_corner * instance.size;
    
    // Transform through camera
    world_pos = (world_pos - camera_transform.xy) * camera_transform.z;
    world_pos += screen_size * 0.5;
    
    // Convert to NDC
    output.position = float4(
        (world_pos.x / screen_size.x) * 2.0 - 1.0,
        1.0 - (world_pos.y / screen_size.y) * 2.0,
        0.0,
        1.0
    );
    
    output.color = instance.color;
    
    return output;
}

float4 ps_main(VertexOutput input) : SV_Target {
    return input.color;
}
```

</File>


<File path="src/shaders/source/debug_circle.hlsl">

```hlsl
// Debug circle shader - simplified version to test visibility
// SDL3 GPU API requires vertex shader uniforms at (b[n], space1)
cbuffer CircleUniforms : register(b0, space1) {
    float2 screen_size;      // 8 bytes
    float2 circle_center;    // 8 bytes
    float circle_radius;     // 4 bytes  
    float _padding1;         // 4 bytes (alignment)
    float4 circle_color;     // 16 bytes (RGBA)
};

// Vertex shader input (just vertex ID)
struct VertexInput {
    uint vertex_id : SV_VertexID;
};

// Vertex to pixel shader
struct VertexOutput {
    float4 position : SV_Position;
    float2 local_pos : TEXCOORD0;
    float4 color : COLOR0;
};

// Generate quad vertices procedurally
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    
    // Generate a simple full-screen quad to test if anything renders
    float2 quad_corner;
    uint tri = input.vertex_id / 3;  // Triangle index (0 or 1)
    uint vert = input.vertex_id % 3; // Vertex in triangle (0, 1, 2)
    
    // Generate quad covering center of screen
    if (tri == 0) {
        if (vert == 0) quad_corner = float2(-0.5, -0.5);      // bottom-left
        else if (vert == 1) quad_corner = float2(0.5, -0.5);  // bottom-right
        else quad_corner = float2(-0.5, 0.5);                 // top-left
    } else {
        if (vert == 0) quad_corner = float2(-0.5, 0.5);       // top-left
        else if (vert == 1) quad_corner = float2(0.5, -0.5);  // bottom-right
        else quad_corner = float2(0.5, 0.5);                  // top-right
    }
    
    // Use the quad corner directly as NDC coordinates (no transformation)
    output.position = float4(quad_corner, 0.0, 1.0);
    
    // Pass through data for pixel shader
    output.local_pos = quad_corner;
    output.color = float4(1.0, 0.0, 1.0, 1.0); // Bright magenta - should be very visible
    
    return output;
}

float4 ps_main(VertexOutput input) : SV_Target {
    // Just return the color - no distance field for now
    return input.color;
}
```

</File>


<File path="src/shaders/source/simple_rectangle.hlsl">

```hlsl
// Rectangle rendering for terrain and obstacles
cbuffer RectUniforms : register(b0, space1) {
    float2 screen_size;      // Screen dimensions for NDC conversion
    float2 rect_position;    // Rectangle position in screen coordinates
    float2 rect_size;        // Rectangle size in pixels
    float rect_color_r;      // Color components split to avoid
    float rect_color_g;      // HLSL array packing issues that
    float rect_color_b;      // caused color channel corruption
    float rect_color_a;      // Alpha channel
};

// Vertex shader input (just vertex ID)
struct VertexInput {
    uint vertex_id : SV_VertexID;
};

// Vertex to pixel shader
struct VertexOutput {
    float4 position : SV_Position;
    float4 color : COLOR0;
};

// Generate quad vertices procedurally
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    
    // Generate quad corner from vertex ID (6 vertices for 2 triangles)
    float2 quad_corner;
    uint tri = input.vertex_id / 3;  // Triangle index (0 or 1)
    uint vert = input.vertex_id % 3; // Vertex in triangle (0, 1, 2)
    
    // First triangle: (0,0), (1,0), (0,1)
    // Second triangle: (0,1), (1,0), (1,1)
    if (tri == 0) {
        if (vert == 0) quad_corner = float2(0.0, 0.0);      // top-left
        else if (vert == 1) quad_corner = float2(1.0, 0.0); // top-right
        else quad_corner = float2(0.0, 1.0);                // bottom-left
    } else {
        if (vert == 0) quad_corner = float2(0.0, 1.0);      // bottom-left
        else if (vert == 1) quad_corner = float2(1.0, 0.0); // top-right
        else quad_corner = float2(1.0, 1.0);                // bottom-right
    }
    
    // Calculate screen position: position + corner * size
    float2 screen_pos = rect_position + quad_corner * rect_size;
    
    // Convert to NDC coordinates
    float2 ndc_pos = float2(
        (screen_pos.x / screen_size.x) * 2.0 - 1.0,  // X: 0->width becomes -1->+1
        -((screen_pos.y / screen_size.y) * 2.0 - 1.0) // Y: 0->height becomes +1->-1 (flip Y)
    );
    
    output.position = float4(ndc_pos, 0.0, 1.0);
    output.color = float4(rect_color_r, rect_color_g, rect_color_b, rect_color_a);
    
    return output;
}

float4 ps_main(VertexOutput input) : SV_Target {
    return input.color;
}
```

</File>


<File path="src/shaders/compile_shaders.sh">

```sh
#!/bin/bash
# compile_shaders.sh - Compile all HLSL shaders to multiple formats
# Usage: ./compile_shaders.sh [--clean]

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SHADERCROSS="/home/desk/dev/gamedev/SDL_shadercross/build/shadercross"

# Parse command line arguments
CLEAN_BUILD=false
if [ "$1" = "--clean" ]; then
    CLEAN_BUILD=true
fi

# Check if shadercross tool exists
if [ ! -f "$SHADERCROSS" ]; then
    echo "Error: shadercross tool not found at $SHADERCROSS"
    echo "Please build SDL_shadercross first"
    exit 1
fi

echo "Working in directory: $SCRIPT_DIR"

# Clean existing compiled shaders if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo "🧹 Cleaning existing compiled shaders..."
    rm -rf compiled/
    echo "   Removed compiled/ directory"
fi

# Create output directories (focusing on working platforms)
mkdir -p compiled/d3d12
mkdir -p compiled/vulkan

# Show what we're about to do
if [ "$CLEAN_BUILD" = true ]; then
    echo "🔄 Clean rebuild requested"
else
    echo "🔧 Incremental build (use --clean for full rebuild)"
fi

# Compile all shaders to multiple formats
FAILED_SHADERS=()
SUCCESS_COUNT=0
TOTAL_COUNT=0

for shader in triangle triangle_uniforms simple_circle debug_circle circle rectangle effect simple_rectangle; do
    echo "Compiling $shader..."
    
    # Check if source file exists
    if [ ! -f "source/${shader}.hlsl" ]; then
        echo "Warning: source/${shader}.hlsl not found, skipping..."
        continue
    fi
    
    # Check if we need to rebuild (source newer than compiled files)
    NEEDS_REBUILD=false
    if [ "$CLEAN_BUILD" = true ]; then
        NEEDS_REBUILD=true
    else
        # Check if any target files are missing or older than source
        for target in "compiled/vulkan/${shader}_vs.spv" "compiled/vulkan/${shader}_ps.spv" \
                     "compiled/d3d12/${shader}_vs.dxil" "compiled/d3d12/${shader}_ps.dxil"; do
            if [ ! -f "$target" ] || [ "source/${shader}.hlsl" -nt "$target" ]; then
                NEEDS_REBUILD=true
                break
            fi
        done
    fi
    
    if [ "$NEEDS_REBUILD" = false ]; then
        echo "  ⏭️  Skipping $shader (up to date)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        continue
    fi
    
    SHADER_SUCCESS=true
    
    # Vulkan (SPIRV)
    echo "  → SPIRV..."
    if ! $SHADERCROSS source/${shader}.hlsl -s HLSL -d SPIRV -t vertex -e vs_main -o compiled/vulkan/${shader}_vs.spv 2>/dev/null; then
        echo "    ❌ Failed to compile ${shader} vertex shader to SPIRV"
        SHADER_SUCCESS=false
    fi
    if ! $SHADERCROSS source/${shader}.hlsl -s HLSL -d SPIRV -t fragment -e ps_main -o compiled/vulkan/${shader}_ps.spv 2>/dev/null; then
        echo "    ❌ Failed to compile ${shader} fragment shader to SPIRV"
        SHADER_SUCCESS=false
    fi
    
    # D3D12 (DXIL)
    echo "  → DXIL..."
    if ! $SHADERCROSS source/${shader}.hlsl -s HLSL -d DXIL -t vertex -e vs_main -o compiled/d3d12/${shader}_vs.dxil 2>/dev/null; then
        echo "    ❌ Failed to compile ${shader} vertex shader to DXIL"
        SHADER_SUCCESS=false
    fi
    if ! $SHADERCROSS source/${shader}.hlsl -s HLSL -d DXIL -t fragment -e ps_main -o compiled/d3d12/${shader}_ps.dxil 2>/dev/null; then
        echo "    ❌ Failed to compile ${shader} fragment shader to DXIL"
        SHADER_SUCCESS=false
    fi
    
    if $SHADER_SUCCESS; then
        echo "✅ Compiled $shader (SPIRV ✓, DXIL ✓)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "❌ Failed to compile $shader"
        FAILED_SHADERS+=("$shader")
    fi
    
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
done

# Only show summary if there were failures or if running interactively
if [ ${#FAILED_SHADERS[@]} -gt 0 ] || [ -t 1 ]; then
    echo ""
    echo "=== Compilation Summary ==="
    echo "Successfully compiled: $SUCCESS_COUNT/$TOTAL_COUNT shaders"
    
    if [ ${#FAILED_SHADERS[@]} -gt 0 ]; then
        echo "Failed shaders: ${FAILED_SHADERS[*]}"
        exit 1
    fi
fi
```

</File>

