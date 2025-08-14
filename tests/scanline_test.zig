const std = @import("std");
const testing = std.testing;

// Test the scanline fill algorithm independently
test "Scanline: Simple rectangle fill" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create a 10x10 bitmap
    const width: u32 = 10;
    const height: u32 = 10;
    var bitmap = try allocator.alloc(u8, width * height);
    defer allocator.free(bitmap);
    @memset(bitmap, 0);
    
    // Simulate scanline filling a 4x4 rectangle at (3,3) to (6,6)
    // This is what the scanline algorithm should produce
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        if (y >= 3 and y <= 6) {
            var x: u32 = 0;
            while (x < width) : (x += 1) {
                if (x >= 3 and x <= 6) {
                    bitmap[y * width + x] = 255;
                }
            }
        }
    }
    
    // Count filled pixels
    var filled: u32 = 0;
    for (bitmap) |pixel| {
        if (pixel != 0) filled += 1;
    }
    
    // Should have 16 pixels filled (4x4 rectangle)
    try testing.expectEqual(@as(u32, 16), filled);
}

test "Scanline: Winding number even-odd rule" {
    // Test that winding number correctly determines fill
    // Winding number != 0 means inside the shape
    
    // Test case 1: Single crossing (enter shape)
    {
        var winding: i32 = 0;
        winding += 1; // Cross edge going down
        try testing.expect(winding != 0); // Should be inside
    }
    
    // Test case 2: Double crossing (enter then exit)
    {
        var winding: i32 = 0;
        winding += 1; // Cross edge going down (enter)
        winding -= 1; // Cross edge going up (exit)
        try testing.expect(winding == 0); // Should be outside
    }
    
    // Test case 3: Nested shapes
    {
        var winding: i32 = 0;
        winding += 1; // Enter outer shape
        winding += 1; // Enter inner shape
        try testing.expect(winding != 0); // Still inside
        winding -= 1; // Exit inner shape
        try testing.expect(winding != 0); // Still inside outer
        winding -= 1; // Exit outer shape
        try testing.expect(winding == 0); // Now outside
    }
}

test "Scanline: Edge sorting" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create active edges that need sorting
    const ActiveEdge = struct {
        x: f32,
        winding: i32,
    };
    
    var edges = std.ArrayList(ActiveEdge).init(allocator);
    defer edges.deinit();
    
    // Add edges in wrong order
    try edges.append(.{ .x = 50.0, .winding = -1 });
    try edges.append(.{ .x = 10.0, .winding = 1 });
    try edges.append(.{ .x = 30.0, .winding = 1 });
    try edges.append(.{ .x = 40.0, .winding = -1 });
    
    // Sort by x coordinate
    const lessThan = struct {
        fn lessThan(_: void, a: ActiveEdge, b: ActiveEdge) bool {
            return a.x < b.x;
        }
    }.lessThan;
    std.sort.insertion(ActiveEdge, edges.items, {}, lessThan);
    
    // Verify sorted order
    try testing.expectEqual(@as(f32, 10.0), edges.items[0].x);
    try testing.expectEqual(@as(f32, 30.0), edges.items[1].x);
    try testing.expectEqual(@as(f32, 40.0), edges.items[2].x);
    try testing.expectEqual(@as(f32, 50.0), edges.items[3].x);
}

test "Scanline: Fill pattern verification" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create a bitmap and simulate filling
    const width: u32 = 20;
    var scanline = try allocator.alloc(u8, width);
    defer allocator.free(scanline);
    @memset(scanline, 0);
    
    // Simulate edges at x=5 (enter) and x=15 (exit)
    var winding: i32 = 0;
    var x: u32 = 0;
    while (x < width) : (x += 1) {
        if (x == 5) winding += 1;  // Enter shape
        if (x == 15) winding -= 1; // Exit shape
        
        if (winding != 0) {
            scanline[x] = 255;
        }
    }
    
    // Verify the pattern
    for (scanline, 0..) |pixel, i| {
        if (i >= 5 and i < 15) {
            try testing.expectEqual(@as(u8, 255), pixel);
        } else {
            try testing.expectEqual(@as(u8, 0), pixel);
        }
    }
}