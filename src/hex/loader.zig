const std = @import("std");
const hex_game_mod = @import("hex_game.zig");
const math = @import("../lib/math/mod.zig");
const colors = @import("../lib/core/colors.zig");
const constants = @import("constants.zig");
const loggers = @import("../lib/debug/loggers.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

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
pub fn loadGameData(allocator: std.mem.Allocator, game: *hex_game_mod.HexGame) !void {
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
        loggers.getGameLog().err("zon_parse_error", "Failed to parse ZON file: {}. Check structure match with GameData struct", .{err});
        return err;
    };

    // Set player start position
    // Create the player entity if it doesn't exist
    loggers.getGameLog().info("player_check", "Checking if player exists: {}", .{game.getPlayer() != null});
    if (game.getPlayer() == null) {
        loggers.getGameLog().info("player_create", "Creating player at position ({}, {})", .{ game_data.player_start.position.x, game_data.player_start.position.y });
        const player_id = try game.createPlayer(Vec2{
            .x = game_data.player_start.position.x,
            .y = game_data.player_start.position.y,
        }, game_data.player_start.radius);
        loggers.getGameLog().info("player_created", "Player created with ID: {}", .{player_id});
    } else {
        // Update existing player position
        game.setPlayerPos(Vec2{
            .x = game_data.player_start.position.x,
            .y = game_data.player_start.position.y,
        });
        // Note: Player radius update requires recreating entity, which isn't supported yet
    }
    // Store original spawn position for full reset
    game.player_start_pos = game.getPlayerPos();

    // Load each zone
    for (game_data.zones, 0..) |zone_data, i| {
        // Initialize zone with basic data (scale will be set in loadZone)
        // Zone is already initialized in HexGame.init(), just need to load data
        // Then load detailed data
        try loadZone(game.zone_manager.getZone(i), zone_data, game, i);
    }

    // Load portals from current zone into zone travel manager
    game.loadPortalsIntoTravelManager() catch |err| {
        loggers.getGameLog().err("portal_load_failed", "Failed to load portals after game data loading: {}", .{err});
    };
}

// Load a single zone from ZON data
fn loadZone(zone: *hex_game_mod.HexGame.ZoneData, data: ZoneData, game: *hex_game_mod.HexGame, zone_index: usize) !void {
    // Zone type is already set in HexWorld.init(), skip name setting

    zone.background_color = Color{
        .r = data.background_color.r,
        .g = data.background_color.g,
        .b = data.background_color.b,
        .a = 255,
    };

    // Set camera mode for this zone
    zone.camera_mode = data.camera_mode;

    // Set camera scale (default to 1.0 if not specified)
    zone.camera_scale = data.camera_scale orelse 1.0;

    // Set spawn position (default to screen center if not specified)
    zone.spawn_pos = if (data.spawn_pos) |pos|
        Vec2{ .x = pos.x, .y = pos.y }
    else
        Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y };

    // Load obstacles
    if (data.obstacles) |obstacles| {
        for (obstacles) |obstacle_data| {
            const is_deadly = obstacle_data.type == .deadly;

            // Create obstacle entity
            const obstacle_id = game.createObstacle(
                @intCast(zone_index),
                Vec2{ .x = obstacle_data.position.x, .y = obstacle_data.position.y },
                Vec2{ .x = obstacle_data.size.x, .y = obstacle_data.size.y },
                is_deadly,
            ) catch |err| {
                loggers.getGameLog().err("obstacle_create_fail", "Failed to create obstacle entity: {}", .{err});
                continue;
            };

            _ = obstacle_id; // Obstacle created successfully
        }
    }

    // Load units as ECS entities
    if (data.units) |units| {
        for (units) |unit_data| {
            // Create ECS unit entity with behavior from ZON data
            const unit_id = game.createUnit(
                @intCast(zone_index),
                Vec2{ .x = unit_data.position.x, .y = unit_data.position.y },
                unit_data.radius,
                unit_data.behavior, // Pass enum directly, defaults to .idle
            ) catch |err| {
                loggers.getGameLog().err("unit_create_fail", "Failed to create unit entity: {}", .{err});
                continue;
            };

            _ = unit_id; // Unit created successfully
        }
    }

    // Load portals as ECS entities
    if (data.portals) |portals| {
        for (portals) |portal_data| {
            // Create ECS portal entity
            const portal_id = game.createPortal(
                zone_index,
                Vec2{ .x = portal_data.position.x, .y = portal_data.position.y },
                portal_data.radius,
                portal_data.destination,
            ) catch |err| {
                loggers.getGameLog().err("portal_create_fail", "Failed to create portal entity: {}", .{err});
                continue;
            };

            _ = portal_id; // Entity automatically tracked in zone.portal_entities
        }
    }

    // Load lifestones as ECS entities
    if (data.lifestones) |lifestones| {
        for (lifestones, 0..) |lifestone_data, lifestone_index| {
            // First lifestone in overgame (zone 0) is pre-attuned
            const pre_attuned = (lifestone_index == 0 and std.mem.eql(u8, data.name, "Overgame"));

            // Create ECS lifestone entity
            const lifestone_id = game.createLifestone(
                @intCast(zone_index),
                Vec2{ .x = lifestone_data.position.x, .y = lifestone_data.position.y },
                lifestone_data.radius,
                pre_attuned,
            ) catch |err| {
                loggers.getGameLog().err("lifestone_create_fail", "Failed to create lifestone entity: {}", .{err});
                continue;
            };

            _ = lifestone_id; // Entity automatically tracked in zone.lifestone_entities
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
    camera_mode: constants.CameraMode,
    camera_scale: ?f32 = null, // Optional camera scale with default value
    spawn_pos: ?struct { x: f32, y: f32 } = null, // Optional spawn position, defaults to screen center
    obstacles: ?[]const struct {
        position: struct { x: f32, y: f32 },
        size: struct { x: f32, y: f32 },
        type: constants.ObstacleType,
    },
    units: ?[]const struct {
        position: struct { x: f32, y: f32 },
        radius: f32,
        behavior: hex_game_mod.BehaviorProfile = .idle,
    },
    portals: ?[]const struct {
        position: struct { x: f32, y: f32 },
        radius: f32,
        destination: usize,
        shape: constants.PortalShape,
    },
    lifestones: ?[]const struct {
        position: struct { x: f32, y: f32 },
        radius: f32,
    },
};
