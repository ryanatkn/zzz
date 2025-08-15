const std = @import("std");

const c = @import("../lib/platform/sdl.zig");

const types = @import("../lib/core/types.zig");
const entities = @import("entities.zig");
const hex_world = @import("hex_world.zig");
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const input = @import("../lib/platform/input.zig");
const player_controller = @import("player.zig");
const combat = @import("combat.zig");
const portals = @import("portals.zig");
const camera = @import("../lib/rendering/camera.zig");
const viewport = @import("../lib/core/viewport.zig");
const effects = @import("effects.zig");
const hud = @import("../hud/hud.zig");
const reactive_hud = @import("../hud/reactive_hud.zig");
const game_renderer = @import("game_renderer.zig");
const constants = @import("constants.zig");
const spells = @import("spells.zig");
const game_systems = @import("../lib/game/game.zig");
const hex_events = @import("events.zig");
const save_data = @import("save_data.zig");
const ecs = @import("../lib/game/ecs.zig");

const Vec2 = types.Vec2;
const HexWorld = hex_world.HexWorld;
const InputState = input.InputState;

pub const GameState = struct {
    world: HexWorld,
    input_state: InputState,
    game_paused: bool,
    quit_requested: bool,

    // Visual effects system
    effect_system: effects.EffectSystem,

    // Spell system
    spell_system: spells.SpellSystem,

    // Allocator for ECS world cleanup
    allocator: std.mem.Allocator,

    // HUD system for system menu (reactive)
    hud_system: ?reactive_hud.ReactiveHud,

    // Iris wipe effect for resurrection
    iris_wipe_active: bool,
    iris_wipe_start_time: u64,
    
    // State management system
    state_manager: ?*game_systems.StateManager(save_data.HexSaveData, hex_events.HexEvents),
    game_stats: save_data.GameStatistics,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .world = try HexWorld.init(allocator),
            .input_state = InputState.init(),
            .game_paused = false,
            .quit_requested = false,
            .effect_system = effects.EffectSystem.init(),
            .spell_system = spells.SpellSystem.init(),
            .allocator = allocator,
            .hud_system = null,
            .iris_wipe_active = false,
            .iris_wipe_start_time = 0,
            .state_manager = null,
            .game_stats = .{},
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.world.deinit();
    }

    pub fn initStateManager(self: *Self, allocator: std.mem.Allocator) !void {
        const manager = try allocator.create(game_systems.StateManager(save_data.HexSaveData, hex_events.HexEvents));
        manager.* = try game_systems.StateManager(save_data.HexSaveData, hex_events.HexEvents).init(
            allocator,
            "dealt",
            "hex",
        );
        self.state_manager = manager;
        
        // Register compute callbacks for expensive operations
        try self.registerComputeCallbacks();
        
        // Set up event listeners
        try self.setupEventListeners();
    }
    
    pub fn deinitStateManager(self: *Self, allocator: std.mem.Allocator) void {
        if (self.state_manager) |manager| {
            manager.deinit();
            allocator.destroy(manager);
            self.state_manager = null;
        }
    }
    
    fn registerComputeCallbacks(self: *Self) !void {
        if (self.state_manager) |manager| {
            // Register callback to compute all_lifestones_attuned
            try manager.registerCompute("all_lifestones_attuned", computeAllLifestonesAttuned);
            try manager.registerCompute("total_lifestones", computeTotalLifestones);
            try manager.registerCompute("total_lifestones_attuned", computeTotalLifestonesAttuned);
        }
    }
    
    fn setupEventListeners(self: *Self) !void {
        if (self.state_manager) |manager| {
            // Listen for lifestone attunement to invalidate cache
            try manager.on(.custom, onCustomEvent, self);
        }
    }
    
    fn onCustomEvent(event: hex_events.HexEvents, ctx: ?*anyopaque) void {
        if (ctx) |context| {
            const self = @as(*Self, @ptrCast(@alignCast(context)));
            if (self.state_manager) |manager| {
                switch (event) {
                    .custom => |custom| {
                        switch (custom) {
                            .lifestone_attuned => {
                                // Invalidate cached values
                                manager.invalidate("all_lifestones_attuned");
                                manager.invalidate("total_lifestones_attuned");
                                
                                // Check if this was the last one
                                if (manager.queryBool("all_lifestones_attuned") catch false) {
                                    // Emit all lifestones attuned event
                                    const total = manager.queryInt("total_lifestones") catch 0;
                                    manager.emit(hex_events.allLifestonesAttuned(@intCast(total)));
                                }
                            },
                            else => {},
                        }
                    },
                    else => {},
                }
            }
        }
    }
    
    fn computeAllLifestonesAttuned(manager: *game_systems.StateManager(save_data.HexSaveData, hex_events.HexEvents)) !void {
        // TEMPORARY: Just return false for now since we need access to world state
        // In a complete implementation, we'd store a reference to the GameState in the manager
        try manager.cache.setBool("all_lifestones_attuned", false);
    }
    
    fn computeTotalLifestones(manager: *game_systems.StateManager(save_data.HexSaveData, hex_events.HexEvents)) !void {
        // TEMPORARY: Just return a reasonable number for now
        try manager.cache.setInt("total_lifestones", 91); // Total from game_data.zon
    }
    
    fn computeTotalLifestonesAttuned(manager: *game_systems.StateManager(save_data.HexSaveData, hex_events.HexEvents)) !void {
        // TEMPORARY: Just return 0 for now
        try manager.cache.setInt("total_lifestones_attuned", 0);
    }

    pub fn initHud(self: *Self, allocator: std.mem.Allocator, renderer_ptr: *game_renderer.GameRenderer) !void {
        self.hud_system = try reactive_hud.ReactiveHud.init(allocator, renderer_ptr);
    }

    pub fn deinitHud(self: *Self) void {
        if (self.hud_system) |*h| {
            h.deinit();
            self.hud_system = null;
        }
    }

    pub fn travelToZone(self: *Self, destination_zone: usize) void {
        if (destination_zone < self.world.zones.len) {
            self.world.current_zone = destination_zone;
            self.world.zones[destination_zone].resetUnits();
            // Clear bullets on zone travel - bullets are now ECS entities
            // TODO: Destroy bullet entities when traveling to new zone
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
        self.world.resetCurrentZone() catch |err| {
            std.log.err("Failed to reset zone: {}", .{err});
        };
        std.debug.print("Zone units reset to original state\n", .{});
    }

    pub fn resetGame(self: *Self) void {
        // Reset player to starting position and state
        self.world.resetPlayerToStart();

        // Reset to starting zone
        if (self.world.current_zone != 0) {
            self.travelToZone(0);
        }

        // Reset all zones
        self.world.resetAllZones() catch |err| {
            std.log.err("Failed to reset all zones: {}", .{err});
        };

        // Clear effects for clean slate
        self.effect_system.clear();
        self.effect_system.refreshAmbientEffects(&self.world);

        std.debug.print("Full game reset\n", .{});
    }
    
    /// Check if all lifestones across all zones are attuned using ECS queries
    pub fn hasAttunedAllLifestones(self: *const Self) bool {
        // Use cached value if state manager is available
        if (self.state_manager) |manager| {
            // For now, fall back to direct computation since cache doesn't have world access
            _ = manager;
        }
        
        // Direct computation using ECS queries
        var total_lifestones: usize = 0;
        var total_attuned: usize = 0;
        
        const ecs_world = self.world.getECSWorld();
        var terrain_iter = @constCast(&ecs_world.terrains).iterator();
        
        while (terrain_iter.next()) |entry| {
            const entity_id = entry.key_ptr.*;
            const terrain = entry.value_ptr.*;
            
            // Only count lifestones (altar terrain with interactable component)
            if (terrain.terrain_type != .altar) continue;
            if (!ecs_world.interactables.has(entity_id)) continue;
            
            total_lifestones += 1;
            
            // Check if lifestone is attuned (using transformable state as attuned indicator)
            if (ecs_world.interactables.getConst(entity_id)) |interactable| {
                if (interactable.interaction_type == .transformable) {
                    total_attuned += 1;
                }
            }
        }
        
        return total_lifestones > 0 and total_attuned == total_lifestones;
    }
    
    /// Properly compute all lifestones attuned for the cache using ECS queries
    pub fn computeAllLifestonesAttunedForWorld(self: *const Self) bool {
        var total_lifestones: usize = 0;
        var total_attuned: usize = 0;
        
        const ecs_world = self.world.getECSWorld();
        var terrain_iter = @constCast(&ecs_world.terrains).iterator();
        
        while (terrain_iter.next()) |entry| {
            const entity_id = entry.key_ptr.*;
            const terrain = entry.value_ptr.*;
            
            // Only count lifestones (altar terrain with interactable component)
            if (terrain.terrain_type != .altar) continue;
            if (!ecs_world.interactables.has(entity_id)) continue;
            
            total_lifestones += 1;
            
            // Check if lifestone is attuned (using transformable state as attuned indicator)
            if (ecs_world.interactables.getConst(entity_id)) |interactable| {
                if (interactable.interaction_type == .transformable) {
                    total_attuned += 1;
                }
            }
        }
        
        return total_lifestones > 0 and total_attuned == total_lifestones;
    }
};

