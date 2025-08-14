const std = @import("std");
const glyph_extractor = @import("glyph_extractor.zig");
const edge_builder = @import("edge_builder.zig");

const log = std.log.scoped(.font_debug);

/// Debug visualization options
pub const DebugOptions = struct {
    show_coverage_map: bool = false,
    show_edge_list: bool = false,
    show_metrics: bool = false,
    show_ascii_art: bool = true,
    log_level: enum { none, info, warn, debug } = .info,
};

/// Visualize bitmap coverage as ASCII art
pub fn printCoverageMap(
    bitmap: []const u8,
    width: u32,
    height: u32,
    codepoint: u32,
) void {
    log.info("Coverage map for '{}' ({}x{}):", .{ @as(u8, @intCast(codepoint)), width, height });
    
    // Print top border
    var border: [256]u8 = undefined;
    var border_len: usize = 0;
    border[border_len] = '+';
    border_len += 1;
    for (0..@min(width, 80)) |_| {
        border[border_len] = '-';
        border_len += 1;
    }
    border[border_len] = '+';
    border_len += 1;
    log.info("{s}", .{border[0..border_len]});
    
    // Print each row
    for (0..@min(height, 40)) |y| {
        var line: [256]u8 = undefined;
        var line_len: usize = 0;
        line[line_len] = '|';
        line_len += 1;
        
        for (0..@min(width, 80)) |x| {
            const idx = y * width + x;
            const coverage = bitmap[idx];
            
            // Map coverage to ASCII intensity
            const char: u8 = if (coverage == 0)
                ' '
            else if (coverage < 64)
                '.'
            else if (coverage < 128)
                ':'
            else if (coverage < 192)
                '*'
            else if (coverage < 255)
                '#'
            else
                '@';
            
            line[line_len] = char;
            line_len += 1;
        }
        
        line[line_len] = '|';
        line_len += 1;
        log.info("{s}", .{line[0..line_len]});
    }
    
    // Print bottom border
    log.info("{s}", .{border[0..border_len]});
}

/// Print detailed bitmap statistics
pub fn printBitmapStats(
    bitmap: []const u8,
    width: u32,
    height: u32,
    codepoint: u32,
) void {
    var non_zero: u32 = 0;
    var total_coverage: u64 = 0;
    var min_coverage: u8 = 255;
    var max_coverage: u8 = 0;
    
    for (bitmap) |pixel| {
        if (pixel > 0) {
            non_zero += 1;
            total_coverage += pixel;
            min_coverage = @min(min_coverage, pixel);
            max_coverage = @max(max_coverage, pixel);
        }
    }
    
    const total_pixels = width * height;
    const coverage_percent = if (total_pixels > 0)
        @as(f32, @floatFromInt(non_zero)) * 100.0 / @as(f32, @floatFromInt(total_pixels))
    else
        0.0;
    
    const avg_coverage = if (non_zero > 0)
        @as(f32, @floatFromInt(total_coverage)) / @as(f32, @floatFromInt(non_zero))
    else
        0.0;
    
    log.info("Bitmap stats for '{}' ({}x{}):", .{ @as(u8, @intCast(codepoint)), width, height });
    log.info("  Pixels filled: {}/{} ({d:.1}%)", .{ non_zero, total_pixels, coverage_percent });
    log.info("  Coverage range: {}-{}", .{ min_coverage, max_coverage });
    log.info("  Average coverage: {d:.1}", .{avg_coverage});
    
    // Check for common issues
    if (coverage_percent < 10) {
        log.warn("  WARNING: Very low coverage - possible rendering issue", .{});
    }
    if (max_coverage < 128 and non_zero > 0) {
        log.warn("  WARNING: Low maximum coverage - possible anti-aliasing issue", .{});
    }
}

/// Print edge list for debugging
pub fn printEdges(edges: []const edge_builder.Edge, max_edges: usize) void {
    log.info("Edge list ({} edges):", .{edges.len});
    
    for (edges[0..@min(edges.len, max_edges)], 0..) |edge, i| {
        log.info("  Edge {}: ({d:.2}, {d:.2}) -> ({d:.2}, {d:.2}) winding={}", .{
            i, edge.x0, edge.y0, edge.x1, edge.y1, edge.winding,
        });
    }
    
    if (edges.len > max_edges) {
        log.info("  ... and {} more edges", .{edges.len - max_edges});
    }
}

