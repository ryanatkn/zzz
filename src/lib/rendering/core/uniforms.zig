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

// Maximum instances per batch
pub const MAX_INSTANCES_PER_BATCH = 1024;
