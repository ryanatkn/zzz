const std = @import("std");
const input = @import("../lib/platform/input.zig");
const hex_game_mod = @import("hex_game.zig");
const factions = @import("factions.zig");
const faction_integration = @import("faction_integration.zig");

const HexGame = hex_game_mod.HexGame;
const EntityId = hex_game_mod.EntityId;
const InputState = input.InputState;
const EntityFactions = factions.EntityFactions;

/// Types of controllers that can control entities
pub const ControllerType = enum {
    player,        // Human player input
    ai_script,     // AI behavior script
    network,       // Remote player input
    replay,        // Recorded input playback
    story_ai,      // Narrative AI controller
};

/// Controller abstraction - overlays that inject input into controllable entities
/// Controllers are not part of entities but control them externally
pub const Controller = struct {
    controller_type: ControllerType,
    controlled_entity: ?EntityId = null,
    
    // When possessing, we see the world through the entity's faction perspective
    possessed_factions: ?EntityFactions = null,
    
    pub fn init(controller_type: ControllerType) Controller {
        return .{
            .controller_type = controller_type,
            .controlled_entity = null,
            .possessed_factions = null,
        };
    }
    
    /// Attempt to possess an entity - returns true if successful
    pub fn possess(self: *Controller, world: *HexGame, entity_id: EntityId) bool {
        // Check if entity exists and can be controlled
        if (!faction_integration.canEntityBeControlled(world, entity_id)) {
            return false;
        }
        
        // Release current possession if any
        if (self.controlled_entity) |current| {
            self.release(world, current);
        }
        
        // Take control of new entity
        self.controlled_entity = entity_id;
        
        // Inherit the entity's faction perspective for viewing the world
        self.possessed_factions = faction_integration.getEntityFactions(world, entity_id);
        
        // Log the possession
        const mutable_world = @constCast(world);
        mutable_world.logger.info("possession", "Controller {} possessed entity {}", .{ @intFromEnum(self.controller_type), entity_id });
        
        return true;
    }
    
    /// Release control of the specified entity
    pub fn release(self: *Controller, world: *HexGame, entity_id: EntityId) void {
        if (self.controlled_entity == entity_id) {
            const mutable_world = @constCast(world);
            mutable_world.logger.info("release", "Controller {} released entity {}", .{ @intFromEnum(self.controller_type), entity_id });
            
            self.controlled_entity = null;
            self.possessed_factions = null;
        }
    }
    
    /// Release any currently controlled entity
    pub fn releaseAny(self: *Controller, world: *HexGame) void {
        if (self.controlled_entity) |entity_id| {
            self.release(world, entity_id);
        }
    }
    
    /// Update the controller - inject input into controlled entity
    pub fn update(self: *Controller, world: *HexGame, input_state: *const InputState) void {
        _ = world; // TODO: Remove once other controller types are implemented
        _ = input_state; // TODO: Remove once other controller types are implemented
        
        if (self.controlled_entity) |_| {
            // For now, only player controllers use direct input
            // Other controller types will be implemented later
            switch (self.controller_type) {
                .player => {
                    // Player input is processed by the main game loop
                    // This controller just tracks which entity receives that input
                },
                .ai_script => {
                    // TODO: Generate AI input based on entity state
                    // const ai_input = generateAIInput(world, entity_id);
                    // applyInputToEntity(world, entity_id, &ai_input);
                },
                .network => {
                    // TODO: Network input from remote player
                    // const net_input = receiveNetworkInput(entity_id);
                    // applyInputToEntity(world, entity_id, &net_input);
                },
                .replay => {
                    // TODO: Replay recorded input
                    // const replay_input = getReplayInput(entity_id);
                    // applyInputToEntity(world, entity_id, &replay_input);
                },
                .story_ai => {
                    // TODO: Story-driven AI control
                    // const story_input = getStoryAIInput(world, entity_id);
                    // applyInputToEntity(world, entity_id, &story_input);
                },
            }
        }
    }
    
    /// Get the faction perspective we're viewing the world through
    pub fn getWorldView(self: *const Controller) ?EntityFactions {
        return self.possessed_factions;
    }
    
    /// Check if this controller is currently controlling an entity
    pub fn isControlling(self: *const Controller) bool {
        return self.controlled_entity != null;
    }
    
    /// Get the ID of the currently controlled entity
    pub fn getControlledEntity(self: *const Controller) ?EntityId {
        return self.controlled_entity;
    }
};

/// Helper functions for controller management

/// Find the next controllable entity after the current one (for possession cycling)
pub fn findNextControllableEntity(world: *const HexGame, current_entity: ?EntityId) ?EntityId {
    const zone = world.getCurrentZoneConst();
    var candidates: [64]EntityId = undefined;
    var count: usize = 0;
    
    // Collect all controllable entities in current zone
    var player_iter = zone.players.entityIterator();
    while (player_iter.next()) |entity_id| {
        if (count >= candidates.len) break;
        if (faction_integration.canEntityBeControlled(world, entity_id)) {
            candidates[count] = entity_id;
            count += 1;
        }
    }
    
    var unit_iter = zone.units.entityIterator();
    while (unit_iter.next()) |entity_id| {
        if (count >= candidates.len) break;
        if (faction_integration.canEntityBeControlled(world, entity_id)) {
            candidates[count] = entity_id;
            count += 1;
        }
    }
    
    if (count == 0) return null;
    
    // Find current entity index
    var current_index: ?usize = null;
    if (current_entity) |current| {
        for (candidates[0..count], 0..) |entity, i| {
            if (entity == current) {
                current_index = i;
                break;
            }
        }
    }
    
    // Return next entity (or first if no current)
    const next_index = if (current_index) |idx| (idx + 1) % count else 0;
    return candidates[next_index];
}

/// Create a player controller (human input)
pub fn createPlayerController() Controller {
    return Controller.init(.player);
}

/// Create an AI controller
pub fn createAIController() Controller {
    return Controller.init(.ai_script);
}