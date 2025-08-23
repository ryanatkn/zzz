// Entity Lifecycle Management - Phase 3 extraction from world_state.zig
// Provides entity creation interface while delegating to existing EntityFactory

const std = @import("std");

// Core capabilities
const math = @import("../../lib/math/mod.zig");

// Hex game modules
const world_state_mod = @import("../world_state.zig");
const entities = @import("../entities/mod.zig");
const disposition = @import("../disposition.zig");

const Vec2 = math.Vec2;
const EntityId = entities.EntityId;
const HexGame = world_state_mod.HexGame;
const Disposition = disposition.Disposition;

/// Entity lifecycle management - extracted from world_state.zig
/// This module provides a clean interface for entity creation while
/// delegating to the existing EntityFactory to avoid duplication
pub const EntityManager = struct {
    /// Create a lifestone entity in the specified zone
    pub fn createLifestone(game: *HexGame, zone_index: usize, pos: Vec2, radius: f32, attuned: bool) !EntityId {
        return entities.EntityFactory.createLifestone(game, zone_index, pos, radius, attuned);
    }

    /// Create a unit entity in the specified zone
    pub fn createUnit(game: *HexGame, zone_index: usize, pos: Vec2, radius: f32, unit_disposition: Disposition) !EntityId {
        return entities.EntityFactory.createUnit(game, zone_index, pos, radius, unit_disposition);
    }

    /// Create a terrain entity in the specified zone
    pub fn createTerrain(game: *HexGame, zone_index: usize, pos: Vec2, size: Vec2, is_deadly: bool) !EntityId {
        return entities.EntityFactory.createTerrain(game, zone_index, pos, size, is_deadly);
    }

    /// Create a portal entity in the specified zone
    pub fn createPortal(game: *HexGame, zone_index: usize, pos: Vec2, radius: f32, destination: usize) !EntityId {
        return entities.EntityFactory.createPortal(game, zone_index, pos, radius, destination);
    }

    /// Create a player entity in the current zone
    pub fn createPlayer(game: *HexGame, pos: Vec2, radius: f32) !EntityId {
        return entities.EntityFactory.createPlayer(game, pos, radius);
    }

    /// Create a projectile entity in the specified zone
    pub fn createProjectile(game: *HexGame, zone_index: usize, pos: Vec2, radius: f32, velocity: Vec2, lifetime: f32) !EntityId {
        return entities.EntityFactory.createProjectile(game, zone_index, pos, radius, velocity, lifetime);
    }
};
