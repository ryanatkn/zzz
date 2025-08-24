// Shader loading and management for GPU rendering
// Handles shader compilation, loading, and creation for all primitive types

const std = @import("std");
const c = @import("../../platform/sdl.zig");
const loggers = @import("../../debug/loggers.zig");

pub const ShaderCreationError = error{
    VertexShaderFailed,
    FragmentShaderFailed,
};

/// Collection of shaders for a complete rendering pipeline
pub const ShaderSet = struct {
    // Circle rendering
    circle_vs: *c.sdl.SDL_GPUShader,
    circle_ps: *c.sdl.SDL_GPUShader,

    // Rectangle rendering
    rect_vs: *c.sdl.SDL_GPUShader,
    rect_ps: *c.sdl.SDL_GPUShader,

    // Effect rendering
    particle_vs: *c.sdl.SDL_GPUShader,
    particle_ps: *c.sdl.SDL_GPUShader,

    // Text rendering
    text_vs: *c.sdl.SDL_GPUShader,
    text_ps: *c.sdl.SDL_GPUShader,

    // Vertex-based text rendering
    text_vertex_vs: *c.sdl.SDL_GPUShader,
    text_vertex_ps: *c.sdl.SDL_GPUShader,

    /// Creates all required shaders for the GPU renderer
    pub fn init(device: *c.sdl.SDL_GPUDevice) ShaderCreationError!ShaderSet {
        loggers.getRenderLog().info("shader_load_start", "Loading simple GPU shaders", .{});

        var shaders = ShaderSet{
            .circle_vs = undefined,
            .circle_ps = undefined,
            .rect_vs = undefined,
            .rect_ps = undefined,
            .particle_vs = undefined,
            .particle_ps = undefined,
            .text_vs = undefined,
            .text_ps = undefined,
            .text_vertex_vs = undefined,
            .text_vertex_ps = undefined,
        };

        // Load simple circle shaders
        const circle_vs_spv = @embedFile("../../../shaders/compiled/vulkan/simple_circle_vs.spv");
        const circle_ps_spv = @embedFile("../../../shaders/compiled/vulkan/simple_circle_ps.spv");

        shaders.circle_vs = createVertexShader(device, circle_vs_spv, "vs_main", 1) catch |err| {
            loggers.getRenderLog().err("circle_vs_fail", "Failed to create circle vertex shader: {s}", .{c.sdl.SDL_GetError()});
            return err;
        };

        shaders.circle_ps = createFragmentShader(device, circle_ps_spv, "ps_main", 0, 0) catch |err| {
            loggers.getRenderLog().err("circle_fs_fail", "Failed to create circle fragment shader", .{});
            c.sdl.SDL_ReleaseGPUShader(device, shaders.circle_vs);
            return err;
        };

        // Load rectangle shaders
        const rect_vs_spv = @embedFile("../../../shaders/compiled/vulkan/simple_rectangle_vs.spv");
        const rect_ps_spv = @embedFile("../../../shaders/compiled/vulkan/simple_rectangle_ps.spv");

        shaders.rect_vs = createVertexShader(device, rect_vs_spv, "vs_main", 1) catch |err| {
            loggers.getRenderLog().err("rect_vs_fail", "Failed to create rectangle vertex shader", .{});
            shaders.deinit(device);
            return err;
        };

        shaders.rect_ps = createFragmentShader(device, rect_ps_spv, "ps_main", 0, 0) catch |err| {
            loggers.getRenderLog().err("rect_fs_fail", "Failed to create rectangle fragment shader", .{});
            shaders.deinit(device);
            return err;
        };

        // Load particle shaders
        const particle_vs_spv = @embedFile("../../../shaders/compiled/vulkan/particle_vs.spv");
        const particle_ps_spv = @embedFile("../../../shaders/compiled/vulkan/particle_ps.spv");

        shaders.particle_vs = createVertexShader(device, particle_vs_spv, "vs_main", 1) catch |err| {
            loggers.getRenderLog().err("particle_vs_fail", "Failed to create particle vertex shader", .{});
            shaders.deinit(device);
            return err;
        };

        shaders.particle_ps = createFragmentShader(device, particle_ps_spv, "ps_main", 0, 0) catch |err| {
            loggers.getRenderLog().err("particle_fs_fail", "Failed to create particle fragment shader", .{});
            shaders.deinit(device);
            return err;
        };

        // Load text shaders
        const text_vs_spv = @embedFile("../../../shaders/compiled/vulkan/text_vs.spv");
        const text_ps_spv = @embedFile("../../../shaders/compiled/vulkan/text_ps.spv");

        shaders.text_vs = createVertexShader(device, text_vs_spv, "vs_main", 1) catch |err| {
            loggers.getRenderLog().err("text_vs_fail", "Failed to create text vertex shader", .{});
            shaders.deinit(device);
            return err;
        };

        shaders.text_ps = createFragmentShader(device, text_ps_spv, "ps_main", 0, 1) catch |err| {
            loggers.getRenderLog().err("text_fs_fail", "Failed to create text fragment shader", .{});
            shaders.deinit(device);
            return err;
        };

        // Load vertex-based text shaders
        const text_vertex_vs_spv = @embedFile("../../../shaders/compiled/vulkan/text_vertex_vs.spv");
        const text_vertex_ps_spv = @embedFile("../../../shaders/compiled/vulkan/text_vertex_ps.spv");
        shaders.text_vertex_vs = createVertexShader(device, text_vertex_vs_spv, "vs_main", 1) catch |err| {
            loggers.getRenderLog().err("text_vertex_vs_fail", "Failed to create text vertex shader", .{});
            shaders.deinit(device);
            return err;
        };
        shaders.text_vertex_ps = createFragmentShader(device, text_vertex_ps_spv, "ps_main", 0, 0) catch |err| {
            loggers.getRenderLog().err("text_vertex_fs_fail", "Failed to create text vertex fragment shader", .{});
            shaders.deinit(device);
            return err;
        };

        loggers.getRenderLog().info("shader_load_success", "Simple GPU shaders loaded successfully", .{});
        return shaders;
    }

    /// Releases all shaders
    pub fn deinit(self: *ShaderSet, device: *c.sdl.SDL_GPUDevice) void {
        c.sdl.SDL_ReleaseGPUShader(device, self.circle_vs);
        c.sdl.SDL_ReleaseGPUShader(device, self.circle_ps);
        c.sdl.SDL_ReleaseGPUShader(device, self.rect_vs);
        c.sdl.SDL_ReleaseGPUShader(device, self.rect_ps);
        c.sdl.SDL_ReleaseGPUShader(device, self.particle_vs);
        c.sdl.SDL_ReleaseGPUShader(device, self.particle_ps);
        c.sdl.SDL_ReleaseGPUShader(device, self.text_vs);
        c.sdl.SDL_ReleaseGPUShader(device, self.text_ps);
        c.sdl.SDL_ReleaseGPUShader(device, self.text_vertex_vs);
        c.sdl.SDL_ReleaseGPUShader(device, self.text_vertex_ps);
    }
};

