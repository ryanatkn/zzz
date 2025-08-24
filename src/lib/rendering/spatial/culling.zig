// Generic spatial culling utilities for efficient rendering
// Extracted from hex/rendering patterns to provide reusable culling for any entity type

const std = @import("std");
const math = @import("../../math/mod.zig");
const transforms_mod = @import("transforms.zig");

const Vec2 = math.Vec2;
const CoordinateContext = transforms_mod.CoordinateContext;

/// Generic culling interface for different primitive types
pub const Culler = struct {
    /// Check if a circle is visible within the camera viewport
    pub fn isCircleVisible(center: Vec2, radius: f32, context: CoordinateContext) bool {
        const viewport_width = context.screen_width / context.camera_zoom;
        const viewport_height = context.screen_height / context.camera_zoom;
        const half_width = viewport_width / 2.0;
        const half_height = viewport_height / 2.0;

        // Check if circle intersects camera viewport (with radius buffer)
        return (center.x + radius >= context.camera_position.x - half_width and
            center.x - radius <= context.camera_position.x + half_width and
            center.y + radius >= context.camera_position.y - half_height and
            center.y - radius <= context.camera_position.y + half_height);
    }

    /// Check if a rectangle is visible within the camera viewport
    pub fn isRectVisible(pos: Vec2, size: Vec2, context: CoordinateContext) bool {
        const viewport_width = context.screen_width / context.camera_zoom;
        const viewport_height = context.screen_height / context.camera_zoom;
        const half_width = viewport_width / 2.0;
        const half_height = viewport_height / 2.0;

        const half_rect_width = size.x / 2.0;
        const half_rect_height = size.y / 2.0;

        // Check if rectangle intersects camera viewport
        return (pos.x + half_rect_width >= context.camera_position.x - half_width and
            pos.x - half_rect_width <= context.camera_position.x + half_width and
            pos.y + half_rect_height >= context.camera_position.y - half_height and
            pos.y - half_rect_height <= context.camera_position.y + half_height);
    }

    /// Check if a point is visible within the camera viewport
    pub fn isPointVisible(point: Vec2, context: CoordinateContext) bool {
        const viewport_width = context.screen_width / context.camera_zoom;
        const viewport_height = context.screen_height / context.camera_zoom;
        const half_width = viewport_width / 2.0;
        const half_height = viewport_height / 2.0;

        return (point.x >= context.camera_position.x - half_width and
            point.x <= context.camera_position.x + half_width and
            point.y >= context.camera_position.y - half_height and
            point.y <= context.camera_position.y + half_height);
    }
};

/// Generic entity culling for archetype-based systems
pub const EntityCuller = struct {
    /// Cull entities with transform and visual components (circles)
    pub fn cullCircleEntities(
        comptime EntityType: type,
        entities: []const EntityType,
        context: CoordinateContext,
        getTransform: fn (entity: EntityType) struct { pos: Vec2, radius: f32 },
        getVisual: fn (entity: EntityType) struct { visible: bool },
    ) []const bool {
        // For now, return a simple visibility array
        // In the future, this could be optimized with spatial data structures
        var visibility = std.ArrayList(bool).init(std.heap.page_allocator);

        for (entities) |entity| {
            const visual = getVisual(entity);
            if (!visual.visible) {
                visibility.append(false) catch continue;
                continue;
            }

            const transform = getTransform(entity);
            const is_visible = Culler.isCircleVisible(transform.pos, transform.radius, context);
            visibility.append(is_visible) catch continue;
        }

        return visibility.toOwnedSlice() catch &[_]bool{};
    }

    /// Cull entities with rectangle bounds
    pub fn cullRectEntities(
        comptime EntityType: type,
        entities: []const EntityType,
        context: CoordinateContext,
        getTransform: fn (entity: EntityType) struct { pos: Vec2, size: Vec2 },
        getVisual: fn (entity: EntityType) struct { visible: bool },
    ) []const bool {
        var visibility = std.ArrayList(bool).init(std.heap.page_allocator);

        for (entities) |entity| {
            const visual = getVisual(entity);
            if (!visual.visible) {
                visibility.append(false) catch continue;
                continue;
            }

            const transform = getTransform(entity);
            const is_visible = Culler.isRectVisible(transform.pos, transform.size, context);
            visibility.append(is_visible) catch continue;
        }

        return visibility.toOwnedSlice() catch &[_]bool{};
    }
};

