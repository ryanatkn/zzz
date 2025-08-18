/// Opaque - blocks sight component
/// Sparse storage - only entities that block sight have this
pub const Opaque = struct {
    transparency: f32 = 0.0, // 0.0 = fully opaque, 1.0 = fully transparent
    blocks_spells: bool = true, // Whether targeted spells can pass through

    pub fn init() Opaque {
        return .{
            .transparency = 0.0,
            .blocks_spells = true,
        };
    }

    pub fn initTranslucent(transparency: f32) Opaque {
        return .{
            .transparency = transparency,
            .blocks_spells = transparency > 0.5, // Semi-transparent allows spells
        };
    }

    pub fn isFullyOpaque(self: Opaque) bool {
        return self.transparency <= 0.0;
    }

    pub fn canSeeThrough(self: Opaque) bool {
        return self.transparency > 0.1;
    }
};
