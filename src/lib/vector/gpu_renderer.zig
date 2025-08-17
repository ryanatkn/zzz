const std = @import("std");
const c = @import("../platform/sdl.zig");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const vector_path = @import("path.zig");
// curve_tessellation functionality removed - using simplified rendering

const Vec2 = math.Vec2;
const Color = colors.Color;
const VectorPath = vector_path.VectorPath;
const QuadraticCurve = vector_path.QuadraticCurve;
const CubicCurve = vector_path.CubicCurve;

/// GPU-accelerated vector graphics renderer
/// Uses vector_path primitives to generate GPU-friendly vertex data
pub const GPUVectorRenderer = struct {
    allocator: std.mem.Allocator,
    device: *c.sdl.SDL_GPUDevice,
    screen_width: f32,
    screen_height: f32,

    // Vector rendering shaders and pipeline (future)
    vector_vs: ?*c.sdl.SDL_GPUShader,
    vector_ps: ?*c.sdl.SDL_GPUShader,
    vector_pipeline: ?*c.sdl.SDL_GPUGraphicsPipeline,

    // Pure procedural rendering - no vertex buffers needed

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice, screen_width: f32, screen_height: f32) Self {
        return Self{
            .allocator = allocator,
            .device = device,
            .screen_width = screen_width,
            .screen_height = screen_height,
            .vector_vs = null,
            .vector_ps = null,
            .vector_pipeline = null,
        };
    }

    pub fn deinit(self: *Self) void {
        // Cleanup GPU resources
        if (self.vector_pipeline) |pipeline| c.sdl.SDL_ReleaseGPUGraphicsPipeline(self.device, pipeline);
        if (self.vector_vs) |shader| c.sdl.SDL_ReleaseGPUShader(self.device, shader);
        if (self.vector_ps) |shader| c.sdl.SDL_ReleaseGPUShader(self.device, shader);
    }

    pub fn updateScreenSize(self: *Self, width: f32, height: f32) void {
        self.screen_width = width;
        self.screen_height = height;
    }

    /// Set tessellation quality for curve rendering
    pub fn setTessellationQuality(self: *Self, quality: enum { fast, medium, high, ultra }) void {
        _ = self;
        _ = quality;
        // Quality settings removed - using simplified rendering
    }

    /// Draw a vector path as filled shape
    pub fn drawPath(
        self: *Self,
        simple_gpu_renderer: anytype, // Use anytype to avoid circular dependency
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        path: *const VectorPath,
        color: Color,
    ) !void {
        _ = cmd_buffer; // No longer needed
        _ = render_pass; // No longer needed

        // For each contour, render as lines using addCircleToTrace for line endpoints
        for (path.contours.items) |*contour| {
            try self.renderContourAsCircles(simple_gpu_renderer, contour, color);
        }
    }

    /// Draw a single quadratic bezier curve
    pub fn drawQuadraticCurve(self: *Self, simple_gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, curve: QuadraticCurve, color: Color, stroke_width: f32) !void {
        _ = self;
        _ = cmd_buffer;
        _ = render_pass;
        
        // Simple line approximation using circles at endpoints
        const radius = stroke_width * 0.5;
        simple_gpu_renderer.addCircleToTrace(curve.start, radius, color);
        simple_gpu_renderer.addCircleToTrace(curve.end, radius, color);
    }

    /// Draw a polygon from a set of points
    pub fn drawPolygon(self: *Self, simple_gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, points: []const Vec2, color: Color, filled: bool) !void {
        _ = self;
        _ = cmd_buffer;
        _ = render_pass;
        
        if (points.len < 3) return; // Need at least 3 points for a polygon

        if (filled) {
            // Simple approximation: draw circles at each vertex
            for (points) |point| {
                simple_gpu_renderer.addCircleToTrace(point, 2.0, color);
            }
        } else {
            // Draw outline as small circles at vertices
            for (points) |point| {
                simple_gpu_renderer.addCircleToTrace(point, 1.0, color);
            }
        }
    }

    /// Render a contour as circles at key points (pure procedural)
    fn renderContourAsCircles(self: *Self, simple_gpu_renderer: anytype, contour: *const vector_path.Contour, color: Color) !void {
        _ = self;
        
        if (contour.points.items.len < 2) return;

        // Render key points as small circles for visualization
        for (contour.points.items) |point| {
            if (point.on_curve) {
                simple_gpu_renderer.addCircleToTrace(point.position, 1.5, color);
            }
        }
    }

    // All rendering methods removed - now using pure procedural generation via addCircleToTrace/addRectToTrace
};

/// Utility functions for vector graphics
pub const VectorUtils = struct {
    /// Create a circle path
    pub fn createCircle(allocator: std.mem.Allocator, center: Vec2, radius: f32, segments: u32) !VectorPath {
        var path = VectorPath.init(allocator);
        var contour = try vector_path.Contour.init(allocator);

        const angle_step = 2.0 * std.math.pi / @as(f32, @floatFromInt(segments));

        for (0..segments) |i| {
            const angle = @as(f32, @floatFromInt(i)) * angle_step;
            const point = vector_path.PathPoint{
                .position = Vec2{
                    .x = center.x + radius * @cos(angle),
                    .y = center.y + radius * @sin(angle),
                },
                .on_curve = true,
            };
            try contour.points.append(point);
        }

        try path.contours.append(contour);
        return path;
    }

    /// Create a rectangle path
    pub fn createRectangle(allocator: std.mem.Allocator, pos: Vec2, size: Vec2) !VectorPath {
        var path = VectorPath.init(allocator);
        var contour = try vector_path.Contour.init(allocator);

        const points = [_]Vec2{
            pos,
            Vec2{ .x = pos.x + size.x, .y = pos.y },
            Vec2{ .x = pos.x + size.x, .y = pos.y + size.y },
            Vec2{ .x = pos.x, .y = pos.y + size.y },
        };

        for (points) |point_pos| {
            const point = vector_path.PathPoint{
                .position = point_pos,
                .on_curve = true,
            };
            try contour.points.append(point);
        }

        try path.contours.append(contour);
        return path;
    }
};
