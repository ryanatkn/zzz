// Pipeline creation and management for GPU rendering
// Handles graphics pipeline state configuration and creation

const std = @import("std");
const c = @import("../../platform/sdl.zig");
const loggers = @import("../../debug/loggers.zig");
const shaders_mod = @import("shaders.zig");
const glyph_triangulator = @import("../../font/strategies/vertex/triangulator.zig");

const ShaderSet = shaders_mod.ShaderSet;

pub const PipelineCreationError = error{
    PipelineCreationFailed,
};

/// Collection of graphics pipelines for different primitive types
pub const PipelineSet = struct {
    circle_pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
    rect_pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
    particle_pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
    text_pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
    text_vertex_pipeline: *c.sdl.SDL_GPUGraphicsPipeline,

    /// Creates all required pipelines for the GPU renderer
    pub fn init(device: *c.sdl.SDL_GPUDevice, window: *c.sdl.SDL_Window, shaders: *const ShaderSet) PipelineCreationError!PipelineSet {
        loggers.getRenderLog().info("pipeline_create_start", "Creating simple graphics pipelines", .{});

        // Get the actual swapchain texture format (usually B8G8R8A8 on most systems)
        const swapchain_format = c.sdl.SDL_GetGPUSwapchainTextureFormat(device, window);

        // Common pipeline states
        const vertex_input_state = getVertexInputState();
        const rasterizer_state = getRasterizerState();
        const multisample_state = getMultisampleState();

        // Blend states
        const alpha_blend_state = getAlphaBlendState(swapchain_format);
        const solid_blend_state = getSolidBlendState(swapchain_format);

        // Target infos
        const circle_target_info = c.sdl.SDL_GPUGraphicsPipelineTargetInfo{
            .color_target_descriptions = &alpha_blend_state,
            .num_color_targets = 1,
            .depth_stencil_format = c.sdl.SDL_GPU_TEXTUREFORMAT_INVALID,
            .has_depth_stencil_target = false,
        };

        const rect_target_info = c.sdl.SDL_GPUGraphicsPipelineTargetInfo{
            .color_target_descriptions = &solid_blend_state,
            .num_color_targets = 1,
            .depth_stencil_format = c.sdl.SDL_GPU_TEXTUREFORMAT_INVALID,
            .has_depth_stencil_target = false,
        };

        const particle_target_info = c.sdl.SDL_GPUGraphicsPipelineTargetInfo{
            .color_target_descriptions = &alpha_blend_state,
            .num_color_targets = 1,
            .depth_stencil_format = c.sdl.SDL_GPU_TEXTUREFORMAT_INVALID,
            .has_depth_stencil_target = false,
        };

        // Create circle pipeline
        const circle_create_info = c.sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = shaders.circle_vs,
            .fragment_shader = shaders.circle_ps,
            .vertex_input_state = vertex_input_state,
            .primitive_type = c.sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizer_state,
            .multisample_state = multisample_state,
            .target_info = circle_target_info,
        };

        const circle_pipeline = c.sdl.SDL_CreateGPUGraphicsPipeline(device, &circle_create_info) orelse {
            loggers.getRenderLog().err("circle_pipeline_fail", "Failed to create circle graphics pipeline", .{});
            loggers.getRenderLog().err("circle_pipeline_sdl_err", "SDL Error: {s}", .{c.sdl.SDL_GetError()});
            return PipelineCreationError.PipelineCreationFailed;
        };

        // Create rectangle pipeline
        const rect_create_info = c.sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = shaders.rect_vs,
            .fragment_shader = shaders.rect_ps,
            .vertex_input_state = vertex_input_state,
            .primitive_type = c.sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizer_state,
            .multisample_state = multisample_state,
            .target_info = rect_target_info,
        };

        const rect_pipeline = c.sdl.SDL_CreateGPUGraphicsPipeline(device, &rect_create_info) orelse {
            loggers.getRenderLog().err("rect_pipeline_fail", "Failed to create rectangle graphics pipeline", .{});
            loggers.getRenderLog().err("rect_pipeline_sdl_err", "SDL Error: {s}", .{c.sdl.SDL_GetError()});
            c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, circle_pipeline);
            return PipelineCreationError.PipelineCreationFailed;
        };

        // Create particle pipeline
        const particle_create_info = c.sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = shaders.particle_vs,
            .fragment_shader = shaders.particle_ps,
            .vertex_input_state = vertex_input_state,
            .primitive_type = c.sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizer_state,
            .multisample_state = multisample_state,
            .target_info = particle_target_info,
        };

        const particle_pipeline = c.sdl.SDL_CreateGPUGraphicsPipeline(device, &particle_create_info) orelse {
            loggers.getRenderLog().err("particle_pipeline_fail", "Failed to create particle graphics pipeline", .{});
            loggers.getRenderLog().err("particle_pipeline_sdl_err", "SDL Error: {s}", .{c.sdl.SDL_GetError()});
            c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, circle_pipeline);
            c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, rect_pipeline);
            return PipelineCreationError.PipelineCreationFailed;
        };

        // Create text pipeline (uses alpha blending like circles)
        const text_target_info = c.sdl.SDL_GPUGraphicsPipelineTargetInfo{
            .color_target_descriptions = &alpha_blend_state,
            .num_color_targets = 1,
            .depth_stencil_format = c.sdl.SDL_GPU_TEXTUREFORMAT_INVALID,
            .has_depth_stencil_target = false,
        };

        const text_create_info = c.sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = shaders.text_vs,
            .fragment_shader = shaders.text_ps,
            .vertex_input_state = vertex_input_state,
            .primitive_type = c.sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizer_state,
            .multisample_state = multisample_state,
            .target_info = text_target_info,
        };

        const text_pipeline = c.sdl.SDL_CreateGPUGraphicsPipeline(device, &text_create_info) orelse {
            loggers.getRenderLog().err("text_pipeline_fail", "Failed to create text graphics pipeline", .{});
            loggers.getRenderLog().err("text_pipeline_sdl_err", "SDL Error: {s}", .{c.sdl.SDL_GetError()});
            c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, circle_pipeline);
            c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, rect_pipeline);
            c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, particle_pipeline);
            return PipelineCreationError.PipelineCreationFailed;
        };

        // Create vertex-based text pipeline (uses actual vertex buffers)
        const text_vertex_input_state = getTextVertexInputState();
        const text_vertex_create_info = c.sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = shaders.text_vertex_vs,
            .fragment_shader = shaders.text_vertex_ps,
            .vertex_input_state = text_vertex_input_state,
            .primitive_type = c.sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizer_state,
            .multisample_state = multisample_state,
            .target_info = text_target_info, // Same target info as regular text
        };

        const text_vertex_pipeline = c.sdl.SDL_CreateGPUGraphicsPipeline(device, &text_vertex_create_info) orelse {
            loggers.getRenderLog().err("text_vertex_pipeline_fail", "Failed to create vertex text graphics pipeline", .{});
            loggers.getRenderLog().err("text_vertex_pipeline_sdl_err", "SDL Error: {s}", .{c.sdl.SDL_GetError()});
            c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, circle_pipeline);
            c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, rect_pipeline);
            c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, particle_pipeline);
            c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, text_pipeline);
            return PipelineCreationError.PipelineCreationFailed;
        };

        loggers.getRenderLog().info("pipeline_create_success", "Simple graphics pipelines created successfully", .{});

        return PipelineSet{
            .circle_pipeline = circle_pipeline,
            .rect_pipeline = rect_pipeline,
            .particle_pipeline = particle_pipeline,
            .text_pipeline = text_pipeline,
            .text_vertex_pipeline = text_vertex_pipeline,
        };
    }

    /// Releases all pipelines
    pub fn deinit(self: *PipelineSet, device: *c.sdl.SDL_GPUDevice) void {
        c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, self.circle_pipeline);
        c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, self.rect_pipeline);
        c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, self.particle_pipeline);
        c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, self.text_pipeline);
        c.sdl.SDL_ReleaseGPUGraphicsPipeline(device, self.text_vertex_pipeline);
    }
};

