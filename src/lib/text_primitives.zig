const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const font_manager = @import("font_manager.zig");
const font_config = @import("font_config.zig");

const Vec2 = types.Vec2;
const Color = types.Color;

/// Text rendering method enumeration
pub const RenderMethod = enum {
    bitmap,         // Direct bitmap rasterization at target size
    sdf,           // Signed Distance Field rendering
    oversampled_2x, // Render at 2x size then downsample
    oversampled_4x, // Render at 4x size then downsample
    cached,        // Use persistent texture caching
};

/// Text texture with metadata
pub const TextTexture = struct {
    texture: *c.sdl.SDL_GPUTexture,
    width: u32,
    height: u32,
    method: RenderMethod,
    font_size: f32,
    render_time_us: u64 = 0,  // Microseconds to render
    quality_score: f32 = 0,   // 0-100 quality metric
    
    pub fn deinit(self: TextTexture, device: *c.sdl.SDL_GPUDevice) void {
        c.sdl.SDL_ReleaseGPUTexture(device, self.texture);
    }
};

/// Text rendering statistics
pub const TextStats = struct {
    coverage_percent: f32,      // Percentage of pixels with coverage
    edge_sharpness: f32,       // Edge quality metric
    kerning_consistency: f32,  // Spacing consistency
    render_time_us: u64,       // Time to render in microseconds
    cache_hit: bool,           // Whether this was cached
};

/// Core text primitive operations
pub const TextPrimitives = struct {
    allocator: std.mem.Allocator,
    device: *c.sdl.SDL_GPUDevice,
    font_mgr: *font_manager.FontManager,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice, fm: *font_manager.FontManager) Self {
        return Self{
            .allocator = allocator,
            .device = device,
            .font_mgr = fm,
        };
    }
    
    /// Create text texture using specified method
    pub fn createTextTexture(
        self: *Self,
        text: []const u8,
        font_size: f32,
        method: RenderMethod,
        color: Color,
    ) !TextTexture {
        const start_time = std.time.microTimestamp();
        
        const texture = switch (method) {
            .bitmap => try self.createBitmapText(text, font_size, color),
            .sdf => try self.createSDFText(text, font_size, color),
            .oversampled_2x => try self.createOversampledText(text, font_size, 2.0, color),
            .oversampled_4x => try self.createOversampledText(text, font_size, 4.0, color),
            .cached => try self.createCachedText(text, font_size, color),
        };
        
        const end_time = std.time.microTimestamp();
        texture.render_time_us = @intCast(end_time - start_time);
        
        return texture;
    }
    
    /// Create bitmap text at exact size
    fn createBitmapText(self: *Self, text: []const u8, font_size: f32, color: Color) !TextTexture {
        const result = try self.font_mgr.renderTextToTexture(
            text,
            .button,
            font_size,
            color,
        );
        
        return TextTexture{
            .texture = result.texture,
            .width = result.width,
            .height = result.height,
            .method = .bitmap,
            .font_size = font_size,
        };
    }
    
    /// Create SDF text (placeholder - not yet implemented)
    fn createSDFText(self: *Self, text: []const u8, font_size: f32, color: Color) !TextTexture {
        // For now, fall back to bitmap
        // TODO: Implement proper SDF generation
        return try self.createBitmapText(text, font_size, color);
    }
    
    /// Create oversampled text (render larger, then downsample)
    fn createOversampledText(self: *Self, text: []const u8, font_size: f32, scale: f32, color: Color) !TextTexture {
        // Render at larger size
        const large_size = font_size * scale;
        const large_result = try self.font_mgr.renderTextToTexture(
            text,
            .button,
            large_size,
            color,
        );
        
        // For now, return the large texture directly
        // TODO: Implement proper downsampling
        return TextTexture{
            .texture = large_result.texture,
            .width = @intFromFloat(@as(f32, @floatFromInt(large_result.width)) / scale),
            .height = @intFromFloat(@as(f32, @floatFromInt(large_result.height)) / scale),
            .method = if (scale == 2.0) .oversampled_2x else .oversampled_4x,
            .font_size = font_size,
        };
    }
    
    /// Create cached text (uses persistent texture system)
    fn createCachedText(self: *Self, text: []const u8, font_size: f32, color: Color) !TextTexture {
        // For now, use regular bitmap
        // TODO: Hook into persistent_text.zig
        return try self.createBitmapText(text, font_size, color);
    }
    
    /// Calculate text quality metrics
    pub fn calculateTextStats(self: *Self, texture: TextTexture, text: []const u8) !TextStats {
        _ = self;
        _ = text;
        
        // Placeholder metrics
        // TODO: Implement actual quality analysis
        return TextStats{
            .coverage_percent = switch (texture.method) {
                .bitmap => 75.0,
                .sdf => 85.0,
                .oversampled_2x => 80.0,
                .oversampled_4x => 90.0,
                .cached => 75.0,
            },
            .edge_sharpness = switch (texture.font_size) {
                0...12 => 40.0,
                13...24 => 70.0,
                25...48 => 85.0,
                else => 95.0,
            },
            .kerning_consistency = 80.0,
            .render_time_us = texture.render_time_us,
            .cache_hit = texture.method == .cached,
        };
    }
    
    /// Get quality color based on score
    pub fn getQualityColor(score: f32) Color {
        if (score >= 80) return Color.fromRGB(0, 255, 0);    // Green - good
        if (score >= 60) return Color.fromRGB(255, 255, 0);  // Yellow - okay
        return Color.fromRGB(255, 0, 0);                      // Red - poor
    }
    
    /// Format method name for display
    pub fn getMethodName(method: RenderMethod) []const u8 {
        return switch (method) {
            .bitmap => "Bitmap",
            .sdf => "SDF",
            .oversampled_2x => "2x AA",
            .oversampled_4x => "4x AA",
            .cached => "Cached",
        };
    }
};