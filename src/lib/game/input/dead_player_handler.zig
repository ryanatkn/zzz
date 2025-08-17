const actions = @import("actions.zig");

const GameAction = actions.GameAction;

/// Simple dead player input handling
/// Standard behavior: click/R to respawn, allow system actions, block everything else
pub const DeadPlayerHandler = struct {
    /// Handle action when player is dead
    pub fn handleDeadPlayerAction(action: GameAction) DeadPlayerResult {
        return switch (action) {
            // Respawn actions
            .PrimaryAttack, .Respawn => .Respawn,
            
            // System actions always allowed
            .ToggleMenu, .TogglePause, .Quit => .Allow,
            
            // Block all other actions when dead
            else => .Block,
        };
    }
    
    /// Check if action should trigger respawn when dead
    pub fn shouldRespawn(action: GameAction) bool {
        return handleDeadPlayerAction(action) == .Respawn;
    }
    
    /// Check if action should be allowed when dead
    pub fn shouldAllow(action: GameAction) bool {
        const result = handleDeadPlayerAction(action);
        return result == .Allow or result == .Respawn;
    }
    
    /// Check if action should be blocked when dead
    pub fn shouldBlock(action: GameAction) bool {
        return handleDeadPlayerAction(action) == .Block;
    }
};

/// Result of dead player action handling
pub const DeadPlayerResult = enum {
    Respawn,  // Trigger respawn
    Allow,    // Allow this action
    Block,    // Block this action
};
