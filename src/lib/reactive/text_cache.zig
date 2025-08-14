const std = @import("std");
const signal = @import("signal.zig");
const derived = @import("derived.zig");
const effect = @import("effect.zig");

/// Reactive text cache to avoid re-rendering identical text content
/// Caches rendered text textures and only re-renders when content changes
pub const ReactiveTextCache = struct {
    allocator: std.mem.Allocator,
    cache: std.AutoHashMap(u64, CachedText),

    // Reactive signals for cache management
    cache_size: *signal.Signal(usize),
    hit_count: *signal.Signal(u64),
    miss_count: *signal.Signal(u64),

    // Derived cache statistics
    hit_ratio: *derived.Derived(f32),

    const Self = @This();

    const CachedText = struct {
        content_hash: u64,
        last_used: u64,
        texture_width: u32,
        texture_height: u32,
        // In a real implementation, this would hold the GPU texture handle
        // For now we'll track metadata and let the renderer handle the actual textures
        is_valid: bool,
    };

    pub fn init(allocator: std.mem.Allocator) !Self {
        // Create reactive signals
        const cache_size_signal = try allocator.create(signal.Signal(usize));
        cache_size_signal.* = try signal.Signal(usize).init(allocator, 0);

        const hit_count_signal = try allocator.create(signal.Signal(u64));
        hit_count_signal.* = try signal.Signal(u64).init(allocator, 0);

        const miss_count_signal = try allocator.create(signal.Signal(u64));
        miss_count_signal.* = try signal.Signal(u64).init(allocator, 0);

        var self = Self{
            .allocator = allocator,
            .cache = std.AutoHashMap(u64, CachedText).init(allocator),
            .cache_size = cache_size_signal,
            .hit_count = hit_count_signal,
            .miss_count = miss_count_signal,
            .hit_ratio = undefined, // Set below
        };

        // Create derived hit ratio
        self.hit_ratio = try self.createHitRatioDerived();

        return self;
    }

    fn createHitRatioDerived(self: *Self) !*derived.Derived(f32) {
        const SelfRef = struct {
            var cache_ref: *ReactiveTextCache = undefined;
        };
        SelfRef.cache_ref = self;

        return try derived.derived(self.allocator, f32, struct {
            fn compute() f32 {
                const cache = SelfRef.cache_ref;
                const hits = cache.hit_count.get();
                const misses = cache.miss_count.get();
                const total = hits + misses;

                if (total == 0) return 0.0;
                return @as(f32, @floatFromInt(hits)) / @as(f32, @floatFromInt(total));
            }
        }.compute);
    }

    /// Check if text content is cached and valid
    pub fn isCached(self: *Self, text: []const u8) bool {
        const hash = self.hashText(text);

        if (self.cache.get(hash)) |cached| {
            if (cached.is_valid) {
                // Cache hit - update statistics
                const hits = self.hit_count.peek() + 1;
                self.hit_count.set(hits);

                // Update last used time
                var updated_cache = cached;
                updated_cache.last_used = @as(u64, @intCast(std.time.milliTimestamp()));
                self.cache.put(hash, updated_cache) catch {}; // Best effort

                return true;
            }
        }

        // Cache miss - update statistics
        const misses = self.miss_count.peek() + 1;
        self.miss_count.set(misses);

        return false;
    }

    /// Cache text content with its rendered dimensions
    pub fn cacheText(self: *Self, text: []const u8, width: u32, height: u32) !void {
        const hash = self.hashText(text);

        const cached = CachedText{
            .content_hash = hash,
            .last_used = @as(u64, @intCast(std.time.milliTimestamp())),
            .texture_width = width,
            .texture_height = height,
            .is_valid = true,
        };

        try self.cache.put(hash, cached);

        // Update cache size signal
        self.cache_size.set(self.cache.count());
    }

    /// Get cached text dimensions if available
    pub fn getCachedDimensions(self: *Self, text: []const u8) ?struct { width: u32, height: u32 } {
        const hash = self.hashText(text);

        if (self.cache.get(hash)) |cached| {
            if (cached.is_valid) {
                return .{
                    .width = cached.texture_width,
                    .height = cached.texture_height,
                };
            }
        }

        return null;
    }

    /// Invalidate cache entry (call when text changes)
    pub fn invalidateText(self: *Self, text: []const u8) void {
        const hash = self.hashText(text);
        _ = self.cache.remove(hash);
        self.cache_size.set(self.cache.count());
    }

    /// Clear entire cache
    pub fn clear(self: *Self) void {
        self.cache.clearAndFree();
        self.cache_size.set(0);
    }

    /// Get cache statistics
    pub fn getHitRatio(self: *Self) f32 {
        return self.hit_ratio.get();
    }

    pub fn getCacheSize(self: *Self) usize {
        return self.cache_size.peek();
    }

    pub fn getHitCount(self: *Self) u64 {
        return self.hit_count.peek();
    }

    pub fn getMissCount(self: *Self) u64 {
        return self.miss_count.peek();
    }

    /// Clean up old cache entries (call periodically)
    pub fn cleanup(self: *Self, max_age_ms: u64) void {
        const current_time = @as(u64, @intCast(std.time.milliTimestamp()));
        var to_remove = std.ArrayList(u64).init(self.allocator);
        defer to_remove.deinit();

        var iterator = self.cache.iterator();
        while (iterator.next()) |entry| {
            const age = current_time - @as(i64, @intCast(entry.value_ptr.last_used));
            if (age > @as(i64, @intCast(max_age_ms))) {
                to_remove.append(entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |hash| {
            _ = self.cache.remove(hash);
        }

        if (to_remove.items.len > 0) {
            self.cache_size.set(self.cache.count());
        }
    }

    fn hashText(self: *Self, text: []const u8) u64 {
        _ = self;
        // Simple hash function for text content
        var hasher = std.hash.Fnv1a_64.init();
        hasher.update(text);
        return hasher.final();
    }

    pub fn deinit(self: *Self) void {
        // Clean up derived values
        self.hit_ratio.deinit();
        self.allocator.destroy(self.hit_ratio);

        // Clean up signals
        self.cache_size.deinit();
        self.allocator.destroy(self.cache_size);
        self.hit_count.deinit();
        self.allocator.destroy(self.hit_count);
        self.miss_count.deinit();
        self.allocator.destroy(self.miss_count);

        // Clean up cache
        self.cache.deinit();
    }
};

// Global text cache instance
var global_text_cache: ?*ReactiveTextCache = null;

pub fn initGlobalTextCache(allocator: std.mem.Allocator) !void {
    if (global_text_cache != null) return;

    const cache = try allocator.create(ReactiveTextCache);
    cache.* = try ReactiveTextCache.init(allocator);
    global_text_cache = cache;
}

pub fn deinitGlobalTextCache(allocator: std.mem.Allocator) void {
    if (global_text_cache) |cache| {
        cache.deinit();
        allocator.destroy(cache);
        global_text_cache = null;
    }
}

pub fn getGlobalTextCache() ?*ReactiveTextCache {
    return global_text_cache;
}

/// Convenience function to check if text should be re-rendered
pub fn shouldRenderText(text: []const u8) bool {
    if (global_text_cache) |cache| {
        return !cache.isCached(text);
    }
    // Without cache, always render
    return true;
}

/// Convenience function to cache text after rendering
pub fn cacheRenderedText(text: []const u8, width: u32, height: u32) void {
    if (global_text_cache) |cache| {
        cache.cacheText(text, width, height) catch {
            // Best effort caching - don't fail if cache is full
        };
    }
}

/// Convenience function to get cache statistics
pub fn getTextCacheStats() struct { hit_ratio: f32, cache_size: usize, hits: u64, misses: u64 } {
    if (global_text_cache) |cache| {
        return .{
            .hit_ratio = cache.getHitRatio(),
            .cache_size = cache.getCacheSize(),
            .hits = cache.getHitCount(),
            .misses = cache.getMissCount(),
        };
    }
    return .{ .hit_ratio = 0.0, .cache_size = 0, .hits = 0, .misses = 0 };
}
