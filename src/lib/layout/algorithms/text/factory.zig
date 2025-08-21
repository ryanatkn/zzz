/// Text layout algorithm factory and vtable implementations
///
/// This module provides factory functions and vtable wrappers for creating
/// text layout algorithm instances with CPU or GPU implementations.
const std = @import("std");
const core = @import("../../core/types.zig");
const interface = @import("../../core/interface.zig");
const cpu = @import("cpu.zig");
const gpu = @import("gpu.zig");

/// Text algorithm configuration
pub const Config = struct {
    implementation: Implementation = .cpu_only,

    pub const Implementation = enum {
        cpu_only,
        gpu_preferred,
        hybrid,
    };
};

/// Create a text layout algorithm instance
pub fn createAlgorithm(
    allocator: std.mem.Allocator,
    config: Config,
    gpu_device: ?*anyopaque,
) !interface.LayoutAlgorithm {
    switch (config.implementation) {
        .cpu_only => {
            const impl = try allocator.create(cpu.TextLayoutCPU);
            impl.* = cpu.TextLayoutCPU.init(allocator);
            return interface.LayoutAlgorithm{
                .ptr = impl,
                .vtable = &.{
                    .calculate = cpuCalculateWrapper,
                    .getCapabilities = cpuGetCapabilitiesWrapper,
                    .canHandle = cpuCanHandleWrapper,
                    .getName = cpuGetNameWrapper,
                    .deinit = cpuDeinitWrapper,
                },
            };
        },
        .gpu_preferred, .hybrid => {
            const impl = try allocator.create(gpu.TextLayoutGPU);
            impl.* = gpu.TextLayoutGPU.init(allocator, gpu_device);
            return interface.LayoutAlgorithm{
                .ptr = impl,
                .vtable = &.{
                    .calculate = gpuCalculateWrapper,
                    .getCapabilities = gpuGetCapabilitiesWrapper,
                    .canHandle = gpuCanHandleWrapper,
                    .getName = gpuGetNameWrapper,
                    .deinit = gpuDeinitWrapper,
                },
            };
        },
    }
}

// CPU Implementation Wrappers
fn cpuCalculateWrapper(ptr: *anyopaque, elements: []interface.LayoutElement, context: core.LayoutContext, allocator: std.mem.Allocator) anyerror![]core.LayoutResult {
    const self: *cpu.TextLayoutCPU = @ptrCast(@alignCast(ptr));
    return self.calculate(elements, context, allocator);
}

fn cpuGetCapabilitiesWrapper(ptr: *anyopaque) interface.AlgorithmCapabilities {
    const self: *cpu.TextLayoutCPU = @ptrCast(@alignCast(ptr));
    return self.getCapabilities();
}

fn cpuCanHandleWrapper(ptr: *anyopaque, elements: []const interface.LayoutElement, context: core.LayoutContext) bool {
    const self: *cpu.TextLayoutCPU = @ptrCast(@alignCast(ptr));
    return self.canHandle(elements, context);
}

fn cpuGetNameWrapper(ptr: *anyopaque) []const u8 {
    const self: *cpu.TextLayoutCPU = @ptrCast(@alignCast(ptr));
    return self.getName();
}

fn cpuDeinitWrapper(ptr: *anyopaque) void {
    const self: *cpu.TextLayoutCPU = @ptrCast(@alignCast(ptr));
    self.deinit();
}

// GPU Implementation Wrappers
fn gpuCalculateWrapper(ptr: *anyopaque, elements: []interface.LayoutElement, context: core.LayoutContext, allocator: std.mem.Allocator) anyerror![]core.LayoutResult {
    const self: *gpu.TextLayoutGPU = @ptrCast(@alignCast(ptr));
    return self.calculate(elements, context, allocator);
}

fn gpuGetCapabilitiesWrapper(ptr: *anyopaque) interface.AlgorithmCapabilities {
    const self: *gpu.TextLayoutGPU = @ptrCast(@alignCast(ptr));
    return self.getCapabilities();
}

fn gpuCanHandleWrapper(ptr: *anyopaque, elements: []const interface.LayoutElement, context: core.LayoutContext) bool {
    const self: *gpu.TextLayoutGPU = @ptrCast(@alignCast(ptr));
    return self.canHandle(elements, context);
}

fn gpuGetNameWrapper(ptr: *anyopaque) []const u8 {
    const self: *gpu.TextLayoutGPU = @ptrCast(@alignCast(ptr));
    return self.getName();
}

fn gpuDeinitWrapper(ptr: *anyopaque) void {
    const self: *gpu.TextLayoutGPU = @ptrCast(@alignCast(ptr));
    self.deinit();
}