/// Distance-based culling for entities
pub const DistanceCuller = struct {
    /// Check if an entity is within a certain distance of the camera
    pub fn isWithinDistance(entity_pos: Vec2, camera_pos: Vec2, max_distance: f32) bool {
        const dx = entity_pos.x - camera_pos.x;
        const dy = entity_pos.y - camera_pos.y;
        const distance_squared = dx * dx + dy * dy;
        const max_distance_squared = max_distance * max_distance;

        return distance_squared <= max_distance_squared;
    }

    /// Cull entities based on distance from camera
    pub fn cullByDistance(
        comptime EntityType: type,
        entities: []const EntityType,
        camera_pos: Vec2,
        max_distance: f32,
        getPosition: fn (entity: EntityType) Vec2,
    ) []const bool {
        var visibility = std.ArrayList(bool).init(std.heap.page_allocator);

        for (entities) |entity| {
            const pos = getPosition(entity);
            const is_visible = isWithinDistance(pos, camera_pos, max_distance);
            visibility.append(is_visible) catch continue;
        }

        return visibility.toOwnedSlice() catch &[_]bool{};
    }
};

/// Level-of-detail culling based on entity size and distance
pub const LODCuller = struct {
    pub const LODLevel = enum {
        high, // Full detail
        medium, // Reduced detail
        low, // Minimal detail
        hidden, // Not rendered
    };

    /// Determine LOD level based on entity screen size
    pub fn getLODLevel(world_size: f32, camera_zoom: f32, distance: f32) LODLevel {
        const screen_size = world_size * camera_zoom;
        const adjusted_size = screen_size / (distance + 1.0); // Prevent division by zero

        if (adjusted_size >= 50.0) return .high;
        if (adjusted_size >= 20.0) return .medium;
        if (adjusted_size >= 5.0) return .low;
        return .hidden;
    }

    /// Cull entities based on level of detail
    pub fn cullByLOD(
        comptime EntityType: type,
        entities: []const EntityType,
        context: CoordinateContext,
        getTransform: fn (entity: EntityType) struct { pos: Vec2, size: f32 },
    ) []const LODLevel {
        var lod_levels = std.ArrayList(LODLevel).init(std.heap.page_allocator);

        for (entities) |entity| {
            const transform = getTransform(entity);
            const dx = transform.pos.x - context.camera_position.x;
            const dy = transform.pos.y - context.camera_position.y;
            const distance = @sqrt(dx * dx + dy * dy);

            const lod = getLODLevel(transform.size, context.camera_zoom, distance);
            lod_levels.append(lod) catch continue;
        }

        return lod_levels.toOwnedSlice() catch &[_]LODLevel{};
    }
};

/// Statistics for culling performance monitoring
pub const CullingStats = struct {
    total_entities: u32 = 0,
    visible_entities: u32 = 0,
    culled_entities: u32 = 0,
    culling_time_us: u64 = 0,

    pub fn update(self: *CullingStats, total: u32, visible: u32, time_us: u64) void {
        self.total_entities = total;
        self.visible_entities = visible;
        self.culled_entities = total - visible;
        self.culling_time_us = time_us;
    }

    pub fn getCullingRatio(self: *const CullingStats) f32 {
        if (self.total_entities == 0) return 0.0;
        return @as(f32, @floatFromInt(self.culled_entities)) / @as(f32, @floatFromInt(self.total_entities));
    }

    pub fn reset(self: *CullingStats) void {
        self.* = .{};
    }
};
