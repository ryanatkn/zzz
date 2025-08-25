const std = @import("std");
const loggers = @import("../lib/debug/loggers.zig");
const log_config = @import("../lib/debug/config.zig");
const c = @import("../lib/platform/sdl.zig");
const platform = @import("../lib/platform/mod.zig");

// Engine imports
const colors = @import("../lib/core/colors.zig");
const input = @import("../lib/platform/input.zig");
const game_renderer_mod = @import("game_renderer.zig");
const math = @import("../lib/math/mod.zig");

// Game-specific imports
const constants = @import("constants.zig");
const physics = @import("physics.zig");
const loader = @import("loader.zig");
const hud = @import("hud.zig");
const game_loop_mod = @import("game_loop.zig");
const combat = @import("combat.zig");
const portals = @import("portals.zig");
const controls = @import("controls.zig");
const behaviors = @import("behaviors/mod.zig");
const router = @import("hud/router.zig");

// Reactive system imports
const reactive_context = @import("../lib/reactive/context.zig");
const reactive_batch = @import("../lib/reactive/batch.zig");
const reactive_time = @import("../lib/reactive/time.zig");
const reactive_text_cache = @import("../lib/reactive/text_cache.zig");
const persistent_text = @import("../lib/text/cache.zig");
// const texture_utils = @import("../lib/image/texture.zig"); // Removed - no more textures

// Debug system imports (already imported above)

const Vec2 = math.Vec2;
const Color = colors.Color;
const WindowConfig = platform.WindowConfig;
const GameRenderer = game_renderer_mod.GameRenderer;
const GameState = game_loop_mod.GameState;
const Hud = hud.Hud;

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
var window: ?*c.sdl.SDL_Window = null;
var game_renderer: ?*GameRenderer = null;
var game_state: ?*GameState = null;
var game_hud: ?*Hud = null;
var global_allocator: std.mem.Allocator = undefined;

// Use pre-configured game logger from loggers module
var logger: ?loggers.GameLogger = null;

// Timing
var last_time: u64 = 0;

fn sdlAppInit(appstate: ?*?*anyopaque, argv: [][*:0]u8) !c.sdl.SDL_AppResult {
    _ = appstate;
    _ = argv;

    try errify(c.sdl.SDL_Init(c.sdl.SDL_INIT_VIDEO));

    // Create window using platform utilities
    const window_config = WindowConfig{
        .title = constants.WINDOW_TITLE,
        .width = @intCast(constants.WINDOW_WIDTH),
        .height = @intCast(constants.WINDOW_HEIGHT),
        .flags = c.sdl.SDL_WINDOW_RESIZABLE | c.sdl.SDL_WINDOW_HIDDEN,
    };

    window = try platform.window.createWindow(window_config);
    errdefer if (window) |w| c.sdl.SDL_DestroyWindow(w);

    // Initialize reactive system
    try reactive_context.initContext(global_allocator);
    try reactive_batch.initGlobalBatcher(global_allocator);
    try reactive_time.initGlobalTime(global_allocator, .Second);
    try reactive_text_cache.initGlobalTextCache(global_allocator);

    // Initialize loggers FIRST (before other components that might use them)
    logger = loggers.GameLogger.init(global_allocator);
    try loggers.initGlobalLoggers(global_allocator);

    // Load optional runtime config overrides from .zz/log-config.zon
    if (log_config.loadOverrides(global_allocator)) |overrides| {
        defer if (@hasDecl(@TypeOf(overrides), "deinit")) overrides.deinit(global_allocator);
        overrides.apply();
    } else |_| {
        // Config loading failed - continue with defaults
    }

    // Initialize renderer (heap allocated to avoid memory corruption)
    game_renderer = try global_allocator.create(GameRenderer);
    errdefer global_allocator.destroy(game_renderer.?);
    game_renderer.?.* = try GameRenderer.init(global_allocator, window.?);

    // Initialize deferred texture upload system - removed (no more textures)
    // texture_utils.initDeferredUploads(global_allocator);

    // Initialize persistent text system (needs GPU device from renderer)
    try persistent_text.initGlobalPersistentTextSystem(global_allocator, game_renderer.?.gpu.device);

    // Initialize game state (heap allocated)
    game_state = try global_allocator.create(GameState);
    errdefer global_allocator.destroy(game_state.?);
    game_state.?.* = try GameState.init(global_allocator);

    // Set global reference for world reloading in HUD
    router.setGameStateReference(game_state.?);

    // Initialize behavior system for modular AI
    behaviors.initBehaviorSystem(global_allocator);

    // Initialize HUD (heap allocated)
    game_hud = try global_allocator.create(Hud);
    errdefer global_allocator.destroy(game_hud.?);
    game_hud.?.* = Hud.init();

    // Load game data
    loader.loadGameData(global_allocator, &game_state.?.hex_game) catch |err| {
        if (logger) |*log| {
            log.err("zon_load_fail", "Failed to load game data from ZON file: {}", .{err});
            log.err("zon_check_msg", "Please check that game_data.zon exists and is valid", .{});
        }
        return err;
    };

    // Effects are ephemeral - no need for ambient effect initialization

    // Initialize HUD system
    try game_state.?.initHud(global_allocator, game_renderer.?);

    // Initialize AI control system (optional - fails silently if file doesn't exist)
    game_state.?.initAIControl(global_allocator) catch |err| {
        if (logger) |*log| {
            log.info("ai_init_skip", "AI control not initialized: {}", .{err});
        }
    };

    // Show window after initialization
    _ = c.sdl.SDL_ShowWindow(window.?);

    last_time = c.sdl.SDL_GetPerformanceCounter();

    fully_initialized = true;
    if (logger) |*log| {
        log.info("game_init_success", "Hex GPU game initialized successfully", .{});
        log.info("controls_info", "Controls: WASD move, left-click shoot, right-click cast ability, 1-4/Q/E/R/F select abilities (see ability bar), L respawn, Space pause, ESC quit", .{});
        log.info("portal_info", "Portal interaction: Walk into portals to travel between zones", .{});
        log.info("ai_control_info", "Press G to toggle AI control mode", .{});
    }
    return c.sdl.SDL_APP_CONTINUE;
}

