const std = @import("std");
const c = @import("../c.zig");
const types = @import("../types.zig");
const vector_path = @import("path.zig");
const curve_tessellation = @import("../font/curve_tessellation.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
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
    
    // Tessellation configuration
    tessellation_config: curve_tessellation.TessellationConfig,
    
    // Vertex data for batching
    vertex_buffer: std.ArrayList(Vec2),
    color_buffer: std.ArrayList(Color),
    
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
            .tessellation_config = curve_tessellation.QualityPresets.medium,
            .vertex_buffer = std.ArrayList(Vec2).init(allocator),
            .color_buffer = std.ArrayList(Color).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        // Cleanup GPU resources
        if (self.vector_pipeline) |pipeline| c.sdl.SDL_ReleaseGPUGraphicsPipeline(self.device, pipeline);
        if (self.vector_vs) |shader| c.sdl.SDL_ReleaseGPUShader(self.device, shader);
        if (self.vector_ps) |shader| c.sdl.SDL_ReleaseGPUShader(self.device, shader);
        
        self.vertex_buffer.deinit();
        self.color_buffer.deinit();
    }
    
    pub fn updateScreenSize(self: *Self, width: f32, height: f32) void {
        self.screen_width = width;
        self.screen_height = height;
    }
    
    /// Set tessellation quality for curve rendering
    pub fn setTessellationQuality(self: *Self, quality: enum { fast, medium, high, ultra }) void {
        self.tessellation_config = switch (quality) {
            .fast => curve_tessellation.QualityPresets.fast,
            .medium => curve_tessellation.QualityPresets.medium,
            .high => curve_tessellation.QualityPresets.high,
            .ultra => curve_tessellation.QualityPresets.ultra,
        };
    }
    
    /// Draw a vector path as filled shape
    pub fn drawPath(
        self: *Self,
        simple_gpu_renderer: anytype, // Use anytype to avoid circular dependency
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        path: *const VectorPath,
        color: Color
    ) !void {
        // Clear vertex buffers for this path
        self.vertex_buffer.clearRetainingCapacity();
        self.color_buffer.clearRetainingCapacity();
        
        // Tessellate all contours in the path
        for (path.contours.items) |*contour| {
            try self.tessellateContour(contour, color);
        }
        
        // For now, render as individual lines using the simple GPU renderer
        // In the future, this could be optimized with a dedicated vector shader
        try self.renderAsLines(simple_gpu_renderer, cmd_buffer, render_pass);
    }
    
    /// Draw a single quadratic bezier curve
    pub fn drawQuadraticCurve(
        self: *Self,
        simple_gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        curve: QuadraticCurve,
        color: Color,
        stroke_width: f32
    ) !void {
        // Clear buffers
        self.vertex_buffer.clearRetainingCapacity();
        self.color_buffer.clearRetainingCapacity();
        
        // Tessellate the curve
        var tessellator = curve_tessellation.CurveTessellator.init(self.allocator, self.tessellation_config);
        defer tessellator.deinit();
        
        const line_segments = try tessellator.tessellateQuadratic(curve);
        defer self.allocator.free(line_segments);
        
        // Convert to vertex data
        for (line_segments) |segment| {
            try self.vertex_buffer.append(segment.start);
            try self.vertex_buffer.append(segment.end);
            try self.color_buffer.append(color);
            try self.color_buffer.append(color);
        }
        
        // Render as thick lines
        try self.renderAsThickLines(simple_gpu_renderer, cmd_buffer, render_pass, stroke_width);
    }
    
    /// Draw a polygon from a set of points
    pub fn drawPolygon(
        self: *Self,
        simple_gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        points: []const Vec2,
        color: Color,
        filled: bool
    ) !void {
        if (points.len < 3) return; // Need at least 3 points for a polygon
        
        self.vertex_buffer.clearRetainingCapacity();
        self.color_buffer.clearRetainingCapacity();
        
        if (filled) {
            // Triangulate the polygon (simple fan triangulation for convex polygons)
            for (1..points.len - 1) |i| {
                try self.vertex_buffer.append(points[0]);
                try self.vertex_buffer.append(points[i]);
                try self.vertex_buffer.append(points[i + 1]);
                try self.color_buffer.append(color);
                try self.color_buffer.append(color);
                try self.color_buffer.append(color);
            }
            try self.renderAsTriangles(simple_gpu_renderer, cmd_buffer, render_pass);
        } else {
            // Draw as outline
            for (0..points.len) |i| {
                const next_i = (i + 1) % points.len;
                try self.vertex_buffer.append(points[i]);
                try self.vertex_buffer.append(points[next_i]);
                try self.color_buffer.append(color);
                try self.color_buffer.append(color);
            }
            try self.renderAsLines(simple_gpu_renderer, cmd_buffer, render_pass);
        }
    }
    
    /// Tessellate a contour into line segments
    fn tessellateContour(self: *Self, contour: *const vector_path.Contour, color: Color) !void {
        if (contour.points.items.len < 2) return;
        
        var tessellator = curve_tessellation.CurveTessellator.init(self.allocator, self.tessellation_config);
        defer tessellator.deinit();
        
        // Process each segment in the contour
        var i: usize = 0;
        while (i < contour.points.items.len) {
            const current = contour.points.items[i];
            const next_index = (i + 1) % contour.points.items.len;
            const next = contour.points.items[next_index];
            
            if (current.on_curve and next.on_curve) {
                // Straight line segment
                try self.vertex_buffer.append(current.position);
                try self.vertex_buffer.append(next.position);
                try self.color_buffer.append(color);
                try self.color_buffer.append(color);
                i += 1;
            } else if (current.on_curve and !next.on_curve) {
                // Quadratic curve: current -> next (control) -> next+1
                const control = next.position;
                const end_index = (i + 2) % contour.points.items.len;
                const end = contour.points.items[end_index].position;
                
                const curve = QuadraticCurve{
                    .start = current.position,
                    .control = control,
                    .end = end,
                };
                
                const line_segments = try tessellator.tessellateQuadratic(curve);
                defer self.allocator.free(line_segments);
                
                for (line_segments) |segment| {
                    try self.vertex_buffer.append(segment.start);
                    try self.vertex_buffer.append(segment.end);
                    try self.color_buffer.append(color);
                    try self.color_buffer.append(color);
                }
                
                i += 2; // Skip the control point and end point
            } else {
                // Other cases (off-curve to on-curve, etc.)
                try self.vertex_buffer.append(current.position);
                try self.vertex_buffer.append(next.position);
                try self.color_buffer.append(color);
                try self.color_buffer.append(color);
                i += 1;
            }
        }
    }
    
    /// Render accumulated vertex data as lines
    fn renderAsLines(
        self: *Self,
        simple_gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass
    ) !void {
        // Render line pairs
        var i: usize = 0;
        while (i + 1 < self.vertex_buffer.items.len) : (i += 2) {
            const start = self.vertex_buffer.items[i];
            const end = self.vertex_buffer.items[i + 1];
            const color = self.color_buffer.items[i]; // Use first vertex color
            
            // Draw as very thin rectangle (line approximation)
            const line_vec = Vec2{
                .x = end.x - start.x,
                .y = end.y - start.y,
            };
            const length = @sqrt(line_vec.x * line_vec.x + line_vec.y * line_vec.y);
            
            if (length > 0.001) { // Avoid zero-length lines
                simple_gpu_renderer.drawRect(
                    cmd_buffer,
                    render_pass,
                    start,
                    Vec2{ .x = length, .y = 1.0 },
                    color
                );
            }
        }
    }
    
    /// Render accumulated vertex data as thick lines
    fn renderAsThickLines(
        self: *Self,
        simple_gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        thickness: f32
    ) !void {
        var i: usize = 0;
        while (i + 1 < self.vertex_buffer.items.len) : (i += 2) {
            const start = self.vertex_buffer.items[i];
            const end = self.vertex_buffer.items[i + 1];
            const color = self.color_buffer.items[i];
            
            const line_vec = Vec2{
                .x = end.x - start.x,
                .y = end.y - start.y,
            };
            const length = @sqrt(line_vec.x * line_vec.x + line_vec.y * line_vec.y);
            
            if (length > 0.001) {
                // Draw thick line as rectangle
                const center = Vec2{
                    .x = (start.x + end.x) * 0.5,
                    .y = (start.y + end.y) * 0.5,
                };
                
                simple_gpu_renderer.drawRect(
                    cmd_buffer,
                    render_pass,
                    Vec2{
                        .x = center.x - length * 0.5,
                        .y = center.y - thickness * 0.5,
                    },
                    Vec2{ .x = length, .y = thickness },
                    color
                );
            }
        }
    }
    
    /// Render accumulated vertex data as triangles (for filled shapes)
    fn renderAsTriangles(
        self: *Self,
        simple_gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass
    ) !void {
        // For now, approximate triangles as small rectangles
        // In the future, this could use a proper triangle rendering pipeline
        var i: usize = 0;
        while (i + 2 < self.vertex_buffer.items.len) : (i += 3) {
            const v0 = self.vertex_buffer.items[i];
            const v1 = self.vertex_buffer.items[i + 1];
            const v2 = self.vertex_buffer.items[i + 2];
            const color = self.color_buffer.items[i];
            
            // Calculate triangle bounds
            const min_x = @min(@min(v0.x, v1.x), v2.x);
            const max_x = @max(@max(v0.x, v1.x), v2.x);
            const min_y = @min(@min(v0.y, v1.y), v2.y);
            const max_y = @max(@max(v0.y, v1.y), v2.y);
            
            // Draw bounding rectangle (approximation)
            simple_gpu_renderer.drawRect(
                cmd_buffer,
                render_pass,
                Vec2{ .x = min_x, .y = min_y },
                Vec2{ .x = max_x - min_x, .y = max_y - min_y },
                color
            );
        }
    }
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