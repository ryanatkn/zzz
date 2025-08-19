const std = @import("std");
const testing = std.testing;
const ttf_parser = @import("ttf_parser.zig");
const rasterizer_core = @import("rasterizer_core.zig");
const test_helpers = @import("test_helpers.zig");

// Test to analyze capital letter alignment issues
test "capital letter alignment analysis" {
    const allocator = testing.allocator;
    
    // Initialize loggers for font system
    try test_helpers.initTestLoggers(allocator);
    defer test_helpers.deinitTestLoggers();
    
    // Try to load DM Sans font
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Font file not found: {s} - skipping test\n", .{font_path});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    std.debug.print("\n🔍 CAPITAL LETTER ALIGNMENT ANALYSIS\n", .{});
    std.debug.print("=" ** 80 ++ "\n", .{});
    
    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    defer parser.deinit();
    
    // Create rasterizer
    var rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    // Test lowercase vs capital alignment
    const test_chars = "nNaAzZ"; // Mix of lowercase and capitals
    
    std.debug.print("\nAnalyzing mixed case characters: ", .{});
    for (test_chars) |c| {
        std.debug.print("{c} ", .{c});
    }
    std.debug.print("\n\n", .{});
    
    // Collect data for comparison
    var char_data: [6]struct {
        char: u8,
        is_capital: bool,
        y_min: f32,
        y_max: f32,
        bearing_y: f32,
        first_ink_row: ?u32,
        last_ink_row: ?u32,
        expected_baseline_row: f32,
        distance_from_baseline_to_ink: f32,
    } = undefined;
    
    for (test_chars, 0..) |char, idx| {
        const is_capital = char >= 'A' and char <= 'Z';
        
        const outline = rasterizer.extractor.extractGlyph(char) catch |err| {
            std.debug.print("Failed to extract '{}': {}\n", .{char, err});
            continue;
        };
        defer outline.deinit(allocator);
        
        const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch |err| {
            std.debug.print("Failed to rasterize '{}': {}\n", .{char, err});
            continue;
        };
        defer allocator.free(rasterized.bitmap);
        
        // Analyze bitmap content
        const width_u32 = @as(u32, @intFromFloat(@ceil(rasterized.width)));
        const height_u32 = @as(u32, @intFromFloat(@ceil(rasterized.height)));
        
        var first_ink_row: ?u32 = null;
        var last_ink_row: ?u32 = null;
        
        if (rasterized.bitmap.len > 0) {
            for (0..height_u32) |y| {
                var has_ink = false;
                for (0..width_u32) |x| {
                    const pixel_idx = y * width_u32 + x;
                    if (pixel_idx < rasterized.bitmap.len and rasterized.bitmap[pixel_idx] > 50) {
                        has_ink = true;
                        break;
                    }
                }
                
                if (has_ink) {
                    if (first_ink_row == null) first_ink_row = @intCast(y);
                    last_ink_row = @intCast(y);
                }
            }
        }
        
        // Calculate expected baseline using new rasterizer logic
        const font_descender = @as(f32, @floatFromInt(-rasterizer.metrics.descender)) * rasterizer.scale;
        const baseline_from_bottom = font_descender + 1.0;
        const expected_baseline_from_top = @as(f32, @floatFromInt(height_u32)) - baseline_from_bottom;
        
        const distance_from_baseline_to_ink = if (first_ink_row != null) 
            expected_baseline_from_top - @as(f32, @floatFromInt(first_ink_row.?))
        else 
            0.0;
        
        char_data[idx] = .{
            .char = char,
            .is_capital = is_capital,
            .y_min = outline.bounds.y_min,
            .y_max = outline.bounds.y_max,
            .bearing_y = rasterized.bearing_y,
            .first_ink_row = first_ink_row,
            .last_ink_row = last_ink_row,
            .expected_baseline_row = expected_baseline_from_top,
            .distance_from_baseline_to_ink = distance_from_baseline_to_ink,
        };
    }
    
    // Print comparison table
    std.debug.print("Character Analysis Table:\n", .{});
    std.debug.print("-" ** 90 ++ "\n", .{});
    std.debug.print("Char | Type | y_min  | y_max  | bearing_y | first_ink | baseline_row | baseline_to_ink\n", .{});
    std.debug.print("-" ** 90 ++ "\n", .{});
    
    for (char_data) |data| {
        const type_str = if (data.is_capital) "CAP " else "low ";
        std.debug.print(" {c}   | {s} | {d:6.2} | {d:6.2} | {d:9.2} | {?:9} | {d:12.1} | {d:15.1}\n", .{
            data.char,
            type_str,
            data.y_min,
            data.y_max,
            data.bearing_y,
            data.first_ink_row,
            data.expected_baseline_row,
            data.distance_from_baseline_to_ink,
        });
    }
    
    std.debug.print("-" ** 90 ++ "\n\n", .{});
    
    // Analyze the differences
    std.debug.print("🎯 CAPITAL VS LOWERCASE ANALYSIS:\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});
    
    // Compare lowercase 'n' with capital 'N'
    const n_data = char_data[0];  // 'n'
    const N_data = char_data[1];  // 'N'
    
    std.debug.print("1. Baseline positioning comparison (n vs N):\n", .{});
    std.debug.print("   'n': baseline at row {d:.1}\n", .{n_data.expected_baseline_row});
    std.debug.print("   'N': baseline at row {d:.1}\n", .{N_data.expected_baseline_row});
    
    if (@abs(n_data.expected_baseline_row - N_data.expected_baseline_row) > 0.1) {
        std.debug.print("   ⚠️ DIFFERENT BASELINE POSITIONS!\n", .{});
    } else {
        std.debug.print("   ✅ Same baseline positions\n", .{});
    }
    
    std.debug.print("\n2. Distance from baseline to first ink:\n", .{});
    std.debug.print("   'n': {d:.1} pixels above baseline\n", .{n_data.distance_from_baseline_to_ink});
    std.debug.print("   'N': {d:.1} pixels above baseline\n", .{N_data.distance_from_baseline_to_ink});
    
    if (@abs(n_data.distance_from_baseline_to_ink - N_data.distance_from_baseline_to_ink) > 1.0) {
        std.debug.print("   ⚠️ SIGNIFICANT DIFFERENCE in ink positioning!\n", .{});
        std.debug.print("   Capital 'N' should align with lowercase 'n' main body\n", .{});
    } else {
        std.debug.print("   ✅ Similar positioning relative to baseline\n", .{});
    }
    
    std.debug.print("\n3. Y-bounds analysis:\n", .{});
    std.debug.print("   'n': y_min={d:.2}, y_max={d:.2} (extends {d:.2} above baseline)\n", 
        .{n_data.y_min, n_data.y_max, n_data.y_max});
    std.debug.print("   'N': y_min={d:.2}, y_max={d:.2} (extends {d:.2} above baseline)\n", 
        .{N_data.y_min, N_data.y_max, N_data.y_max});
    
    if (N_data.y_max > n_data.y_max + 2.0) {
        std.debug.print("   ℹ️ Capital is significantly taller, which is expected\n", .{});
    }
    
    std.debug.print("\n4. bearing_y comparison:\n", .{});
    std.debug.print("   'n': bearing_y = {d:.2}\n", .{n_data.bearing_y});
    std.debug.print("   'N': bearing_y = {d:.2}\n", .{N_data.bearing_y});
    
    if (@abs(n_data.bearing_y - N_data.bearing_y) > 1.0) {
        std.debug.print("   ⚠️ Different bearing_y values may cause alignment issues\n", .{});
        std.debug.print("   This affects where the character is positioned relative to baseline\n", .{});
    } else {
        std.debug.print("   ✅ Similar bearing_y values should align well\n", .{});
    }
    
    std.debug.print("\n" ++ "=" ** 80 ++ "\n", .{});
    std.debug.print("🔧 CAPITAL LETTER DIAGNOSIS:\n", .{});
    
    if (N_data.bearing_y > n_data.bearing_y + 2.0) {
        std.debug.print("ISSUE: Capital letters have higher bearing_y, making them position higher\n", .{});
        std.debug.print("SOLUTION NEEDED: Adjust bearing_y calculation for capitals or layout positioning\n", .{});
    } else if (@abs(N_data.distance_from_baseline_to_ink - n_data.distance_from_baseline_to_ink) > 1.0) {
        std.debug.print("ISSUE: Capitals and lowercase have different baseline-to-ink distances\n", .{});
        std.debug.print("SOLUTION NEEDED: Normalize coordinate system further\n", .{});
    } else {
        std.debug.print("Status: Capital alignment looks mostly correct in test data\n", .{});
        std.debug.print("If visual issues persist, investigate layout positioning logic\n", .{});
    }
    
    std.debug.print("=" ** 80 ++ "\n", .{});
}