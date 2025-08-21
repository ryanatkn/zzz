/// Content measurement utilities for layout systems
///
/// This module provides utilities for measuring various types of content
/// to determine their natural sizes for layout calculations.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;

/// Content measurement interface
pub const ContentMeasurer = struct {
    /// Function pointer for measuring text content
    measureTextFn: ?*const fn (text: []const u8, font_size: f32, max_width: ?f32) Vec2 = null,
    
    /// Function pointer for measuring image content  
    measureImageFn: ?*const fn (image_data: []const u8) Vec2 = null,
    
    /// Function pointer for measuring custom content
    measureCustomFn: ?*const fn (content_data: *anyopaque) Vec2 = null,

    /// Measure text content
    pub fn measureText(self: *const ContentMeasurer, text: []const u8, font_size: f32, max_width: ?f32) Vec2 {
        if (self.measureTextFn) |measure_fn| {
            return measure_fn(text, font_size, max_width);
        }
        // Fallback to estimated measurement
        return estimateTextSize(text, font_size, max_width);
    }

    /// Measure image content
    pub fn measureImage(self: *const ContentMeasurer, image_data: []const u8) Vec2 {
        if (self.measureImageFn) |measure_fn| {
            return measure_fn(image_data);
        }
        // Fallback to default size
        return Vec2{ .x = 100, .y = 100 };
    }

    /// Measure custom content
    pub fn measureCustom(self: *const ContentMeasurer, content_data: *anyopaque) Vec2 {
        if (self.measureCustomFn) |measure_fn| {
            return measure_fn(content_data);
        }
        // Fallback to default size
        return Vec2{ .x = 50, .y = 50 };
    }
};

/// Estimated text measurement (fallback when no font system available)
pub fn estimateTextSize(text: []const u8, font_size: f32, max_width: ?f32) Vec2 {
    if (text.len == 0) return Vec2.ZERO;
    
    // Rough estimates based on typical font metrics
    const char_width = font_size * 0.6; // Average character width
    const line_height = font_size * 1.2; // Typical line height
    
    const total_width = @as(f32, @floatFromInt(text.len)) * char_width;
    
    if (max_width) |max_w| {
        if (total_width <= max_w) {
            // Single line
            return Vec2{ .x = total_width, .y = line_height };
        } else {
            // Multiple lines needed
            const chars_per_line = @as(usize, @intFromFloat(max_w / char_width));
            const lines_needed = (text.len + chars_per_line - 1) / chars_per_line; // Ceiling division
            return Vec2{ 
                .x = max_w, 
                .y = @as(f32, @floatFromInt(lines_needed)) * line_height 
            };
        }
    } else {
        // No width constraint - single line
        return Vec2{ .x = total_width, .y = line_height };
    }
}

/// Content type enumeration
pub const ContentType = enum {
    text,
    image,
    replaced, // video, canvas, etc.
    container, // has children
    empty,
};

/// Content information for measurement
pub const ContentInfo = struct {
    content_type: ContentType,
    data: union {
        text: struct {
            text: []const u8,
            font_size: f32,
            line_height: f32,
        },
        image: struct {
            natural_size: Vec2,
            data: []const u8,
        },
        replaced: struct {
            natural_size: Vec2,
            aspect_ratio: ?f32,
        },
        container: struct {
            children_count: usize,
            min_child_size: Vec2,
        },
        empty: void,
    },
};

/// Comprehensive content measurement
pub const ContentMeasurement = struct {
    /// Measure content based on content info and constraints
    pub fn measureContent(
        info: ContentInfo,
        available_width: ?f32,
        measurer: *const ContentMeasurer,
    ) Vec2 {
        return switch (info.content_type) {
            .text => {
                const text_data = info.data.text;
                return measurer.measureText(text_data.text, text_data.font_size, available_width);
            },
            .image => {
                const image_data = info.data.image;
                var size = image_data.natural_size;
                
                // Constrain to available width if specified
                if (available_width) |max_w| {
                    if (size.x > max_w) {
                        const scale = max_w / size.x;
                        size = Vec2{ .x = max_w, .y = size.y * scale };
                    }
                }
                
                return size;
            },
            .replaced => {
                const replaced_data = info.data.replaced;
                var size = replaced_data.natural_size;
                
                // Apply aspect ratio constraint if available width is specified
                if (available_width) |max_w| {
                    if (size.x > max_w) {
                        size.x = max_w;
                        if (replaced_data.aspect_ratio) |ratio| {
                            size.y = max_w / ratio;
                        }
                    }
                }
                
                return size;
            },
            .container => {
                const container_data = info.data.container;
                // For containers, return minimum size based on children
                var size = container_data.min_child_size;
                
                if (available_width) |max_w| {
                    size.x = @min(size.x, max_w);
                }
                
                return size;
            },
            .empty => Vec2.ZERO,
        };
    }

    /// Calculate minimum content size (cannot be smaller)
    pub fn calculateMinContentSize(info: ContentInfo) Vec2 {
        return switch (info.content_type) {
            .text => {
                const text_data = info.data.text;
                // Minimum is roughly one character wide
                return Vec2{ 
                    .x = text_data.font_size * 0.6, 
                    .y = text_data.line_height 
                };
            },
            .image, .replaced => {
                // Images can't be smaller than 1x1
                return Vec2{ .x = 1, .y = 1 };
            },
            .container => {
                const container_data = info.data.container;
                return container_data.min_child_size;
            },
            .empty => Vec2.ZERO,
        };
    }

    /// Calculate maximum content size (preferred maximum)
    pub fn calculateMaxContentSize(info: ContentInfo, container_size: Vec2) Vec2 {
        return switch (info.content_type) {
            .text => {
                const text_data = info.data.text;
                // Maximum is all text on one line (up to container width)
                const estimated_width = @as(f32, @floatFromInt(text_data.text.len)) * text_data.font_size * 0.6;
                return Vec2{
                    .x = @min(estimated_width, container_size.x),
                    .y = text_data.line_height,
                };
            },
            .image => {
                const image_data = info.data.image;
                return Vec2{
                    .x = @min(image_data.natural_size.x, container_size.x),
                    .y = @min(image_data.natural_size.y, container_size.y),
                };
            },
            .replaced => {
                const replaced_data = info.data.replaced;
                return Vec2{
                    .x = @min(replaced_data.natural_size.x, container_size.x),
                    .y = @min(replaced_data.natural_size.y, container_size.y),
                };
            },
            .container => container_size, // Containers can grow to fill available space
            .empty => Vec2.ZERO,
        };
    }
};

