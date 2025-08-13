const std = @import("std");
const c = @import("c.zig");

const ShaderType = enum { vertex, fragment };

pub const ShaderInfo = struct {
    name: []const u8,
    vertex_entry: []const u8 = "vs_main",
    fragment_entry: []const u8 = "ps_main",
    num_samplers: u32 = 0,
    num_uniform_buffers: u32 = 0,
    num_storage_buffers: u32 = 0,
    num_storage_textures: u32 = 0,
};

pub const ShaderPair = struct {
    vertex: *c.sdl.SDL_GPUShader,
    fragment: *c.sdl.SDL_GPUShader,
};

pub const ShaderManager = struct {
    allocator: std.mem.Allocator,
    device: *c.sdl.SDL_GPUDevice,
    shaders: std.StringHashMap(ShaderPair),
    
    pub fn init(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice) ShaderManager {
        return ShaderManager{
            .allocator = allocator,
            .device = device,
            .shaders = std.StringHashMap(ShaderPair).init(allocator),
        };
    }
    
    pub fn deinit(self: *ShaderManager) void {
        var iter = self.shaders.iterator();
        while (iter.next()) |entry| {
            c.sdl.SDL_ReleaseGPUShader(self.device, entry.value_ptr.vertex);
            c.sdl.SDL_ReleaseGPUShader(self.device, entry.value_ptr.fragment);
            self.allocator.free(entry.key_ptr.*);
        }
        self.shaders.deinit();
    }
    
    pub fn loadShader(self: *ShaderManager, info: ShaderInfo) !ShaderPair {
        // Check if already loaded
        if (self.shaders.get(info.name)) |pair| {
            return pair;
        }
        
        // Load vertex shader
        const vertex_shader = try self.loadShaderFromFile(info.name, .vertex, info.vertex_entry, info.num_uniform_buffers, info.num_samplers, info.num_storage_buffers, info.num_storage_textures);
        
        // Load fragment shader
        const fragment_shader = try self.loadShaderFromFile(info.name, .fragment, info.fragment_entry, 0, info.num_samplers, info.num_storage_buffers, info.num_storage_textures);
        
        const pair = ShaderPair{
            .vertex = vertex_shader,
            .fragment = fragment_shader,
        };
        
        // Store in cache
        try self.shaders.put(try self.allocator.dupe(u8, info.name), pair);
        
        return pair;
    }
    
    fn loadShaderFromFile(
        self: *ShaderManager, 
        name: []const u8, 
        shader_type: ShaderType, 
        entry_point: []const u8,
        num_uniform_buffers: u32,
        num_samplers: u32,
        num_storage_buffers: u32,
        num_storage_textures: u32
    ) !*c.sdl.SDL_GPUShader {
        // Construct file path
        var path_buf: [256]u8 = undefined;
        const type_suffix = switch (shader_type) {
            .vertex => "_vs",
            .fragment => "_ps",
        };
        
        // Try SPIRV first (Vulkan)
        const spirv_path = std.fmt.bufPrint(&path_buf, "src/shaders/compiled/vulkan/{s}{s}.spv", .{ name, type_suffix }) catch {
            return error.PathTooLong;
        };
        
        if (self.loadShaderFromPath(spirv_path, entry_point, shader_type, num_uniform_buffers, num_samplers, num_storage_buffers, num_storage_textures, c.sdl.SDL_GPU_SHADERFORMAT_SPIRV)) |shader| {
            return shader;
        } else |_| {
            // Try DXIL (D3D12)
            const dxil_path = std.fmt.bufPrint(&path_buf, "src/shaders/compiled/d3d12/{s}{s}.dxil", .{ name, type_suffix }) catch {
                return error.PathTooLong;
            };
            
            return self.loadShaderFromPath(dxil_path, entry_point, shader_type, num_uniform_buffers, num_samplers, num_storage_buffers, num_storage_textures, c.sdl.SDL_GPU_SHADERFORMAT_DXIL) catch {
                std.debug.print("Failed to load shader: {s} (tried both SPIRV and DXIL)\n", .{name});
                return error.ShaderLoadFailed;
            };
        }
    }
    
    fn loadShaderFromPath(
        self: *ShaderManager,
        path: []const u8,
        entry_point: []const u8,
        shader_type: ShaderType,
        num_uniform_buffers: u32,
        num_samplers: u32,
        num_storage_buffers: u32,
        num_storage_textures: u32,
        format: c.sdl.SDL_GPUShaderFormat
    ) !*c.sdl.SDL_GPUShader {
        // Read shader file
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            std.debug.print("Failed to open shader file: {s} (error: {})\n", .{ path, err });
            return err;
        };
        defer file.close();
        
        const file_size = try file.getEndPos();
        const shader_data = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(shader_data);
        
        _ = try file.readAll(shader_data);
        
        // Create shader
        const stage = switch (shader_type) {
            .vertex => c.sdl.SDL_GPU_SHADERSTAGE_VERTEX,
            .fragment => c.sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
        };
        
        const shader_info = c.sdl.SDL_GPUShaderCreateInfo{
            .code_size = shader_data.len,
            .code = @ptrCast(shader_data.ptr),
            .entrypoint = entry_point.ptr,
            .format = format,
            .stage = stage,
            .num_samplers = num_samplers,
            .num_storage_textures = num_storage_textures,
            .num_storage_buffers = num_storage_buffers,
            .num_uniform_buffers = num_uniform_buffers,
        };
        
        const shader = c.sdl.SDL_CreateGPUShader(self.device, &shader_info) orelse {
            std.debug.print("Failed to create shader from {s}: {s}\n", .{ path, c.sdl.SDL_GetError() });
            return error.ShaderCreationFailed;
        };
        
        std.debug.print("Loaded shader: {s} from {s}\n", .{ entry_point, path });
        return shader;
    }
    
    pub fn getShader(self: *ShaderManager, name: []const u8) ?ShaderPair {
        return self.shaders.get(name);
    }
};