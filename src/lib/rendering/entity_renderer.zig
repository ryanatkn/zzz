// Generic entity rendering utilities
// Eliminates duplicate rendering loops and provides batched entity rendering

const std = @import("std");
const c = @import("../platform/sdl.zig");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const camera_mod = @import("camera.zig");
const camera_utils = @import("camera_utils.zig");
const interface = @import("interface.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const Camera = camera_mod.Camera;
const RendererInterface = interface.RendererInterface;
const EntityTransform = camera_utils.EntityTransform;
const RectTransform = camera_utils.RectTransform;

/// Generic circle entity rendering function
/// Works with any entity storage that provides transforms and visuals
pub fn renderCircleEntities(
    comptime EntityStorage: type,
    renderer: RendererInterface,
    cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
    render_pass: *c.sdl.SDL_GPURenderPass,
    cam: *const Camera,
    storage: *const EntityStorage,
    count: u32,
) void {
    // Batch transform all entities
    var transforms: [1000]EntityTransform = undefined;
    var visible_indices: [1000]u32 = undefined;

    // Collect world positions and radii
    var world_positions: [1000]Vec2 = undefined;
    var world_radii: [1000]f32 = undefined;
    var entity_colors: [1000]Color = undefined;

    const actual_count = @min(count, 1000);

    for (0..actual_count) |i| {
        world_positions[i] = storage.transforms[i].pos;
        world_radii[i] = storage.transforms[i].radius;
        entity_colors[i] = storage.visuals[i].color;
    }

    // Efficient batch processing with culling
    const config = camera_utils.CameraUtilsConfig{
        .culling_margin = 50.0,
        .enable_depth_sorting = false,
    };

    const visible_count = camera_utils.prepareEntitiesForRendering(
        cam,
        world_positions[0..actual_count],
        world_radii[0..actual_count],
        config,
        &transforms,
        &visible_indices,
    );

    // Render only visible entities
    for (0..visible_count) |i| {
        const transform = transforms[i];
        const original_index = visible_indices[i];
        const color = entity_colors[original_index];

        renderer.drawCircle(cmd_buffer, render_pass, transform.screen_pos, transform.screen_radius, color);
    }
}

/// Generic rectangle entity rendering function
pub fn renderRectEntities(
    comptime EntityStorage: type,
    renderer: RendererInterface,
    cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
    render_pass: *c.sdl.SDL_GPURenderPass,
    cam: *const Camera,
    storage: *const EntityStorage,
    count: u32,
) void {
    var transforms: [1000]RectTransform = undefined;
    var world_positions: [1000]Vec2 = undefined;
    var world_sizes: [1000]Vec2 = undefined;
    var entity_colors: [1000]Color = undefined;

    const actual_count = @min(count, 1000);

    for (0..actual_count) |i| {
        world_positions[i] = storage.transforms[i].pos;
        world_sizes[i] = storage.terrains[i].size; // Assuming terrain component has size
        entity_colors[i] = storage.visuals[i].color;
    }

    // Batch transform rectangles
    camera_utils.batchTransformRects(
        cam,
        world_positions[0..actual_count],
        world_sizes[0..actual_count],
        transforms[0..actual_count],
    );

    // Render all rectangles (could add culling here too)
    for (0..actual_count) |i| {
        const transform = transforms[i];
        const color = entity_colors[i];

        renderer.drawRect(cmd_buffer, render_pass, transform.screen_pos, transform.screen_size, color);
    }
}

/// Circle entities with conditional rendering (e.g., for visibility checks)
pub fn renderConditionalCircleEntities(
    comptime EntityStorage: type,
    comptime ConditionFn: type,
    renderer: RendererInterface,
    cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
    render_pass: *c.sdl.SDL_GPURenderPass,
    cam: *const Camera,
    storage: *const EntityStorage,
    count: u32,
    condition_fn: ConditionFn,
) void {
    // Similar to renderCircleEntities but with condition check
    var transforms: [1000]EntityTransform = undefined;
    var visible_indices: [1000]u32 = undefined;
    var world_positions: [1000]Vec2 = undefined;
    var world_radii: [1000]f32 = undefined;
    var entity_colors: [1000]Color = undefined;

    const actual_count = @min(count, 1000);
    var valid_count: u32 = 0;

    // Filter entities based on condition
    for (0..actual_count) |i| {
        if (condition_fn(storage, i)) {
            world_positions[valid_count] = storage.transforms[i].pos;
            world_radii[valid_count] = storage.transforms[i].radius;
            entity_colors[valid_count] = storage.visuals[i].color;
            visible_indices[valid_count] = @intCast(i); // Store original index
            valid_count += 1;
        }
    }

    // Transform valid entities
    camera_utils.batchTransformEntities(
        cam,
        world_positions[0..valid_count],
        world_radii[0..valid_count],
        transforms[0..valid_count],
    );

    // Render valid entities
    for (0..valid_count) |i| {
        const transform = transforms[i];
        const color = entity_colors[i];

        renderer.drawCircle(cmd_buffer, render_pass, transform.screen_pos, transform.screen_radius, color);
    }
}

/// High-level zone rendering function for hex-style games
/// Eliminates the need for multiple rendering loops
pub fn renderZoneEntities(
    comptime ZoneType: type,
    renderer: RendererInterface,
    cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
    render_pass: *c.sdl.SDL_GPURenderPass,
    cam: *const Camera,
    zone: *const ZoneType,
) void {
    // Render obstacles (rectangles)
    renderRectEntities(
        @TypeOf(zone.obstacles),
        renderer,
        cmd_buffer,
        render_pass,
        cam,
        &zone.obstacles,
        zone.obstacles.count,
    );

    // Render units (circles)
    renderCircleEntities(
        @TypeOf(zone.units),
        renderer,
        cmd_buffer,
        render_pass,
        cam,
        &zone.units,
        zone.units.count,
    );

    // Render lifestones (circles)
    renderCircleEntities(
        @TypeOf(zone.lifestones),
        renderer,
        cmd_buffer,
        render_pass,
        cam,
        &zone.lifestones,
        zone.lifestones.count,
    );

    // Render portals (circles)
    renderCircleEntities(
        @TypeOf(zone.portals),
        renderer,
        cmd_buffer,
        render_pass,
        cam,
        &zone.portals,
        zone.portals.count,
    );
}

/// Player rendering with zone check
pub fn renderPlayerInZone(
    comptime ZoneType: type,
    comptime GameType: type,
    renderer: RendererInterface,
    cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
    render_pass: *c.sdl.SDL_GPURenderPass,
    cam: *const Camera,
    zone: *const ZoneType,
    game: *const GameType,
) void {
    // Only render player if in current zone
    if (game.player_zone == game.zone_manager.getCurrentZoneIndex()) {
        renderCircleEntities(
            @TypeOf(zone.players),
            renderer,
            cmd_buffer,
            render_pass,
            cam,
            &zone.players,
            zone.players.count,
        );
    }
}

/// Projectile rendering with visibility check
pub fn renderProjectiles(
    comptime ZoneType: type,
    renderer: RendererInterface,
    cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
    render_pass: *c.sdl.SDL_GPURenderPass,
    cam: *const Camera,
    zone: *const ZoneType,
) void {
    // Condition function for visible projectiles
    const VisibilityCondition = struct {
        fn check(storage: anytype, index: usize) bool {
            return storage.visuals[index].visible;
        }
    };

    renderConditionalCircleEntities(
        @TypeOf(zone.projectiles),
        @TypeOf(VisibilityCondition.check),
        renderer,
        cmd_buffer,
        render_pass,
        cam,
        &zone.projectiles,
        zone.projectiles.count,
        VisibilityCondition.check,
    );
}

/// Complete zone rendering function that combines all entity types
/// This replaces the entire renderZone() function in game_renderer.zig
pub fn renderCompleteZone(
    comptime ZoneType: type,
    comptime GameType: type,
    renderer: RendererInterface,
    cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
    render_pass: *c.sdl.SDL_GPURenderPass,
    cam: *const Camera,
    zone: *const ZoneType,
    game: *const GameType,
) void {
    // Render all basic zone entities
    renderZoneEntities(ZoneType, renderer, cmd_buffer, render_pass, cam, zone);

    // Render player (with zone check)
    renderPlayerInZone(ZoneType, GameType, renderer, cmd_buffer, render_pass, cam, zone, game);

    // Render projectiles (with visibility check)
    renderProjectiles(ZoneType, renderer, cmd_buffer, render_pass, cam, zone);
}

/// Batch rendering statistics for performance monitoring
pub const RenderStats = struct {
    entities_culled: u32 = 0,
    entities_rendered: u32 = 0,
    draw_calls_saved: u32 = 0,

    pub fn reset(self: *RenderStats) void {
        self.* = RenderStats{};
    }

    pub fn getCullingEfficiency(self: RenderStats) f32 {
        const total = self.entities_culled + self.entities_rendered;
        if (total == 0) return 0.0;
        return @as(f32, @floatFromInt(self.entities_culled)) / @as(f32, @floatFromInt(total));
    }
};

/// Configuration for entity rendering optimization
pub const EntityRenderConfig = struct {
    /// Enable frustum culling for off-screen entities
    enable_culling: bool = true,

    /// Culling margin in screen pixels
    culling_margin: f32 = 50.0,

    /// Enable depth sorting for correct rendering order
    enable_depth_sorting: bool = false,

    /// Maximum entities to process per batch
    max_batch_size: u32 = 1000,

    /// Collect rendering statistics
    collect_stats: bool = false,
};
