const std = @import("std");
const c = @import("../c.zig");
const types = @import("../types.zig");
const font_manager = @import("../font/manager.zig");
const font_config = @import("../font/config.zig");
const font_debug = @import("../font/font_debug.zig");

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
    contrast_ratio: f32,       // Contrast between text and background
    kerning_consistency: f32,  // Spacing consistency
    subpixel_accuracy: f32,    // Accuracy of subpixel positioning  
    overall_score: f32,        // Combined quality score (0-100)
    render_time_us: u64,       // Time to render in microseconds
    cache_hit: bool,           // Whether this was cached
    
    /// Convert from font_debug QualityMetrics
    pub fn fromQualityMetrics(metrics: font_debug.QualityMetrics, render_time: u64, is_cached: bool) TextStats {
        return TextStats{
            .coverage_percent = metrics.coverage_percent,
            .edge_sharpness = metrics.edge_sharpness,
            .contrast_ratio = metrics.contrast_ratio,
            .kerning_consistency = metrics.kerning_consistency,
            .subpixel_accuracy = metrics.subpixel_accuracy,
            .overall_score = metrics.overall_score,
            .render_time_us = render_time,
            .cache_hit = is_cached,
        };
    }
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
    
    /// Calculate text quality metrics with improved estimation
    /// TODO: For real bitmap analysis, use `analyzeTexturePixels` when GPU->CPU readback is implemented
    pub fn calculateTextStats(self: *Self, texture: TextTexture, text: []const u8) !TextStats {
        _ = self;
        
        // Enhanced quality estimation based on texture properties and known rendering characteristics
        const base_coverage = switch (texture.method) {
            .bitmap => 75.0,
            .sdf => 85.0,
            .oversampled_2x => 80.0,
            .oversampled_4x => 90.0,
            .cached => 75.0,
        };
        
        // Size-dependent quality adjustments (based on known font rendering issues)
        const size_factor: f32 = if (texture.font_size < 12.0)
            0.5  // Small sizes are problematic
        else if (texture.font_size < 16.0)
            0.7  // Still issues but better
        else if (texture.font_size < 24.0)
            0.9  // Generally good
        else if (texture.font_size <= 48.0)
            1.0  // Optimal range
        else
            0.95; // Very large sizes might have minor issues
        
        const coverage_percent = base_coverage * size_factor;
        
        // Edge sharpness based on method and size
        const base_sharpness = switch (texture.method) {
            .bitmap => 70.0,
            .sdf => 90.0,
            .oversampled_2x => 80.0,
            .oversampled_4x => 85.0,
            .cached => 70.0,
        };
        const edge_sharpness = base_sharpness * size_factor;
        
        // Contrast estimation
        const contrast_ratio = if (texture.font_size < 12.0)
            60.0  // Poor contrast at small sizes
        else
            85.0; // Good contrast at readable sizes
            
        // Kerning consistency (text length affects this)
        const text_length = @as(f32, @floatFromInt(text.len));
        const kerning_consistency = if (text_length > 10)
            75.0  // Longer text may have kerning issues
        else
            85.0; // Short text generally consistent
            
        // Subpixel accuracy based on size  
        const subpixel_accuracy = if (texture.font_size < 16.0)
            50.0  // Poor subpixel positioning at small sizes
        else
            80.0; // Better at larger sizes
            
        // Calculate overall score
        const overall_score = (coverage_percent * 0.25 +
                               edge_sharpness * 0.25 +
                               contrast_ratio * 0.20 +
                               kerning_consistency * 0.15 +
                               subpixel_accuracy * 0.15);
        
        return TextStats{
            .coverage_percent = @min(100.0, coverage_percent),
            .edge_sharpness = @min(100.0, edge_sharpness),
            .contrast_ratio = @min(100.0, contrast_ratio),
            .kerning_consistency = @min(100.0, kerning_consistency),
            .subpixel_accuracy = @min(100.0, subpixel_accuracy),
            .overall_score = @min(100.0, overall_score),
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
    
    /// Future method for real bitmap pixel analysis (requires GPU->CPU texture readback)
    /// This would use font_debug.analyzeBitmap for accurate quality metrics
    fn analyzeTexturePixels(self: *Self, texture: TextTexture) !font_debug.QualityMetrics {
        _ = self;
        _ = texture;
        // TODO: Implement SDL_DownloadFromGPUTexture equivalent
        // 1. Create CPU transfer buffer
        // 2. Copy GPU texture to CPU buffer
        // 3. Extract bitmap pixel data
        // 4. Call font_debug.analyzeBitmap(bitmap, width, height)
        // 5. Return real quality metrics
        return error.NotImplemented;
    }
};