/// Print glyph outline information
pub fn printOutline(outline: glyph_extractor.GlyphOutline) void {
    log.info("Glyph outline:", .{});
    log.info("  Contours: {}", .{outline.contours.len});
    log.info("  Bounds: ({d:.2}, {d:.2}) to ({d:.2}, {d:.2})", .{
        outline.bounds.x_min,
        outline.bounds.y_min,
        outline.bounds.x_max,
        outline.bounds.y_max,
    });
    log.info("  Size: {d:.2} x {d:.2}", .{
        outline.bounds.width(),
        outline.bounds.height(),
    });
    log.info("  Advance: {d:.2}", .{outline.metrics.advance_width});
    
    for (outline.contours, 0..) |contour, i| {
        var on_curve: u32 = 0;
        var off_curve: u32 = 0;
        for (contour.points) |point| {
            if (point.on_curve) {
                on_curve += 1;
            } else {
                off_curve += 1;
            }
        }
        log.info("  Contour {}: {} points ({} on-curve, {} off-curve)", .{
            i, contour.points.len, on_curve, off_curve,
        });
    }
}

/// Compare two bitmaps and report differences
pub fn compareBitmaps(
    bitmap1: []const u8,
    bitmap2: []const u8,
    width: u32,
    height: u32,
) f32 {
    if (bitmap1.len != bitmap2.len) {
        log.warn("Bitmaps have different sizes: {} vs {}", .{ bitmap1.len, bitmap2.len });
        return 0.0;
    }
    
    var differences: u32 = 0;
    var total_diff: u64 = 0;
    
    for (bitmap1, bitmap2) |p1, p2| {
        if (p1 != p2) {
            differences += 1;
            total_diff += @abs(@as(i32, p1) - @as(i32, p2));
        }
    }
    
    const similarity = 100.0 - (@as(f32, @floatFromInt(differences)) * 100.0 / @as(f32, @floatFromInt(bitmap1.len)));
    const avg_diff = if (differences > 0)
        @as(f32, @floatFromInt(total_diff)) / @as(f32, @floatFromInt(differences))
    else
        0.0;
    
    log.info("Bitmap comparison:", .{});
    log.info("  Size: {}x{} ({} pixels)", .{ width, height, bitmap1.len });
    log.info("  Differences: {} pixels", .{differences});
    log.info("  Similarity: {d:.1}%", .{similarity});
    log.info("  Average difference: {d:.1}", .{avg_diff});
    
    return similarity;
}

/// Debug helper to save bitmap to file (for external visualization)
pub fn saveBitmapToPGM(
    allocator: std.mem.Allocator,
    bitmap: []const u8,
    width: u32,
    height: u32,
    filename: []const u8,
) !void {
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    
    // Write PGM header
    const header = try std.fmt.allocPrint(allocator, "P2\n{} {}\n255\n", .{ width, height });
    defer allocator.free(header);
    try file.writeAll(header);
    
    // Write pixel data
    for (0..height) |y| {
        for (0..width) |x| {
            const pixel = bitmap[y * width + x];
            const pixel_str = try std.fmt.allocPrint(allocator, "{} ", .{pixel});
            defer allocator.free(pixel_str);
            try file.writeAll(pixel_str);
        }
        try file.writeAll("\n");
    }
    
    log.info("Saved bitmap to {s}", .{filename});
}

// ============================================================================
// Text Quality Analysis (merged from text_quality.zig)
// ============================================================================

/// Quality metrics for rendered text
pub const QualityMetrics = struct {
    coverage_percent: f32,      // Percentage of pixels with non-zero coverage
    edge_sharpness: f32,       // Sharpness of edges (0-100)
    contrast_ratio: f32,       // Contrast between text and background
    kerning_consistency: f32,  // Consistency of character spacing
    subpixel_accuracy: f32,    // Accuracy of subpixel positioning
    overall_score: f32,        // Combined quality score (0-100)
};

