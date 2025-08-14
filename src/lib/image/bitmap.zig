const std = @import("std");

/// A bitmap representation for image processing and font rendering
pub const Bitmap = struct {
    data: []u8,
    width: u32,
    height: u32,
    
    /// Create a new bitmap with the given dimensions
    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Bitmap {
        const data = try allocator.alloc(u8, width * height);
        @memset(data, 0);
        return Bitmap{
            .data = data,
            .width = width,
            .height = height,
        };
    }
    
    /// Free the bitmap memory
    pub fn deinit(self: Bitmap, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
    
    /// Get pixel value at coordinates (returns 0 if out of bounds)
    pub fn getPixel(self: Bitmap, x: u32, y: u32) u8 {
        if (x >= self.width or y >= self.height) return 0;
        return self.data[y * self.width + x];
    }
    
    /// Set pixel value at coordinates (does nothing if out of bounds)
    pub fn setPixel(self: Bitmap, x: u32, y: u32, value: u8) void {
        if (x >= self.width or y >= self.height) return;
        self.data[y * self.width + x] = value;
    }
    
    /// Fill entire bitmap with a value
    pub fn fill(self: Bitmap, value: u8) void {
        @memset(self.data, value);
    }
};

/// Coverage levels for anti-aliased rendering
/// Provides standardized grayscale values for different coverage levels
pub const Coverage = struct {
    pub const EMPTY: u8 = 0;           // 0% coverage
    pub const LIGHT: u8 = 64;          // 25% coverage  
    pub const MEDIUM: u8 = 128;        // 50% coverage
    pub const HEAVY: u8 = 192;         // 75% coverage
    pub const FULL: u8 = 255;          // 100% coverage
    
    /// Get coverage level from 0.0-1.0 range
    pub fn fromFloat(coverage: f32) u8 {
        const clamped = @max(0.0, @min(1.0, coverage));
        return @intFromFloat(clamped * 255.0);
    }
    
    /// Get coverage level from boolean (0 or 255)
    pub fn fromBool(inside: bool) u8 {
        return if (inside) FULL else EMPTY;
    }
};

/// Bitmap visualization and debugging utilities
pub const Visualizer = struct {
    /// Convert bitmap to ASCII art for console output with border
    pub fn toAsciiArt(data: []const u8, width: u32, height: u32) void {
        std.debug.print("\n=== Bitmap {}x{} ===\n", .{ width, height });
        
        // Top border
        std.debug.print("+", .{});
        for (0..width) |_| std.debug.print("-", .{});
        std.debug.print("+\n", .{});
        
        // Bitmap content
        for (0..height) |y| {
            std.debug.print("|", .{});
            for (0..width) |x| {
                const pixel = data[y * width + x];
                const char: u8 = switch (pixel) {
                    0 => ' ',
                    1...31 => '.',
                    32...63 => ':',
                    64...95 => '-',
                    96...127 => '=',
                    128...159 => '+',
                    160...191 => '*',
                    192...223 => '%',
                    224...255 => '#',
                };
                std.debug.print("{c}", .{char});
            }
            std.debug.print("|\n", .{});
        }
        
        // Bottom border
        std.debug.print("+", .{});
        for (0..width) |_| std.debug.print("-", .{});
        std.debug.print("+\n", .{});
    }
    
    /// Calculate coverage percentage of non-zero pixels
    pub fn calculateCoverage(data: []const u8) f32 {
        var non_zero: u32 = 0;
        for (data) |pixel| {
            if (pixel > 0) non_zero += 1;
        }
        return @as(f32, @floatFromInt(non_zero)) / @as(f32, @floatFromInt(data.len)) * 100.0;
    }
    
    /// Save bitmap to a simple PGM file (portable graymap)
    pub fn saveToPGM(data: []const u8, width: u32, height: u32, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        
        // PGM header
        try file.writer().print("P2\n", .{}); // ASCII grayscale
        try file.writer().print("{} {}\n", .{ width, height });
        try file.writer().print("255\n", .{}); // Max value
        
        // Pixel data
        for (0..height) |y| {
            for (0..width) |x| {
                const pixel = data[y * width + x];
                try file.writer().print("{} ", .{pixel});
            }
            try file.writer().print("\n", .{});
        }
    }
};

/// Format conversion utilities
pub const Convert = struct {
    /// Convert grayscale bitmap to RGBA format for GPU textures
    pub fn grayscaleToRGBA(allocator: std.mem.Allocator, grayscale_data: []const u8, width: u32, height: u32) ![]u8 {
        const rgba_data = try allocator.alloc(u8, width * height * 4);
        
        for (grayscale_data, 0..) |gray_value, i| {
            const rgba_idx = i * 4;
            // White text on transparent background
            rgba_data[rgba_idx + 0] = 255; // R
            rgba_data[rgba_idx + 1] = 255; // G  
            rgba_data[rgba_idx + 2] = 255; // B
            rgba_data[rgba_idx + 3] = gray_value; // A (coverage as alpha)
        }
        
        return rgba_data;
    }
    
    /// Create a copy of an existing bitmap
    pub fn copy(allocator: std.mem.Allocator, source: Bitmap) !Bitmap {
        const bitmap = try Bitmap.init(allocator, source.width, source.height);
        @memcpy(bitmap.data, source.data);
        return bitmap;
    }
    
    /// Create a copy of raw bitmap data
    pub fn copyData(allocator: std.mem.Allocator, source_data: []const u8) ![]u8 {
        const data = try allocator.alloc(u8, source_data.len);
        @memcpy(data, source_data);
        return data;
    }
};

/// Test pattern generators
pub const TestPatterns = struct {
    /// Create a test bitmap with a checkerboard pattern
    pub fn createCheckerboard(allocator: std.mem.Allocator, width: u32, height: u32, square_size: u32) ![]u8 {
        const data = try allocator.alloc(u8, width * height);
        
        for (0..height) |y| {
            for (0..width) |x| {
                const checker_x = x / square_size;
                const checker_y = y / square_size;
                const is_black = (checker_x + checker_y) % 2 == 0;
                data[y * width + x] = if (is_black) 255 else 0;
            }
        }
        
        return data;
    }
    
    /// Create a gradient pattern for testing
    pub fn createGradient(allocator: std.mem.Allocator, width: u32, height: u32) ![]u8 {
        const data = try allocator.alloc(u8, width * height);
        
        for (0..height) |y| {
            for (0..width) |x| {
                const value = @as(u8, @intCast((x + y) * 255 / (width + height)));
                data[y * width + x] = value;
            }
        }
        
        return data;
    }
};

/// Test assertions for bitmap validation
pub const Assertions = struct {
    /// Verify that a bitmap has expected coverage
    pub fn expectCoverage(data: []const u8, min_coverage: f32, max_coverage: f32) !void {
        const coverage = Visualizer.calculateCoverage(data);
        if (coverage < min_coverage or coverage > max_coverage) {
            std.debug.print("Coverage {d:.2}% outside expected range [{d:.2}%, {d:.2}%]\n", 
                          .{ coverage, min_coverage, max_coverage });
            return error.CoverageOutOfRange;
        }
    }
    
    /// Verify that a bitmap is not empty
    pub fn expectNonEmpty(data: []const u8) !void {
        for (data) |pixel| {
            if (pixel > 0) return; // Found non-zero pixel
        }
        return error.BitmapEmpty;
    }
    
    /// Verify bitmap dimensions
    pub fn expectDimensions(width: u32, height: u32, expected_width: u32, expected_height: u32) !void {
        if (width != expected_width or height != expected_height) {
            std.debug.print("Dimensions {}x{} don't match expected {}x{}\n", 
                          .{ width, height, expected_width, expected_height });
            return error.DimensionMismatch;
        }
    }
};