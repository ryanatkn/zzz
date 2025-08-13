const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");

const Vec2 = types.Vec2;
const Color = types.Color;

// Text rendering uniforms
const TextUniforms = extern struct {
    screen_size: [2]f32,      // Screen dimensions for NDC conversion
    text_position: [2]f32,    // Text position in screen coordinates
    text_size: [2]f32,        // Text size in pixels
    text_color_r: f32,        // Color components split to avoid
    text_color_g: f32,        // HLSL array packing issues
    text_color_b: f32,        
    text_color_a: f32,        // Alpha channel
    time: f32,                // Animation time
    _padding: [3]f32,         // Pad to 16-byte alignment
};

// Text texture wrapper
const TextTexture = struct {
    texture: *c.sdl.SDL_GPUTexture,
    sampler: *c.sdl.SDL_GPUSampler,
    width: u32,
    height: u32,

    fn deinit(self: TextTexture, device: *c.sdl.SDL_GPUDevice) void {
        // Note: Don't release sampler here - it's shared across all text renders
        // Note: Don't release texture here - it's managed by fonts.zig
        _ = device;
        _ = self;
    }
};

// Queued text draw command
const TextDrawCommand = struct {
    texture: TextTexture,    // Texture containing rendered text
    position: Vec2,          // Screen position to draw at
    color: Color,           // Text color (applied to texture)
};

