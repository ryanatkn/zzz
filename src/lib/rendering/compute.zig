const std = @import("std");
const loggers = @import("../debug/loggers.zig");
const c = @import("../platform/sdl.zig");

/// Compute shader wrapper with SDL3 GPU API integration
pub const ComputeShader = struct {
    device: *c.sdl.SDL_GPUDevice,
    shader: *c.sdl.SDL_GPUShader,
    name: []const u8,

    const Self = @This();

    pub fn init(device: *c.sdl.SDL_GPUDevice, name: []const u8, num_storage_buffers: u32, num_storage_textures: u32, num_uniform_buffers: u32) !Self {
        const shader = try loadComputeShaderFromFile(device, name, num_storage_buffers, num_storage_textures, num_uniform_buffers);

        return Self{
            .device = device,
            .shader = shader,
            .name = name,
        };
    }

    pub fn deinit(self: *Self) void {
        c.sdl.SDL_ReleaseGPUShader(self.device, self.shader);
    }
};

/// Compute pipeline wrapper
pub const ComputePipeline = struct {
    device: *c.sdl.SDL_GPUDevice,
    pipeline: *c.sdl.SDL_GPUComputePipeline,
    shader: ComputeShader,

    const Self = @This();

    pub fn init(device: *c.sdl.SDL_GPUDevice, shader: ComputeShader) !Self {
        const pipeline_info = c.sdl.SDL_GPUComputePipelineCreateInfo{
            .code_size = 0, // Not needed for pre-compiled shaders
            .code = null,
            .entrypoint = "cs_main",
            .format = c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .num_samplers = 0,
            .num_readonly_storage_textures = 0,
            .num_readonly_storage_buffers = 0,
            .num_readwrite_storage_textures = 0,
            .num_readwrite_storage_buffers = 1, // For our UIElement buffer
            .num_uniform_buffers = 1, // For frame data
            .threadcount_x = 64,
            .threadcount_y = 1,
            .threadcount_z = 1,
            .props = 0,
        };

        // Create the pipeline using the shader
        const pipeline = c.sdl.SDL_CreateGPUComputePipeline(device, &pipeline_info) orelse {
            loggers.getRenderLog().err("compute_pipeline_fail", "Failed to create compute pipeline: {s}", .{c.sdl.SDL_GetError()});
            return error.ComputePipelineCreationFailed;
        };

        loggers.getRenderLog().info("compute_pipeline_success", "Created compute pipeline for shader: {s}", .{shader.name});

        return Self{
            .device = device,
            .pipeline = pipeline,
            .shader = shader,
        };
    }

    pub fn deinit(self: *Self) void {
        c.sdl.SDL_ReleaseGPUComputePipeline(self.device, self.pipeline);
    }
};

