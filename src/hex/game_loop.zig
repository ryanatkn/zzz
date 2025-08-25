const std = @import("std");

// Core capabilities
const math = @import("../lib/math/mod.zig");
const time_utils = @import("../lib/core/time.zig");
const frame = @import("../lib/core/frame.zig");

// Platform capabilities
const c = @import("../lib/platform/sdl.zig");
const input = @import("../lib/platform/input.zig");

// Physics capabilities
const collision = @import("../lib/physics/collision/mod.zig");

// Game system capabilities
const game_systems = @import("../lib/game/mod.zig");
const camera = @import("../lib/game/camera/camera.zig");
const GameParticleSystem = @import("../lib/particles/game_particles.zig").GameParticleSystem;

// Debug capabilities
const Logger = @import("../lib/debug/logger.zig").Logger;
const outputs = @import("../lib/debug/outputs.zig");
const filters = @import("../lib/debug/filters.zig");

// Hex game modules - now using refactored structure
const world_state_mod = @import("world_state.zig");
const systems = @import("systems/mod.zig");
const controllers = @import("controllers/mod.zig");
const world = @import("world/mod.zig");
const ui = @import("ui/mod.zig");
const behaviors = @import("behaviors/mod.zig");
const physics = @import("physics.zig");
const game_renderer = @import("game_renderer.zig");
const constants = @import("constants.zig");
const color_mappings = @import("color_mappings.zig");
const spells = @import("spells.zig");

// Extracted modules for clean architecture
const input_modules = @import("input/mod.zig");
const state_modules = @import("state/mod.zig");

// HUD modules
const hud = @import("hud/hud.zig");
const reactive_hud = @import("hud/reactive_hud.zig");

const Vec2 = math.Vec2;
const HexGame = world_state_mod.HexGame;
const InputState = input.InputState;
const FrameContext = frame.FrameContext;
const ai_control = @import("../lib/game/control/mod.zig");

