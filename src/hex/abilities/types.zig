// Ability types and effect types for the hex game
// Extracted from abilities.zig for better modularity

pub const AbilityType = enum {
    None,
    // Magical abilities (spells)
    Lull, // Reduce aggro range
    Blink, // Teleport (dungeon only)
    Phase, // Walk through solid objects
    Charm, // Control units
    Lethargy, // Slow enemy movement speed
    Haste, // Movement speed boost
    Dazzle, // Area confusion/slow
    // Combat abilities
    Multishot, // Fire multiple projectiles
    // Future: PowerShot, DodgeRoll, Shield, etc.
};

// Hex-specific effect types for the generic effect manager
pub const HexEffectType = enum {
    lull,
    blink_trail,
    phase_state,
    charm_effect,
    shield_aura,
    haste_boost,
    damage_zone,
    heal_zone,
};