fn sdlAppIterate(appstate: ?*anyopaque) !c.sdl.SDL_AppResult {
    _ = appstate;

    if (game_state.?.shouldQuit()) {
        return c.sdl.SDL_APP_SUCCESS;
    }

    // Run the game
    try runGameLoop();

    return c.sdl.SDL_APP_CONTINUE;
}

fn sdlAppEvent(appstate: ?*anyopaque, event: *c.sdl.SDL_Event) !c.sdl.SDL_AppResult {
    _ = appstate;

    // Prevent accessing uninitialized game objects
    if (!fully_initialized) {
        // During initialization, only handle critical events
        switch (event.type) {
            c.sdl.SDL_EVENT_QUIT => return c.sdl.SDL_APP_SUCCESS,
            else => return c.sdl.SDL_APP_CONTINUE,
        }
    }

    return controls.handleSDLEvent(game_state.?, game_renderer.?, game_hud.?, event);
}

fn sdlAppQuit(appstate: ?*anyopaque, result: anyerror!c.sdl.SDL_AppResult) void {
    _ = appstate;
    const app_result = result catch |err| {
        loggers.getGameLog().err("sdl_quit", "SDL app quit with error: {}", .{err});
        return;
    };
    loggers.getGameLog().info("sdl_quit", "SDL app quit with result: {}", .{app_result});

    if (fully_initialized) {
        {
            game_state.?.deinitHud();

            // Clean up behavior system
            behaviors.deinitBehaviorSystem();

            // CRITICAL: Clean up persistent text system BEFORE game_renderer.deinit()
            // This ensures GPU textures are released before the GPU device is destroyed
            persistent_text.deinitGlobalPersistentTextSystem(global_allocator);

            // Clean up deferred texture upload system - removed (no more textures)
            // texture_utils.deinitDeferredUploads();

            // Now safe to deinitialize the renderer and GPU device
            game_renderer.?.deinit();
            // Clean up ZON data arena allocator
            loader.deinit();

            // Free heap-allocated structures
            global_allocator.destroy(game_renderer.?);
            game_state.?.deinit();
            global_allocator.destroy(game_state.?);
            global_allocator.destroy(game_hud.?);

            // Clean up reactive system
            reactive_text_cache.deinitGlobalTextCache(global_allocator);
            reactive_time.deinitGlobalTime();
            reactive_batch.deinitGlobalBatcher(global_allocator);
            reactive_context.deinitContext(global_allocator);

            // Clean up logger system
            if (logger) |*log| {
                log.deinit();
            }
            loggers.deinitGlobalLoggers();
        }
        if (window) |w| {
            c.sdl.SDL_DestroyWindow(w);
            window = null;
        }
        fully_initialized = false;
    }
}

