const std = @import("std");
const c = @import("../platform/sdl.zig");
const colors = @import("../core/colors.zig");
const reactive_text_cache = @import("../reactive/text_cache.zig");
const loggers = @import("../debug/loggers.zig");
const text_primitives = @import("primitives.zig");
const hash = @import("../core/hash.zig");
const texture_formats = @import("../rendering/core/texture_formats.zig");
const rendering_core = @import("../rendering/core/mod.zig");

/// Persistent text texture system that maintains texture handles across frames
/// Unlike the immediate mode text renderer, this system keeps textures alive
/// until the content changes, eliminating flashing on cache hits.
pub const PersistentTextSystem = struct {
    allocator: std.mem.Allocator,
    device: *c.sdl.SDL_GPUDevice,
    textures: std.AutoHashMap(u64, PersistentTexture),

    // Rendering resources
    sampler: ?*c.sdl.SDL_GPUSampler,

    // Circuit breaker to prevent infinite loops
    recent_failures: u32,
    last_failure_check: i64,

    const Self = @This();
    const max_failures_per_second = 100; // Stop after 100 failures in 1 second

    const PersistentTexture = struct {
        texture: *c.sdl.SDL_GPUTexture,
        width: u32,
        height: u32,
        content_hash: u64,
        last_used: u64,
        is_valid: bool,

        pub fn deinit(self: *PersistentTexture, device: *c.sdl.SDL_GPUDevice) void {
            if (self.is_valid) {
                c.sdl.SDL_ReleaseGPUTexture(device, self.texture);
                self.is_valid = false;
            }
        }
    };

    pub fn init(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice) !Self {
        var self = Self{
            .allocator = allocator,
            .device = device,
            .textures = std.AutoHashMap(u64, PersistentTexture).init(allocator),
            .sampler = null,
            .recent_failures = 0,
            .last_failure_check = std.time.milliTimestamp(),
        };

        try self.createSampler();

        return self;
    }

    pub fn deinit(self: *Self) void {
        // Release all persistent textures
        var iterator = self.textures.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.deinit(self.device);
        }
        self.textures.deinit();

        // Release sampler
        if (self.sampler) |sampler| {
            c.sdl.SDL_ReleaseGPUSampler(self.device, sampler);
        }
    }

    /// Get or create a persistent texture for the given text content
    /// Returns existing texture if content hasn't changed, or creates new one
    /// REQUIRES: command buffer from the current frame - critical for texture lifecycle
    pub fn getOrCreateTexture(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, text: []const u8, font_manager: anytype, font_category: anytype, font_size: f32, color: colors.Color) !?PersistentTextureHandle {
        _ = font_category; // TODO: Use font_category to select appropriate font (currently defaults to .sans)
        // Validate UTF-8 before processing
        if (!std.unicode.utf8ValidateSlice(text)) {
            loggers.getFontLog().err("invalid_utf8_skip", "Skipping invalid UTF-8 text (length {})", .{text.len});
            return null;
        }

        // Circuit breaker: Check if we're hitting too many failures
        const now = std.time.milliTimestamp();
        if (now - self.last_failure_check > 1000) {
            // Reset counter every second
            self.recent_failures = 0;
            self.last_failure_check = now;
        } else if (self.recent_failures > max_failures_per_second) {
            // Too many failures, stop trying
            loggers.getFontLog().err("circuit_breaker", "Circuit breaker triggered: too many texture creation failures", .{});
            return null;
        }

        const content_hash = self.hashText(text);
        const current_time = @as(u64, @intCast(std.time.milliTimestamp()));

        // Check if we already have a valid texture for this content
        if (self.textures.getPtr(content_hash)) |existing| {
            if (existing.is_valid) {
                existing.last_used = current_time;

                loggers.getFontLog().debug("cache_hit", "Using persistent texture for '{s}' ({}x{})", .{ text, existing.width, existing.height });

                return PersistentTextureHandle{
                    .texture = existing.texture,
                    .sampler = self.sampler.?,
                    .width = existing.width,
                    .height = existing.height,
                    .is_cached = true,
                };
            }
        }

        // Validate UTF-8 before attempting texture creation
        if (!std.unicode.utf8ValidateSlice(text)) {
            loggers.getFontLog().err("invalid_utf8_skip", "Skipping invalid UTF-8 text (length {})", .{text.len});
            self.recent_failures += 1;
            return null;
        }

        // Create new texture (only log first few times to avoid spam)
        loggers.getFontLog().debug("create_texture", "Creating new persistent texture for '{s}'", .{text});

        // Use text primitives to create texture (proper domain separation)
        // Create bitmap text directly to avoid circular dependency with .cached mode
        var primitives = text_primitives.TextPrimitives.init(self.allocator, self.device, font_manager);
        const text_result = primitives.createBitmapText(cmd_buffer, text, font_size, color) catch |err| {
            loggers.getFontLog().err("texture_error", "Failed to create persistent texture for text: {}", .{err});
            self.recent_failures += 1;
            return null;
        };

        // Store the persistent texture
        const persistent = PersistentTexture{
            .texture = text_result.texture,
            .width = text_result.width,
            .height = text_result.height,
            .content_hash = content_hash,
            .last_used = current_time,
            .is_valid = true,
        };

        try self.textures.put(content_hash, persistent);

        loggers.getFontLog().debug("texture_created", "Created persistent texture: {}x{}", .{ text_result.width, text_result.height });

        return PersistentTextureHandle{
            .texture = text_result.texture,
            .sampler = self.sampler.?,
            .width = text_result.width,
            .height = text_result.height,
            .is_cached = false,
        };
    }

    /// Check if a texture exists for the given text (without creating it)
    pub fn hasTexture(self: *Self, text: []const u8) bool {
        const content_hash = self.hashText(text);
        if (self.textures.get(content_hash)) |existing| {
            return existing.is_valid;
        }
        return false;
    }

    /// Invalidate a specific text texture (call when you know content will change)
    pub fn invalidateTexture(self: *Self, text: []const u8) void {
        const content_hash = self.hashText(text);
        if (self.textures.getPtr(content_hash)) |existing| {
            existing.deinit(self.device);
            _ = self.textures.remove(content_hash);

            loggers.getFontLog().info("invalidate", "Invalidated persistent texture for '{s}'", .{text});
        }
    }

    /// Clean up old textures that haven't been used recently
    pub fn cleanup(self: *Self, max_age_ms: u64) void {
        const current_time = @as(u64, @intCast(std.time.milliTimestamp()));
        var to_remove = std.ArrayList(u64).init(self.allocator);
        defer to_remove.deinit();

        var iterator = self.textures.iterator();
        while (iterator.next()) |entry| {
            const age = current_time - entry.value_ptr.last_used;
            if (age > max_age_ms) {
                entry.value_ptr.deinit(self.device);
                to_remove.append(entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |item_hash| {
            _ = self.textures.remove(item_hash);
        }

        if (to_remove.items.len > 0) {
            loggers.getFontLog().info("cleanup", "Cleaned up {} old persistent textures", .{to_remove.items.len});
        }
    }

    /// Get statistics about the persistent texture system
    pub fn getStats(self: *Self) PersistentTextStats {
        var valid_count: u32 = 0;
        var total_memory: u64 = 0;

        var iterator = self.textures.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.is_valid) {
                valid_count += 1;
                // Use shared utilities for memory calculation
                const texture_size = texture_formats.calculateTextureSize(entry.value_ptr.width, entry.value_ptr.height, .r8g8b8a8_unorm);
                total_memory += @as(u64, texture_size);
            }
        }

        return PersistentTextStats{
            .texture_count = valid_count,
            .estimated_memory_bytes = total_memory,
        };
    }

    fn hashText(self: *Self, text: []const u8) u64 {
        _ = self;
        return hash.hashText(text);
    }

    fn createSampler(self: *Self) !void {
        self.sampler = try rendering_core.Samplers.createLinearSampler(self.device);
    }
};

