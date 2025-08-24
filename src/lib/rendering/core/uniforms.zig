// GPU uniform buffer structures - GPU-aligned data for shader uniforms
// All structures use explicit padding for consistent GPU memory layout

// Circle uniform buffer - color components split to avoid HLSL array packing issues
pub const CircleUniforms = extern struct {
    screen_size: [2]f32, // 8 bytes
    circle_center: [2]f32, // 8 bytes
    circle_size: [2]f32, // 8 bytes (use [0] for radius, [1] unused)
    circle_color_r: f32, // 4 bytes
    circle_color_g: f32, // 4 bytes
    circle_color_b: f32, // 4 bytes
    circle_color_a: f32, // 4 bytes
    _padding: f32, // 4 bytes (16-byte alignment)
    // Total: 44 bytes (exactly matches RectUniforms)
};

// Rectangle uniform buffer - color components split to avoid HLSL array packing issues
pub const RectUniforms = extern struct {
    screen_size: [2]f32, // 8 bytes
    rect_position: [2]f32, // 8 bytes
    rect_size: [2]f32, // 8 bytes
    rect_color_r: f32, // 4 bytes
    rect_color_g: f32, // 4 bytes
    rect_color_b: f32, // 4 bytes
    rect_color_a: f32, // 4 bytes
    _padding: f32, // 4 bytes (16-byte alignment like CircleUniforms)
    // Total: 44 bytes
};

// Particle uniform buffer for GPU-based visual particles
pub const ParticleUniforms = extern struct {
    screen_size: [2]f32, // 8 bytes
    center: [2]f32, // 8 bytes
    radius: f32, // 4 bytes
    color_r: f32, // 4 bytes
    color_g: f32, // 4 bytes
    color_b: f32, // 4 bytes
    color_a: f32, // 4 bytes
    intensity: f32, // 4 bytes
    time: f32, // 4 bytes (for animations)
    _padding: [3]f32, // 12 bytes (16-byte alignment)
    // Total: 64 bytes
};

// Frame uniforms for instanced rendering
pub const FrameUniforms = extern struct {
    screen_size: [2]f32,
    camera_transform: [4]f32, // [offset_x, offset_y, zoom, rotation]
    time: f32,
    _padding: f32,
};

// Instance data for circle batching
pub const CircleInstance = extern struct {
    center: [2]f32,
    radius: f32,
    color: [4]f32, // r, g, b, a
};

// Instance data for rectangle batching
pub const RectInstance = extern struct {
    position: [2]f32,
    size: [2]f32,
    color: [4]f32, // r, g, b, a
};

// Text uniform buffer for buffer-based text rendering (individual glyph)
pub const TextUniforms = extern struct {
    uv_min: [2]f32, // 8 bytes (atlas UV coordinates - top-left)
    uv_max: [2]f32, // 8 bytes (atlas UV coordinates - bottom-right)
    screen_size: [2]f32, // 8 bytes
    glyph_position: [2]f32, // 8 bytes (screen position)
    glyph_size: [2]f32, // 8 bytes (glyph size in pixels)
    text_color_r: f32, // 4 bytes
    text_color_g: f32, // 4 bytes
    text_color_b: f32, // 4 bytes
    text_color_a: f32, // 4 bytes
    _padding: [2]f32, // 8 bytes padding for 64-byte alignment
    // Total: 64 bytes (16-byte aligned, proper HLSL cbuffer size)
};

// Instance data for text glyph batching
pub const TextInstance = extern struct {
    screen_pos: [2]f32, // Screen position in pixels
    size: [2]f32, // Glyph size in pixels
    color: [4]f32, // r, g, b, a
    coverage_params: [4]f32, // Coverage sampling parameters (future use)
};

// Maximum instances per batch
pub const MAX_INSTANCES_PER_BATCH = 1024;

/// Uniform push helpers - eliminate SDL_PushGPUVertexUniformData boilerplate
/// These provide type safety and consistent slot management
const c = @import("../../platform/sdl.zig");

pub const UniformPush = struct {
    /// Push circle uniforms to vertex shader (slot 0)
    pub fn pushCircleUniforms(cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, uniforms: CircleUniforms) void {
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniforms, @sizeOf(CircleUniforms));
    }

    /// Push rectangle uniforms to vertex shader (slot 0)
    pub fn pushRectUniforms(cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, uniforms: RectUniforms) void {
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniforms, @sizeOf(RectUniforms));
    }

    /// Push particle uniforms to vertex shader (slot 0)
    pub fn pushParticleUniforms(cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, uniforms: ParticleUniforms) void {
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniforms, @sizeOf(ParticleUniforms));
    }

    /// Push frame uniforms to vertex shader (slot 0)
    pub fn pushFrameUniforms(cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, uniforms: FrameUniforms) void {
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniforms, @sizeOf(FrameUniforms));
    }

    /// Push text uniforms to vertex shader (slot 0)
    pub fn pushTextUniforms(cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, uniforms: TextUniforms) void {
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniforms, @sizeOf(TextUniforms));
    }
};
