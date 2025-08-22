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

// Track current world path
var current_world_path: []const u8 = DEFAULT_WORLD;

// Clean up game data memory
pub fn deinit() void {
    if (game_data_arena) |*arena| {
        arena.deinit();
        game_data_arena = null;
    }
}

// Default world for development
// Change this line to quickly switch default worlds:
pub const DEFAULT_WORLD = "worlds/game_world.zon"; // or "worlds/test_world.zon"

// Available worlds
pub const AVAILABLE_WORLDS = [_][]const u8{
    "worlds/test_world.zon",
    "worlds/game_world.zon",
};

// World display names (for menu)
pub const WORLD_NAMES = [_][]const u8{
    "Test World (Dev)",
    "Game World",
};

// Get embedded world file based on path
fn getWorldFile(world_path: []const u8) []const u8 {
    // TODO: Add environment variable and command line support
    // For now, switch based on path string
    if (std.mem.eql(u8, world_path, "worlds/test_world.zon")) {
        return @embedFile("worlds/test_world.zon");
    } else if (std.mem.eql(u8, world_path, "worlds/game_world.zon")) {
        return @embedFile("worlds/game_world.zon");
    } else {
        // Default to test world
        return @embedFile("worlds/test_world.zon");
    }
}

// Get current world path
pub fn getCurrentWorld() []const u8 {
    return current_world_path;
}

// Get current world display name
pub fn getCurrentWorldDisplayName() []const u8 {
    return getWorldDisplayName(current_world_path);
}

// Load game data from world file
pub fn loadGameData(allocator: std.mem.Allocator, game: *hex_game_mod.HexGame) !void {
    return loadWorldData(allocator, game, DEFAULT_WORLD);
}

// Get world name for display
pub fn getWorldDisplayName(world_path: []const u8) []const u8 {
    for (AVAILABLE_WORLDS, 0..) |available_path, i| {
        if (std.mem.eql(u8, world_path, available_path)) {
            return WORLD_NAMES[i];
        }
    }
    return "Unknown World";
}

// Validate world path
pub fn isValidWorldPath(world_path: []const u8) bool {
    for (AVAILABLE_WORLDS) |available_path| {
        if (std.mem.eql(u8, world_path, available_path)) {
            return true;
        }
    }
    return false;
}

// Load specific world file
pub fn loadWorldData(allocator: std.mem.Allocator, game: *hex_game_mod.HexGame, world_path: []const u8) !void {
    // Update current world tracking
    current_world_path = world_path;

    // Load world data from ZON file
    const worldDataFile = getWorldFile(world_path);

    // Initialize arena if not already done
    if (game_data_arena == null) {
        game_data_arena = std.heap.ArenaAllocator.init(allocator);
    }
    const arena_allocator = game_data_arena.?.allocator();

    // Convert to null-terminated string for ZON parser
    const worldDataNullTerm = try arena_allocator.dupeZ(u8, worldDataFile);

    const game_data = std.zon.parse.fromSlice(GameData, arena_allocator, worldDataNullTerm, null, .{}) catch |err| {
        loggers.getGameLog().err("zon_parse_error", "Failed to parse world ZON file {s}: {}. Check structure match with GameData struct", .{ world_path, err });
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
        Vec2.position(pos.x, pos.y)
    else
        Vec2.screenCenter(constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT);

    // Load obstacles
    if (data.obstacles) |obstacles| {
        for (obstacles) |obstacle_data| {
            const is_deadly = obstacle_data.type == .deadly;

            // Create obstacle entity
            const obstacle_id = game.createObstacle(
                @intCast(zone_index),
                Vec2.position(obstacle_data.position.x, obstacle_data.position.y),
                Vec2.size(obstacle_data.size.x, obstacle_data.size.y),
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
            // Create ECS unit entity with disposition from ZON data
            const unit_id = game.createUnit(
                @intCast(zone_index),
                Vec2.position(unit_data.position.x, unit_data.position.y),
                unit_data.radius,
                unit_data.disposition, // Pass enum directly, defaults to .neutral
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
                Vec2.position(portal_data.position.x, portal_data.position.y),
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
                Vec2.position(lifestone_data.position.x, lifestone_data.position.y),
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
        disposition: hex_game_mod.Disposition = .neutral,
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
