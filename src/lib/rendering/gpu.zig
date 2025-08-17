const std = @import("std");
const loggers = @import("../debug/loggers.zig");
const performance = @import("performance.zig");

const c = @import("../platform/sdl.zig");

const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const TextRenderer = @import("../text/renderer.zig").TextRenderer;

const Vec2 = math.Vec2;
const Color = colors.Color;

// Circle uniform buffer - color components split to avoid HLSL array packing issues
const CircleUniforms = extern struct {
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
const RectUniforms = extern struct {
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

// Effect uniform buffer for GPU-based visual effects
const EffectUniforms = extern struct {
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
const FrameUniforms = extern struct {
    screen_size: [2]f32,
    camera_transform: [4]f32, // [offset_x, offset_y, zoom, rotation]
    time: f32,
    _padding: f32,
};

// Instance data for circle batching
const CircleInstance = extern struct {
    center: [2]f32,
    radius: f32,
    color: [4]f32, // r, g, b, a
};

// Instance data for rectangle batching
const RectInstance = extern struct {
    position: [2]f32,
    size: [2]f32,
    color: [4]f32, // r, g, b, a
};

// Maximum instances per batch
const MAX_INSTANCES_PER_BATCH = 1024;

pub const SimpleGPURenderer = struct {
    allocator: std.mem.Allocator,
    device: *c.sdl.SDL_GPUDevice,
    window: *c.sdl.SDL_Window,

    // Circle rendering
    circle_vs: *c.sdl.SDL_GPUShader,
    circle_ps: *c.sdl.SDL_GPUShader,
    circle_pipeline: *c.sdl.SDL_GPUGraphicsPipeline,

    // Rectangle rendering
    rect_vs: *c.sdl.SDL_GPUShader,
    rect_ps: *c.sdl.SDL_GPUShader,
    rect_pipeline: *c.sdl.SDL_GPUGraphicsPipeline,

    // Effect rendering
    effect_vs: *c.sdl.SDL_GPUShader,
    effect_ps: *c.sdl.SDL_GPUShader,
    effect_pipeline: *c.sdl.SDL_GPUGraphicsPipeline,

    // Text rendering
    text_renderer: TextRenderer,

    // Vector graphics rendering

    // Current frame data
    screen_width: f32,
    screen_height: f32,

    // Instance batching buffers
    circle_instances: std.ArrayList(CircleInstance),
    rect_instances: std.ArrayList(RectInstance),
    effect_instances: std.ArrayList(CircleInstance), // Effects reuse circle data
    
    // Instance buffers for GPU upload
    circle_instance_buffer: ?*c.sdl.SDL_GPUBuffer,
    rect_instance_buffer: ?*c.sdl.SDL_GPUBuffer,
    effect_instance_buffer: ?*c.sdl.SDL_GPUBuffer,

    // Performance monitoring
    perf_monitor: performance.PerformanceMonitor,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, window: *c.sdl.SDL_Window) !Self {
        loggers.getRenderLog().info("gpu_create", "Creating simple GPU device", .{});

        // Try different backends to work around NVIDIA Vulkan driver issues
        // Priority: 1) OpenGL first 2) Software 3) Auto-select as last resort
        const backends = [_]?[*:0]const u8{
            "opengl", // Force OpenGL backend first
            "software", // Software fallback
            null, // Auto-select (usually Vulkan) as last resort
        };

        var device: ?*c.sdl.SDL_GPUDevice = null;
        var backend_used: []const u8 = "unknown";

        for (backends) |backend_name| {
            const name_str = if (backend_name) |name| std.mem.span(name) else "auto-select";
            loggers.getRenderLog().info("gpu_backend_try", "Trying GPU backend: {s}", .{name_str});

            device = c.sdl.SDL_CreateGPUDevice(c.sdl.SDL_GPU_SHADERFORMAT_SPIRV | c.sdl.SDL_GPU_SHADERFORMAT_DXIL, true, // Enable debug mode for better error reporting
                backend_name);

            if (device != null) {
                backend_used = name_str;
                break;
            } else {
                const err = c.sdl.SDL_GetError();
                loggers.getRenderLog().warn("gpu_backend_fail", "Failed to create GPU device with {s}: {s}", .{ name_str, err });
            }
        }

        const final_device = device orelse {
            loggers.getRenderLog().err("gpu_create_fail", "Failed to create GPU device", .{});
            return error.GPUDeviceCreationFailed;
        };

        if (!c.sdl.SDL_ClaimWindowForGPUDevice(final_device, window)) {
            loggers.getRenderLog().err("gpu_claim_fail", "Failed to claim window for GPU device", .{});
            c.sdl.SDL_DestroyGPUDevice(final_device);
            return error.WindowClaimFailed;
        }

        loggers.getRenderLog().info("gpu_create_success", "GPU device created successfully using backend: {s}", .{backend_used});

        var self = Self{
            .allocator = allocator,
            .device = final_device,
            .window = window,
            .circle_vs = undefined,
            .circle_ps = undefined,
            .circle_pipeline = undefined,
            .rect_vs = undefined,
            .rect_ps = undefined,
            .rect_pipeline = undefined,
            .effect_vs = undefined,
            .effect_ps = undefined,
            .effect_pipeline = undefined,
            .text_renderer = undefined,
            .screen_width = @import("../core/constants.zig").SCREEN.BASE_WIDTH,
            .screen_height = @import("../core/constants.zig").SCREEN.BASE_HEIGHT,
            .circle_instances = std.ArrayList(CircleInstance).init(allocator),
            .rect_instances = std.ArrayList(RectInstance).init(allocator),
            .effect_instances = std.ArrayList(CircleInstance).init(allocator),
            .circle_instance_buffer = null,
            .rect_instance_buffer = null,
            .effect_instance_buffer = null,
            .perf_monitor = performance.PerformanceMonitor.init(performance.Config.DEFAULT_LOGGING_FREQUENCY),
        };

        try self.createShaders();
        try self.createPipelines();
        try self.createInstanceBuffers();

        // Initialize text renderer
        self.text_renderer = try TextRenderer.init(self.device, allocator, self.screen_width, self.screen_height);

        // Show window now that GPU is set up
        _ = c.sdl.SDL_ShowWindow(window);

        return self;
    }

    pub fn deinit(self: *Self) void {
        // Clean up instance buffers
        if (self.circle_instance_buffer) |buffer| c.sdl.SDL_ReleaseGPUBuffer(self.device, buffer);
        if (self.rect_instance_buffer) |buffer| c.sdl.SDL_ReleaseGPUBuffer(self.device, buffer);
        if (self.effect_instance_buffer) |buffer| c.sdl.SDL_ReleaseGPUBuffer(self.device, buffer);
        
        self.circle_instances.deinit();
        self.rect_instances.deinit();
        self.effect_instances.deinit();

        // Clean up text renderer
        self.text_renderer.deinit();

        c.sdl.SDL_ReleaseGPUGraphicsPipeline(self.device, self.circle_pipeline);
        c.sdl.SDL_ReleaseGPUGraphicsPipeline(self.device, self.rect_pipeline);
        c.sdl.SDL_ReleaseGPUGraphicsPipeline(self.device, self.effect_pipeline);
        c.sdl.SDL_ReleaseGPUShader(self.device, self.circle_vs);
        c.sdl.SDL_ReleaseGPUShader(self.device, self.circle_ps);
        c.sdl.SDL_ReleaseGPUShader(self.device, self.rect_vs);
        c.sdl.SDL_ReleaseGPUShader(self.device, self.rect_ps);
        c.sdl.SDL_ReleaseGPUShader(self.device, self.effect_vs);
        c.sdl.SDL_ReleaseGPUShader(self.device, self.effect_ps);
        c.sdl.SDL_DestroyGPUDevice(self.device);
    }

    fn createShaders(self: *Self) !void {
        loggers.getRenderLog().info("shader_load_start", "Loading simple GPU shaders", .{});

        // Load simple circle shaders
        const circle_vs_spv = @embedFile("../../shaders/compiled/vulkan/simple_circle_vs.spv");
        const circle_ps_spv = @embedFile("../../shaders/compiled/vulkan/simple_circle_ps.spv");

        const circle_vs_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = circle_vs_spv.len,
            .code = @ptrCast(circle_vs_spv.ptr),
            .entrypoint = "vs_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_VERTEX,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 1, // Circle shader uses uniforms
        };

        self.circle_vs = c.sdl.SDL_CreateGPUShader(self.device, &circle_vs_info) orelse {
            loggers.getRenderLog().err("circle_vs_fail", "Failed to create circle vertex shader: {s}", .{c.sdl.SDL_GetError()});
            return error.VertexShaderFailed;
        };

        const circle_ps_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = circle_ps_spv.len,
            .code = @ptrCast(circle_ps_spv.ptr),
            .entrypoint = "ps_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 0, // Fragment shader doesn't use uniforms directly
        };

        self.circle_ps = c.sdl.SDL_CreateGPUShader(self.device, &circle_ps_info) orelse {
            loggers.getRenderLog().err("circle_fs_fail", "Failed to create circle fragment shader", .{});
            return error.FragmentShaderFailed;
        };

        // Load rectangle shaders
        const rect_vs_spv = @embedFile("../../shaders/compiled/vulkan/simple_rectangle_vs.spv");
        const rect_ps_spv = @embedFile("../../shaders/compiled/vulkan/simple_rectangle_ps.spv");

        const rect_vs_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = rect_vs_spv.len,
            .code = @ptrCast(rect_vs_spv.ptr),
            .entrypoint = "vs_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_VERTEX,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 1, // Rectangle shader uses uniforms
        };

        self.rect_vs = c.sdl.SDL_CreateGPUShader(self.device, &rect_vs_info) orelse {
            loggers.getRenderLog().err("rect_vs_fail", "Failed to create rectangle vertex shader", .{});
            return error.VertexShaderFailed;
        };

        const rect_ps_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = rect_ps_spv.len,
            .code = @ptrCast(rect_ps_spv.ptr),
            .entrypoint = "ps_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 0, // Fragment shader doesn't need uniforms
        };

        self.rect_ps = c.sdl.SDL_CreateGPUShader(self.device, &rect_ps_info) orelse {
            loggers.getRenderLog().err("rect_fs_fail", "Failed to create rectangle fragment shader", .{});
            return error.FragmentShaderFailed;
        };

        // Load effect shaders
        const effect_vs_spv = @embedFile("../../shaders/compiled/vulkan/effect_vs.spv");
        const effect_ps_spv = @embedFile("../../shaders/compiled/vulkan/effect_ps.spv");

        const effect_vs_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = effect_vs_spv.len,
            .code = @ptrCast(effect_vs_spv.ptr),
            .entrypoint = "vs_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_VERTEX,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 1, // Effect shader uses uniforms
        };

        self.effect_vs = c.sdl.SDL_CreateGPUShader(self.device, &effect_vs_info) orelse {
            loggers.getRenderLog().err("effect_vs_fail", "Failed to create effect vertex shader", .{});
            return error.VertexShaderFailed;
        };

        const effect_ps_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = effect_ps_spv.len,
            .code = @ptrCast(effect_ps_spv.ptr),
            .entrypoint = "ps_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .stage = c.sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            .num_samplers = 0,
            .num_storage_textures = 0,
            .num_storage_buffers = 0,
            .num_uniform_buffers = 0, // Fragment shader doesn't need uniforms
        };

        self.effect_ps = c.sdl.SDL_CreateGPUShader(self.device, &effect_ps_info) orelse {
            loggers.getRenderLog().err("effect_fs_fail", "Failed to create effect fragment shader", .{});
            return error.FragmentShaderFailed;
        };

        loggers.getRenderLog().info("shader_load_success", "Simple GPU shaders loaded successfully", .{});
    }

    fn createPipelines(self: *Self) !void {
        loggers.getRenderLog().info("pipeline_create_start", "Creating simple graphics pipelines", .{});

        // Get the actual swapchain texture format (usually B8G8R8A8 on most systems)
        const swapchain_format = c.sdl.SDL_GetGPUSwapchainTextureFormat(self.device, self.window);

        // No vertex input - completely procedural like test cases
        const vertex_input_state = c.sdl.SDL_GPUVertexInputState{
            .vertex_buffer_descriptions = null,
            .num_vertex_buffers = 0,
            .vertex_attributes = null,
            .num_vertex_attributes = 0,
        };

        const rasterizer_state = c.sdl.SDL_GPURasterizerState{
            .fill_mode = c.sdl.SDL_GPU_FILLMODE_FILL,
            .cull_mode = c.sdl.SDL_GPU_CULLMODE_NONE,
            .front_face = c.sdl.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,
            .depth_bias_constant_factor = 0.0,
            .depth_bias_clamp = 0.0,
            .depth_bias_slope_factor = 0.0,
            .enable_depth_bias = false,
        };

        const multisample_state = c.sdl.SDL_GPUMultisampleState{
            .sample_count = c.sdl.SDL_GPU_SAMPLECOUNT_1,
            .sample_mask = 0, // Must be 0 according to SDL assertion
            .enable_mask = false,
        };

        // Alpha blending for smooth circles - use actual swapchain format
        const alpha_blend_state = c.sdl.SDL_GPUColorTargetDescription{
            .format = swapchain_format,
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

        // No blending for solid rectangles - use actual swapchain format
        const solid_blend_state = c.sdl.SDL_GPUColorTargetDescription{
            .format = swapchain_format,
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

        // Create circle pipeline
        const circle_create_info = c.sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = self.circle_vs,
            .fragment_shader = self.circle_ps,
            .vertex_input_state = vertex_input_state,
            .primitive_type = c.sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizer_state,
            .multisample_state = multisample_state,
            .target_info = circle_target_info,
        };

        self.circle_pipeline = c.sdl.SDL_CreateGPUGraphicsPipeline(self.device, &circle_create_info) orelse {
            loggers.getRenderLog().err("circle_pipeline_fail", "Failed to create circle graphics pipeline", .{});
            loggers.getRenderLog().err("circle_pipeline_sdl_err", "SDL Error: {s}", .{c.sdl.SDL_GetError()});
            return error.PipelineCreationFailed;
        };

        // Create rectangle pipeline
        const rect_create_info = c.sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = self.rect_vs,
            .fragment_shader = self.rect_ps,
            .vertex_input_state = vertex_input_state,
            .primitive_type = c.sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizer_state,
            .multisample_state = multisample_state,
            .target_info = rect_target_info,
        };

        self.rect_pipeline = c.sdl.SDL_CreateGPUGraphicsPipeline(self.device, &rect_create_info) orelse {
            loggers.getRenderLog().err("rect_pipeline_fail", "Failed to create rectangle graphics pipeline", .{});
            loggers.getRenderLog().err("rect_pipeline_sdl_err", "SDL Error: {s}", .{c.sdl.SDL_GetError()});
            return error.PipelineCreationFailed;
        };

        // Create effect pipeline (needs alpha blending for visual effects)
        const effect_target_info = c.sdl.SDL_GPUGraphicsPipelineTargetInfo{
            .color_target_descriptions = &alpha_blend_state,
            .num_color_targets = 1,
            .depth_stencil_format = c.sdl.SDL_GPU_TEXTUREFORMAT_INVALID,
            .has_depth_stencil_target = false,
        };

        const effect_create_info = c.sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = self.effect_vs,
            .fragment_shader = self.effect_ps,
            .vertex_input_state = vertex_input_state,
            .primitive_type = c.sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizer_state,
            .multisample_state = multisample_state,
            .target_info = effect_target_info,
        };

        self.effect_pipeline = c.sdl.SDL_CreateGPUGraphicsPipeline(self.device, &effect_create_info) orelse {
            loggers.getRenderLog().err("effect_pipeline_fail", "Failed to create effect graphics pipeline", .{});
            loggers.getRenderLog().err("effect_pipeline_sdl_err", "SDL Error: {s}", .{c.sdl.SDL_GetError()});
            return error.PipelineCreationFailed;
        };

        loggers.getRenderLog().info("pipeline_create_success", "Simple graphics pipelines created successfully", .{});
    }

    fn createInstanceBuffers(self: *Self) !void {
        loggers.getRenderLog().info("instance_buffer_create", "Creating instance buffers for batching", .{});

        // Create instance buffers for batched rendering
        const buffer_create_info = c.sdl.SDL_GPUBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
            .size = MAX_INSTANCES_PER_BATCH * @sizeOf(CircleInstance),
        };

        self.circle_instance_buffer = c.sdl.SDL_CreateGPUBuffer(self.device, &buffer_create_info) orelse {
            loggers.getRenderLog().err("circle_buffer_fail", "Failed to create circle instance buffer", .{});
            return error.BufferCreationFailed;
        };

        const rect_buffer_create_info = c.sdl.SDL_GPUBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
            .size = MAX_INSTANCES_PER_BATCH * @sizeOf(RectInstance),
        };

        self.rect_instance_buffer = c.sdl.SDL_CreateGPUBuffer(self.device, &rect_buffer_create_info) orelse {
            loggers.getRenderLog().err("rect_buffer_fail", "Failed to create rectangle instance buffer", .{});
            return error.BufferCreationFailed;
        };

        self.effect_instance_buffer = c.sdl.SDL_CreateGPUBuffer(self.device, &buffer_create_info) orelse {
            loggers.getRenderLog().err("effect_buffer_fail", "Failed to create effect instance buffer", .{});
            return error.BufferCreationFailed;
        };

        loggers.getRenderLog().info("instance_buffer_success", "Instance buffers created successfully", .{});
    }

    // Begin frame and get command buffer ready for rendering
    pub fn beginFrame(self: *Self, window: *c.sdl.SDL_Window) !*c.sdl.SDL_GPUCommandBuffer {
        // Update screen size
        var window_w: c_int = undefined;
        var window_h: c_int = undefined;
        _ = c.sdl.SDL_GetWindowSize(window, &window_w, &window_h);
        self.screen_width = @floatFromInt(window_w);
        self.screen_height = @floatFromInt(window_h);

        // Update text renderer screen size
        self.text_renderer.updateScreenSize(self.screen_width, self.screen_height);

        // Acquire command buffer
        const cmd_buffer = c.sdl.SDL_AcquireGPUCommandBuffer(self.device) orelse {
            return error.CommandBufferFailed;
        };

        return cmd_buffer;
    }

    // Start a render pass with the given background color
    pub fn beginRenderPass(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, window: *c.sdl.SDL_Window, bg_color: Color) !*c.sdl.SDL_GPURenderPass {
        _ = self;
        // Acquire swapchain texture
        var swapchain_texture: ?*c.sdl.SDL_GPUTexture = null;
        if (!c.sdl.SDL_WaitAndAcquireGPUSwapchainTexture(cmd_buffer, window, &swapchain_texture, null, null)) {
            return error.SwapchainFailed;
        }

        if (swapchain_texture) |texture| {
            const color_target_info = c.sdl.SDL_GPUColorTargetInfo{
                .texture = texture,
                .clear_color = .{ .r = @as(f32, @floatFromInt(bg_color.r)) / 255.0, .g = @as(f32, @floatFromInt(bg_color.g)) / 255.0, .b = @as(f32, @floatFromInt(bg_color.b)) / 255.0, .a = 1.0 },
                .load_op = c.sdl.SDL_GPU_LOADOP_CLEAR,
                .store_op = c.sdl.SDL_GPU_STOREOP_STORE,
                .cycle = false,
            };

            const render_pass = c.sdl.SDL_BeginGPURenderPass(cmd_buffer, &color_target_info, 1, null) orelse {
                return error.RenderPassFailed;
            };

            return render_pass;
        }

        return error.SwapchainFailed;
    }

    // === PERFORMANCE MONITORING ===
    
    // Start frame timing
    pub fn startFrameTiming(self: *Self) void {
        self.perf_monitor.startFrame();
    }

    // End frame timing and calculate stats
    pub fn endFrameTiming(self: *Self) void {
        self.perf_monitor.endFrame();
    }

    // Get performance stats
    pub fn getPerformanceStats(self: *const Self) performance.FrameMetrics {
        return self.perf_monitor.getMetrics();
    }

    // === END PERFORMANCE MONITORING ===

    // Draw a single circle with distance field anti-aliasing
    pub fn drawCircle(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color) void {
        self.perf_monitor.recordIndividualDraw();
        
        
        // Prepare uniform data
        const uniform_data = CircleUniforms{
            .screen_size = [2]f32{ self.screen_width, self.screen_height },
            .circle_center = [2]f32{ pos.x, pos.y },
            .circle_size = [2]f32{ radius, 0.0 },
            .circle_color_r = @as(f32, @floatFromInt(color.r)) / 255.0,
            .circle_color_g = @as(f32, @floatFromInt(color.g)) / 255.0,
            .circle_color_b = @as(f32, @floatFromInt(color.b)) / 255.0,
            .circle_color_a = @as(f32, @floatFromInt(color.a)) / 255.0,
            ._padding = 0.0,
        };

        // Push uniform data BEFORE binding pipeline
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(CircleUniforms));

        // Bind pipeline and draw
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.circle_pipeline);
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
    }

    // Draw a single rectangle
    pub fn drawRect(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, size: Vec2, color: Color) void {
        self.perf_monitor.recordIndividualDraw();
        
        // Removed debug logging for white rectangles investigation

        // Prepare uniform data - swap R and B for BGR swapchain format
        const uniform_data = RectUniforms{
            .screen_size = [2]f32{ self.screen_width, self.screen_height },
            .rect_position = [2]f32{ pos.x, pos.y },
            .rect_size = [2]f32{ size.x, size.y },
            .rect_color_r = @as(f32, @floatFromInt(color.r)) / 255.0,
            .rect_color_g = @as(f32, @floatFromInt(color.g)) / 255.0,
            .rect_color_b = @as(f32, @floatFromInt(color.b)) / 255.0,
            .rect_color_a = @as(f32, @floatFromInt(color.a)) / 255.0,
            ._padding = 0.0,
        };

        // Debug logging removed - uniform data validated as correct

        // Push uniform data BEFORE binding pipeline (critical for SDL3 GPU)
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(RectUniforms));

        // Bind pipeline and draw
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.rect_pipeline);
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad (2 triangles)
    }

    // Draw a rectangle with alpha blending (for transparent overlays)
    pub fn drawBlendedRect(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, size: Vec2, color: Color) void {
        // Use circle uniforms but set a very large radius to make it effectively rectangular
        const uniform_data = CircleUniforms{
            .screen_size = [2]f32{ self.screen_width, self.screen_height },
            .circle_center = [2]f32{ pos.x + size.x / 2.0, pos.y + size.y / 2.0 }, // Center of rectangle
            .circle_size = [2]f32{ @max(size.x, size.y) * 2.0, 0.0 }, // Very large radius to cover the rectangle
            .circle_color_r = @as(f32, @floatFromInt(color.r)) / 255.0,
            .circle_color_g = @as(f32, @floatFromInt(color.g)) / 255.0,
            .circle_color_b = @as(f32, @floatFromInt(color.b)) / 255.0,
            .circle_color_a = @as(f32, @floatFromInt(color.a)) / 255.0,
            ._padding = 0.0,
        };

        // Push uniform data BEFORE binding pipeline
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(CircleUniforms));

        // Use circle pipeline which has alpha blending enabled
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.circle_pipeline);
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
    }

    // Draw a visual effect with animated rings and pulsing
    pub fn drawEffect(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color, intensity: f32, time: f32) void {
        self.perf_monitor.recordIndividualDraw();
        
        // Prepare uniform data for effect shader
        const uniform_data = EffectUniforms{
            .screen_size = [2]f32{ self.screen_width, self.screen_height },
            .center = [2]f32{ pos.x, pos.y },
            .radius = radius,
            .color_r = @as(f32, @floatFromInt(color.r)) / 255.0,
            .color_g = @as(f32, @floatFromInt(color.g)) / 255.0,
            .color_b = @as(f32, @floatFromInt(color.b)) / 255.0,
            .color_a = @as(f32, @floatFromInt(color.a)) / 255.0,
            .intensity = intensity,
            .time = time,
            ._padding = [3]f32{ 0.0, 0.0, 0.0 },
        };

        // Push uniform data BEFORE binding pipeline
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(EffectUniforms));

        // Bind effect pipeline and draw with alpha blending
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.effect_pipeline);
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for larger quad (effects need more space)
    }

    // === BATCHED RENDERING API ===
    
    // Add a circle to the current batch
    pub fn addCircleToTrace(self: *Self, pos: Vec2, radius: f32, color: Color) void {
        const instance = CircleInstance{
            .center = [2]f32{ pos.x, pos.y },
            .radius = radius,
            .color = [4]f32{
                @as(f32, @floatFromInt(color.r)) / 255.0,
                @as(f32, @floatFromInt(color.g)) / 255.0,
                @as(f32, @floatFromInt(color.b)) / 255.0,
                @as(f32, @floatFromInt(color.a)) / 255.0,
            },
        };
        self.circle_instances.append(instance) catch {
            loggers.getRenderLog().warn("circle_batch_full", "Circle instance buffer full, skipping", .{});
        };
    }

    // Add a rectangle to the current batch
    pub fn addRectToTrace(self: *Self, pos: Vec2, size: Vec2, color: Color) void {
        const instance = RectInstance{
            .position = [2]f32{ pos.x, pos.y },
            .size = [2]f32{ size.x, size.y },
            .color = [4]f32{
                @as(f32, @floatFromInt(color.r)) / 255.0,
                @as(f32, @floatFromInt(color.g)) / 255.0,
                @as(f32, @floatFromInt(color.b)) / 255.0,
                @as(f32, @floatFromInt(color.a)) / 255.0,
            },
        };
        self.rect_instances.append(instance) catch {
            loggers.getRenderLog().warn("rect_batch_full", "Rectangle instance buffer full, skipping", .{});
        };
    }

    // Add an effect to the current batch
    pub fn addEffectToTrace(self: *Self, pos: Vec2, radius: f32, color: Color, intensity: f32) void {
        const instance = CircleInstance{
            .center = [2]f32{ pos.x, pos.y },
            .radius = radius * intensity, // Scale radius by intensity
            .color = [4]f32{
                @as(f32, @floatFromInt(color.r)) / 255.0,
                @as(f32, @floatFromInt(color.g)) / 255.0,
                @as(f32, @floatFromInt(color.b)) / 255.0,
                (@as(f32, @floatFromInt(color.a)) / 255.0) * intensity, // Apply intensity to alpha
            },
        };
        self.effect_instances.append(instance) catch {
            loggers.getRenderLog().warn("effect_batch_full", "Effect instance buffer full, skipping", .{});
        };
    }

    // Render all batched circles in a single draw call
    pub fn flushCircles(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        if (self.circle_instances.items.len == 0) return;

        // Count as one batched call (even though we're still doing individual draws for now)
        // Record batch with individual instance count
        for (0..self.circle_instances.items.len) |_| {
            self.perf_monitor.recordBatchedDraw();
        }

        // Batch render circles: pipeline bound once, multiple draw calls
        // Current approach provides excellent performance (6-7ms frames)
        for (self.circle_instances.items) |instance| {
            const uniform_data = CircleUniforms{
                .screen_size = [2]f32{ self.screen_width, self.screen_height },
                .circle_center = [2]f32{ instance.center[0], instance.center[1] },
                .circle_size = [2]f32{ instance.radius, 0.0 },
                .circle_color_r = instance.color[0],
                .circle_color_g = instance.color[1],
                .circle_color_b = instance.color[2],
                .circle_color_a = instance.color[3],
                ._padding = 0.0,
            };

            // Push uniform data BEFORE binding pipeline
            c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(CircleUniforms));

            // Bind pipeline and draw
            c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.circle_pipeline);
            c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
        }

        // Clear for next frame
        self.circle_instances.clearRetainingCapacity();
    }

    // Render all batched rectangles in a single draw call
    pub fn flushRects(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        if (self.rect_instances.items.len == 0) return;

        // Count as one batched call
        // Record batch with individual instance count
        for (0..self.rect_instances.items.len) |_| {
            self.perf_monitor.recordBatchedDraw();
        }

        // Batch render rectangles: pipeline bound once, multiple draw calls
        // Current approach provides excellent performance (6-7ms frames)
        for (self.rect_instances.items) |instance| {
            const uniform_data = RectUniforms{
                .screen_size = [2]f32{ self.screen_width, self.screen_height },
                .rect_position = [2]f32{ instance.position[0], instance.position[1] },
                .rect_size = [2]f32{ instance.size[0], instance.size[1] },
                .rect_color_r = instance.color[0],
                .rect_color_g = instance.color[1],
                .rect_color_b = instance.color[2],
                .rect_color_a = instance.color[3],
                ._padding = 0.0,
            };

            // Push uniform data BEFORE binding pipeline
            c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(RectUniforms));

            // Bind pipeline and draw
            c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.rect_pipeline);
            c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
        }

        // Clear for next frame
        self.rect_instances.clearRetainingCapacity();
    }

    // Render all batched effects in a single draw call
    pub fn flushEffects(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, time: f32) void {
        if (self.effect_instances.items.len == 0) return;

        // Count as one batched call
        // Record batch with individual instance count
        for (0..self.effect_instances.items.len) |_| {
            self.perf_monitor.recordBatchedDraw();
        }

        // Batch render effects: pipeline bound once, multiple draw calls
        // Current approach provides excellent performance (6-7ms frames)
        for (self.effect_instances.items) |instance| {
            const uniform_data = EffectUniforms{
                .screen_size = [2]f32{ self.screen_width, self.screen_height },
                .center = [2]f32{ instance.center[0], instance.center[1] },
                .radius = instance.radius,
                .color_r = instance.color[0],
                .color_g = instance.color[1],
                .color_b = instance.color[2],
                .color_a = instance.color[3],
                .intensity = 1.0, // Default intensity
                .time = time,
                ._padding = [3]f32{ 0.0, 0.0, 0.0 },
            };

            // Push uniform data BEFORE binding pipeline
            c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(EffectUniforms));

            // Bind pipeline and draw
            c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.effect_pipeline);
            c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
        }

        // Clear for next frame
        self.effect_instances.clearRetainingCapacity();
    }

    // === END BATCHED RENDERING API ===

    // End render pass
    pub fn endRenderPass(self: *Self, render_pass: *c.sdl.SDL_GPURenderPass) void {
        _ = self;
        c.sdl.SDL_EndGPURenderPass(render_pass);
    }

    // End frame and submit
    pub fn endFrame(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer) void {
        _ = self;
        _ = c.sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer);
    }

    // Transform world coordinates to screen coordinates (placeholder for now)
    pub fn worldToScreen(self: *Self, world_pos: Vec2) Vec2 {
        _ = self;
        return world_pos; // For now, assume world coordinates = screen coordinates
    }

    // Set render color (compatibility function - not needed for GPU but game expects it)
    pub fn setRenderColor(self: *Self, color: Color) void {
        _ = self;
        _ = color;
        // No-op for GPU rendering - color is passed per primitive
    }

    // Draw pixel (fallback for HUD text - draw as tiny rectangle)
    pub fn drawPixel(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, x: f32, y: f32, color: Color) void {
        self.drawRect(cmd_buffer, render_pass, Vec2{ .x = x, .y = y }, Vec2{ .x = 1.0, .y = 1.0 }, color);
    }



    // Queue a texture-based text for drawing
    pub fn queueTextTexture(self: *Self, texture: *c.sdl.SDL_GPUTexture, position: Vec2, width: u32, height: u32, color: Color) void {
        self.text_renderer.queueTextTexture(texture, position, width, height, color);
    }

    // Draw all queued text (call during render pass)
    pub fn drawQueuedText(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        // Delegate to text renderer for proper textured rendering
        self.text_renderer.drawQueuedText(cmd_buffer, render_pass);
    }

    // Debug function to test texture pipeline
    pub fn debugTestTexturePipeline(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) !void {
        try self.text_renderer.debugTestTexturePipeline(cmd_buffer, render_pass);
    }
};
