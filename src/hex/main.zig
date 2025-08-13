const std = @import("std");

const c = @import("../lib/c.zig");

// Engine imports
const types = @import("../lib/types.zig");
const input = @import("../lib/input.zig");
const game_renderer_mod = @import("game_renderer.zig");
const maths = @import("../lib/maths.zig");

// Game-specific imports
const constants = @import("constants.zig");
const entities = @import("entities.zig");
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const loader = @import("loader.zig");
const hud = @import("hud.zig");
const game_controller = @import("game.zig");
const combat = @import("combat.zig");
const player_controller = @import("player.zig");
const portals = @import("portals.zig");
const controls = @import("controls.zig");

// Reactive system imports
const reactive_context = @import("../lib/reactive/context.zig");
const reactive_batch = @import("../lib/reactive/batch.zig");
const reactive_time = @import("../lib/reactive/time.zig");
const reactive_text_cache = @import("../lib/reactive/text_cache.zig");

const window_w = @as(u32, @intFromFloat(constants.SCREEN_WIDTH));
const window_h = @as(u32, @intFromFloat(constants.SCREEN_HEIGHT));
const Vec2 = types.Vec2;
const Color = types.Color;
const World = entities.World;
const GameRenderer = game_renderer_mod.GameRenderer;
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
var game_renderer: GameRenderer = undefined;
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

    // Initialize reactive system
    try reactive_context.initContext(global_allocator);
    try reactive_batch.initGlobalBatcher(global_allocator);
    try reactive_time.initGlobalTime(global_allocator, .Second);
    try reactive_text_cache.initGlobalTextCache(global_allocator);

    // Initialize renderer
    game_renderer = try GameRenderer.init(global_allocator, window);

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

    // Initialize HUD system
    try game_state.initHud(global_allocator, &game_renderer);

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
            game_state.deinitHud();
            game_renderer.deinit();
            loader.deinit(); // Clean up ZON data memory
            
            // Clean up reactive system
            reactive_text_cache.deinitGlobalTextCache(global_allocator);
            reactive_time.deinitGlobalTime();
            reactive_batch.deinitGlobalBatcher(global_allocator);
            reactive_context.deinitContext(global_allocator);
        }
        c.sdl.SDL_DestroyWindow(window);
        fully_initialized = false;
    }
}

// Game loop functions
fn runGameLoop() !void {
    // Tick reactive time system (updates frame count and time signals)
    reactive_time.tickGlobalTime();

    // Calculate delta time
    const current_time = c.sdl.SDL_GetPerformanceCounter();
    const frequency = c.sdl.SDL_GetPerformanceFrequency();
    const delta_ticks = current_time - last_time;
    const deltaTime: f32 = @as(f32, @floatFromInt(delta_ticks)) / @as(f32, @floatFromInt(frequency));
    last_time = current_time;

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
        const fps = reactive_time.getFPS();
        game_renderer.drawFPS(cmd_buffer, render_pass, fps);
    }
    
    // Draw all queued text (TTF text that was queued during frame)
    game_renderer.gpu.drawQueuedText(cmd_buffer, render_pass);

    // Render HUD overlay if open
    if (game_state.hud_system) |*hud_sys| {
        try hud_sys.render(cmd_buffer, render_pass);
    }

    // Draw state borders with stacking support and iris wipe effect - LAST for proper visual effect
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