// Text renderer - handles all text-specific GPU operations
pub const TextRenderer = struct {
    // Core GPU resources
    device: *c.sdl.SDL_GPUDevice,
    allocator: std.mem.Allocator,
    screen_width: f32,
    screen_height: f32,

    // Text-specific shaders and pipeline
    text_vs: ?*c.sdl.SDL_GPUShader,
    text_ps: ?*c.sdl.SDL_GPUShader,
    text_pipeline: ?*c.sdl.SDL_GPUGraphicsPipeline,
    text_sampler: ?*c.sdl.SDL_GPUSampler,

    // Text rendering queue
    text_draw_queue: std.ArrayList(TextDrawCommand),

    const Self = @This();

    pub fn init(device: *c.sdl.SDL_GPUDevice, allocator: std.mem.Allocator, screen_width: f32, screen_height: f32) !Self {
        var self = Self{
            .device = device,
            .allocator = allocator,
            .screen_width = screen_width,
            .screen_height = screen_height,
            .text_vs = null,
            .text_ps = null,
            .text_pipeline = null,
            .text_sampler = null,
            .text_draw_queue = std.ArrayList(TextDrawCommand).init(allocator),
        };

        try self.loadTextShaders();
        try self.createTextPipeline();
        try self.createTextSampler();

        return self;
    }

    pub fn deinit(self: *Self) void {
        // Cleanup text resources
        if (self.text_sampler) |sampler| c.sdl.SDL_ReleaseGPUSampler(self.device, sampler);
        if (self.text_pipeline) |pipeline| c.sdl.SDL_ReleaseGPUGraphicsPipeline(self.device, pipeline);
        if (self.text_vs) |shader| c.sdl.SDL_ReleaseGPUShader(self.device, shader);
        if (self.text_ps) |shader| c.sdl.SDL_ReleaseGPUShader(self.device, shader);
        
        self.text_draw_queue.deinit();
    }

    pub fn updateScreenSize(self: *Self, width: f32, height: f32) void {
        self.screen_width = width;
        self.screen_height = height;
    }

    // Queue a texture-based text for drawing
    pub fn queueTextTexture(
        self: *Self,
        texture: *c.sdl.SDL_GPUTexture,
        position: Vec2,
        width: u32,
        height: u32,
        color: Color
    ) void {
        // Create a TextTexture with the shared sampler
        if (self.text_sampler) |sampler| {
            const text_texture = TextTexture{
                .texture = texture,
                .sampler = sampler,  // Use shared sampler
                .width = width,
                .height = height,
            };
            
            const cmd = TextDrawCommand{
                .texture = text_texture,
                .position = position,
                .color = color,
            };
            
            self.text_draw_queue.append(cmd) catch |err| {
                std.log.err("Failed to queue text texture: {}", .{err});
            };
        } else {
            std.log.warn("Text sampler not initialized, cannot queue text texture", .{});
        }
    }

    // Draw all queued text (call during render pass)
    pub fn drawQueuedText(
        self: *Self,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass
    ) void {
        if (self.text_draw_queue.items.len == 0) {
            return;
        }
        
        const log = std.log.scoped(.text_renderer);
        log.info("=== DRAWING {} QUEUED TEXT TEXTURES ===", .{self.text_draw_queue.items.len});
        
        // Draw each queued text texture as a textured quad
        for (self.text_draw_queue.items, 0..) |cmd, cmd_index| {
            log.info("Drawing text texture {} as textured quad: {}x{} at ({}, {})", .{ 
                cmd_index, cmd.texture.width, cmd.texture.height, cmd.position.x, cmd.position.y 
            });
            
            // Get the size of the text texture
            const size = Vec2{
                .x = @as(f32, @floatFromInt(cmd.texture.width)),
                .y = @as(f32, @floatFromInt(cmd.texture.height)),
            };
            
            // Draw the textured quad with the actual texture
            self.drawTexturedQuad(
                cmd_buffer, 
                render_pass, 
                cmd.texture.texture,  // The actual SDL texture 
                cmd.texture.sampler,  // The sampler for the texture
                cmd.position, 
                size, 
                cmd.color
            );
            
            log.info("  ✓ Successfully drew text as textured quad", .{});
        }
        
        log.info("Drew {} text textures as textured quads", .{self.text_draw_queue.items.len});
        
        // Release textures after drawing and clear queue for next frame
        for (self.text_draw_queue.items) |cmd| {
            // Release the GPU texture after drawing is complete
            c.sdl.SDL_ReleaseGPUTexture(self.device, cmd.texture.texture);
        }
        self.text_draw_queue.clearRetainingCapacity();
    }

    // Load text shaders
    fn loadTextShaders(self: *Self) !void {
        const text_vs_spv = @embedFile("../shaders/compiled/vulkan/text_vs.spv");
        const text_ps_spv = @embedFile("../shaders/compiled/vulkan/text_ps.spv");

        const text_vs_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = text_vs_spv.len,
            .code = @ptrCast(text_vs_spv.ptr),
            .entrypoint = "vs_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_VERTEX,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 1, // Text shader uses uniforms
        };

        self.text_vs = c.sdl.SDL_CreateGPUShader(self.device, &text_vs_info);
        if (self.text_vs == null) {
            std.debug.print("Failed to create text vertex shader: {s}\n", .{c.sdl.SDL_GetError()});
            return error.TextVertexShaderFailed;
        }

        const text_ps_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = text_ps_spv.len,
            .code = @ptrCast(text_ps_spv.ptr),
            .entrypoint = "ps_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            .num_samplers = 1, // Fragment shader uses sampler for texture
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 0,
        };

        if (self.text_vs != null) {
            self.text_ps = c.sdl.SDL_CreateGPUShader(self.device, &text_ps_info);
            if (self.text_ps == null) {
                std.debug.print("Failed to create text fragment shader: {s}\n", .{c.sdl.SDL_GetError()});
                return error.TextFragmentShaderFailed;
            }
        } else {
            self.text_ps = null;
        }
    }

    // Create text rendering pipeline
    fn createTextPipeline(self: *Self) !void {
        if (self.text_vs == null or self.text_ps == null) {
            std.debug.print("Text shaders not loaded, skipping pipeline creation\n", .{});
            return error.TextShadersNotLoaded;
        }

        const text_create_info = c.sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .target_info = .{
                .num_color_targets = 1,
                .color_target_descriptions = &[_]c.sdl.SDL_GPUColorTargetDescription{
                    .{
                        .format = c.sdl.SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM, // Common swapchain format
                        .blend_state = .{
                            .src_color_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ONE,
                            .dst_color_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
                            .color_blend_op = c.sdl.SDL_GPU_BLENDOP_ADD,
                            .src_alpha_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ONE,
                            .dst_alpha_blendfactor = c.sdl.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
                            .alpha_blend_op = c.sdl.SDL_GPU_BLENDOP_ADD,
                            .color_write_mask = c.sdl.SDL_GPU_COLORCOMPONENT_R | c.sdl.SDL_GPU_COLORCOMPONENT_G | c.sdl.SDL_GPU_COLORCOMPONENT_B | c.sdl.SDL_GPU_COLORCOMPONENT_A,
                            .enable_blend = true,
                        },
                    },
                },
                .has_depth_stencil_target = false,
                .depth_stencil_format = c.sdl.SDL_GPU_TEXTUREFORMAT_D32_FLOAT,
            },
            .vertex_input_state = .{
                .num_vertex_attributes = 0,
                .vertex_attributes = null,
                .num_vertex_buffers = 0,
                .vertex_buffer_descriptions = null,
            },
            .primitive_type = c.sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = .{
                .fill_mode = c.sdl.SDL_GPU_FILLMODE_FILL,
                .cull_mode = c.sdl.SDL_GPU_CULLMODE_NONE,
                .front_face = c.sdl.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,
                .depth_bias_constant_factor = 0.0,
                .depth_bias_clamp = 0.0,
                .depth_bias_slope_factor = 0.0,
                .enable_depth_bias = false,
            },
            .multisample_state = .{
                .sample_count = c.sdl.SDL_GPU_SAMPLECOUNT_1,
                .sample_mask = 0,
            },
            .vertex_shader = self.text_vs.?,
            .fragment_shader = self.text_ps.?,
        };

        self.text_pipeline = c.sdl.SDL_CreateGPUGraphicsPipeline(self.device, &text_create_info);
        if (self.text_pipeline == null) {
            std.debug.print("Failed to create text graphics pipeline: {s}\n", .{c.sdl.SDL_GetError()});
            return error.TextPipelineCreationFailed;
        }

        std.debug.print("✓ Text pipeline created successfully\n", .{});
    }

    // Create sampler for text textures
    fn createTextSampler(self: *Self) !void {
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

        self.text_sampler = c.sdl.SDL_CreateGPUSampler(self.device, &sampler_info);
        if (self.text_sampler == null) {
            std.debug.print("Failed to create text sampler: {s}\n", .{c.sdl.SDL_GetError()});
            return error.SamplerCreationFailed;
        }

        std.debug.print("✓ Text sampler created successfully\n", .{});
    }

    // Draw a textured quad for text rendering
    fn drawTexturedQuad(
        self: *Self, 
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, 
        render_pass: *c.sdl.SDL_GPURenderPass, 
        texture: *c.sdl.SDL_GPUTexture,
        sampler: *c.sdl.SDL_GPUSampler,
        position: Vec2, 
        size: Vec2, 
        color: Color
    ) void {
        // Prepare uniform data for text shader
        const uniform_data = TextUniforms{
            .screen_size = [2]f32{ self.screen_width, self.screen_height },
            .text_position = [2]f32{ position.x, position.y },
            .text_size = [2]f32{ size.x, size.y },
            .text_color_r = @as(f32, @floatFromInt(color.r)) / 255.0,
            .text_color_g = @as(f32, @floatFromInt(color.g)) / 255.0,
            .text_color_b = @as(f32, @floatFromInt(color.b)) / 255.0,
            .text_color_a = @as(f32, @floatFromInt(color.a)) / 255.0,
            .time = 0.0, // TODO: Add actual time if needed for animations
            ._padding = [3]f32{ 0.0, 0.0, 0.0 },
        };
        
        // Push uniform data BEFORE binding pipeline (critical for SDL3 GPU)
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(TextUniforms));
        
        // Bind text pipeline
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.text_pipeline);
        
        // Bind texture and sampler for fragment shader
        const texture_sampler_binding = c.sdl.SDL_GPUTextureSamplerBinding{
            .texture = texture,
            .sampler = sampler,
        };
        c.sdl.SDL_BindGPUFragmentSamplers(render_pass, 0, &texture_sampler_binding, 1);
        
        // Draw the textured quad
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad (2 triangles)
    }
};