/// Cached content measurement for performance
pub const CachedContentMeasurer = struct {
    const CacheEntry = struct {
        key: u64, // Hash of measurement parameters
        size: Vec2,
        timestamp: i64,
    };

    allocator: std.mem.Allocator,
    cache: std.HashMap(u64, CacheEntry, std.hash_map.DefaultContext(u64), std.hash_map.default_max_load_percentage),
    cache_ttl_ms: i64, // Time to live in milliseconds
    base_measurer: ContentMeasurer,

    /// Initialize cached measurer
    pub fn init(allocator: std.mem.Allocator, base_measurer: ContentMeasurer, cache_ttl_ms: i64) CachedContentMeasurer {
        return CachedContentMeasurer{
            .allocator = allocator,
            .cache = std.HashMap(u64, CacheEntry, std.hash_map.DefaultContext(u64), std.hash_map.default_max_load_percentage).init(allocator),
            .cache_ttl_ms = cache_ttl_ms,
            .base_measurer = base_measurer,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *CachedContentMeasurer) void {
        self.cache.deinit();
    }

    /// Measure with caching
    pub fn measureText(self: *CachedContentMeasurer, text: []const u8, font_size: f32, max_width: ?f32) Vec2 {
        // Create cache key from parameters
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(text);
        hasher.update(std.mem.asBytes(&font_size));
        if (max_width) |w| {
            hasher.update(std.mem.asBytes(&w));
        }
        const key = hasher.final();

        const current_time = std.time.milliTimestamp();

        // Check cache
        if (self.cache.get(key)) |entry| {
            if (current_time - entry.timestamp < self.cache_ttl_ms) {
                return entry.size;
            }
        }

        // Measure and cache
        const size = self.base_measurer.measureText(text, font_size, max_width);
        self.cache.put(key, CacheEntry{
            .key = key,
            .size = size,
            .timestamp = current_time,
        }) catch {}; // Ignore cache failures

        return size;
    }

    /// Clear expired cache entries
    pub fn cleanup(self: *CachedContentMeasurer) void {
        const current_time = std.time.milliTimestamp();
        var iterator = self.cache.iterator();
        var expired_keys = std.ArrayList(u64).init(self.allocator);
        defer expired_keys.deinit();

        // Find expired entries
        while (iterator.next()) |entry| {
            if (current_time - entry.value_ptr.timestamp >= self.cache_ttl_ms) {
                expired_keys.append(entry.key_ptr.*) catch continue;
            }
        }

        // Remove expired entries
        for (expired_keys.items) |key| {
            _ = self.cache.remove(key);
        }
    }
};

// Tests
test "text size estimation" {
    const testing = std.testing;

    const size1 = estimateTextSize("Hello", 16, null);
    try testing.expect(size1.x > 0);
    try testing.expect(size1.y > 0);

    // With width constraint
    const size2 = estimateTextSize("This is a very long text that should wrap", 16, 100);
    try testing.expect(size2.x == 100); // Should be constrained to max width
    try testing.expect(size2.y > size1.y); // Should be taller due to wrapping
}

test "content measurement" {
    const testing = std.testing;

    const text_info = ContentInfo{
        .content_type = .text,
        .data = .{ .text = .{
            .text = "Hello World",
            .font_size = 16,
            .line_height = 20,
        }},
    };

    const measurer = ContentMeasurer{};
    const size = ContentMeasurement.measureContent(text_info, null, &measurer);
    try testing.expect(size.x > 0);
    try testing.expect(size.y == 20); // Should match line height

    const min_size = ContentMeasurement.calculateMinContentSize(text_info);
    try testing.expect(min_size.x < size.x); // Min should be smaller
    try testing.expect(min_size.y == 20); // Same height

    const container_size = Vec2{ .x = 200, .y = 100 };
    const max_size = ContentMeasurement.calculateMaxContentSize(text_info, container_size);
    try testing.expect(max_size.x <= container_size.x);
    try testing.expect(max_size.y == 20);
}

test "cached measurement" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const base_measurer = ContentMeasurer{};
    var cached_measurer = CachedContentMeasurer.init(allocator, base_measurer, 1000); // 1 second TTL
    defer cached_measurer.deinit();

    // Measure twice - second should be from cache
    const size1 = cached_measurer.measureText("Hello", 16, null);
    const size2 = cached_measurer.measureText("Hello", 16, null);

    try testing.expect(size1.x == size2.x);
    try testing.expect(size1.y == size2.y);
}