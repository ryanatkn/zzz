const std = @import("std");

/// A bitmap representation for font rendering
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

/// ASCII debug representation utilities
pub const AsciiDebug = struct {
    /// ASCII characters representing different coverage levels
    pub const CHARS = [_]u8{ ' ', '.', ':', '+', '*', '#', '@' };
    
    /// Convert grayscale value to ASCII character for debugging
    pub fn toChar(value: u8) u8 {
        const index = (value * (CHARS.len - 1)) / 255;
        return CHARS[index];
    }
    
    /// Convert ASCII character back to grayscale value
    pub fn fromChar(char: u8) u8 {
        for (CHARS, 0..) |c, i| {
            if (c == char) {
                return @intCast((i * 255) / (CHARS.len - 1));
            }
        }
        return 0; // Default to empty if character not found
    }
    
    /// Print bitmap as ASCII art to stdout
    pub fn print(bitmap: Bitmap) void {
        var y: u32 = 0;
        while (y < bitmap.height) : (y += 1) {
            var x: u32 = 0;
            while (x < bitmap.width) : (x += 1) {
                const value = bitmap.getPixel(x, y);
                const char = toChar(value);
                std.debug.print("{c}", .{char});
            }
            std.debug.print("\n", .{});
        }
    }
};

/// Bitmap conversion utilities
pub const Convert = struct {
    /// Convert ASCII debug bitmap to standard grayscale bitmap
    pub fn asciiToGrayscale(allocator: std.mem.Allocator, ascii_bitmap: []const u8, width: u32, height: u32) !Bitmap {
        const bitmap = try Bitmap.init(allocator, width, height);
        
        for (ascii_bitmap, 0..) |char, i| {
            bitmap.data[i] = AsciiDebug.fromChar(char);
        }
        
        return bitmap;
    }
    
    /// Create a copy of an existing bitmap
    pub fn copy(allocator: std.mem.Allocator, source: Bitmap) !Bitmap {
        const bitmap = try Bitmap.init(allocator, source.width, source.height);
        @memcpy(bitmap.data, source.data);
        return bitmap;
    }
};