/// Compute pass management
pub const ComputePass = struct {
    command_buffer: *c.sdl.SDL_GPUCommandBuffer,
    compute_pass: *c.sdl.SDL_GPUComputePass,
    is_active: bool,

    const Self = @This();

    pub fn begin(command_buffer: *c.sdl.SDL_GPUCommandBuffer, storage_buffers: ?[]const *c.sdl.SDL_GPUBuffer, storage_textures: ?[]const *c.sdl.SDL_GPUTexture) !Self {
        // Prepare storage buffer bindings
        var buffer_bindings: [8]c.sdl.SDL_GPUStorageBufferReadWriteBinding = undefined;
        var buffer_count: u32 = 0;

        if (storage_buffers) |buffers| {
            for (buffers, 0..) |buffer, i| {
                if (i >= buffer_bindings.len) break;
                buffer_bindings[i] = c.sdl.SDL_GPUStorageBufferReadWriteBinding{
                    .buffer = buffer,
                    .cycle = false,
                    .padding1 = 0,
                    .padding2 = 0,
                    .padding3 = 0,
                };
                buffer_count += 1;
            }
        }

        // Prepare storage texture bindings (if any)
        var texture_bindings: [8]c.sdl.SDL_GPUStorageTextureReadWriteBinding = undefined;
        var texture_count: u32 = 0;

        if (storage_textures) |textures| {
            for (textures, 0..) |texture, i| {
                if (i >= texture_bindings.len) break;
                texture_bindings[i] = c.sdl.SDL_GPUStorageTextureReadWriteBinding{
                    .texture = texture,
                    .mip_level = 0,
                    .layer = 0,
                    .cycle = false,
                    .padding1 = 0,
                    .padding2 = 0,
                    .padding3 = 0,
                };
                texture_count += 1;
            }
        }

        const compute_pass = c.sdl.SDL_BeginGPUComputePass(command_buffer, if (texture_count > 0) &texture_bindings[0] else null, texture_count, if (buffer_count > 0) &buffer_bindings[0] else null, buffer_count) orelse {
            loggers.getRenderLog().err("compute_pass_fail", "Failed to begin compute pass: {s}", .{c.sdl.SDL_GetError()});
            return error.ComputePassFailed;
        };

        loggers.getRenderLog().info("compute_pass_begin", "Began compute pass with {} buffers, {} textures", .{ buffer_count, texture_count });

        return Self{
            .command_buffer = command_buffer,
            .compute_pass = compute_pass,
            .is_active = true,
        };
    }

    pub fn bindPipeline(self: *Self, pipeline: *ComputePipeline) void {
        if (!self.is_active) {
            loggers.getRenderLog().err("compute_pass_inactive", "Cannot bind pipeline to inactive compute pass", .{});
            return;
        }

        c.sdl.SDL_BindGPUComputePipeline(self.compute_pass, pipeline.pipeline);
        loggers.getRenderLog().info("compute_bind_pipeline", "Bound compute pipeline: {s}", .{pipeline.shader.name});
    }

    pub fn pushUniformData(self: *Self, slot_index: u32, data: []const u8) void {
        if (!self.is_active) {
            loggers.getRenderLog().err("compute_pass_inactive", "Cannot push uniform data to inactive compute pass", .{});
            return;
        }

        c.sdl.SDL_PushGPUComputeUniformData(self.command_buffer, slot_index, data.ptr, @intCast(data.len));
    }

    pub fn dispatch(self: *Self, group_count_x: u32, group_count_y: u32, group_count_z: u32) void {
        if (!self.is_active) {
            loggers.getRenderLog().err("compute_pass_inactive", "Cannot dispatch compute on inactive pass", .{});
            return;
        }

        c.sdl.SDL_DispatchGPUCompute(self.compute_pass, group_count_x, group_count_y, group_count_z);
        loggers.getRenderLog().info("compute_dispatch", "Dispatched compute: {}x{}x{} groups", .{ group_count_x, group_count_y, group_count_z });
    }

    pub fn end(self: *Self) void {
        if (!self.is_active) return;

        c.sdl.SDL_EndGPUComputePass(self.compute_pass);
        self.is_active = false;
        loggers.getRenderLog().info("compute_pass_end", "Ended compute pass", .{});
    }

    pub fn deinit(self: *Self) void {
        if (self.is_active) {
            self.end();
        }
    }
};