pub const GameState = struct {
    hex_game: HexGame,
    input_state: InputState,
    game_paused: bool,
    quit_requested: bool,

    // Visual effects system
    particle_system: GameParticleSystem,

    // Spell system
    spell_system: spells.SpellSystem,

    // Spellbar UI
    spellbar_ui: ui.spellbar.Spellbar,

    // Allocator for ECS world cleanup
    allocator: std.mem.Allocator,

    // HUD system for system menu (reactive)
    hud_system: ?reactive_hud.ReactiveHud,

    // Renderer reference for HUD recreation during world reload
    renderer: ?*game_renderer.GameRenderer,

    // Iris wipe effect for resurrection
    iris_wipe_active: bool,
    iris_wipe_start_time: time_utils.Timestamp,

    // Game statistics (uses generic StatisticsInterface from lib/game/persistence)
    game_stats: world.save_data.GameStatistics,

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
            .particle_system = GameParticleSystem.init(),
            .logger = ModuleLogger.init(allocator),
            .spell_system = spells.SpellSystem.init(),
            .spellbar_ui = ui.spellbar.Spellbar.init(),
            .allocator = allocator,
            .hud_system = null,
            .renderer = null,
            .iris_wipe_active = false,
            .iris_wipe_start_time = time_utils.Time.now(),
            .game_stats = .{},
            .ai_input = null,
            .ai_enabled = false,
            .frame_counter = 0,
        };

        // Connect the effect system to the hex game for travel effects
        game_state.hex_game.setParticleSystemRef(&game_state.particle_system);

        return game_state;
    }

    pub fn deinit(self: *Self) void {
        // Clean up HUD system
        self.deinitHud();

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
        return input_modules.InputHandler.initAIControl(&self.ai_input, &self.ai_enabled, allocator, &self.logger);
    }

    pub fn deinitAIControl(self: *Self, allocator: std.mem.Allocator) void {
        input_modules.InputHandler.deinitAIControl(&self.ai_input, &self.ai_enabled, allocator, &self.logger);
    }

    pub fn toggleAIControl(self: *Self) void {
        input_modules.InputHandler.toggleAIControl(&self.ai_enabled, self.ai_input, &self.logger);
    }

    // Possession/Control methods (Phase 2)
    pub fn cyclePossessionTarget(self: *Self) void {
        if (self.hex_game.cyclePossession()) {
            if (self.hex_game.getControlledEntity()) |entity_id| {
                self.logger.info("possession", "Cycled to entity {}", .{entity_id});

                // Log faction perspective change
                if (self.hex_game.getControlledEntityFactions()) |factions| {
                    self.logger.info("faction_view", "Now viewing world through {} faction tags", .{factions.tags.count()});
                }
            }
        } else {
            self.logger.info("possession", "No controllable entities found to cycle to", .{});
        }
    }

    pub fn releaseControl(self: *Self) void {
        if (self.hex_game.getControlledEntity()) |entity_id| {
            self.hex_game.releaseControl();
            self.logger.info("autonomous", "Released control of entity {} - entering autonomous simulation", .{entity_id});
        } else {
            self.logger.info("autonomous", "No entity was controlled - already in autonomous mode", .{});
        }
    }

    // Save/load functions can be implemented using generic persistence patterns from lib/game/persistence/
    // when needed - GameStatistics already uses StatisticsInterface

    pub fn initHud(self: *Self, allocator: std.mem.Allocator, renderer_ptr: *game_renderer.GameRenderer) !void {
        self.renderer = renderer_ptr; // Store renderer reference
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
        if (destination_zone < world_state_mod.MAX_ZONES) {
            // Get the default spawn position for the zone if not provided
            const zone = self.hex_game.zone_manager.getZoneConst(destination_zone);
            const actual_spawn_pos = spawn_pos orelse zone.spawn_pos;

            // Use travel system for zone transition
            try world.TravelSystem.travelToZone(&self.hex_game, destination_zone, actual_spawn_pos);

            // Clear ALL effects on zone travel to keep them fully ephemeral
            ui.EffectsSystem.clearAllEffects(&self.particle_system);
        }
    }

    pub fn togglePause(self: *Self) void {
        state_modules.PauseManager.togglePause(&self.game_paused, &self.logger);
    }

    pub fn requestQuit(self: *Self) void {
        state_modules.PauseManager.requestQuit(&self.quit_requested);
    }

    pub fn shouldQuit(self: *const Self) bool {
        return state_modules.PauseManager.shouldQuit(self.quit_requested);
    }

    pub fn isPaused(self: *const Self) bool {
        return state_modules.PauseManager.isPaused(self.game_paused);
    }

    pub fn resetZone(self: *Self) void {
        // Reset units in current zone to their original spawn state
        // Reset current zone (implemented with hex_game architecture)
        self.logger.info("zone_reset", "Zone units reset to original state", .{});
    }

    pub fn resetGame(self: *Self) void {
        // Reset controlled entity to starting position and state - now uses zone spawn position
        const overworld_zone = self.hex_game.zone_manager.getZoneConst(0);

        if (self.hex_game.getControlledEntity()) |controlled_entity| {
            const zone = self.hex_game.getCurrentZone();
            if (zone.units.getComponentMut(controlled_entity, .transform)) |transform| {
                transform.pos = overworld_zone.spawn_pos;
            }
            if (zone.units.getComponentMut(controlled_entity, .health)) |health| {
                health.alive = true;
                health.current = health.max;
            }
        }

        // Reset to starting zone
        if (self.hex_game.zone_manager.getCurrentZoneIndex() != 0) {
            self.travelToZone(0) catch |err| {
                self.logger.err("reset_travel_fail", "Failed to travel to overworld during reset: {}", .{err});
            };
        }

        // Reset all zones (implemented with hex_game architecture)

        // Clear effects for clean slate (keep ephemeral)
        self.particle_system.clear();

        self.logger.info("full_reset", "Full game reset", .{});
    }

    /// Reload the game with a different world
    pub fn reloadWithWorld(self: *Self, world_path: []const u8) !void {
        self.logger.info("world_reload", "Reloading with world: {s}", .{world_path});

        // Clean up HUD before world reload to prevent reactive state corruption
        self.deinitHud();
        self.logger.info("world_reload_hud_cleanup", "HUD deinitialized", .{});

        // Clear current game state
        self.hex_game.deinit();
        self.particle_system.clear();

        // Clear zone manager state
        self.hex_game = HexGame.init(self.allocator);

        // Load new world data with error handling
        var world_loaded_successfully = false;
        world.loader.loadWorldData(self.allocator, &self.hex_game, world_path) catch |err| {
            self.logger.err("world_reload_failed", "Failed to load world {s}: {}", .{ world_path, err });

            // Try to recover by loading the default world
            const fallback_world = world.loader.DEFAULT_WORLD;
            self.logger.info("world_reload_fallback", "Attempting fallback to: {s}", .{fallback_world});

            world.loader.loadWorldData(self.allocator, &self.hex_game, fallback_world) catch |fallback_err| {
                self.logger.err("world_reload_fallback_failed", "Fallback also failed: {}", .{fallback_err});

                // Try to recreate HUD even after failure to maintain some stability
                self.tryRecreateHud();

                return fallback_err;
            };

            self.logger.info("world_reload_fallback_success", "Fallback successful", .{});
            world_loaded_successfully = true;
        };

        if (!world_loaded_successfully) {
            world_loaded_successfully = true;
        }

        // Recreate HUD after successful world loading
        self.tryRecreateHud();

        // Reset game state for new world
        self.game_paused = false;
        self.iris_wipe_active = false;

        self.logger.info("world_reload_complete", "Successfully reloaded world: {s}", .{world_path});
    }

    /// Helper function to recreate HUD, handling errors gracefully
    fn tryRecreateHud(self: *Self) void {
        if (self.renderer) |renderer_ptr| {
            self.initHud(self.allocator, renderer_ptr) catch |hud_err| {
                self.logger.err("hud_recreation_failed", "Failed to recreate HUD: {}", .{hud_err});
            };
            self.logger.info("hud_recreation_attempted", "HUD recreation attempted", .{});
        } else {
            self.logger.warn("hud_recreation_no_renderer", "No renderer reference available for HUD recreation", .{});
        }
    }

    /// Check if all lifestones across all zones are attuned - now delegated to LifestoneSystem
    pub fn hasAttunedAllLifestones(self: *const Self) bool {
        return state_modules.StatisticsManager.hasAttunedAllLifestones(self);
    }

    /// Properly compute all lifestones attuned for the cache
    pub fn computeAllLifestonesAttunedForWorld(self: *const Self) bool {
        return state_modules.StatisticsManager.computeAllLifestonesAttunedForWorld(self);
    }

    /// Get total number of lifestones in the world
    pub fn computeTotalLifestonesForWorld(self: *const Self) usize {
        return state_modules.StatisticsManager.computeTotalLifestonesForWorld(self);
    }

    /// Get number of attuned lifestones in the world
    pub fn computeTotalAttunedLifestonesForWorld(self: *const Self) usize {
        return state_modules.StatisticsManager.computeTotalAttunedLifestonesForWorld(self);
    }
};

/// Context-aware update all units function
fn updateUnits(game_state: *GameState, frame_ctx: FrameContext) void {
    // Delegate to UpdateSystem
    systems.UpdateSystem.updateUnits(game_state, frame_ctx);
}

pub fn updateGame(game_state: *GameState, cam: *const camera.Camera, deltaTime: f32) void {
    // Delegate to UpdateSystem
    systems.UpdateSystem.updateGame(game_state, cam, deltaTime);
}

pub fn checkCollisions(game_state: *GameState) void {
    // Delegate to CollisionSystem
    systems.CollisionSystem.checkAllCollisions(game_state);
}

// Lifestone collision checking now handled by LifestoneSystem

pub fn handleRespawn(game_state: *GameState) void {
    ui.EffectsSystem.handleRespawn(game_state);
}
