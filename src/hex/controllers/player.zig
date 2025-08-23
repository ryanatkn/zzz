const std = @import("std");

// Core capabilities
const math = @import("../../lib/math/mod.zig");
const frame = @import("../../lib/core/frame.zig");

// Platform capabilities
const input = @import("../../lib/platform/input.zig");

// Game system capabilities
const camera = @import("../../lib/game/camera/camera.zig");

// Hex game modules
const controller_mod = @import("../controller.zig");

const Vec2 = math.Vec2;
const FrameContext = frame.FrameContext;
const InputState = input.InputState;

/// Player controller functionality extracted from controller.zig
pub const PlayerController = struct {
    /// Create a player controller
    pub fn createPlayerController() controller_mod.Controller {
        return controller_mod.createPlayerController();
    }

    /// Update controlled entity - extracted from controlled_entity.zig
    pub fn updateControlledEntity(world: anytype, controlled_entity: anytype, frame_ctx: FrameContext, input_state: *const InputState, cam: *const camera.Camera) void {
        const controlled_entity_mod = @import("../controlled_entity.zig");
        controlled_entity_mod.updateControlledEntity(world, controlled_entity, frame_ctx, input_state, cam);
    }

    /// Find next controllable entity for cycling
    pub fn findNextControllableEntity(world: anytype, current_entity: anytype) @TypeOf(controller_mod.findNextControllableEntity(world, current_entity)) {
        return controller_mod.findNextControllableEntity(world, current_entity);
    }
};