// Pipeline state helpers

// Static storage for vertex descriptions and attributes (needed for C interop)
var static_vertex_desc: c.sdl.SDL_GPUVertexBufferDescription = undefined;
var static_vertex_attrib: c.sdl.SDL_GPUVertexAttribute = undefined;
var vertex_state_initialized: bool = false;

fn getTextVertexInputState() c.sdl.SDL_GPUVertexInputState {
    if (!vertex_state_initialized) {
        static_vertex_desc = c.sdl.SDL_GPUVertexBufferDescription{
            .slot = 0, // Binding slot 0
            .pitch = @sizeOf(glyph_triangulator.GlyphVertex), // Size of actual GlyphVertex struct
            .input_rate = c.sdl.SDL_GPU_VERTEXINPUTRATE_VERTEX,
            .instance_step_rate = 0,
        };

        static_vertex_attrib = c.sdl.SDL_GPUVertexAttribute{
            .location = 0, // POSITION attribute
            .buffer_slot = 0,
            .format = c.sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, // [2]f32 position
            .offset = 0,
        };

        vertex_state_initialized = true;
    }

    return c.sdl.SDL_GPUVertexInputState{
        .vertex_buffer_descriptions = &static_vertex_desc,
        .num_vertex_buffers = 1,
        .vertex_attributes = &static_vertex_attrib,
        .num_vertex_attributes = 1,
    };
}