/// Update all units using ECS
fn updateUnitsECS(game_state: *GameState, deltaTime: f32) void {
    const world = &game_state.world;
    
    // Note: Obstacle collision now uses ECS queries
    
    // Query all units from ECS system
    var unit_iter = world.world.units.iterator();
    while (unit_iter.next()) |entry| {
        const unit_id = entry.key_ptr.*;
        
        // Skip if entity is not alive
        if (!world.world.isAlive(unit_id)) continue;
        
        // Get components
        if (world.world.transforms.get(unit_id)) |transform| {
            if (world.world.healths.get(unit_id)) |health| {
                if (!health.alive) continue;
                
                if (world.world.units.get(unit_id)) |unit_comp| {
                    const old_pos = transform.pos;
                    
                    if (world.world.visuals.get(unit_id)) |visual| {
                        const aggro_mod = spells.SpellSystem.getAggroMultiplierForUnitECS(unit_id, &world.world);
                        
                        // Update unit AI behavior using ECS components
                        behaviors.updateUnitWithAggroModECS(
                            unit_comp,
                            transform,
                            visual,
                            world.getPlayerPos(),
                            world.getPlayerAlive(),
                            deltaTime,
                            aggro_mod
                        );
                    }
                    
                    // Check collision with obstacles using ECS queries
                    if (physics.checkUnitObstacleCollisionECS(@constCast(world), unit_id, transform, health, old_pos)) {
                        // Collision was handled by the function
                        break;
                    }
                }
            }
        }
    }
}

