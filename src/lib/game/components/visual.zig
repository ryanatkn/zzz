const colors = @import("../../core/colors.zig");
const Color = colors.Color;

/// Visual - rendering properties
/// Dense storage - all visible entities have this
pub const Visual = struct {
    color: Color,
    scale: f32,
    visible: bool,
    z_order: i32, // For layering

    pub fn init(color: Color) Visual {
        return .{
            .color = color,
            .scale = 1.0,
            .visible = true,
            .z_order = 0,
        };
    }
};