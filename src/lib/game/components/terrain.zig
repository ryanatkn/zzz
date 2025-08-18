const math = @import("../../math/mod.zig");
pub const Vec2 = math.Vec2;

/// Terrain - for static/semi-static world geometry
/// Sparse storage - only terrain entities have this
pub const Terrain = struct {
    pub const TerrainType = enum {
        wall,
        floor,
        door,
        water,
        pit,
        altar,
    };

    solid: bool,
    blocks_sight: bool,
    terrain_type: TerrainType,
    size: Vec2, // Original rectangular size for proper rendering

    pub fn init(terrain_type: TerrainType, size: Vec2) Terrain {
        return .{
            .solid = switch (terrain_type) {
                .wall, .door => true,
                else => false,
            },
            .blocks_sight = switch (terrain_type) {
                .wall, .door => true,
                else => false,
            },
            .terrain_type = terrain_type,
            .size = size,
        };
    }
};