/// Creates a vertex shader from SPIRV bytecode
fn createVertexShader(device: *c.sdl.SDL_GPUDevice, spirv_data: []const u8, entrypoint: [*:0]const u8, uniform_buffers: u32) ShaderCreationError!*c.sdl.SDL_GPUShader {
    const shader_info = c.sdl.SDL_GPUShaderCreateInfo{
        .code_size = spirv_data.len,
        .code = @ptrCast(spirv_data.ptr),
        .entrypoint = entrypoint,
        .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
        .stage = c.sdl.SDL_GPU_SHADERSTAGE_VERTEX,
        .num_samplers = 0,
        .num_storage_textures = 0,
        .num_storage_buffers = 0,
        .num_uniform_buffers = uniform_buffers,
    };

    return c.sdl.SDL_CreateGPUShader(device, &shader_info) orelse {
        return ShaderCreationError.VertexShaderFailed;
    };
}

/// Creates a fragment shader from SPIRV bytecode
fn createFragmentShader(device: *c.sdl.SDL_GPUDevice, spirv_data: []const u8, entrypoint: [*:0]const u8, uniform_buffers: u32, samplers: u32) ShaderCreationError!*c.sdl.SDL_GPUShader {
    const shader_info = c.sdl.SDL_GPUShaderCreateInfo{
        .code_size = spirv_data.len,
        .code = @ptrCast(spirv_data.ptr),
        .entrypoint = entrypoint,
        .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
        .stage = c.sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
        .num_samplers = samplers,
        .num_storage_textures = 0,
        .num_storage_buffers = 0,
        .num_uniform_buffers = uniform_buffers,
    };

    return c.sdl.SDL_CreateGPUShader(device, &shader_info) orelse {
        return ShaderCreationError.FragmentShaderFailed;
    };
}
