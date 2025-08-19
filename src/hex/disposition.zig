// Disposition - Hex-specific AI temperament types
// Defines the 4 disposition types that determine unit personality and behavior tendencies

/// Hex-specific unit dispositions (temperament/personality)
pub const Disposition = enum {
    hostile, // Always aggressive, never flees (red)
    fearful, // Always flees from player (orange/yellow)
    neutral, // Ignores player, returns home when far (gray)
    friendly, // Never attacks, may follow player (green)
};
