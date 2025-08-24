// GPU buffer creation utilities - type-safe instance buffer helpers
// Consolidates duplicate buffer creation patterns across primitive renderers

const std = @import("std");
const c = @import("../../platform/sdl.zig");
const uniforms_mod = @import("uniforms.zig");
const loggers = @import("../../debug/loggers.zig");

/// Instance buffer creation utilities
pub const InstanceBuffers = struct {
    /// Create a vertex instance buffer for batching primitives
    /// Type-safe with comptime instance type validation
    pub inline fn createInstanceBuffer(
        comptime T: type,
        device: *c.sdl.SDL_GPUDevice,
        max_instances: u32,
    ) !*c.sdl.SDL_GPUBuffer {
        // Validate instance type at compile time
        comptime {
            const type_info = @typeInfo(T);
            if (type_info != .@"struct") {
                @compileError("Instance type must be a struct, got: " ++ @typeName(T));
            }
        }

        const buffer_create_info = c.sdl.SDL_GPUBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
            .size = max_instances * @sizeOf(T),
        };

        const instance_buffer = c.sdl.SDL_CreateGPUBuffer(device, &buffer_create_info) orelse {
            loggers.getRenderLog().err("instance_buffer_fail", "Failed to create instance buffer for type: {s}", .{@typeName(T)});
            return error.BufferCreationFailed;
        };

        return instance_buffer;
    }

    /// Create circle instance buffer (specialized helper)
    pub inline fn createCircleInstanceBuffer(device: *c.sdl.SDL_GPUDevice) !*c.sdl.SDL_GPUBuffer {
        return createInstanceBuffer(uniforms_mod.CircleInstance, device, uniforms_mod.MAX_INSTANCES_PER_BATCH);
    }

    /// Create rectangle instance buffer (specialized helper)
    pub inline fn createRectInstanceBuffer(device: *c.sdl.SDL_GPUDevice) !*c.sdl.SDL_GPUBuffer {
        return createInstanceBuffer(uniforms_mod.RectInstance, device, uniforms_mod.MAX_INSTANCES_PER_BATCH);
    }

    /// Create text instance buffer (specialized helper)
    pub inline fn createTextInstanceBuffer(device: *c.sdl.SDL_GPUDevice) !*c.sdl.SDL_GPUBuffer {
        return createInstanceBuffer(uniforms_mod.TextInstance, device, uniforms_mod.MAX_INSTANCES_PER_BATCH);
    }
};

test "instance buffer creation" {
    // Test compile-time type validation
    const TestInstance = extern struct {
        pos: [2]f32,
        color: [4]f32,
    };

    // These should compile
    const size = uniforms_mod.MAX_INSTANCES_PER_BATCH * @sizeOf(TestInstance);
    try std.testing.expect(size > 0);

    // Test type name extraction
    try std.testing.expectEqualStrings("uniforms.CircleInstance", @typeName(uniforms_mod.CircleInstance));
}