var frame_counter: u32 = 0;

// Game loop functions
fn runGameLoop() !void {
    // Tick reactive time system (updates frame count and time signals)
    reactive_time.tickGlobalTime();

    // Print logging summary every 10 seconds (at 60 FPS = 600 frames)
    frame_counter += 1;
    if (frame_counter % 600 == 0) {
        // Print throttle summary if available
        if (logger) |*log| {
            if (@hasDecl(@TypeOf(log.filter), "getSummary")) {
                // Throttle filter summary printing (feature available but optional)
            }
        }
    }

    // Calculate delta time
    const current_time = c.sdl.SDL_GetPerformanceCounter();
    const frequency = c.sdl.SDL_GetPerformanceFrequency();
    const delta_ticks = current_time - last_time;
    const deltaTime: f32 = @as(f32, @floatFromInt(delta_ticks)) / @as(f32, @floatFromInt(frequency));
    last_time = current_time;

    // Update camera before game logic (for correct mouse coordinate transformation)
    game_renderer.?.updateCamera(&game_state.?.hex_game);

    // Update game state
    // Pass camera pointer directly from the heap-allocated GameRenderer
    game_loop_mod.updateGame(game_state.?, &game_renderer.?.camera, deltaTime);

    // Render
    try renderGame();
}

fn renderGame() !void {
    const zone = game_state.?.hex_game.getCurrentZone();

    // Begin GPU frame
    const cmd_buffer = try game_renderer.?.beginFrame();

    // CRITICAL: Create all text textures BEFORE render pass begins
    // This avoids "Cannot begin copy pass during another pass" errors
    if (game_hud.?.visible) {
        const fps = reactive_time.getFPS();
        game_renderer.?.prepareFPS(fps);

        // Prepare AI mode indicator if enabled
        game_renderer.?.prepareAIMode(game_state.?.ai_enabled);

        // Prepare debug info (player position and camera viewport)
        game_renderer.?.prepareDebugInfo(&game_state.?.hex_game);
    }

    // CRITICAL: Ensure all GPU operations complete before beginning render pass
    // This ensures textures are fully uploaded and ready for use
    _ = c.sdl.SDL_WaitForGPUIdle(game_renderer.?.gpu.device);

    const render_pass = try game_renderer.?.beginRenderPass(cmd_buffer, zone.background_color);

    // Render all entities
    game_renderer.?.renderZone(cmd_buffer, render_pass, &game_state.?.hex_game);

    // Render visual particles
    game_renderer.?.renderParticles(cmd_buffer, render_pass, &game_state.?.particle_system);

    // Draw HUD (now just queues already-created textures)
    if (game_hud.?.visible) {
        game_renderer.?.drawFPS(cmd_buffer, render_pass);
        game_renderer.?.drawAIMode(cmd_buffer, render_pass);
        game_renderer.?.drawDebugInfo(cmd_buffer, render_pass);

        // Draw ability bar
        game_renderer.?.drawAbilityBar(cmd_buffer, render_pass, &game_state.?.ability_system, &game_state.?.ability_bar_ui);
    }

    // Render HUD overlay if open
    if (game_state.?.hud_system) |*hud_sys| {
        try hud_sys.render(cmd_buffer, render_pass);
    }

    // Draw all queued text (TTF text that was queued during frame)
    // IMPORTANT: This must come AFTER HUD rendering so text queued by HUD is drawn
    // Draw all queued text using buffer-based rendering
    const main_render_log = loggers.getRenderLog();
    main_render_log.info("main_draw_queued", "About to draw queued text from main loop", .{});
    game_renderer.?.gpu.text_integration.drawQueuedText(&game_renderer.?.gpu, cmd_buffer, render_pass) catch |err| {
        const render_error_log = loggers.getRenderLog();
        render_error_log.err("text_render_fail", "Failed to draw queued text: {}", .{err});
    };
    main_render_log.info("main_draw_complete", "Completed drawing queued text from main loop", .{});

    // Draw state borders with stacking support and iris wipe effect - LAST for proper visual effect
    game_renderer.?.drawBorders(cmd_buffer, render_pass, game_state.?);

    game_renderer.?.endRenderPass(render_pass);
    game_renderer.?.endFrame(cmd_buffer);
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