/// Helper for managing compute dispatch operations
pub const ComputeDispatcher = struct {
    device: *c.sdl.SDL_GPUDevice,
    pipelines: std.HashMap([]const u8, *ComputePipeline, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice) Self {
        return Self{
            .device = device,
            .pipelines = std.HashMap([]const u8, *ComputePipeline, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var iterator = self.pipelines.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.pipelines.deinit();
    }

    pub fn loadComputePipeline(self: *Self, name: []const u8, num_storage_buffers: u32, num_storage_textures: u32, num_uniform_buffers: u32) !*ComputePipeline {
        // Check if already loaded
        if (self.pipelines.get(name)) |pipeline| {
            return pipeline;
        }

        // Create new compute shader and pipeline
        const shader = try ComputeShader.init(self.device, name, num_storage_buffers, num_storage_textures, num_uniform_buffers);

        const pipeline = try self.allocator.create(ComputePipeline);
        pipeline.* = try ComputePipeline.init(self.device, shader);

        // Store in cache
        const owned_name = try self.allocator.dupe(u8, name);
        try self.pipelines.put(owned_name, pipeline);

        return pipeline;
    }

    pub fn getPipeline(self: *Self, name: []const u8) ?*ComputePipeline {
        return self.pipelines.get(name);
    }
};

/// Calculate optimal dispatch parameters for element count
pub fn calculateDispatchGroups(element_count: u32, thread_group_size: u32) u32 {
    return (element_count + thread_group_size - 1) / thread_group_size;
}

// Helper functions
fn loadComputeShaderFromFile(device: *c.sdl.SDL_GPUDevice, name: []const u8, num_storage_buffers: u32, num_storage_textures: u32, num_uniform_buffers: u32) !*c.sdl.SDL_GPUShader {
    // Construct file path
    var path_buf: [256]u8 = undefined;

    // Try SPIRV first (Vulkan)
    const spirv_path = std.fmt.bufPrint(path_buf[0..], "src/shaders/compiled/vulkan/{s}_cs.spv", .{name}) catch {
        return error.PathTooLong;
    };

    if (loadShaderFromPath(device, spirv_path, num_storage_buffers, num_storage_textures, num_uniform_buffers, c.sdl.SDL_GPU_SHADERFORMAT_SPIRV)) |shader| {
        return shader;
    } else |_| {
        // Try DXIL (Direct3D 12)
        const dxil_path = std.fmt.bufPrint(path_buf[0..], "src/shaders/compiled/d3d12/{s}_cs.dxil", .{name}) catch {
            return error.PathTooLong;
        };

        return loadShaderFromPath(device, dxil_path, num_storage_buffers, num_storage_textures, num_uniform_buffers, c.sdl.SDL_GPU_SHADERFORMAT_DXIL) catch {
            loggers.getRenderLog().err("compute_shader_load_fail", "Failed to load compute shader: {s} (tried both SPIRV and DXIL)", .{name});
            return error.ComputeShaderLoadFailed;
        };
    }
}

fn loadShaderFromPath(device: *c.sdl.SDL_GPUDevice, path: []const u8, num_storage_buffers: u32, num_storage_textures: u32, num_uniform_buffers: u32, format: c.sdl.SDL_GPUShaderFormat) !*c.sdl.SDL_GPUShader {
    // Read shader file
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        loggers.getRenderLog().err("compute_shader_file", "Cannot open compute shader file {s}: {}", .{ path, err });
        return error.ComputeShaderFileNotFound;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const shader_code = try std.heap.page_allocator.alloc(u8, file_size);
    defer std.heap.page_allocator.free(shader_code);

    _ = try file.readAll(shader_code);

    const shader_info = c.sdl.SDL_GPUShaderCreateInfo{
        .code_size = shader_code.len,
        .code = shader_code.ptr,
        .entrypoint = "cs_main",
        .format = format,
        .num_samplers = 0,
        .num_storage_textures = num_storage_textures,
        .num_storage_buffers = num_storage_buffers,
        .num_uniform_buffers = num_uniform_buffers,
        .props = 0,
    };

    const shader = c.sdl.SDL_CreateGPUShader(device, &shader_info) orelse {
        loggers.getRenderLog().err("compute_shader_create_fail", "Failed to create compute shader from {s}: {s}", .{ path, c.sdl.SDL_GetError() });
        return error.ComputeShaderCreationFailed;
    };

    loggers.getRenderLog().info("compute_shader_success", "Loaded compute shader: {s}", .{path});
    return shader;
}

// Tests
test "compute dispatcher creation" {
    const allocator = std.testing.allocator;

    // Mock device pointer for testing
    var mock_device: c.sdl.SDL_GPUDevice = undefined;

    var dispatcher = ComputeDispatcher.init(allocator, &mock_device);
    defer dispatcher.deinit();

    try std.testing.expect(dispatcher.pipelines.count() == 0);
}

test "dispatch group calculation" {
    try std.testing.expect(calculateDispatchGroups(100, 64) == 2);
    try std.testing.expect(calculateDispatchGroups(64, 64) == 1);
    try std.testing.expect(calculateDispatchGroups(1, 64) == 1);
    try std.testing.expect(calculateDispatchGroups(1000, 64) == 16);
}
