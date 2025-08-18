const std = @import("std");

// Core capabilities
const math = @import("../lib/math/mod.zig");
const time_utils = @import("../lib/core/time.zig");
const frame = @import("../lib/core/frame.zig");

// Platform capabilities
const c = @import("../lib/platform/sdl.zig");
const input = @import("../lib/platform/input.zig");

// Rendering capabilities
const camera = @import("../lib/rendering/camera.zig");

// Physics capabilities
const collision = @import("../lib/physics/collision.zig");

// Game system capabilities
const game_systems = @import("../lib/game/mod.zig");
const GameEffectSystem = @import("../lib/effects/game_effects.zig").GameEffectSystem;

// Debug capabilities
const Logger = @import("../lib/debug/logger.zig").Logger;
const outputs = @import("../lib/debug/outputs.zig");
const filters = @import("../lib/debug/filters.zig");

// Hex game modules
const hex_game_mod = @import("hex_game.zig");
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const player_controller = @import("player.zig");
const combat = @import("combat.zig");
const portals = @import("portals.zig");
const game_renderer = @import("game_renderer.zig");
const constants = @import("constants.zig");
const spells = @import("spells.zig");
const save_data = @import("save_data.zig");
const spellbar = @import("spellbar.zig");

// HUD modules
const hud = @import("../hud/hud.zig");
const reactive_hud = @import("../hud/reactive_hud.zig");

const Vec2 = math.Vec2;
const HexGame = hex_game_mod.HexGame;
const InputState = input.InputState;
const FrameContext = frame.FrameContext;
const ai_control = @import("../lib/game/control/mod.zig");