/// Handle to a persistent texture that can be used for rendering
pub const PersistentTextureHandle = struct {
    texture: *c.sdl.SDL_GPUTexture,
    sampler: *c.sdl.SDL_GPUSampler,
    width: u32,
    height: u32,
    is_cached: bool, // True if this was a cache hit, false if newly created
};

/// Statistics about persistent texture usage
pub const PersistentTextStats = struct {
    texture_count: u32,
    estimated_memory_bytes: u64,
};

// Global persistent text system
var global_persistent_text_system: ?*PersistentTextSystem = null;

pub fn initGlobalPersistentTextSystem(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice) !void {
    if (global_persistent_text_system != null) return;

    const system = try allocator.create(PersistentTextSystem);
    system.* = try PersistentTextSystem.init(allocator, device);
    global_persistent_text_system = system;

    loggers.getFontLog().info("init_system", "Initialized global persistent text system", .{});
}

pub fn deinitGlobalPersistentTextSystem(allocator: std.mem.Allocator) void {
    if (global_persistent_text_system) |system| {
        system.deinit();
        allocator.destroy(system);
        global_persistent_text_system = null;

        loggers.getFontLog().info("deinit_system", "Deinitialized global persistent text system", .{});
    }
}

pub fn getGlobalPersistentTextSystem() ?*PersistentTextSystem {
    return global_persistent_text_system;
}

/// Rendering modes to guide developers on when to use each approach
pub const RenderingMode = enum {
    /// Use for text that changes every frame or very frequently
    /// Textures are created, used once, then immediately released
    /// Examples: particle counts, frame-based debug info
    immediate,

    /// Use for text that changes occasionally or stays the same
    /// Textures are kept alive until content changes
    /// Examples: FPS counter, UI labels, menu text
    persistent,
};

/// Helper to decide which rendering mode to use based on content characteristics
pub fn recommendRenderingMode(content_changes_per_second: f32) RenderingMode {
    // If content changes more than 10 times per second, use immediate mode
    if (content_changes_per_second > 10.0) {
        return .immediate;
    }
    // Otherwise use persistent mode for better performance
    return .persistent;
}
