const std = @import("std");
const testing = std.testing;
const readline = @import("readline.zig");
const kernel = @import("../../kernel/mod.zig");

test "ReadlineInput - basic creation and destruction" {
    const allocator = testing.allocator;
    
    const ri = try readline.ReadlineInput.create(allocator);
    defer readline.ReadlineInput.destroy(ri, allocator);
    
    try testing.expectEqualStrings("readline_input", ri.getName());
    try testing.expectEqualStrings("input", ri.getType());
    try testing.expectEqual(@as(usize, 3), ri.getDependencies().len);
}

test "ReadlineInput - word boundary detection" {
    const allocator = testing.allocator;
    
    var ri = readline.ReadlineInput.init(allocator);
    defer ri.deinit();
    
    // Test word boundary detection
    const test_line = "hello world_123 test";
    try ri.updateWordBoundaries(test_line);
    
    // Should detect word starts at positions 0, 6, 16
    try testing.expectEqual(@as(usize, 3), ri.word_boundaries.items.len);
    try testing.expectEqual(@as(usize, 0), ri.word_boundaries.items[0]);
    try testing.expectEqual(@as(usize, 6), ri.word_boundaries.items[1]);
    try testing.expectEqual(@as(usize, 16), ri.word_boundaries.items[2]);
}

test "ReadlineInput - kill ring management" {
    const allocator = testing.allocator;
    
    var ri = readline.ReadlineInput.init(allocator);
    defer ri.deinit();
    
    // Add items to kill ring
    try ri.addToKillRing("first");
    try ri.addToKillRing("second");
    try ri.addToKillRing("third");
    
    try testing.expectEqual(@as(usize, 3), ri.kill_ring.items.len);
    try testing.expectEqualStrings("first", ri.kill_ring.items[0]);
    try testing.expectEqualStrings("second", ri.kill_ring.items[1]);
    try testing.expectEqualStrings("third", ri.kill_ring.items[2]);
    
    // Test kill ring index
    try testing.expectEqual(@as(usize, 2), ri.kill_ring_index);
}

test "ReadlineInput - selection management" {
    const allocator = testing.allocator;
    
    var ri = readline.ReadlineInput.init(allocator);
    defer ri.deinit();
    
    // Test selection operations
    try testing.expect(ri.selection_start == null);
    try testing.expect(ri.selection_end == null);
    
    ri.startSelection();
    // In a real test we'd have a cursor position
    
    ri.clearSelection();
    try testing.expect(ri.selection_start == null);
    try testing.expect(ri.selection_end == null);
}

test "ReadlineInput - clipboard operations" {
    const allocator = testing.allocator;
    
    var ri = readline.ReadlineInput.init(allocator);
    defer ri.deinit();
    
    // Test clipboard
    try ri.clipboard.appendSlice("test text");
    try testing.expectEqualStrings("test text", ri.clipboard.items);
    
    ri.clipboard.clearRetainingCapacity();
    try testing.expectEqual(@as(usize, 0), ri.clipboard.items.len);
}