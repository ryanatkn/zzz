const std = @import("std");
const types = @import("types.zig");

const Vec2 = types.Vec2;

/// Information about a cached glyph
pub const CachedGlyph = struct {
    /// Glyph bitmap data (single channel alpha)
    bitmap: ?[]u8,
    
    /// Dimensions of the glyph
    width: u32,
    height: u32,
    
    /// Bearing (offset from baseline)
    bearing_x: i32,
    bearing_y: i32,
    
    /// Horizontal advance to next glyph
    advance: f32,
    
    /// Reference count for memory management
    ref_count: u32,
    
    /// Last access time for LRU eviction
    last_access: u64,
    
    /// Size in bytes for memory tracking
    memory_size: usize,
};

/// Cache statistics for monitoring performance
pub const CacheStats = struct {
    total_requests: u64,
    cache_hits: u64,
    cache_misses: u64,
    evictions: u64,
    memory_used: usize,
    memory_limit: usize,
    
    pub fn hitRate(self: CacheStats) f32 {
        if (self.total_requests == 0) return 0.0;
        return @as(f32, @floatFromInt(self.cache_hits)) / @as(f32, @floatFromInt(self.total_requests));
    }
    
    pub fn missRate(self: CacheStats) f32 {
        return 1.0 - self.hitRate();
    }
    
    pub fn memoryUsagePercent(self: CacheStats) f32 {
        if (self.memory_limit == 0) return 0.0;
        return @as(f32, @floatFromInt(self.memory_used)) / @as(f32, @floatFromInt(self.memory_limit));
    }
};

/// Configuration for the glyph cache
pub const CacheConfig = struct {
    /// Maximum number of glyphs to cache
    max_glyphs: u32 = 1024,
    
    /// Maximum memory usage in bytes (0 = unlimited)
    memory_limit: usize = 16 * 1024 * 1024, // 16MB default
    
    /// Initial capacity for the hash map
    initial_capacity: u32 = 256,
    
    /// Enable LRU eviction when limits are reached
    enable_lru: bool = true,
    
    /// Enable reference counting for shared glyphs
    enable_ref_counting: bool = true,
};