fn getVertexInputState() c.sdl.SDL_GPUVertexInputState {
    // No vertex input - completely procedural like test cases
    return c.sdl.SDL_GPUVertexInputState{
        .vertex_buffer_descriptions = null,
        .num_vertex_buffers = 0,
        .vertex_attributes = null,
        .num_vertex_attributes = 0,
    };
}

fn getRasterizerState() c.sdl.SDL_GPURasterizerState {
    return c.sdl.SDL_GPURasterizerState{
        .fill_mode = c.sdl.SDL_GPU_FILLMODE_FILL,
        .cull_mode = c.sdl.SDL_GPU_CULLMODE_NONE,
        .front_face = c.sdl.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,
        .depth_bias_constant_factor = 0.0,
        .depth_bias_clamp = 0.0,
        .depth_bias_slope_factor = 0.0,
        .enable_depth_bias = false,
    };
}

fn getMultisampleState() c.sdl.SDL_GPUMultisampleState {
    return c.sdl.SDL_GPUMultisampleState{
        .sample_count = c.sdl.SDL_GPU_SAMPLECOUNT_1,
        .sample_mask = 0, // Must be 0 according to SDL assertion
        .enable_mask = false,
    };
}

fn getAlphaBlendState(format: c.sdl.SDL_GPUTextureFormat) c.sdl.SDL_GPUColorTargetDescription {
    return c.sdl.SDL_GPUColorTargetDescription{
        .format = format,
        .blend_state = .{
            .src_color_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_SRC_ALPHA,
            .dst_color_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
            .color_blend_op = c.sdl.SDL_GPU_BLENDOP_ADD,
            .src_alpha_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ONE,
            .dst_alpha_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ZERO,
            .alpha_blend_op = c.sdl.SDL_GPU_BLENDOP_ADD,
            .color_write_mask = c.sdl.SDL_GPU_COLORCOMPONENT_R | c.sdl.SDL_GPU_COLORCOMPONENT_G | c.sdl.SDL_GPU_COLORCOMPONENT_B | c.sdl.SDL_GPU_COLORCOMPONENT_A,
            .enable_blend = true,
            .enable_color_write_mask = false,
        },
    };
}

fn getSolidBlendState(format: c.sdl.SDL_GPUTextureFormat) c.sdl.SDL_GPUColorTargetDescription {
    return c.sdl.SDL_GPUColorTargetDescription{
        .format = format,
        .blend_state = .{
            .src_color_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ONE,
            .dst_color_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ZERO,
            .color_blend_op = c.sdl.SDL_GPU_BLENDOP_ADD,
            .src_alpha_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ONE,
            .dst_alpha_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ZERO,
            .alpha_blend_op = c.sdl.SDL_GPU_BLENDOP_ADD,
            .color_write_mask = c.sdl.SDL_GPU_COLORCOMPONENT_R | c.sdl.SDL_GPU_COLORCOMPONENT_G | c.sdl.SDL_GPU_COLORCOMPONENT_B | c.sdl.SDL_GPU_COLORCOMPONENT_A,
            .enable_blend = false,
            .enable_color_write_mask = false,
        },
    };
}
