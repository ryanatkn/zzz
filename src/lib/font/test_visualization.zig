const std = @import("std");
const rasterizer_core = @import("rasterizer_core.zig");

/// Font testing and visualization utilities
pub const FontTestVisualization = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FontTestVisualization {
        return FontTestVisualization{
            .allocator = allocator,
        };
    }

    /// Create a composite bitmap showing all characters aligned on a common baseline
    pub fn createCompositeBitmap(
        self: *FontTestVisualization,
        rasterizer: *rasterizer_core.RasterizerCore,
        test_chars: []const u8,
        output_path: []const u8,
    ) !void {
        std.debug.print("\n🖼️  Creating composite bitmap: {s}...\n", .{output_path});

        // Calculate composite dimensions
        const char_spacing: u32 = 5; // Pixels between characters
        const padding: u32 = 10; // Border padding
        var total_width: u32 = padding * 2;
        var max_height: u32 = 0;

        // Store glyph data for rendering
        var glyphs = std.ArrayList(rasterizer_core.RasterizedGlyph).init(self.allocator);
        defer {
            for (glyphs.items) |glyph| {
                self.allocator.free(glyph.bitmap);
            }
            glyphs.deinit();
        }

        // First pass: calculate dimensions and rasterize all glyphs
        for (test_chars) |char| {
            const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch continue;
            total_width += @as(u32, @intFromFloat(rasterized.width)) + char_spacing;
            max_height = @max(max_height, @as(u32, @intFromFloat(rasterized.height)));
            try glyphs.append(rasterized);
        }
        total_width -= char_spacing; // Remove last spacing

        // Find maximum bearing_y to position baseline correctly
        var max_bearing_y: f32 = 0;
        for (glyphs.items) |glyph| {
            max_bearing_y = @max(max_bearing_y, glyph.bearing_y);
        }
        
        const composite_height = max_height + padding * 2;
        const baseline_y = padding + @as(u32, @intFromFloat(max_bearing_y));

        std.debug.print("Composite dimensions: {}x{}, baseline at y={}\n", .{ total_width, composite_height, baseline_y });

        // Create composite bitmap
        const composite_bitmap = try self.allocator.alloc(u8, total_width * composite_height);
        defer self.allocator.free(composite_bitmap);
        @memset(composite_bitmap, 0); // White background

        // Second pass: render glyphs to composite bitmap
        var current_x: u32 = padding;
        for (glyphs.items, 0..) |glyph, i| {
            _ = test_chars[i]; // Character ID for debugging
            const glyph_width = @as(u32, @intFromFloat(glyph.width));
            const glyph_height = @as(u32, @intFromFloat(glyph.height));
            
            // Calculate glyph position (baseline-aligned)
            const bearing_y_u32 = @as(u32, @intFromFloat(glyph.bearing_y));
            const glyph_y = if (baseline_y >= bearing_y_u32) baseline_y - bearing_y_u32 else 0;
            
            // Copy glyph bitmap to composite
            for (0..glyph_height) |y| {
                for (0..glyph_width) |x| {
                    const src_idx = y * glyph_width + x;
                    const dst_x = current_x + x;
                    const dst_y = glyph_y + y;
                    
                    if (dst_x < total_width and dst_y < composite_height and src_idx < glyph.bitmap.len) {
                        const dst_idx = dst_y * total_width + dst_x;
                        if (dst_idx < composite_bitmap.len) {
                            composite_bitmap[dst_idx] = glyph.bitmap[src_idx];
                        }
                    }
                }
            }

            current_x += glyph_width + char_spacing;
        }

        // Add baseline guide line
        if (baseline_y < composite_height) {
            for (0..total_width) |x| {
                const idx = baseline_y * total_width + x;
                if (idx < composite_bitmap.len) {
                    // Light gray baseline (128 = 50% gray in binary becomes visible pattern)
                    if (x % 4 == 0) composite_bitmap[idx] = 128;
                }
            }
        }

        // Save composite bitmap
        try self.saveBitmapAsPPM(composite_bitmap, total_width, composite_height, output_path);
        std.debug.print("✅ Composite bitmap saved to {s}\n", .{output_path});
    }

    /// Analyze character baseline consistency and print detailed report
    pub fn analyzeBaselineConsistency(
        self: *FontTestVisualization,
        rasterizer: *rasterizer_core.RasterizerCore,
        test_chars: []const u8,
    ) !void {
        std.debug.print("\n📊 BASELINE CONSISTENCY ANALYSIS\n", .{});
        std.debug.print("=" ** 50 ++ "\n", .{});

        var baseline_positions = std.ArrayList(f32).init(self.allocator);
        defer baseline_positions.deinit();

        var character_types = std.HashMap(u8, std.ArrayList(u8), std.hash_map.AutoContext(u8), std.hash_map.default_max_load_percentage).init(self.allocator);
        defer character_types.deinit();

        // Categorize characters and collect baseline data
        for (test_chars) |char| {
            const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch continue;
            defer self.allocator.free(rasterized.bitmap);

            const baseline_y = rasterized.bearing_y;
            try baseline_positions.append(baseline_y);

            // Categorize character
            const category: u8 = if (char >= 'A' and char <= 'Z') 'U' // Uppercase
            else if (char >= 'a' and char <= 'z') 'l' // Lowercase
            else if (char >= '0' and char <= '9') 'n' // Numbers
            else 's'; // Special

            var entry = character_types.getOrPut(category) catch continue;
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList(u8).init(self.allocator);
            }
            entry.value_ptr.append(char) catch continue;
        }

        // Analyze overall baseline consistency
        if (baseline_positions.items.len > 0) {
            var min_baseline: f32 = baseline_positions.items[0];
            var max_baseline: f32 = baseline_positions.items[0];
            var sum: f32 = 0;

            for (baseline_positions.items) |pos| {
                min_baseline = @min(min_baseline, pos);
                max_baseline = @max(max_baseline, pos);
                sum += pos;
            }

            const avg_baseline = sum / @as(f32, @floatFromInt(baseline_positions.items.len));
            const baseline_range = max_baseline - min_baseline;

            std.debug.print("Overall baseline statistics:\n", .{});
            std.debug.print("  Min: {:.1} px, Max: {:.1} px, Avg: {:.1} px\n", .{ min_baseline, max_baseline, avg_baseline });
            std.debug.print("  Range: {:.1} px\n", .{baseline_range});

            if (baseline_range > 5.0) {
                std.debug.print("  ⚠️  Wide baseline range detected - may indicate alignment issues\n", .{});
            } else {
                std.debug.print("  ✅ Baseline consistency looks good\n", .{});
            }
        }

        // Analyze by character type
        std.debug.print("\nBaseline by character type:\n", .{});
        var type_iterator = character_types.iterator();
        while (type_iterator.next()) |entry| {
            const category = entry.key_ptr.*;
            const chars = entry.value_ptr.*;
            defer chars.deinit();

            const type_name = switch (category) {
                'U' => "Uppercase",
                'l' => "Lowercase", 
                'n' => "Numbers",
                's' => "Special",
                else => "Other",
            };

            var type_baselines = std.ArrayList(f32).init(self.allocator);
            defer type_baselines.deinit();

            for (chars.items) |char| {
                const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch continue;
                defer self.allocator.free(rasterized.bitmap);
                try type_baselines.append(rasterized.bearing_y);
            }

            if (type_baselines.items.len > 0) {
                var sum: f32 = 0;
                for (type_baselines.items) |pos| sum += pos;
                const avg = sum / @as(f32, @floatFromInt(type_baselines.items.len));
                std.debug.print("  {s}: avg={:.1} px ({} chars)\n", .{ type_name, avg, type_baselines.items.len });
            }
        }
    }

    /// Save bitmap as PPM with optional coordinate system corrections
    fn saveBitmapAsPPM(
        self: *FontTestVisualization,
        bitmap: []const u8,
        width: u32,
        height: u32,
        filename: []const u8,
    ) !void {
        _ = self;
        
        // Create output directory
        const dirname = std.fs.path.dirname(filename) orelse ".";
        std.fs.cwd().makePath(dirname) catch {};

        const file = std.fs.cwd().createFile(filename, .{}) catch |err| {
            std.debug.print("Could not create bitmap file {s}: {}\n", .{ filename, err });
            return;
        };
        defer file.close();

        // Write PPM header (P2 = grayscale)
        try file.writer().print("P2\n{} {}\n255\n", .{ width, height });

        // Write bitmap data in normal orientation (rasterizer output is correct)
        // No Y-flip needed - our coordinate system produces correct results
        for (0..height) |y| {
            for (0..width) |x| {
                const idx = y * width + x;
                const pixel = if (idx < bitmap.len) bitmap[idx] else 0;
                try file.writer().print("{} ", .{pixel});
            }
            try file.writer().print("\n", .{});
        }
    }

    /// Generate individual character analysis report
    pub fn analyzeCharacter(
        self: *FontTestVisualization,
        rasterizer: *rasterizer_core.RasterizerCore,
        char: u8,
    ) !void {
        std.debug.print("\n🔍 CHARACTER ANALYSIS: '{}' (ASCII {})\n", .{ @as(u21, char), char });
        std.debug.print("-" ** 40 ++ "\n", .{});

        const outline = rasterizer.extractor.extractGlyph(char) catch |err| {
            std.debug.print("❌ Failed to extract glyph: {}\n", .{err});
            return;
        };
        defer outline.deinit(self.allocator);

        const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch |err| {
            std.debug.print("❌ Failed to rasterize glyph: {}\n", .{err});
            return;
        };
        defer self.allocator.free(rasterized.bitmap);

        // Print glyph metrics
        std.debug.print("Outline bounds: x[{:.1}, {:.1}] y[{:.1}, {:.1}]\n", .{
            outline.bounds.x_min, outline.bounds.x_max, 
            outline.bounds.y_min, outline.bounds.y_max,
        });
        std.debug.print("Rasterized: {:.1}x{:.1} px, bearing_x:{:.1}, bearing_y:{:.1}\n", .{
            rasterized.width, rasterized.height, 
            rasterized.bearing_x, rasterized.bearing_y,
        });
        std.debug.print("Advance width: {:.1} px\n", .{rasterized.advance});

        // Analyze baseline relationship
        if (outline.bounds.y_min < 0) {
            std.debug.print("🔽 DESCENDER: extends {:.1} px below baseline\n", .{-outline.bounds.y_min});
        }
        if (outline.bounds.y_max > rasterizer.metrics.getBaselineOffset()) {
            std.debug.print("🔼 ASCENDER: extends {:.1} px above baseline\n", .{outline.bounds.y_max});
        }

        // Print contour information
        std.debug.print("Contours: {} (", .{outline.contours.len});
        for (outline.contours, 0..) |contour, i| {
            std.debug.print("{} pts", .{contour.points.len});
            if (i < outline.contours.len - 1) std.debug.print(", ", .{});
        }
        std.debug.print(")\n", .{});
    }
};