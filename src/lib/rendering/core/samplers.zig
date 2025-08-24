const std = @import("std");
const c = @import("../../platform/sdl.zig");

/// Common GPU sampler presets for consistent texture filtering
/// These are zero-overhead function wrappers that create standard sampler configurations
pub const Samplers = struct {
    /// Create a linear filtering sampler for smooth texture interpolation
    /// Used for font atlases and UI textures where smooth scaling is desired
    pub fn createLinearSampler(device: *c.sdl.SDL_GPUDevice) !*c.sdl.SDL_GPUSampler {
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

        return c.sdl.SDL_CreateGPUSampler(device, &sampler_info) orelse {
            return error.SamplerCreationFailed;
        };
    }

    /// Create a nearest filtering sampler for pixel-perfect rendering
    /// Used for pixel art textures where interpolation would blur details
    pub fn createNearestSampler(device: *c.sdl.SDL_GPUDevice) !*c.sdl.SDL_GPUSampler {
        const sampler_info = c.sdl.SDL_GPUSamplerCreateInfo{
            .min_filter = c.sdl.SDL_GPU_FILTER_NEAREST,
            .mag_filter = c.sdl.SDL_GPU_FILTER_NEAREST,
            .mipmap_mode = c.sdl.SDL_GPU_SAMPLERMIPMAPMODE_NEAREST,
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

        return c.sdl.SDL_CreateGPUSampler(device, &sampler_info) orelse {
            return error.SamplerCreationFailed;
        };
    }

    /// Create a text rendering sampler optimized for font textures
    /// Uses linear filtering with nearest mipmap for crisp text at standard scales
    pub fn createTextSampler(device: *c.sdl.SDL_GPUDevice) !*c.sdl.SDL_GPUSampler {
        const sampler_info = c.sdl.SDL_GPUSamplerCreateInfo{
            .min_filter = c.sdl.SDL_GPU_FILTER_LINEAR,
            .mag_filter = c.sdl.SDL_GPU_FILTER_LINEAR,
            .mipmap_mode = c.sdl.SDL_GPU_SAMPLERMIPMAPMODE_NEAREST,
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

        return c.sdl.SDL_CreateGPUSampler(device, &sampler_info) orelse {
            return error.SamplerCreationFailed;
        };
    }
};

test "sampler creation utilities" {
    // These are basic structure tests - actual GPU tests require SDL context
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

    // Test that sampler info structure is properly initialized
    try std.testing.expect(sampler_info.min_filter == c.sdl.SDL_GPU_FILTER_LINEAR);
    try std.testing.expect(sampler_info.address_mode_u == c.sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE);
    try std.testing.expect(sampler_info.enable_anisotropy == false);
}