pub fn updateGame(game_state: *GameState, cam: *const camera.Camera, deltaTime: f32) void {
    // Update HUD system if open
    if (game_state.hud_system) |*h| {
        h.update(deltaTime);
        // Don't update game when HUD is open
        if (h.is_open()) return;
    }

    if (game_state.game_paused) return;

    const world = &game_state.world;
    const input_state = &game_state.input_state;

    if (world.getPlayerAlive()) {
        // Update player using ECS-compatible controller
        player_controller.updatePlayerECS(world, input_state, cam, deltaTime);

        // Handle continuous shooting on left-click hold (rhythm mode)
        // Only shoot if Ctrl is NOT held (Ctrl enables mouse movement instead)
        if (!input_state.isCtrlHeld() and input_state.isLeftMouseHeld() and world.canFireBullet()) {
            // Direct camera coordinate conversion - no viewport indirection
            const screen_mouse_pos = input_state.getMousePos();
            const world_mouse_pos = cam.screenToWorldSafe(screen_mouse_pos);
            _ = combat.fireBulletAtMouse(world, world_mouse_pos, &world.bullet_pool);
        }
    }

    // Update bullet entities using ECS
    world.updateProjectiles(deltaTime) catch |err| {
        std.log.err("Failed to update projectiles: {}", .{err});
    };

    // Update units using ECS queries
    updateUnitsECS(game_state, deltaTime);

    checkCollisions(game_state);

    // Update visual effects
    game_state.effect_system.update();

    // Update spell system
    game_state.spell_system.update(deltaTime);

    // Update bullet pool (manages firing rate limiting)
    world.updateBulletPool(deltaTime);
}

