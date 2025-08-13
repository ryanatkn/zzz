const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const reactive_text_cache = @import("reactive/text_cache.zig");

/// Persistent text texture system that maintains texture handles across frames
/// Unlike the immediate mode text renderer, this system keeps textures alive
/// until the content changes, eliminating flashing on cache hits.
pub const PersistentTextSystem = struct {
    allocator: std.mem.Allocator,
    device: *c.sdl.SDL_GPUDevice,
    textures: std.AutoHashMap(u64, PersistentTexture),
    
    // Rendering resources
    sampler: ?*c.sdl.SDL_GPUSampler,
    
    const Self = @This();
    
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
    pub fn getOrCreateTexture(
        self: *Self, 
        text: []const u8,
        font_manager: anytype,
        font_category: anytype,
        font_size: f32,
        color: types.Color
    ) !?PersistentTextureHandle {
        const content_hash = self.hashText(text);
        const current_time = @as(u64, @intCast(std.time.milliTimestamp()));
        
        // Check if we already have a valid texture for this content
        if (self.textures.getPtr(content_hash)) |existing| {
            if (existing.is_valid) {
                existing.last_used = current_time;
                
                const log = std.log.scoped(.persistent_text);
                log.debug("Using persistent texture for '{s}' ({}x{})", .{ text, existing.width, existing.height });
                
                return PersistentTextureHandle{
                    .texture = existing.texture,
                    .sampler = self.sampler.?,
                    .width = existing.width,
                    .height = existing.height,
                    .is_cached = true,
                };
            }
        }
        
        // Create new texture
        const log = std.log.scoped(.persistent_text);
        log.info("Creating new persistent texture for '{s}'", .{text});
        
        const text_result = font_manager.renderTextToTexture(text, font_category, font_size, color, self.device) catch |err| {
            log.err("Failed to create persistent texture for text: {}", .{err});
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
        
        log.info("Created persistent texture: {}x{}", .{ text_result.width, text_result.height });
        
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
            
            const log = std.log.scoped(.persistent_text);
            log.debug("Invalidated persistent texture for '{s}'", .{text});
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
        
        for (to_remove.items) |hash| {
            _ = self.textures.remove(hash);
        }
        
        if (to_remove.items.len > 0) {
            const log = std.log.scoped(.persistent_text);
            log.info("Cleaned up {} old persistent textures", .{to_remove.items.len});
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
                // Rough estimate: RGBA8 = 4 bytes per pixel
                total_memory += @as(u64, entry.value_ptr.width) * entry.value_ptr.height * 4;
            }
        }
        
        return PersistentTextStats{
            .texture_count = valid_count,
            .estimated_memory_bytes = total_memory,
        };
    }
    
    fn hashText(self: *Self, text: []const u8) u64 {
        _ = self;
        var hasher = std.hash.Fnv1a_64.init();
        hasher.update(text);
        return hasher.final();
    }
    
    fn createSampler(self: *Self) !void {
        const sampler_info = c.sdl.SDL_GPUSamplerCreateInfo{
            .min_filter = c.sdl.SDL_GPU_FILTER_LINEAR,
            .mag_filter = c.sdl.SDL_GPU_FILTER_LINEAR,
            .mipmap_mode = c.sdl.SDL_GPU_SAMPLERMIPMAPMODE_LINEAR,
            .address_mode_u = c.sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
            .address_mode_v = c.sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
            .address_mode_w = c.sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
            .mip_lod_bias = 0.0,
            .max_anisotropy = 1.0,
            .compare_op = c.sdl.SDL_GPU_COMPAREOP_NEVER,
            .min_lod = 0.0,
            .max_lod = 1000.0,
            .enable_anisotropy = false,
            .enable_compare = false,
        };
        
        self.sampler = c.sdl.SDL_CreateGPUSampler(self.device, &sampler_info);
        if (self.sampler == null) {
            return error.SamplerCreationFailed;
        }
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
    
    const log = std.log.scoped(.persistent_text);
    log.info("Initialized global persistent text system", .{});
}

pub fn deinitGlobalPersistentTextSystem(allocator: std.mem.Allocator) void {
    if (global_persistent_text_system) |system| {
        system.deinit();
        allocator.destroy(system);
        global_persistent_text_system = null;
        
        const log = std.log.scoped(.persistent_text);
        log.info("Deinitialized global persistent text system", .{});
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