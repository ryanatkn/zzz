// Disposition - Single Authoritative Entity Relationship System
//
// This enum determines all entity colors and behaviors in the game.
// Currently uses a simple static approach with potential for future expansion:
//
// Current Implementation:
// - Static assignment from .zon world data files
// - Combined with dynamic energy levels (idle=dim, active=bright)
// - Example: .disposition = .hostile → red color → energy_level affects brightness
//
// Future Expansion Potential:
// - Temporary spell effects (charm, corruption) could override base disposition
// - Faction relationships could influence disposition calculation
//
// Data Flow: World Data (.zon) → Unit.disposition → dispositionToBaseColor() → Color
// All entity coloring flows through this single, consistent system.

/// Single authoritative disposition system - computed differently per context
pub const Disposition = enum {
    hostile, // Attacks on sight, chases player (red)
    fearful, // Flees from player, avoids combat (yellow)
    neutral, // Ignores player, returns home when far (gray)
    friendly, // Never attacks, may follow player (teal)
    allied, // Actively helps player in combat (green)
};