/// A glyph cache using LRU eviction and optional reference counting
pub const GlyphCache = struct {
    allocator: std.mem.Allocator,
    config: CacheConfig,
    cache: std.AutoHashMap(u64, CachedGlyph),
    stats: CacheStats,
    access_counter: u64,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, config: CacheConfig) !Self {
        var cache = std.AutoHashMap(u64, CachedGlyph).init(allocator);
        try cache.ensureTotalCapacity(config.initial_capacity);
        
        return Self{
            .allocator = allocator,
            .config = config,
            .cache = cache,
            .stats = CacheStats{
                .total_requests = 0,
                .cache_hits = 0,
                .cache_misses = 0,
                .evictions = 0,
                .memory_used = 0,
                .memory_limit = config.memory_limit,
            },
            .access_counter = 0,
        };
    }
    
    pub fn deinit(self: *Self) void {
        // Free all cached bitmaps
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.bitmap) |bitmap| {
                self.allocator.free(bitmap);
            }
        }
        self.cache.deinit();
    }
    
    /// Get a cached glyph, returning null if not found
    pub fn get(self: *Self, key: u64) ?*CachedGlyph {
        self.stats.total_requests += 1;
        self.access_counter += 1;
        
        if (self.cache.getPtr(key)) |glyph| {
            // Update access time for LRU
            glyph.last_access = self.access_counter;
            
            // Increment reference count if enabled
            if (self.config.enable_ref_counting) {
                glyph.ref_count += 1;
            }
            
            self.stats.cache_hits += 1;
            return glyph;
        }
        
        self.stats.cache_misses += 1;
        return null;
    }
    
    /// Insert a glyph into the cache
    pub fn put(self: *Self, key: u64, glyph: CachedGlyph) !void {
        // Calculate memory size
        const memory_size = if (glyph.bitmap) |bitmap| 
            bitmap.len + @sizeOf(CachedGlyph)
        else 
            @sizeOf(CachedGlyph);
        
        // Check if we need to evict before inserting
        if (self.needsEviction(memory_size)) {
            try self.evictLRU(memory_size);
        }
        
        // Create a copy of the glyph with correct metadata
        var cached_glyph = glyph;
        cached_glyph.ref_count = if (self.config.enable_ref_counting) 1 else 0;
        cached_glyph.last_access = self.access_counter;
        cached_glyph.memory_size = memory_size;
        
        // If there's a bitmap, make a copy
        if (glyph.bitmap) |bitmap| {
            const bitmap_copy = try self.allocator.alloc(u8, bitmap.len);
            @memcpy(bitmap_copy, bitmap);
            cached_glyph.bitmap = bitmap_copy;
        }
        
        // Insert into cache
        try self.cache.put(key, cached_glyph);
        self.stats.memory_used += memory_size;
    }
    
    /// Release a reference to a cached glyph
    pub fn release(self: *Self, key: u64) void {
        if (!self.config.enable_ref_counting) return;
        
        if (self.cache.getPtr(key)) |glyph| {
            if (glyph.ref_count > 0) {
                glyph.ref_count -= 1;
            }
        }
    }
    
    /// Remove a glyph from the cache
    pub fn remove(self: *Self, key: u64) bool {
        if (self.cache.fetchRemove(key)) |kv| {
            if (kv.value.bitmap) |bitmap| {
                self.allocator.free(bitmap);
            }
            self.stats.memory_used -= kv.value.memory_size;
            return true;
        }
        return false;
    }
    
    /// Clear all cached glyphs
    pub fn clear(self: *Self) void {
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.bitmap) |bitmap| {
                self.allocator.free(bitmap);
            }
        }
        self.cache.clearRetainingCapacity();
        self.stats.memory_used = 0;
    }
    
    /// Check if eviction is needed before inserting new data
    fn needsEviction(self: *Self, new_size: usize) bool {
        // Check count limit
        if (self.cache.count() >= self.config.max_glyphs) {
            return true;
        }
        
        // Check memory limit
        if (self.config.memory_limit > 0) {
            return self.stats.memory_used + new_size > self.config.memory_limit;
        }
        
        return false;
    }
    
    /// Evict least recently used glyphs until we have enough space
    fn evictLRU(self: *Self, needed_size: usize) !void {
        if (!self.config.enable_lru) return;
        
        var candidates = std.ArrayList(struct { key: u64, last_access: u64, ref_count: u32, size: usize }).init(self.allocator);
        defer candidates.deinit();
        
        // Collect all cache entries with their access times
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            try candidates.append(.{
                .key = entry.key_ptr.*,
                .last_access = entry.value_ptr.last_access,
                .ref_count = entry.value_ptr.ref_count,
                .size = entry.value_ptr.memory_size,
            });
        }
        
        // Sort by access time (oldest first), but consider reference counts
        std.sort.heap(@TypeOf(candidates.items[0]), candidates.items, {}, struct {
            fn lessThan(_: void, a: @TypeOf(candidates.items[0]), b: @TypeOf(candidates.items[0])) bool {
                // If reference counting is enabled, prefer evicting unreferenced items
                if (a.ref_count == 0 and b.ref_count > 0) return true;
                if (a.ref_count > 0 and b.ref_count == 0) return false;
                
                // Otherwise, use LRU order
                return a.last_access < b.last_access;
            }
        }.lessThan);
        
        // Evict glyphs until we have enough space
        var freed_space: usize = 0;
        for (candidates.items) |candidate| {
            // Stop if we've freed enough space
            if (self.config.memory_limit == 0) {
                if (self.cache.count() < self.config.max_glyphs) break;
            } else {
                if (self.stats.memory_used - freed_space + needed_size <= self.config.memory_limit) break;
            }
            
            if (self.remove(candidate.key)) {
                freed_space += candidate.size;
                self.stats.evictions += 1;
            }
        }
    }
    
    /// Get current cache statistics
    pub fn getStats(self: *const Self) CacheStats {
        return self.stats;
    }
    
    /// Reset cache statistics
    pub fn resetStats(self: *Self) void {
        self.stats = CacheStats{
            .total_requests = 0,
            .cache_hits = 0,
            .cache_misses = 0,
            .evictions = 0,
            .memory_used = self.stats.memory_used, // Keep current memory usage
            .memory_limit = self.stats.memory_limit,
        };
    }
    
    /// Get the number of cached glyphs
    pub fn count(self: *const Self) u32 {
        return @intCast(self.cache.count());
    }
    
    /// Check if a glyph is cached
    pub fn contains(self: *const Self, key: u64) bool {
        return self.cache.contains(key);
    }
    
    /// Compact the cache by removing unreferenced glyphs
    pub fn compact(self: *Self) !void {
        if (!self.config.enable_ref_counting) return;
        
        var to_remove = std.ArrayList(u64).init(self.allocator);
        defer to_remove.deinit();
        
        // Find all unreferenced glyphs
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.ref_count == 0) {
                try to_remove.append(entry.key_ptr.*);
            }
        }
        
        // Remove them
        for (to_remove.items) |key| {
            _ = self.remove(key);
        }
    }
    
    /// Prefetch a glyph (mark as recently accessed without returning it)
    pub fn prefetch(self: *Self, key: u64) void {
        if (self.cache.getPtr(key)) |glyph| {
            glyph.last_access = self.access_counter;
            self.access_counter += 1;
        }
    }
};

/// Utility functions for creating cache keys
pub const CacheKey = struct {
    /// Create a cache key from font ID, size, and codepoint
    pub fn create(font_id: u32, size: u32, codepoint: u32) u64 {
        return (@as(u64, font_id) << 32) | (@as(u64, size) << 16) | @as(u64, codepoint);
    }
    
    /// Extract font ID from cache key
    pub fn getFontId(key: u64) u32 {
        return @intCast(key >> 32);
    }
    
    /// Extract size from cache key
    pub fn getSize(key: u64) u32 {
        return @intCast((key >> 16) & 0xFFFF);
    }
    
    /// Extract codepoint from cache key
    pub fn getCodepoint(key: u64) u32 {
        return @intCast(key & 0xFFFF);
    }
};

