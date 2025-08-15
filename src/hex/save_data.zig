const std = @import("std");
const types = @import("../lib/core/types.zig");
const entities = @import("entities.zig");
const constants = @import("constants.zig");
const game_systems = @import("../lib/game/game.zig");

const Vec2 = types.Vec2;

/// Hex-specific save data structure
pub const HexSaveData = struct {
    // Player state
    player_zone: usize,
    player_pos: Vec2,
    player_alive: bool,
    
    // World state - track lifestone attunement per zone
    lifestones: [7]ZoneLifestones,
    
    // Combat state
    units_killed: [7]ZoneUnits,
    
    // Statistics
    total_deaths: usize,
    total_bullets_fired: usize,
    total_spells_cast: usize,
    total_portals_used: usize,
    play_time_ms: u64,
    
    // Cached computed values for performance
    cached: CachedData,
    
    pub const ZoneLifestones = struct {
        attuned: [entities.MAX_LIFESTONES]bool = [_]bool{false} ** entities.MAX_LIFESTONES,
        count: usize = 0,
    };
    
    pub const ZoneUnits = struct {
        killed: [entities.MAX_UNITS]bool = [_]bool{false} ** entities.MAX_UNITS,
        count: usize = 0,
    };
    
    pub const CachedData = struct {
        all_lifestones_attuned: bool = false,
        total_lifestones_attuned: usize = 0,
        total_lifestones: usize = 0,
        zones_fully_cleared: [7]bool = [_]bool{false} ** 7,
        zones_fully_explored: [7]bool = [_]bool{false} ** 7,
        completion_percentage: f32 = 0.0,
    };
    
    /// Create save data from current game state
    pub fn fromGameState(world: *const entities.World, stats: GameStatistics) HexSaveData {
        var save = HexSaveData{
            .player_zone = world.current_zone,
            .player_pos = world.player.pos,
            .player_alive = world.player.alive,
            .lifestones = undefined,
            .units_killed = undefined,
            .total_deaths = stats.total_deaths,
            .total_bullets_fired = stats.total_bullets_fired,
            .total_spells_cast = stats.total_spells_cast,
            .total_portals_used = stats.total_portals_used,
            .play_time_ms = stats.play_time_ms,
            .cached = .{},
        };
        
        // Save lifestone state for each zone
        var total_lifestones: usize = 0;
        var total_attuned: usize = 0;
        
        for (world.zones, 0..) |*zone, zone_idx| {
            save.lifestones[zone_idx].count = zone.lifestone_count;
            total_lifestones += zone.lifestone_count;
            
            for (0..zone.lifestone_count) |i| {
                save.lifestones[zone_idx].attuned[i] = zone.lifestones[i].attuned;
                if (zone.lifestones[i].attuned) {
                    total_attuned += 1;
                }
            }
            
            // Save unit state
            save.units_killed[zone_idx].count = zone.unit_count;
            var units_killed_in_zone: usize = 0;
            
            for (0..zone.unit_count) |i| {
                save.units_killed[zone_idx].killed[i] = !zone.units[i].alive;
                if (!zone.units[i].alive) {
                    units_killed_in_zone += 1;
                }
            }
            
            // Update zone clear status
            save.cached.zones_fully_cleared[zone_idx] = units_killed_in_zone == zone.unit_count;
            save.cached.zones_fully_explored[zone_idx] = save.lifestones[zone_idx].count > 0 and
                std.mem.allEqual(bool, save.lifestones[zone_idx].attuned[0..save.lifestones[zone_idx].count], true);
        }
        
        // Update cached values
        save.cached.total_lifestones = total_lifestones;
        save.cached.total_lifestones_attuned = total_attuned;
        save.cached.all_lifestones_attuned = (total_attuned == total_lifestones) and (total_lifestones > 0);
        save.cached.completion_percentage = if (total_lifestones > 0) 
            @as(f32, @floatFromInt(total_attuned)) / @as(f32, @floatFromInt(total_lifestones)) * 100.0
        else 0.0;
        
        return save;
    }
    
    /// Apply save data to game state
    pub fn applyToGameState(self: *const HexSaveData, world: *entities.World, stats: *GameStatistics) void {
        // Restore player state
        world.current_zone = self.player_zone;
        world.player.pos = self.player_pos;
        world.player.alive = self.player_alive;
        
        // Restore lifestone state for each zone
        for (world.zones, 0..) |*zone, zone_idx| {
            for (0..@min(zone.lifestone_count, self.lifestones[zone_idx].count)) |i| {
                zone.lifestones[i].attuned = self.lifestones[zone_idx].attuned[i];
                zone.lifestones[i].color = if (zone.lifestones[i].attuned)
                    constants.COLOR_LIFESTONE_ATTUNED
                else
                    constants.COLOR_LIFESTONE_UNATTUNED;
            }
            
            // Restore unit state
            for (0..@min(zone.unit_count, self.units_killed[zone_idx].count)) |i| {
                if (self.units_killed[zone_idx].killed[i]) {
                    zone.units[i].alive = false;
                    zone.units[i].color = constants.COLOR_DEAD;
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

/// Complete save state for Hex game
pub const HexSaveState = game_systems.SaveState(HexSaveData);