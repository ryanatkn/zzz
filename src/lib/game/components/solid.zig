/// Solid - blocks movement component
/// Sparse storage - only entities that block movement have this
pub const Solid = struct {
    passable_with_phase: bool = true, // Can phase spell bypass?
    strength: f32 = 1.0, // How hard to break through (for future destructible systems)

    pub fn init() Solid {
        return .{
            .passable_with_phase = true,
            .strength = 1.0,
        };
    }

    pub fn initImpassable() Solid {
        return .{
            .passable_with_phase = false, // Even phase can't pass through
            .strength = 999.0,
        };
    }
};