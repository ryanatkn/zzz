const std = @import("std");
const hex_game_mod = @import("hex_game.zig");
const HexGame = hex_game_mod.HexGame;
const MAX_ZONES = hex_game_mod.MAX_ZONES;
const math = @import("../lib/math/mod.zig");
const Vec2 = math.Vec2;

// Load game data from ZON file
pub fn loadGameData(allocator: std.mem.Allocator, game: *HexGame) !void {
    // Read and parse ZON file
    const file = std.fs.cwd().openFile("src/hex/game_data.zon", .{}) catch |err| {
        std.log.err("Failed to open game_data.zon: {}", .{err});
        return err;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const contents = try allocator.alloc(u8, file_size);
    defer allocator.free(contents);
    _ = try file.read(contents);

    // Convert to null-terminated string for ZON parser
    const contents_null_term = try allocator.dupeZ(u8, contents);
    defer allocator.free(contents_null_term);

    // Parse ZON data
    const game_data = std.zon.parse.fromSlice(GameData, allocator, contents_null_term, null, .{}) catch |err| {
        std.log.err("Failed to parse ZON data: {}", .{err});
        return err;
    };

    // Load zones WITHOUT switching current zone
    for (game_data.zones, 0..) |zone_data, zone_index| {
        try loadZoneData(game, @intCast(zone_index), zone_data);
    }
    
    // Log zone contents for debugging
    for (0..MAX_ZONES) |i| {
        game.debugLogZoneEntities(@intCast(i));
    }
}

fn loadZoneData(game: *HexGame, zone_index: u8, data: ZoneData) !void {
    const zone = game.getZone(zone_index) orelse return;
    
    // Update zone metadata
    if (data.camera_scale) |scale| {
        zone.camera_scale = scale;
    }
    zone.background_color = .{
        .r = data.background_color.r,
        .g = data.background_color.g,
        .b = data.background_color.b,
        .a = 255,
    };
    
    // Load obstacles directly into the zone
    if (data.obstacles) |obstacles| {
        for (obstacles) |obstacle_data| {
            const is_deadly = std.mem.eql(u8, obstacle_data.type, "pit");
            _ = try game.createObstacle(
                zone_index,
                Vec2{ .x = obstacle_data.position.x, .y = obstacle_data.position.y },
                Vec2{ .x = obstacle_data.size.x, .y = obstacle_data.size.y },
                is_deadly,
            );
        }
    }
    
    // Load units directly into the zone
    if (data.units) |units| {
        for (units) |unit_data| {
            _ = try game.createUnit(
                zone_index,
                Vec2{ .x = unit_data.position.x, .y = unit_data.position.y },
                unit_data.radius,
            );
        }
    }
    
    // Load portals directly into the zone
    if (data.portals) |portals| {
        for (portals) |portal_data| {
            _ = try game.createPortal(
                zone_index,
                Vec2{ .x = portal_data.position.x, .y = portal_data.position.y },
                portal_data.radius,
                portal_data.destination,
            );
        }
    }
    
    // Load lifestones with explicit pre-attunement for first overworld lifestone
    if (data.lifestones) |lifestones| {
        for (lifestones, 0..) |lifestone_data, lifestone_index| {
            // First lifestone in overworld (zone 0) is pre-attuned
            const pre_attuned = (zone_index == 0 and lifestone_index == 0);
            
            const lifestone_id = try game.createLifestone(
                zone_index,
                Vec2{ .x = lifestone_data.position.x, .y = lifestone_data.position.y },
                lifestone_data.radius,
                pre_attuned,
            );
            
            if (pre_attuned) {
                std.log.info("Pre-attuned first lifestone in overworld: {any}", .{lifestone_id});
            }
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
    camera_scale: ?f32 = null,
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