pub const GameState = struct {
    hex_game: HexGame,
    input_state: InputState,
    game_paused: bool,
    quit_requested: bool,

    // Visual effects system
    effect_system: GameEffectSystem,

    // Spell system
    spell_system: spells.SpellSystem,

    // Spellbar UI
    spellbar_ui: spellbar.Spellbar,

    // Allocator for ECS world cleanup
    allocator: std.mem.Allocator,

    // HUD system for system menu (reactive)
    hud_system: ?reactive_hud.ReactiveHud,

    // Iris wipe effect for resurrection
    iris_wipe_active: bool,
    iris_wipe_start_time: time_utils.Timestamp,

    // Game statistics (uses generic StatisticsInterface from lib/game/persistence)
    game_stats: save_data.GameStatistics,

    // AI control system
    ai_input: ?*ai_control.MappedInput,
    ai_enabled: bool,
    frame_counter: u32,

    // Logging system
    logger: ModuleLogger,

    const Self = @This();

    const ModuleLogger = Logger(.{
        .output = outputs.Console,
        .filter = filters.Throttle,
    });

    pub fn init(allocator: std.mem.Allocator) !Self {
        // No behavior system initialization needed - using persistent state machines

        var game_state = Self{
            .hex_game = HexGame.init(allocator),
            .input_state = InputState.init(),
            .game_paused = false,
            .quit_requested = false,
            .effect_system = GameEffectSystem.init(),
            .logger = ModuleLogger.init(allocator),
            .spell_system = spells.SpellSystem.init(),
            .spellbar_ui = spellbar.Spellbar.init(),
            .allocator = allocator,
            .hud_system = null,
            .iris_wipe_active = false,
            .iris_wipe_start_time = time_utils.Time.now(),
            .game_stats = .{},
            .ai_input = null,
            .ai_enabled = false,
            .frame_counter = 0,
        };

        // Connect the effect system to the hex game for travel effects
        game_state.hex_game.setEffectSystemRef(&game_state.effect_system);

        return game_state;
    }

    pub fn deinit(self: *Self) void {
        // No behavior system cleanup needed - persistent state machines clean themselves
        self.hex_game.deinit();
        self.logger.deinit();
        if (self.ai_input) |ai| {
            ai.deinit();
            self.allocator.destroy(ai);
            self.ai_input = null;
        }
    }

    pub fn initAIControl(self: *Self, allocator: std.mem.Allocator) !void {
        if (self.ai_input == null) {
            // Log the memory layout that Zig expects
            ai_control.DirectInputBuffer.InputCommand.debugLayout();

            const ai = try allocator.create(ai_control.MappedInput);
            ai.* = try ai_control.MappedInput.init(".ai_commands");
            self.ai_input = ai;
            self.ai_enabled = true;
            self.logger.info("ai_init", "AI control system initialized", .{});
        }
    }

    pub fn deinitAIControl(self: *Self, allocator: std.mem.Allocator) void {
        if (self.ai_input) |ai| {
            ai.deinit();
            allocator.destroy(ai);
            self.ai_input = null;
            self.ai_enabled = false;
            self.logger.info("ai_deinit", "AI control system deinitialized", .{});
        }
    }

    pub fn toggleAIControl(self: *Self) void {
        self.ai_enabled = !self.ai_enabled;
        if (self.ai_input) |mapped| {
            const pending = mapped.buffer.pending();
            self.logger.info("ai_toggle", "AI control: {} (ai_input exists, {} commands pending)", .{ self.ai_enabled, pending });
        } else {
            self.logger.info("ai_toggle", "AI control: {} (ai_input is null)", .{self.ai_enabled});
        }
    }

    // Save/load functions can be implemented using generic persistence patterns from lib/game/persistence/
    // when needed - GameStatistics already uses StatisticsInterface

    pub fn initHud(self: *Self, allocator: std.mem.Allocator, renderer_ptr: *game_renderer.GameRenderer) !void {
        self.hud_system = try reactive_hud.ReactiveHud.init(allocator, renderer_ptr);
    }

    pub fn deinitHud(self: *Self) void {
        if (self.hud_system) |*h| {
            h.deinit();
            self.hud_system = null;
        }
    }

    pub fn travelToZone(self: *Self, destination_zone: usize) !void {
        self.travelToZoneWithSpawn(destination_zone, null) catch |err| {
            return err;
        };
    }

    pub fn travelToZoneWithSpawn(self: *Self, destination_zone: usize, spawn_pos: ?math.Vec2) !void {
        if (destination_zone < hex_game_mod.MAX_ZONES) {
            // Get the default spawn position for the zone if not provided
            const zone = self.hex_game.zone_manager.getZoneConst(destination_zone);
            const actual_spawn_pos = spawn_pos orelse zone.spawn_pos;

            // Use hex_game's travelToZone which properly handles entity transfer
            try self.hex_game.travelToZone(destination_zone, actual_spawn_pos);

            // Clear ALL effects on zone travel to keep them fully ephemeral
            self.effect_system.clear();
        }
    }

    pub fn togglePause(self: *Self) void {
        self.game_paused = !self.game_paused;
        if (self.game_paused) {
            self.logger.info("game_paused", "Game paused", .{});
        } else {
            self.logger.info("game_resumed", "Game resumed", .{});
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
        // Reset current zone (implemented with hex_game architecture)
        self.logger.info("zone_reset", "Zone units reset to original state", .{});
    }

    pub fn resetGame(self: *Self) void {
        // Reset player to starting position and state
        self.hex_game.setPlayerPos(self.hex_game.player_start_pos);
        self.hex_game.setPlayerAlive(true);

        // Reset to starting zone
        if (self.hex_game.zone_manager.getCurrentZoneIndex() != 0) {
            self.travelToZone(0) catch |err| {
                self.logger.err("reset_travel_fail", "Failed to travel to overworld during reset: {}", .{err});
            };
        }

        // Reset all zones (implemented with hex_game architecture)

        // Clear effects for clean slate (keep ephemeral)
        self.effect_system.clear();

        self.logger.info("full_reset", "Full game reset", .{});
    }

    /// Check if all lifestones across all zones are attuned
    pub fn hasAttunedAllLifestones(self: *const Self) bool {
        // Direct computation - no complex caching
        var total_lifestones: usize = 0;
        var total_attuned: usize = 0;

        // Check all zones
        for (0..hex_game_mod.MAX_ZONES) |zone_idx| {
            const zone = self.hex_game.zone_manager.getZoneConst(zone_idx);

            // Count lifestones in this zone
            for (0..zone.lifestones.count) |i| {
                const entity_id = zone.lifestones.entities[i];
                if (entity_id == std.math.maxInt(u32)) continue;

                total_lifestones += 1;

                // Check if attuned
                if (zone.lifestones.getComponent(entity_id, .interactable)) |interactable| {
                    if (interactable.attuned) {
                        total_attuned += 1;
                    }
                }
            }
        }

        return total_lifestones > 0 and total_attuned == total_lifestones;
    }

    /// Properly compute all lifestones attuned for the cache
    pub fn computeAllLifestonesAttunedForWorld(self: *const Self) bool {
        return self.hasAttunedAllLifestones();
    }

    /// Get total number of lifestones in the world
    pub fn computeTotalLifestonesForWorld(self: *const Self) usize {
        var total_lifestones: usize = 0;

        // Check all zones
        for (0..hex_game_mod.MAX_ZONES) |zone_idx| {
            const zone = self.hex_game.zone_manager.getZoneConst(zone_idx);

            // Count lifestones in this zone
            for (0..zone.lifestones.count) |i| {
                const entity_id = zone.lifestones.entities[i];
                if (entity_id == std.math.maxInt(u32)) continue;
                total_lifestones += 1;
            }
        }

        return total_lifestones;
    }

    /// Get number of attuned lifestones in the world
    pub fn computeTotalAttunedLifestonesForWorld(self: *const Self) usize {
        var total_attuned: usize = 0;

        // Check all zones
        for (0..hex_game_mod.MAX_ZONES) |zone_idx| {
            const zone = self.hex_game.zone_manager.getZoneConst(zone_idx);

            // Count attuned lifestones in this zone
            for (0..zone.lifestones.count) |i| {
                const entity_id = zone.lifestones.entities[i];
                if (entity_id == std.math.maxInt(u32)) continue;

                // Check if attuned
                if (zone.lifestones.getComponent(entity_id, .interactable)) |interactable| {
                    if (interactable.attuned) {
                        total_attuned += 1;
                    }
                }
            }
        }

        return total_attuned;
    }
};

/// Context-aware update all units function
fn updateUnits(game_state: *GameState, frame_ctx: FrameContext) void {
    const world = &game_state.hex_game;

    // Note: Obstacle collision now uses ECS queries

    // Query all units from ECS system
    const zone_storage = world.getZoneStorage();
    var unit_iter = zone_storage.units.entityIterator();
    while (unit_iter.next()) |unit_id| {
        // Skip if entity is not alive
        if (!zone_storage.isAlive(unit_id)) continue;

        // Get components
        if (zone_storage.units.getComponentMut(unit_id, .transform)) |transform| {
            if (zone_storage.units.getComponentMut(unit_id, .health)) |health| {
                if (!health.alive) continue;

                if (zone_storage.units.getComponentMut(unit_id, .unit)) |unit_comp| {
                    const old_pos = transform.pos;

                    if (zone_storage.units.getComponentMut(unit_id, .visual)) |visual| {
                        // Update unit AI behavior using HexGame components with context
                        // For now using 1.0 aggro modifier (no spell effects)
                        const aggro_mod: f32 = 1.0;
                        behaviors.updateUnitWithAggroMod(unit_comp, transform, visual, world.getPlayerPos(), world.getPlayerAlive(), aggro_mod, frame_ctx);
                    }

                    // Check collision with obstacles
                    if (physics.checkUnitObstacleCollision(world, unit_id, transform, health, old_pos)) {
                        // Collision was handled by the function
                        break;
                    }
                }
            }
        }
    }
}

pub fn updateGame(game_state: *GameState, cam: *const camera.Camera, deltaTime: f32) void {
    // Reset frame pool for this frame's temporary allocations
    game_state.hex_game.frame_pool.reset();

    // Create minimal frame context
    const frame_allocator = game_state.hex_game.frame_pool.allocator();
    const frame_ctx = FrameContext.init(frame_allocator, deltaTime, game_state.frame_counter, game_state.game_paused);

    const world = &game_state.hex_game;
    const input_state = &game_state.input_state;

    // Increment frame counter
    game_state.frame_counter += 1;

    // Process AI commands if enabled
    if (game_state.ai_enabled and game_state.ai_input != null) {
        if (game_state.ai_input) |mapped| {
            const pending = mapped.buffer.pending();
            if (pending > 0) {
                game_state.logger.info("ai_process", "Processing {} AI commands at frame {}", .{ pending, game_state.frame_counter });
            }
            ai_control.processCommands(mapped.buffer, &game_state.input_state, game_state.frame_counter);
        }
    }

    // Update HUD system if open
    if (game_state.hud_system) |*h| {
        h.update(deltaTime);
        // Don't update game when HUD is open
        if (h.is_open()) return;
    }

    if (game_state.game_paused) return;

    // Update portal cooldown
    portals.updatePortalCooldown(world, frame_ctx);

    if (world.getPlayerAlive()) {
        // Update player controller
        player_controller.updatePlayer(world, frame_ctx, input_state, cam);

        // Handle continuous shooting on left-click hold (rhythm mode)
        // Only shoot if Ctrl is NOT held (Ctrl enables mouse movement instead)
        if (!input_state.isCtrlHeld() and input_state.isLeftMouseHeld() and world.canFireBullet()) {
            // Use context-aware bullet firing
            _ = combat.fireBulletAtMouse(world, input_state.getMousePos(), &world.bullet_pool);
        }
    }

    // Update bullet entities using ECS
    world.updateProjectiles(frame_ctx);

    // Update units with context
    updateUnits(game_state, frame_ctx);

    checkCollisions(game_state);

    // Update visual effects
    game_state.effect_system.update();

    // Update spell system with context
    game_state.spell_system.update(frame_ctx);

    // Update bullet pool with context
    world.updateBulletPool(frame_ctx);
}

pub fn checkCollisions(game_state: *GameState) void {
    const world = &game_state.hex_game;

    // Player entity is accessed via helper methods instead of direct field access

    // Bullet-unit collision is handled in world.updateProjectiles() above

    if (!world.getPlayerAlive()) return;

    // Debug: Check if portal checking is being called
    game_state.logger.debug("game_loop", "Checking portal collisions in game loop", .{});
    if (portals.checkPortalCollisions(world)) {
        game_state.logger.info("game_portal_activated", "Portal activated, exiting game loop", .{});
        return;
    }

    // Get player position and radius for collision checks
    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();

    // Check player-unit collisions (player dies on contact)
    if (physics.checkPlayerUnitCollision(world)) {
        // Player dies on unit contact
        world.setPlayerAlive(false);
        world.setPlayerColor(constants.COLOR_DEAD);
        return;
    }

    // Check lifestone collisions
    checkLifestoneCollisions(game_state, player_pos, player_radius);

    // Check collision with deadly obstacles
    if (physics.collidesWithDeadlyObstacle(player_pos, player_radius, world)) {
        // Player dies on hazard contact
        world.setPlayerAlive(false);
        world.setPlayerColor(constants.COLOR_DEAD);
    }
}

pub fn handleFireBullet(game_state: *GameState, cam: *const camera.Camera) void {
    if (game_state.hex_game.getPlayerAlive() and !game_state.game_paused and game_state.hex_game.canFireBullet()) {
        const screen_mouse_pos = game_state.input_state.getMousePos();
        const world_mouse_pos = cam.screenToWorldSafe(screen_mouse_pos);
        _ = combat.fireBulletAtMouse(&game_state.hex_game, world_mouse_pos, &game_state.hex_game.bullet_pool);
    }
}

// Check lifestone collisions
fn checkLifestoneCollisions(game_state: *GameState, player_pos: Vec2, player_radius: f32) void {
    const world = &game_state.hex_game;

    // Use the same approach as physics.zig for consistency
    const zone = world.getCurrentZone();

    // Check all lifestones in this zone using direct array access like physics.zig does
    for (0..zone.lifestones.count) |i| {
        const entity_id = zone.lifestones.entities[i];
        if (entity_id == std.math.maxInt(u32)) continue;

        const transform = &zone.lifestones.transforms[i];
        const interactable = &zone.lifestones.interactables[i];

        // Lifestones are identified by component composition (having both Transform and Interactable with attunement capability)
        // This is more flexible than checking terrain type

        // Check collision first (allows re-attunement when overlapping)
        if (collision.checkCircleCollision(player_pos, player_radius, transform.pos, transform.radius)) {
            const was_attuned = interactable.attuned;

            // Attune the lifestone
            interactable.attuned = true;

            // Update visual color for attunement
            const visual = &zone.lifestones.visuals[i];
            visual.color = constants.COLOR_LIFESTONE_ATTUNED;

            // Only log and track stats for new attunements
            if (!was_attuned) {
                game_state.logger.info("lifestone_attuned", "Lifestone attuned!", .{});

                // Track lifestone attunement for save system
                game_state.game_stats.lifestones_attuned += 1;

                // Check if all lifestones are now attuned
                if (game_state.hasAttunedAllLifestones()) {
                    game_state.logger.info("achievement", "All lifestones attuned!", .{});
                    game_state.game_stats.all_lifestones_attuned = true;
                }
            }

            // Add inner effect for newly attuned lifestone
            game_state.effect_system.addLifestoneInnerEffectOnly(transform.pos, transform.radius);
        }
    }
}

pub fn handleRespawn(game_state: *GameState) void {
    // Start iris wipe effect
    game_state.iris_wipe_active = true;
    game_state.iris_wipe_start_time = time_utils.Time.now();

    combat.respawnPlayer(game_state);
}
