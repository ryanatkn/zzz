const math = @import("../../math/mod.zig");
pub const Vec2 = math.Vec2;

/// Terrain - for static/semi-static world geometry
/// Sparse storage - only terrain entities have this
pub const Terrain = struct {
    pub const TerrainType = enum {
        rock,
        floor,
        door,
        water,
        pit,
        altar,
    };

    solid: bool,
    blocks_sight: bool,
    deadly: bool,
    allows_ricochet: bool,
    terrain_type: TerrainType,
    size: Vec2, // Original rectangular size for proper rendering

    pub fn init(terrain_type: TerrainType, size: Vec2) Terrain {
        return .{
            .solid = switch (terrain_type) {
                .rock, .door => true,
                else => false,
            },
            .blocks_sight = switch (terrain_type) {
                .rock, .door => true,
                else => false,
            },
            .deadly = switch (terrain_type) {
                .pit => true,
                else => false,
            },
            .allows_ricochet = switch (terrain_type) {
                .rock, .door => true, // Solid surfaces ricochet
                .pit => false, // Pits absorb projectiles
                else => false,
            },
            .terrain_type = terrain_type,
            .size = size,
        };
    }
};