/// Multi-resolution glyph cache for different scales
pub const MultiResolutionCache = struct {
    allocator: std.mem.Allocator,
    caches: std.AutoHashMap(u32, GlyphCache), // Scale -> Cache
    default_config: CacheConfig,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, config: CacheConfig) Self {
        return Self{
            .allocator = allocator,
            .caches = std.AutoHashMap(u32, GlyphCache).init(allocator),
            .default_config = config,
        };
    }
    
    pub fn deinit(self: *Self) void {
        var iter = self.caches.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.caches.deinit();
    }
    
    /// Get or create a cache for a specific scale
    fn getCacheForScale(self: *Self, scale: u32) !*GlyphCache {
        if (self.caches.getPtr(scale)) |cache| {
            return cache;
        }
        
        // Create new cache for this scale
        const cache = try GlyphCache.init(self.allocator, self.default_config);
        try self.caches.put(scale, cache);
        return self.caches.getPtr(scale).?;
    }
    
    /// Get a glyph at a specific scale
    pub fn get(self: *Self, scale: u32, key: u64) !?*CachedGlyph {
        const cache = try self.getCacheForScale(scale);
        return cache.get(key);
    }
    
    /// Put a glyph at a specific scale
    pub fn put(self: *Self, scale: u32, key: u64, glyph: CachedGlyph) !void {
        const cache = try self.getCacheForScale(scale);
        try cache.put(key, glyph);
    }
    
    /// Get combined statistics across all scales
    pub fn getCombinedStats(self: *Self) CacheStats {
        var combined = CacheStats{
            .total_requests = 0,
            .cache_hits = 0,
            .cache_misses = 0,
            .evictions = 0,
            .memory_used = 0,
            .memory_limit = 0,
        };
        
        var iter = self.caches.iterator();
        while (iter.next()) |entry| {
            const stats = entry.value_ptr.getStats();
            combined.total_requests += stats.total_requests;
            combined.cache_hits += stats.cache_hits;
            combined.cache_misses += stats.cache_misses;
            combined.evictions += stats.evictions;
            combined.memory_used += stats.memory_used;
            combined.memory_limit += stats.memory_limit;
        }
        
        return combined;
    }
    
    /// Clear all caches
    pub fn clear(self: *Self) void {
        var iter = self.caches.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.clear();
        }
    }
};

/// Cache configuration presets
pub const CachePresets = struct {
    /// Minimal cache for low-memory environments
    pub const minimal = CacheConfig{
        .max_glyphs = 128,
        .memory_limit = 2 * 1024 * 1024, // 2MB
        .initial_capacity = 64,
        .enable_lru = true,
        .enable_ref_counting = false,
    };
    
    /// Balanced cache for typical use
    pub const balanced = CacheConfig{
        .max_glyphs = 512,
        .memory_limit = 8 * 1024 * 1024, // 8MB
        .initial_capacity = 128,
        .enable_lru = true,
        .enable_ref_counting = true,
    };
    
    /// Large cache for high-performance scenarios
    pub const performance = CacheConfig{
        .max_glyphs = 2048,
        .memory_limit = 32 * 1024 * 1024, // 32MB
        .initial_capacity = 512,
        .enable_lru = true,
        .enable_ref_counting = true,
    };
    
    /// No limits cache (for testing or unlimited memory scenarios)
    pub const unlimited = CacheConfig{
        .max_glyphs = std.math.maxInt(u32),
        .memory_limit = 0, // No limit
        .initial_capacity = 256,
        .enable_lru = false,
        .enable_ref_counting = false,
    };
};

test "glyph cache basic operations" {
    const testing = std.testing;
    var cache = try GlyphCache.init(testing.allocator, CachePresets.balanced);
    defer cache.deinit();
    
    const key = CacheKey.create(1, 16, 65); // Font 1, size 16, 'A'
    
    // Initially empty
    try testing.expect(cache.get(key) == null);
    try testing.expect(cache.count() == 0);
    
    // Insert a glyph
    const glyph = CachedGlyph{
        .bitmap = null,
        .width = 10,
        .height = 12,
        .bearing_x = 1,
        .bearing_y = 9,
        .advance = 8.0,
        .ref_count = 0,
        .last_access = 0,
        .memory_size = 0,
    };
    
    try cache.put(key, glyph);
    try testing.expect(cache.count() == 1);
    
    // Retrieve the glyph
    const cached = cache.get(key);
    try testing.expect(cached != null);
    try testing.expect(cached.?.width == 10);
    try testing.expect(cached.?.height == 12);
}

test "cache key encoding and decoding" {
    const testing = std.testing;
    
    const font_id: u32 = 42;
    const size: u32 = 24;
    const codepoint: u32 = 8364; // Euro symbol
    
    const key = CacheKey.create(font_id, size, codepoint);
    
    try testing.expect(CacheKey.getFontId(key) == font_id);
    try testing.expect(CacheKey.getSize(key) == size);
    try testing.expect(CacheKey.getCodepoint(key) == codepoint);
}