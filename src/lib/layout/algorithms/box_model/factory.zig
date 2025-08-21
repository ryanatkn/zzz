/// Box model algorithm factory and vtable implementations
const std = @import("std");
const interface = @import("../../core/interface.zig");
const core = @import("../../core/types.zig");
const cpu = @import("cpu.zig");
const gpu = @import("gpu.zig");

/// Box model configuration
pub const Config = struct {
    /// Implementation preference
    implementation: Implementation = .auto,
    /// Maximum elements for GPU implementation
    max_gpu_elements: usize = 1000,
    /// Enable layout caching (CPU only)
    enable_caching: bool = true,
    /// Debug validation
    debug_mode: bool = false,

    pub const Implementation = enum {
        auto, // Select best based on element count
        cpu_only, // Force CPU implementation
        gpu_only, // Force GPU implementation (if available)
    };
};

/// Create box model algorithm with automatic CPU/GPU selection
pub fn createAlgorithm(
    allocator: std.mem.Allocator,
    config: Config,
    gpu_device: ?*anyopaque,
) !interface.LayoutAlgorithm {
    switch (config.implementation) {
        .cpu_only => {
            const cpu_impl = try allocator.create(cpu.BoxModelAlgorithm);
            cpu_impl.* = cpu.BoxModelAlgorithm.init(allocator);

            return interface.LayoutAlgorithm{
                .ptr = cpu_impl,
                .vtable = &cpu_vtable,
            };
        },
        .gpu_only => {
            if (gpu_device == null) {
                return error.GPUNotAvailable;
            }
            // TODO: Create GPU implementation
            return error.GPUNotImplemented;
        },
        .auto => {
            // For now, always use CPU
            // TODO: Implement intelligent selection based on element count
            const cpu_impl = try allocator.create(cpu.BoxModelAlgorithm);
            cpu_impl.* = cpu.BoxModelAlgorithm.init(allocator);

            return interface.LayoutAlgorithm{
                .ptr = cpu_impl,
                .vtable = &cpu_vtable,
            };
        },
    }
}

/// CPU implementation vtable
const cpu_vtable = interface.LayoutAlgorithm.VTable{
    .calculate = cpuCalculateWrapper,
    .getCapabilities = cpuGetCapabilitiesWrapper,
    .init = cpuInitWrapper,
    .deinit = cpuDeinitWrapper,
    .canHandle = cpuCanHandleWrapper,
    .getName = cpuGetNameWrapper,
};

fn cpuCalculateWrapper(ptr: *anyopaque, elements: []interface.LayoutElement, context: core.LayoutContext, allocator: std.mem.Allocator) anyerror![]core.LayoutResult {
    const self: *cpu.BoxModelAlgorithm = @ptrCast(@alignCast(ptr));
    return self.calculate(elements, context, allocator);
}

fn cpuGetCapabilitiesWrapper(ptr: *anyopaque) interface.AlgorithmCapabilities {
    const self: *cpu.BoxModelAlgorithm = @ptrCast(@alignCast(ptr));
    return self.getCapabilities();
}

fn cpuInitWrapper(ptr: *anyopaque, allocator: std.mem.Allocator, config: interface.AlgorithmConfig) anyerror!void {
    _ = ptr;
    _ = allocator;
    _ = config;
    // CPU algorithm doesn't need initialization
}

fn cpuDeinitWrapper(ptr: *anyopaque) void {
    const self: *cpu.BoxModelAlgorithm = @ptrCast(@alignCast(ptr));
    const allocator = self.allocator; // Get allocator before calling deinit
    self.deinit();
    allocator.destroy(self); // Free the allocated algorithm instance
}

fn cpuCanHandleWrapper(ptr: *anyopaque, elements: []const interface.LayoutElement, context: core.LayoutContext) bool {
    const self: *cpu.BoxModelAlgorithm = @ptrCast(@alignCast(ptr));
    return self.canHandle(elements, context);
}

fn cpuGetNameWrapper(ptr: *anyopaque) []const u8 {
    const self: *cpu.BoxModelAlgorithm = @ptrCast(@alignCast(ptr));
    return self.getName();
}

// Tests
test "box model algorithm creation" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = Config{ .implementation = .cpu_only };
    var algorithm = try createAlgorithm(allocator, config, null);
    defer algorithm.deinit(); // deinit handles deallocation internally

    const capabilities = algorithm.getCapabilities();
    try testing.expectEqualStrings("Box Model CPU", capabilities.name);
    try testing.expect(capabilities.supports_gpu == false);
    try testing.expect(capabilities.features.nesting == true);
    try testing.expect(capabilities.features.spacing == true);
}