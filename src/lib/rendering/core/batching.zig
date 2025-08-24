// Batching system for GPU rendering - manages instance buffers and batch operations
// Provides utilities for efficient batched rendering of primitives

const std = @import("std");
const c = @import("../../platform/sdl.zig");
const uniforms_mod = @import("uniforms.zig");
const loggers = @import("../../debug/loggers.zig");
const buffers = @import("buffers.zig");

pub const BatchingError = error{
    BufferCreationFailed,
};

/// Creates instance buffers for batched rendering using shared utilities
pub fn createInstanceBuffers(device: *c.sdl.SDL_GPUDevice) BatchingError!InstanceBuffers {
    loggers.getRenderLog().info("instance_buffer_create", "Creating instance buffers for batching", .{});

    const circle_instance_buffer = buffers.InstanceBuffers.createCircleInstanceBuffer(device) catch |err| {
        return switch (err) {
            error.BufferCreationFailed => BatchingError.BufferCreationFailed,
        };
    };

    const rect_instance_buffer = buffers.InstanceBuffers.createRectInstanceBuffer(device) catch |err| {
        c.sdl.SDL_ReleaseGPUBuffer(device, circle_instance_buffer);
        return switch (err) {
            error.BufferCreationFailed => BatchingError.BufferCreationFailed,
        };
    };

    const effect_instance_buffer = buffers.InstanceBuffers.createCircleInstanceBuffer(device) catch |err| {
        c.sdl.SDL_ReleaseGPUBuffer(device, circle_instance_buffer);
        c.sdl.SDL_ReleaseGPUBuffer(device, rect_instance_buffer);
        return switch (err) {
            error.BufferCreationFailed => BatchingError.BufferCreationFailed,
        };
    };

    loggers.getRenderLog().info("instance_buffer_success", "Instance buffers created successfully", .{});

    return InstanceBuffers{
        .circle_instance_buffer = circle_instance_buffer,
        .rect_instance_buffer = rect_instance_buffer,
        .effect_instance_buffer = effect_instance_buffer,
    };
}

/// Collection of instance buffers for different primitive types
pub const InstanceBuffers = struct {
    circle_instance_buffer: *c.sdl.SDL_GPUBuffer,
    rect_instance_buffer: *c.sdl.SDL_GPUBuffer,
    effect_instance_buffer: *c.sdl.SDL_GPUBuffer,

    /// Release all instance buffers
    pub fn deinit(self: *InstanceBuffers, device: *c.sdl.SDL_GPUDevice) void {
        c.sdl.SDL_ReleaseGPUBuffer(device, self.circle_instance_buffer);
        c.sdl.SDL_ReleaseGPUBuffer(device, self.rect_instance_buffer);
        c.sdl.SDL_ReleaseGPUBuffer(device, self.effect_instance_buffer);
    }
};

/// Utility functions for batching operations
/// Upload instance data to GPU buffer
pub fn uploadInstances(
    device: *c.sdl.SDL_GPUDevice,
    buffer: *c.sdl.SDL_GPUBuffer,
    instances: anytype, // Generic slice type
    transfer_buffer: *c.sdl.SDL_GPUTransferBuffer,
) void {
    // TODO: Implement true GPU instance buffer uploads
    // For now, individual draw calls provide excellent performance
    _ = device;
    _ = buffer;
    _ = instances;
    _ = transfer_buffer;
}

/// Calculate optimal batch size based on instance count
pub fn calculateOptimalBatchSize(instance_count: usize) usize {
    return @min(instance_count, uniforms_mod.MAX_INSTANCES_PER_BATCH);
}

/// Batch statistics for performance monitoring
pub const BatchStats = struct {
    total_instances: u32 = 0,
    batch_count: u32 = 0,
    avg_instances_per_batch: f32 = 0.0,

    pub fn update(self: *BatchStats, instances: u32) void {
        self.total_instances += instances;
        self.batch_count += 1;
        self.avg_instances_per_batch = @as(f32, @floatFromInt(self.total_instances)) / @as(f32, @floatFromInt(self.batch_count));
    }

    pub fn reset(self: *BatchStats) void {
        self.total_instances = 0;
        self.batch_count = 0;
        self.avg_instances_per_batch = 0.0;
    }
};
