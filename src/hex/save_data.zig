const std = @import("std");
const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const world_state_mod = @import("world_state.zig");
const game_persistence = @import("../lib/game/persistence/mod.zig");

const Vec2 = math.Vec2;
const EntityId = world_state_mod.EntityId;
const HexGame = world_state_mod.HexGame;

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
                .lifestone_entities = std.BoundedArray(EntitySaveData, 32).init(0) catch unreachable, // init(0) cannot fail
                .unit_entities = std.BoundedArray(EntitySaveData, 256).init(0) catch unreachable, // init(0) cannot fail
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
    pub fn fromGameState(world: *const HexGame, stats: GameStatistics) !HexSaveData {
        var save = HexSaveData{
            .player_zone = world.getCurrentZoneIndex(),
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

        // Save entity state for each zone using ECS archetype storages
        var total_lifestones: usize = 0;
        var total_attuned: usize = 0;

        for (0..7) |zone_idx| {
            const zone_storage = world.getZoneStorageByIndex(@intCast(zone_idx));

            // Save lifestone entities from the zone's ECS world
            var lifestone_iter = zone_storage.lifestones.entityIterator();
            while (lifestone_iter.next()) |entity_id| {
                if (zone_storage.lifestones.getComponent(entity_id, .transform)) |transform| {
                    const alive = if (zone_storage.lifestones.getComponent(entity_id, .health)) |health| health.alive else true;
                    const attuned = if (zone_storage.lifestones.getComponent(entity_id, .interactable)) |interactable| interactable.attuned else false;

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

            // Save unit entities from the zone's ECS world
            var units_killed_in_zone: usize = 0;
            var total_units_in_zone: usize = 0;
            var unit_iter = zone_storage.units.entityIterator();
            while (unit_iter.next()) |entity_id| {
                if (zone_storage.units.getComponent(entity_id, .transform)) |transform| {
                    const alive = if (zone_storage.units.getComponent(entity_id, .health)) |health| health.alive else true;

                    try save.zones[zone_idx].unit_entities.append(.{
                        .entity_id = entity_id,
                        .pos = transform.pos,
                        .alive = alive,
                        .attuned = false,
                    });

                    total_units_in_zone += 1;
                    if (!alive) {
                        units_killed_in_zone += 1;
                    }
                }
            }

            // Update zone clear status based on actual ECS data
            save.cached.zones_fully_cleared[zone_idx] = (total_units_in_zone > 0) and (units_killed_in_zone == total_units_in_zone);
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
    pub fn applyToGameState(self: *const HexSaveData, world: *HexGame, stats: *GameStatistics) void {
        // Restore player state
        world.getZonedWorld().setCurrentZone(@intCast(self.player_zone));
        world.setPlayerPos(self.player_pos);
        world.setPlayerAlive(self.player_alive);

        // Restore entity state for each zone using zone-specific ECS access
        for (self.zones, 0..) |zone_data, zone_idx| {
            const zone_storage = world.getZoneStorageByIndex(@intCast(zone_idx));

            // Restore lifestone entities
            for (zone_data.lifestone_entities.slice()) |entity_data| {
                if (zone_storage.lifestones.getComponentMut(entity_data.entity_id, .interactable)) |interactable| {
                    interactable.attuned = entity_data.attuned;
                }
                if (zone_storage.lifestones.getComponentMut(entity_data.entity_id, .health)) |health| {
                    health.alive = entity_data.alive;
                }
                if (zone_storage.lifestones.getComponentMut(entity_data.entity_id, .transform)) |transform| {
                    transform.pos = entity_data.pos;
                }
                // Update visual color based on attunement
                if (zone_storage.lifestones.getComponentMut(entity_data.entity_id, .visual)) |visual| {
                    visual.color = if (entity_data.attuned)
                        constants.COLOR_LIFESTONE_ATTUNED
                    else
                        constants.COLOR_LIFESTONE_UNATTUNED;
                }
            }

            // Restore unit entities
            for (zone_data.unit_entities.slice()) |entity_data| {
                if (zone_storage.units.getComponentMut(entity_data.entity_id, .health)) |health| {
                    health.alive = entity_data.alive;
                }
                if (zone_storage.units.getComponentMut(entity_data.entity_id, .transform)) |transform| {
                    transform.pos = entity_data.pos;
                }
                // Update visual color based on alive status
                if (zone_storage.units.getComponentMut(entity_data.entity_id, .visual)) |visual| {
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
/// Uses generic StatisticsInterface for common operations
pub const GameStatistics = struct {
    total_deaths: usize = 0,
    total_bullets_fired: usize = 0,
    total_spells_cast: usize = 0,
    total_portals_used: usize = 0,
    play_time_ms: u64 = 0,
    lifestones_attuned: usize = 0,
    all_lifestones_attuned: bool = false,

    // Use generic statistics interface
    pub usingnamespace game_persistence.statistics.StatisticsInterface;

    // Hex-specific convenience methods
    pub fn incrementDeath(self: *GameStatistics) void {
        self.increment("total_deaths");
    }

    pub fn incrementBullet(self: *GameStatistics) void {
        self.increment("total_bullets_fired");
    }

    pub fn incrementSpell(self: *GameStatistics) void {
        self.increment("total_spells_cast");
    }

    pub fn incrementPortal(self: *GameStatistics) void {
        self.increment("total_portals_used");
    }

    pub fn incrementLifestone(self: *GameStatistics) void {
        self.increment("lifestones_attuned");
    }
};