/// Analyze bitmap data for quality metrics
pub fn analyzeBitmap(
    bitmap: []const u8,
    width: u32,
    height: u32,
) QualityMetrics {
    var coverage_count: u32 = 0;
    var edge_pixels: u32 = 0;
    var min_value: u8 = 255;
    var max_value: u8 = 0;
    
    // First pass: basic statistics
    for (bitmap) |pixel| {
        if (pixel > 0) coverage_count += 1;
        if (pixel < min_value) min_value = pixel;
        if (pixel > max_value) max_value = pixel;
    }
    
    // Calculate coverage percentage
    const total_pixels = width * height;
    const coverage_percent = if (total_pixels > 0)
        @as(f32, @floatFromInt(coverage_count)) / @as(f32, @floatFromInt(total_pixels)) * 100.0
    else
        0.0;
    
    // Second pass: edge detection
    for (0..height) |y| {
        for (0..width) |x| {
            const idx = y * width + x;
            const current = bitmap[idx];
            
            // Check if this is an edge pixel
            if (current > 0 and current < 255) {
                // Check neighbors
                var is_edge = false;
                
                if (x > 0) {
                    const left = bitmap[idx - 1];
                    if (@abs(@as(i32, current) - @as(i32, left)) > 50) is_edge = true;
                }
                if (x < width - 1) {
                    const right = bitmap[idx + 1];
                    if (@abs(@as(i32, current) - @as(i32, right)) > 50) is_edge = true;
                }
                if (y > 0) {
                    const top = bitmap[idx - width];
                    if (@abs(@as(i32, current) - @as(i32, top)) > 50) is_edge = true;
                }
                if (y < height - 1) {
                    const bottom = bitmap[idx + width];
                    if (@abs(@as(i32, current) - @as(i32, bottom)) > 50) is_edge = true;
                }
                
                if (is_edge) edge_pixels += 1;
            }
        }
    }
    
    // Calculate edge sharpness (fewer intermediate values = sharper)
    const edge_sharpness = if (coverage_count > 0) 
        100.0 - (@as(f32, @floatFromInt(edge_pixels)) / @as(f32, @floatFromInt(coverage_count)) * 100.0)
    else
        0.0;
    
    // Calculate contrast ratio
    const contrast_ratio = @as(f32, max_value - min_value) / 255.0 * 100.0;
    
    // Placeholder for advanced metrics
    const kerning_consistency = 75.0;  // TODO: Implement actual kerning analysis
    const subpixel_accuracy = 80.0;    // TODO: Implement subpixel analysis
    
    // Calculate overall score
    const overall_score = (coverage_percent * 0.2 +
                          edge_sharpness * 0.3 +
                          contrast_ratio * 0.2 +
                          kerning_consistency * 0.15 +
                          subpixel_accuracy * 0.15);
    
    return QualityMetrics{
        .coverage_percent = coverage_percent,
        .edge_sharpness = edge_sharpness,
        .contrast_ratio = contrast_ratio,
        .kerning_consistency = kerning_consistency,
        .subpixel_accuracy = subpixel_accuracy,
        .overall_score = @min(100.0, overall_score),
    };
}

/// Generate quality report for console output
pub fn generateQualityReport(metrics: QualityMetrics, font_size: f32, method: []const u8) void {
    log.info("=== Text Quality Report ===", .{});
    log.info("Font Size: {d:.1}pt | Method: {s}", .{ font_size, method });
    log.info("Coverage: {d:.1}%", .{metrics.coverage_percent});
    log.info("Edge Sharpness: {d:.1}%", .{metrics.edge_sharpness});
    log.info("Contrast: {d:.1}%", .{metrics.contrast_ratio});
    log.info("Kerning: {d:.1}%", .{metrics.kerning_consistency});
    log.info("Subpixel: {d:.1}%", .{metrics.subpixel_accuracy});
    log.info("Overall Score: {d:.1}/100", .{metrics.overall_score});
    
    // Quality assessment
    const assessment = if (metrics.overall_score >= 80)
        "EXCELLENT"
    else if (metrics.overall_score >= 60)
        "GOOD"
    else if (metrics.overall_score >= 40)
        "FAIR"
    else
        "POOR";
    
    log.info("Assessment: {s}", .{assessment});
}

/// Compare two quality metrics and return improvement percentage
pub fn compareMetrics(before: QualityMetrics, after: QualityMetrics) f32 {
    return after.overall_score - before.overall_score;
}

/// Get recommended improvements based on metrics
pub fn getRecommendations(metrics: QualityMetrics) []const u8 {
    if (metrics.coverage_percent < 50) {
        return "Increase glyph coverage - check rasterization";
    } else if (metrics.edge_sharpness < 60) {
        return "Improve edge quality - consider oversampling";
    } else if (metrics.contrast_ratio < 70) {
        return "Enhance contrast - check anti-aliasing";
    } else if (metrics.kerning_consistency < 70) {
        return "Fix character spacing - check metrics";
    } else if (metrics.subpixel_accuracy < 70) {
        return "Improve subpixel precision - use fixed-point";
    } else {
        return "Quality acceptable - minor tuning possible";
    }
}