const std = @import("std");
const font_types = @import("font_types.zig");
const bitmap = @import("../core/bitmap.zig");

/// Visual debugging helper for bitmaps
pub const BitmapVisualizer = struct {
    /// Convert bitmap to ASCII art for console output
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

/// Test data generators for font testing
pub const TestData = struct {
    /// Create a simple rectangular glyph outline for testing
    pub fn createRectangleOutline(allocator: std.mem.Allocator, x: i32, y: i32, width: i32, height: i32) !font_types.GlyphOutline {
        const points = try allocator.alloc(font_types.Point, 4);
        
        // Counter-clockwise winding
        points[0] = .{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
        points[1] = .{ .x = @floatFromInt(x), .y = @floatFromInt(y + height) };
        points[2] = .{ .x = @floatFromInt(x + width), .y = @floatFromInt(y + height) };
        points[3] = .{ .x = @floatFromInt(x + width), .y = @floatFromInt(y) };
        
        const on_curve = try allocator.alloc(bool, 4);
        @memset(on_curve, true);
        
        const contours = try allocator.alloc(font_types.Contour, 1);
        contours[0] = .{
            .points = points,
            .on_curve = on_curve,
        };
        
        return font_types.GlyphOutline{
            .contours = contours,
            .bounds = .{
                .x_min = @intCast(x),
                .y_min = @intCast(y),
                .x_max = @intCast(x + width),
                .y_max = @intCast(y + height),
            },
            .metrics = .{
                .advance_width = @intCast(width + 10),
                .left_side_bearing = @intCast(x),
            },
        };
    }
    
    /// Create a triangle outline for testing
    pub fn createTriangleOutline(allocator: std.mem.Allocator) !font_types.GlyphOutline {
        const points = try allocator.alloc(font_types.Point, 3);
        
        // Simple triangle
        points[0] = .{ .x = 50, .y = 100 };
        points[1] = .{ .x = 100, .y = 200 };
        points[2] = .{ .x = 150, .y = 100 };
        
        const on_curve = try allocator.alloc(bool, 3);
        @memset(on_curve, true);
        
        const contours = try allocator.alloc(font_types.Contour, 1);
        contours[0] = .{
            .points = points,
            .on_curve = on_curve,
        };
        
        return font_types.GlyphOutline{
            .contours = contours,
            .bounds = .{
                .x_min = 50,
                .y_min = 100,
                .x_max = 150,
                .y_max = 200,
            },
            .metrics = .{
                .advance_width = 200,
                .left_side_bearing = 50,
            },
        };
    }
    
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
};

/// Test assertions for font rendering
pub const Assertions = struct {
    /// Verify that a bitmap has expected coverage
    pub fn expectCoverage(data: []const u8, min_coverage: f32, max_coverage: f32) !void {
        const coverage = BitmapVisualizer.calculateCoverage(data);
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

/// Performance measurement helpers
pub const Benchmark = struct {
    start_time: i64,
    name: []const u8,
    
    pub fn start(name: []const u8) Benchmark {
        return .{
            .start_time = std.time.microTimestamp(),
            .name = name,
        };
    }
    
    pub fn end(self: Benchmark) void {
        const elapsed = std.time.microTimestamp() - self.start_time;
        std.debug.print("[BENCH] {s}: {}µs\n", .{ self.name, elapsed });
    }
    
    pub fn endExpectUnder(self: Benchmark, max_microseconds: i64) !void {
        const elapsed = std.time.microTimestamp() - self.start_time;
        std.debug.print("[BENCH] {s}: {}µs (max: {}µs)\n", .{ self.name, elapsed, max_microseconds });
        if (elapsed > max_microseconds) {
            return error.BenchmarkExceeded;
        }
    }
};