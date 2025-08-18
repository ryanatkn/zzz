// Behavior Update Context - Simplified parameter passing
// Replaces multiple individual parameters with clean struct

const Vec2 = @import("../../lib/math/mod.zig").Vec2;
const Unit = @import("../unit_ext.zig").HexUnit;
const Transform = @import("../hex_game.zig").Transform;
const Visual = @import("../hex_game.zig").Visual;
const FrameContext = @import("../../lib/core/frame.zig").FrameContext;

/// Context for unit behavior updates - clean parameter passing
pub const UnitUpdateContext = struct {
    // Unit components
    unit: *Unit,
    transform: *Transform,
    visual: *Visual,
    
    // World context
    player_pos: Vec2,
    player_alive: bool,
    
    // Timing
    frame_ctx: FrameContext,

    pub fn init(
        unit: *Unit,
        transform: *Transform,
        visual: *Visual,
        player_pos: Vec2,
        player_alive: bool,
        frame_ctx: FrameContext,
    ) UnitUpdateContext {
        return .{
            .unit = unit,
            .transform = transform,
            .visual = visual,
            .player_pos = player_pos,
            .player_alive = player_alive,
            .frame_ctx = frame_ctx,
        };
    }
};