pub fn checkCollisions(game_state: *GameState) void {
    const world = &game_state.world;
    
    // Player entity is accessed via helper methods instead of direct field access

    // TODO: Update physics.processBulletCollisions to work with ECS
    // physics.processBulletCollisions(world);

    if (!world.getPlayerAlive()) return;

    if (portals.checkPortalCollisions(game_state)) {
        return;
    }

    // Get player position and radius for collision checks
    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();

    // Check player-unit collisions (player dies on contact) - ECS version
    if (physics.checkPlayerUnitCollisionECS(world)) {
        // Player dies on unit contact
        world.setPlayerAlive(false);
        world.setPlayerColor(constants.COLOR_DEAD);
        return;
    }

    // Check lifestone collisions using ECS queries
    checkLifestoneCollisionsECS(game_state, player_pos, player_radius);

    // Check collision with deadly obstacles
    if (physics.collidesWithDeadlyObstacle(player_pos, player_radius, world)) {
        // Player dies on hazard contact
        world.setPlayerAlive(false);
        world.setPlayerColor(constants.COLOR_DEAD);
    }
}

pub fn handleFireBullet(game_state: *GameState, cam: *const camera.Camera) void {
    if (game_state.world.getPlayerAlive() and !game_state.game_paused and game_state.world.canFireBullet()) {
        const screen_mouse_pos = game_state.input_state.getMousePos();
        const world_mouse_pos = cam.screenToWorldSafe(screen_mouse_pos);
        _ = combat.fireBulletAtMouse(&game_state.world, world_mouse_pos, &game_state.world.bullet_pool);
    }
}

// Check lifestone collisions using ECS queries
fn checkLifestoneCollisionsECS(game_state: *GameState, player_pos: types.Vec2, player_radius: f32) void {
    const world = &game_state.world;
    const ecs_world = world.getECSWorldMut();
    var terrain_iter = @constCast(&ecs_world.terrains).iterator();
    
    while (terrain_iter.next()) |entry| {
        const entity_id = entry.key_ptr.*;
        const terrain = entry.value_ptr.*;
        
        // Only check lifestones (altar terrain with interactable component)
        if (terrain.terrain_type != .altar) continue;
        if (!ecs_world.interactables.has(entity_id)) continue;
        
        // Get components
        if (ecs_world.transforms.getConst(entity_id)) |transform| {
            if (ecs_world.interactables.get(entity_id)) |interactable| {
                // Check if lifestone is not yet attuned (using transformable state as attuned indicator)
                const is_attuned = (interactable.interaction_type == .transformable);
                if (is_attuned) continue; // Skip already attuned lifestones
                
                // Check collision
                if (physics.checkCircleCollision(player_pos, player_radius, transform.pos, transform.radius)) {
                    // Attune the lifestone by changing interaction type to transformable
                    interactable.interaction_type = .transformable;
                    
                    // Update visual color for attunement
                    if (ecs_world.visuals.get(entity_id)) |visual| {
                        visual.color = constants.COLOR_LIFESTONE_ATTUNED;
                    }
                    
                    std.debug.print("Lifestone attuned!\n", .{});
                    
                    // Emit lifestone attuned event
                    if (game_state.state_manager) |manager| {
                        manager.emit(hex_events.lifestoneAttuned(
                            game_state.world.current_zone,
                            0, // TODO: Get actual index from entity system
                            transform.pos,
                        ));
                    }
                    
                    // Add inner effect for newly attuned lifestone
                    game_state.effect_system.addLifestoneInnerEffectOnly(transform.pos, transform.radius);
                    
                    return; // Only attune one lifestone per frame
                }
            }
        }
    }
}

pub fn handleRespawn(game_state: *GameState) void {
    // Start iris wipe effect
    game_state.iris_wipe_active = true;
    game_state.iris_wipe_start_time = c.sdl.SDL_GetPerformanceCounter();

    combat.respawnPlayer(game_state);
}
