const std = @import("std");

// Minimal test to debug font rendering issue
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create a simple 5x5 test bitmap
    const width: u32 = 5;
    const height: u32 = 5;
    var bitmap = try allocator.alloc(u8, width * height);
    defer allocator.free(bitmap);
    
    // Initialize to all zeros
    @memset(bitmap, 0);
    
    // Manually set some pixels to create a simple pattern (cross)
    // Middle row
    bitmap[2 * width + 0] = 255;
    bitmap[2 * width + 1] = 255;
    bitmap[2 * width + 2] = 255;
    bitmap[2 * width + 3] = 255;
    bitmap[2 * width + 4] = 255;
    
    // Middle column
    bitmap[0 * width + 2] = 255;
    bitmap[1 * width + 2] = 255;
    bitmap[3 * width + 2] = 255;
    bitmap[4 * width + 2] = 255;
    
    // Print the bitmap
    std.debug.print("Test bitmap ({} x {}):\n", .{width, height});
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const pixel = bitmap[y * width + x];
            if (pixel > 0) {
                std.debug.print("█", .{});
            } else {
                std.debug.print("·", .{});
            }
        }
        std.debug.print("\n", .{});
    }
    
    // Count filled pixels
    var filled: u32 = 0;
    for (bitmap) |pixel| {
        if (pixel != 0) filled += 1;
    }
    std.debug.print("Filled: {}/{} pixels\n", .{filled, bitmap.len});
}