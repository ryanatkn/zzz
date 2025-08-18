/// Surface - ground movement properties component
/// Sparse storage - only entities with special movement properties have this
pub const Surface = struct {
    friction: f32 = 1.0, // 1.0 = normal, 0.1 = ice, 2.0 = sticky
    walkable: bool = true,
    climbable: bool = false,
    slippery: bool = false,
    sticky: bool = false,

    pub fn init() Surface {
        return .{
            .friction = 1.0,
            .walkable = true,
            .climbable = false,
            .slippery = false,
            .sticky = false,
        };
    }

    pub fn initIce() Surface {
        return .{
            .friction = 0.2,
            .walkable = true,
            .climbable = false,
            .slippery = true,
            .sticky = false,
        };
    }

    pub fn initSticky() Surface {
        return .{
            .friction = 2.0,
            .walkable = true,
            .climbable = false,
            .slippery = false,
            .sticky = true,
        };
    }

    pub fn getMovementMultiplier(self: Surface) f32 {
        if (self.sticky) return 0.5;
        if (self.slippery) return 1.5; // Move faster but less control
        return 1.0;
    }
};