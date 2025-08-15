const std = @import("std");
const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const hex_world = @import("hex_world.zig");
const ecs = @import("../lib/game/ecs.zig");

const Vec2 = math.Vec2;
const EntityId = ecs.EntityId;
const HexWorld = hex_world.HexWorld;

/// ECS-based save data structure
pub const HexSaveData = struct {
    // Player state
    player_zone: usize,
    player_pos: Vec2,
    player_alive: bool,

    // Entity state per zone - store entity IDs and their key properties
    zones: [7]ZoneSaveData,

    // Statistics
    total_deaths: usize,
    total_bullets_fired: usize,
    total_spells_cast: usize,
    total_portals_used: usize,
    play_time_ms: u64,

    // Cached computed values for performance
    cached: CachedData,

    pub const ZoneSaveData = struct {
        lifestone_entities: std.BoundedArray(EntitySaveData, 32),
        unit_entities: std.BoundedArray(EntitySaveData, 256),

        pub fn init() ZoneSaveData {
            return .{
                .lifestone_entities = std.BoundedArray(EntitySaveData, 32).init(0) catch |err| {
                    std.log.err("Failed to initialize lifestone entities array: {}", .{err});
                    @panic("ZoneSaveData lifestone initialization failed");
                },
                .unit_entities = std.BoundedArray(EntitySaveData, 256).init(0) catch |err| {
                    std.log.err("Failed to initialize unit entities array: {}", .{err});
                    @panic("ZoneSaveData unit initialization failed");
                },
            };
        }
    };

    pub const EntitySaveData = struct {
        entity_id: EntityId,
        pos: Vec2,
        alive: bool,
        attuned: bool, // For lifestones
    };

    pub const CachedData = struct {
        all_lifestones_attuned: bool = false,
        total_lifestones_attuned: usize = 0,
        total_lifestones: usize = 0,
        zones_fully_cleared: [7]bool = [_]bool{false} ** 7,
        zones_fully_explored: [7]bool = [_]bool{false} ** 7,
        completion_percentage: f32 = 0.0,
    };

    /// Create save data from current ECS game state
    pub fn fromGameState(world: *const HexWorld, stats: GameStatistics) !HexSaveData {
        var save = HexSaveData{
            .player_zone = world.current_zone,
            .player_pos = world.getPlayerPosConst(),
            .player_alive = world.getPlayerAliveConst(),
            .zones = undefined,
            .total_deaths = stats.total_deaths,
            .total_bullets_fired = stats.total_bullets_fired,
            .total_spells_cast = stats.total_spells_cast,
            .total_portals_used = stats.total_portals_used,
            .play_time_ms = stats.play_time_ms,
            .cached = .{},
        };

        // Initialize zone data
        for (&save.zones) |*zone_data| {
            zone_data.* = ZoneSaveData.init();
        }

        // Save entity state for each zone
        var total_lifestones: usize = 0;
        var total_attuned: usize = 0;

        for (world.zones, 0..) |zone, zone_idx| {
            // Save lifestone entities
            for (zone.lifestone_entities.items) |entity_id| {
                if (world.world.transforms.getConst(entity_id)) |transform| {
                    const alive = if (world.world.healths.getConst(entity_id)) |health| health.alive else true;
                    const attuned = if (world.world.interactables.getConst(entity_id)) |interactable| interactable.attuned else false;

                    try save.zones[zone_idx].lifestone_entities.append(.{
                        .entity_id = entity_id,
                        .pos = transform.pos,
                        .alive = alive,
                        .attuned = attuned,
                    });

                    total_lifestones += 1;
                    if (attuned) {
                        total_attuned += 1;
                    }
                }
            }

            // Save unit entities
            var units_killed_in_zone: usize = 0;
            for (zone.unit_entities.items) |entity_id| {
                if (world.world.transforms.getConst(entity_id)) |transform| {
                    const alive = if (world.world.healths.getConst(entity_id)) |health| health.alive else true;

                    try save.zones[zone_idx].unit_entities.append(.{
                        .entity_id = entity_id,
                        .pos = transform.pos,
                        .alive = alive,
                        .attuned = false,
                    });

                    if (!alive) {
                        units_killed_in_zone += 1;
                    }
                }
            }

            // Update zone clear status
            save.cached.zones_fully_cleared[zone_idx] = units_killed_in_zone == zone.unit_entities.items.len;
            save.cached.zones_fully_explored[zone_idx] = save.zones[zone_idx].lifestone_entities.len > 0 and
                blk: {
                    for (save.zones[zone_idx].lifestone_entities.slice()) |entity_data| {
                        if (!entity_data.attuned) break :blk false;
                    }
                    break :blk true;
                };
        }

        // Update cached values
        save.cached.total_lifestones = total_lifestones;
        save.cached.total_lifestones_attuned = total_attuned;
        save.cached.all_lifestones_attuned = (total_attuned == total_lifestones) and (total_lifestones > 0);
        save.cached.completion_percentage = if (total_lifestones > 0)
            @as(f32, @floatFromInt(total_attuned)) / @as(f32, @floatFromInt(total_lifestones)) * 100.0
        else
            0.0;

        return save;
    }

    /// Apply save data to ECS game state
    pub fn applyToGameState(self: *const HexSaveData, world: *HexWorld, stats: *GameStatistics) void {
        // Restore player state
        world.current_zone = self.player_zone;
        world.setPlayerPos(self.player_pos);
        world.setPlayerAlive(self.player_alive);

        // Restore entity state for each zone
        for (self.zones) |zone_data| {
            // Restore lifestone entities
            for (zone_data.lifestone_entities.slice()) |entity_data| {
                if (world.world.interactables.get(entity_data.entity_id)) |interactable| {
                    interactable.attuned = entity_data.attuned;
                }
                if (world.world.healths.get(entity_data.entity_id)) |health| {
                    health.alive = entity_data.alive;
                }
                if (world.world.transforms.get(entity_data.entity_id)) |transform| {
                    transform.pos = entity_data.pos;
                }
                // Update visual color based on attunement
                if (world.world.visuals.get(entity_data.entity_id)) |visual| {
                    visual.color = if (entity_data.attuned)
                        constants.COLOR_LIFESTONE_ATTUNED
                    else
                        constants.COLOR_LIFESTONE_UNATTUNED;
                }
            }

            // Restore unit entities
            for (zone_data.unit_entities.slice()) |entity_data| {
                if (world.world.healths.get(entity_data.entity_id)) |health| {
                    health.alive = entity_data.alive;
                }
                if (world.world.transforms.get(entity_data.entity_id)) |transform| {
                    transform.pos = entity_data.pos;
                }
                // Update visual color based on alive status
                if (world.world.visuals.get(entity_data.entity_id)) |visual| {
                    visual.color = if (entity_data.alive)
                        constants.COLOR_UNIT_ALIVE
                    else
                        constants.COLOR_DEAD;
                }
            }
        }

        // Restore statistics
        stats.total_deaths = self.total_deaths;
        stats.total_bullets_fired = self.total_bullets_fired;
        stats.total_spells_cast = self.total_spells_cast;
        stats.total_portals_used = self.total_portals_used;
        stats.play_time_ms = self.play_time_ms;
    }
};

/// Game statistics that should persist
pub const GameStatistics = struct {
    total_deaths: usize = 0,
    total_bullets_fired: usize = 0,
    total_spells_cast: usize = 0,
    total_portals_used: usize = 0,
    play_time_ms: u64 = 0,
};
