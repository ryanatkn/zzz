const std = @import("std");
const hex_game_mod = @import("hex_game.zig");
const physics = @import("physics.zig");
const input = @import("../lib/platform/input.zig");
const math = @import("../lib/math/mod.zig");
const camera = @import("../lib/rendering/camera.zig");
const constants = @import("constants.zig");
const frame = @import("../lib/core/frame.zig");
const entity_queries = @import("entity_queries.zig");
const faction_integration = @import("faction_integration.zig");

const Vec2 = math.Vec2;
const HexGame = hex_game_mod.HexGame;
const EntityId = hex_game_mod.EntityId;
const InputState = input.InputState;
const FrameContext = frame.FrameContext;

const WALK_SPEED_MULT = constants.WALK_SPEED_MULTIPLIER; // Walking speed is 1/4 of normal

/// Update any controlled entity with frame context and direct parameters
/// This replaces the old updatePlayer function and works with any controllable entity
pub fn updateControlledEntity(
    game: *HexGame, 
    entity_id: EntityId,
    frame_ctx: FrameContext, 
    input_state: *const InputState, 
    cam: *const camera.Camera
) void {
    const deltaTime = frame_ctx.effectiveDelta();

    // Check if entity is alive
    if (!entity_queries.isEntityAlive(game, entity_id)) return;

    // Get entity capabilities to determine movement parameters
    const capabilities = faction_integration.getEntityCapabilities(game, entity_id) orelse return;
    if (!capabilities.can_move) return;

    // Calculate velocity from input
    const velocity = calculateVelocityFromInput(
        game,
        entity_id,
        input_state,
        cam,
        capabilities.move_speed
    );

    // Get current position
    const current_pos = entity_queries.getEntityPos(game, entity_id) orelse return;

    // Calculate new position
    var new_pos = Vec2{
        .x = current_pos.x + velocity.x * deltaTime,
        .y = current_pos.y + velocity.y * deltaTime,
    };

    // Apply movement bounds based on zone camera mode
    new_pos = entity_queries.applyMovementBounds(game, entity_id, new_pos);

    // Check collision with obstacles before moving
    if (physics.canEntityMoveTo(game, entity_id, new_pos)) {
        // No collision, safe to move
        entity_queries.setEntityPos(game, entity_id, new_pos);
    }
    // If collision detected, don't move (entity stays at current position)
    
    entity_queries.setEntityVelocity(game, entity_id, velocity);
}

/// Calculate velocity from input for any entity
fn calculateVelocityFromInput(
    game: *HexGame,
    entity_id: EntityId,
    input_state: *const InputState,
    cam: *const camera.Camera,
    base_speed: f32
) Vec2 {
    var keyboard_velocity = Vec2.ZERO;
    var mouse_velocity = Vec2.ZERO;

    // Check modifiers
    const is_walking = input_state.isShiftHeld();
    const ctrl_held = input_state.isCtrlHeld();

    // Speed modifier for walking
    const speed_mult: f32 = if (is_walking) WALK_SPEED_MULT else 1.0;
    const move_speed = base_speed * speed_mult;

    // Keyboard movement
    const movement = input_state.getMovementVector();
    keyboard_velocity.x = movement.x * move_speed;
    keyboard_velocity.y = movement.y * move_speed;

    // Get current entity position for mouse movement
    const entity_pos = entity_queries.getEntityPos(game, entity_id) orelse return Vec2.ZERO;
    const entity_radius = entity_queries.getEntityRadius(game, entity_id) orelse 20.0;

    // Only allow mouse movement when Ctrl is held
    if (ctrl_held and input_state.isLeftMouseHeld()) {
        const screen_mouse_pos = input_state.getMousePos();
        const world_mouse_pos = cam.screenToWorldSafe(screen_mouse_pos);
        const to_mouse = world_mouse_pos.sub(entity_pos);
        const distance_sq = to_mouse.lengthSquared();
        const radius_sq = entity_radius * entity_radius;

        if (distance_sq > radius_sq) {
            const direction = to_mouse.normalize();
            mouse_velocity = direction.scale(move_speed);
        }
    }

    // Prefer mouse movement when active
    if (ctrl_held and input_state.isLeftMouseHeld() and (mouse_velocity.x != 0 or mouse_velocity.y != 0)) {
        return mouse_velocity;
    } else {
        return keyboard_velocity;
    }
}

/// Get movement direction of any controlled entity (replaces getPlayerMovementDirection)
pub fn getControlledEntityMovementDirection(game: *const HexGame, entity_id: EntityId) Vec2 {
    return entity_queries.getEntityVelocity(game, entity_id).normalize();
}

/// Check if entity can be controlled (helper for possession system)
pub fn canControlEntity(game: *const HexGame, entity_id: EntityId) bool {
    return faction_integration.canEntityBeControlled(game, entity_id);
}

/// Get the speed of a controllable entity
pub fn getEntitySpeed(game: *const HexGame, entity_id: EntityId) f32 {
    if (faction_integration.getEntityCapabilities(game, entity_id)) |caps| {
        return caps.move_speed;
    }
    return constants.PLAYER_SPEED; // Default fallback
}

/// Legacy function for backward compatibility during migration
/// TODO: Remove this once all calls are updated to use updateControlledEntity
pub fn updatePlayer(game: *HexGame, frame_ctx: FrameContext, input_state: *const InputState, cam: *const camera.Camera) void {
    // Find the player entity (should be the controlled entity)
    if (game.player_entity) |player_entity| {
        updateControlledEntity(game, player_entity, frame_ctx, input_state, cam);
    }
}

/// Legacy function for backward compatibility during migration
/// TODO: Remove this once all calls are updated
pub fn getPlayerMovementDirection(game: *const HexGame) Vec2 {
    if (game.player_entity) |player_entity| {
        return getControlledEntityMovementDirection(game, player_entity);
    }
    return Vec2.ZERO;
}