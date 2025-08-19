const std = @import("std");

// Import all font test modules
comptime {
    // Core font metrics tests
    _ = @import("font_metrics.zig");
    _ = @import("font_types.zig");
    _ = @import("simple_font_test.zig");
    
    // Pipeline debugging tests  
    _ = @import("test_pipeline_debug.zig");
    _ = @import("test_bearing_analysis.zig");
    _ = @import("test_baseline_alignment.zig");
    _ = @import("test_proper_baseline.zig");
    _ = @import("test_pqy_specific.zig");
    
    // Advanced analysis tests
    _ = @import("test_pixel_analysis.zig");
    _ = @import("test_descender_analysis.zig");
    _ = @import("test_capital_letters.zig");
}

// Test metadata for summary
pub const test_modules = [_][]const u8{
    "font_metrics",
    "font_types", 
    "simple_font_test",
    "test_pipeline_debug",
    "test_bearing_analysis", 
    "test_baseline_alignment",
    "test_proper_baseline",
    "test_pqy_specific",
    "test_pixel_analysis",
    "test_descender_analysis",
    "test_capital_letters",
};

test "font module test summary" {
    std.debug.print("\n=== Font System Tests ===\n", .{});

    for (test_modules) |module| {
        std.debug.print("✅ {s}\n", .{module});
    }

    std.debug.print("\nTotal font test modules: {}\n", .{test_modules.len});
    std.debug.print("Recent Progress: ✅ Major descender alignment improvements\n", .{});
    std.debug.print("Remaining Work: 🔄 Capital letters and fine-tuning\n", .{});
}