const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const math = @import("../../lib/math/mod.zig");
const colors = @import("../../lib/core/colors.zig");

// Reuse lib/rendering utilities for efficient entity rendering
const entity_renderer = @import("../../lib/rendering/systems/entity_renderer.zig");
const viewport_mod = @import("../../lib/rendering/spatial/viewport.zig");
const visibility = @import("../../lib/rendering/spatial/visibility.zig");
const transforms_mod = @import("../../lib/rendering/spatial/transforms.zig");

// Game system capabilities
const camera_mod = @import("../../lib/game/camera/camera.zig");

// Hex game modules
const world_state_mod = @import("../world_state.zig");
const constants = @import("../constants.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const Camera = camera_mod.Camera;
const HexGame = world_state_mod.HexGame;
const ZoneData = world_state_mod.HexGame.ZoneData;
const Viewport = viewport_mod.Viewport;
const CoordinateContext = transforms_mod.CoordinateContext;

// Rectangle data for batched terrain rendering (legacy support)
const RectData = struct {
    pos: Vec2,
    size: Vec2,
    color: Color,
};

const MAX_BATCHED_RECTS = constants.MAX_TERRAIN;

/// Entity batch rendering system that reuses lib/rendering utilities
/// Replaces the manual rendering loops in game_renderer.zig with optimized batch rendering
pub const EntityBatchRenderer = struct {
    /// Render all entities in a zone using optimized lib/rendering utilities
    pub fn renderZone(gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, camera: *const Camera, game: *const HexGame) void {
        const zone = game.getCurrentZoneConst();

        // Create coordinate context for visibility culling
        const context = CoordinateContext{
            .camera_position = camera.view_center,
            .camera_zoom = camera.zoom_level,
            .screen_width = constants.SCREEN_WIDTH,
            .screen_height = constants.SCREEN_HEIGHT,
            .ui_scale = 1.0, // Default UI scale
        };

        // Render terrain using legacy batching (terrain uses rectangles, not circles)
        renderTerrainBatched(gpu_renderer, cmd_buffer, render_pass, camera, zone);

        // Use lib/rendering for circle entities with visibility culling
        renderCircleEntitiesWithCulling(gpu_renderer, cmd_buffer, render_pass, camera, &zone.units, @intCast(zone.units.count), context);
        renderCircleEntitiesWithCulling(gpu_renderer, cmd_buffer, render_pass, camera, &zone.lifestones, @intCast(zone.lifestones.count), context);
        renderCircleEntitiesWithCulling(gpu_renderer, cmd_buffer, render_pass, camera, &zone.portals, @intCast(zone.portals.count), context);
        renderCircleEntitiesWithCulling(gpu_renderer, cmd_buffer, render_pass, camera, &zone.projectiles, @intCast(zone.projectiles.count), context);

        // Render player (only if in current zone)
        if (game.player_zone == game.zone_manager.getCurrentZoneIndex()) {
            renderCircleEntitiesWithCulling(gpu_renderer, cmd_buffer, render_pass, camera, &zone.players, @intCast(zone.players.count), context);
        }
    }

    /// Render terrain using batched rectangles (terrain doesn't use the circle renderer)
    fn renderTerrainBatched(gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, camera: *const Camera, zone: *const ZoneData) void {
        // Batch terrain rectangles for optimal rendering
        var rect_batch: [MAX_BATCHED_RECTS]RectData = undefined;
        var rect_count: usize = 0;

        // Add terrain rectangles to batch with visibility culling
        for (0..zone.terrain.count) |i| {
            const transform = &zone.terrain.transforms[i];
            const visual = &zone.terrain.visuals[i];
            const terrain = &zone.terrain.terrains[i];

            // Simple visibility check for terrain rectangles
            const half_width = terrain.size.x / 2.0;
            const half_height = terrain.size.y / 2.0;
            const viewport_width = camera.viewport_width;
            const viewport_height = camera.viewport_height;

            // Check if terrain intersects camera viewport
            if (transform.pos.x + half_width >= camera.view_center.x - viewport_width / 2.0 and
                transform.pos.x - half_width <= camera.view_center.x + viewport_width / 2.0 and
                transform.pos.y + half_height >= camera.view_center.y - viewport_height / 2.0 and
                transform.pos.y - half_height <= camera.view_center.y + viewport_height / 2.0)
            {
                if (rect_count < MAX_BATCHED_RECTS) {
                    rect_batch[rect_count] = RectData{
                        .pos = camera.worldToScreen(transform.pos),
                        .size = Vec2{
                            .x = camera.worldSizeToScreen(terrain.size.x),
                            .y = camera.worldSizeToScreen(terrain.size.y),
                        },
                        .color = visual.color,
                    };
                    rect_count += 1;
                }
            }
        }

        // Single batched draw call for visible terrain rectangles
        for (rect_batch[0..rect_count]) |rect| {
            gpu_renderer.drawRect(cmd_buffer, render_pass, rect.pos, rect.size, rect.color);
        }
    }

    /// Render circle entities with visibility culling using lib/rendering utilities
    fn renderCircleEntitiesWithCulling(gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, camera: *const Camera, storage: anytype, count: u32, context: CoordinateContext) void {
        // Early exit if no entities
        if (count == 0) return;

        // Render each visible entity (we could batch this further in the future)
        const actual_count = @min(count, storage.transforms.len);
        for (0..actual_count) |i| {
            const transform = &storage.transforms[i];
            const visual = &storage.visuals[i];

            // Skip if not visible
            if (@hasField(@TypeOf(visual.*), "visible") and !visual.visible) continue;

            // Use lib/rendering visibility culling
            if (visibility.isCircleVisible(transform.pos, transform.radius, context)) {
                const screen_pos = camera.worldToScreen(transform.pos);
                const screen_radius = camera.worldSizeToScreen(transform.radius);
                gpu_renderer.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, visual.color);
            }
        }
    }
};
