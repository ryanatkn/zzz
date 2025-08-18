// Behavior Profile - Hex-specific AI behavior types
// Defines the 4 behavior profiles used by hex units

/// Hex-specific behavior profiles
pub const BehaviorProfile = enum {
    hostile,  // Always aggressive, never flees (red)
    fearful,  // Always flees from player (orange/yellow)  
    neutral,  // Ignores player, returns home when far (gray)
    friendly, // Never attacks, may follow player (green)
};