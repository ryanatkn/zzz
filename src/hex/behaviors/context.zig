// Behavior Update Context - Simplified parameter passing
// Replaces multiple individual parameters with clean struct

const Vec2 = @import("../../lib/math/mod.zig").Vec2;
const Unit = @import("../unit_ext.zig").HexUnit;
const Transform = @import("../world_state.zig").Transform;
const Visual = @import("../world_state.zig").Visual;
const FrameContext = @import("../../lib/core/frame.zig").FrameContext;

/// Context for unit behavior updates - clean parameter passing
pub const UnitUpdateContext = struct {
    // Unit components
    unit: *Unit,
    transform: *Transform,
    visual: *Visual,

    // World context - controlled entity position and state
    controlled_entity_pos: ?Vec2,
    controlled_entity_alive: bool,

    // Timing
    frame_ctx: FrameContext,

    pub fn init(
        unit: *Unit,
        transform: *Transform,
        visual: *Visual,
        controlled_entity_pos: ?Vec2,
        controlled_entity_alive: bool,
        frame_ctx: FrameContext,
    ) UnitUpdateContext {
        return .{
            .unit = unit,
            .transform = transform,
            .visual = visual,
            .controlled_entity_pos = controlled_entity_pos,
            .controlled_entity_alive = controlled_entity_alive,
            .frame_ctx = frame_ctx,
        };
    }
};
