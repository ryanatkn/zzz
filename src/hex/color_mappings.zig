// Hex-specific color mappings for faction relationships and dispositions
// Bridges between hex game logic and the generic color variant system

const color_variants = @import("../lib/core/color_variants.zig");
const colors = @import("../lib/core/colors.zig");
const FactionRelation = @import("factions.zig").FactionRelation;
const Disposition = @import("disposition.zig").Disposition;
const EnergyLevel = @import("constants.zig").EnergyLevel;

const BaseColor = color_variants.BaseColor;
const Color = colors.Color;

/// Map faction relationships to base colors
pub inline fn relationshipToBaseColor(relationship: FactionRelation) BaseColor {
    return switch (relationship) {
        .hostile => .red,
        .suspicious => .orange,
        .neutral => .brown,
        .friendly => .teal,
        .allied => .green,
    };
}

/// Map dispositions to base colors
pub inline fn dispositionToBaseColor(disposition: Disposition) BaseColor {
    return switch (disposition) {
        .hostile => .red,
        .fearful => .yellow,
        .neutral => .brown,
        .friendly => .teal,
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

/// Get color for relationship with energy level
pub inline fn getRelationshipEnergyColor(relationship: FactionRelation, energy: EnergyLevel) Color {
    const base = relationshipToBaseColor(relationship);
    return getEnergyColor(base, energy);
}

/// Get color for disposition with energy level
pub inline fn getDispositionEnergyColor(disposition: Disposition, energy: EnergyLevel) Color {
    const base = dispositionToBaseColor(disposition);
    return getEnergyColor(base, energy);
}
