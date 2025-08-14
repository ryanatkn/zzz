const std = @import("std");

pub fn main() !void {
    const value: f32 = 3.14159;
    
    // Test different format options
    std.debug.print("Test 1: {d:.1}\n", .{value});
    std.debug.print("Test 2: {d:5.1}\n", .{value});
    
    // In multiline string
    const str = try std.fmt.allocPrint(std.heap.page_allocator,
        \\Value: {d:.1}
    , .{value});
    defer std.heap.page_allocator.free(str);
    std.debug.print("Result: {s}\n", .{str});
}
