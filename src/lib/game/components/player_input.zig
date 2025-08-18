/// PlayerInput - distinguishes player-controlled entities
/// Sparse storage - only player entities have this
pub const PlayerInput = struct {
    controller_id: u8,

    pub fn init(controller_id: u8) PlayerInput {
        return .{
            .controller_id = controller_id,
        };
    }
};
