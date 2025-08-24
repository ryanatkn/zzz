// Hex-specific color mappings for the unified disposition system
// Single source of truth for all entity colors - all coloring flows through dispositionToBaseColor()

const color_variants = @import("../lib/core/color_variants.zig");
const colors = @import("../lib/core/colors.zig");
const Disposition = @import("disposition.zig").Disposition;
const EnergyLevel = @import("constants.zig").EnergyLevel;

const BaseColor = color_variants.BaseColor;
const Color = colors.Color;

/// Single authoritative color mapping - all entity colors flow through this function
/// Uses distinct colors that are easily distinguishable in gameplay
pub inline fn dispositionToBaseColor(disposition: Disposition) BaseColor {
    return switch (disposition) {
        .hostile => .red, // Danger - attacks on sight
        .fearful => .yellow, // Caution - flees from player (distinct from orange)
        .neutral => .brown, // Passive - ignores player
        .friendly => .blue, // Safe - won't attack, may help
        .allied => .green, // Helpful - actively assists player
    };
}

/// Get color based on energy level
pub inline fn getEnergyColor(base: BaseColor, energy: EnergyLevel) Color {
    const variant: u8 = switch (energy) {
        .lowered => 3,
        .normal => 5,
        .raised => 8,
    };
    return base.getVariant(variant);
}

/// Get color for disposition with energy level - unified system
pub inline fn getDispositionEnergyColor(disposition: Disposition, energy: EnergyLevel) Color {
    const base = dispositionToBaseColor(disposition);
    return getEnergyColor(base, energy);
}
