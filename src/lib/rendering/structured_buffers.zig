const std = @import("std");
const loggers = @import("../debug/loggers.zig");
const c = @import("../platform/sdl.zig");

/// Generic structured buffer for GPU compute operations
pub fn StructuredBuffer(comptime T: type) type {
    return struct {
        device: *c.sdl.SDL_GPUDevice,
        buffer: *c.sdl.SDL_GPUBuffer,
        transfer_buffer: ?*c.sdl.SDL_GPUTransferBuffer,
        capacity: usize,
        size: usize,
        usage: c.sdl.SDL_GPUBufferUsageFlags,
        allocator: std.mem.Allocator,
        name: []const u8,

        const Self = @This();

        pub const CreateInfo = struct {
            capacity: usize,
            usage: c.sdl.SDL_GPUBufferUsageFlags = c.sdl.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE,
            name: ?[]const u8 = null,
            enable_transfer: bool = true,
        };

        pub fn init(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice, create_info: CreateInfo) !Self {
            const buffer_size = create_info.capacity * @sizeOf(T);

            const buffer_create_info = c.sdl.SDL_GPUBufferCreateInfo{
                .usage = create_info.usage,
                .size = @intCast(buffer_size),
                .props = 0,
            };

            const buffer = c.sdl.SDL_CreateGPUBuffer(device, &buffer_create_info) orelse {
                loggers.getRenderLog().err("structured_buffer_fail", "Failed to create structured buffer: {s}", .{c.sdl.SDL_GetError()});
                return error.BufferCreationFailed;
            };

            // Create transfer buffer if needed for CPU→GPU uploads
            var transfer_buffer: ?*c.sdl.SDL_GPUTransferBuffer = null;
            if (create_info.enable_transfer) {
                const transfer_create_info = c.sdl.SDL_GPUTransferBufferCreateInfo{
                    .usage = c.sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
                    .size = @intCast(buffer_size),
                };
                transfer_buffer = c.sdl.SDL_CreateGPUTransferBuffer(device, &transfer_create_info) orelse {
                    loggers.getRenderLog().err("transfer_buffer_fail", "Failed to create transfer buffer: {s}", .{c.sdl.SDL_GetError()});
                    c.sdl.SDL_ReleaseGPUBuffer(device, buffer);
                    return error.TransferBufferCreationFailed;
                };
            }

            const name = create_info.name orelse @typeName(T);
            loggers.getRenderLog().info("structured_buffer_success", "Created structured buffer '{s}': {} elements, {} bytes", .{ name, create_info.capacity, buffer_size });

            return Self{
                .device = device,
                .buffer = buffer,
                .transfer_buffer = transfer_buffer,
                .capacity = create_info.capacity,
                .size = 0,
                .usage = create_info.usage,
                .allocator = allocator,
                .name = name,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.transfer_buffer) |tb| {
                c.sdl.SDL_ReleaseGPUTransferBuffer(self.device, tb);
            }
            c.sdl.SDL_ReleaseGPUBuffer(self.device, self.buffer);
            loggers.getRenderLog().info("structured_buffer_cleanup", "Released structured buffer '{s}'", .{self.name});
        }

        /// Upload data from CPU to GPU buffer
        pub fn upload(self: *Self, data: []const T) !void {
            if (data.len > self.capacity) {
                loggers.getRenderLog().err("buffer_overflow", "Data size {} exceeds buffer capacity {}", .{ data.len, self.capacity });
                return error.BufferOverflow;
            }

            const transfer_buffer = self.transfer_buffer orelse {
                return error.TransferBufferNotAvailable;
            };

            // Map transfer buffer and copy data
            const mapped_data = c.sdl.SDL_MapGPUTransferBuffer(self.device, transfer_buffer, false) orelse {
                loggers.getRenderLog().err("buffer_map_fail", "Failed to map transfer buffer: {s}", .{c.sdl.SDL_GetError()});
                return error.BufferMapFailed;
            };

            const byte_size = data.len * @sizeOf(T);
            @memcpy(@as([*]u8, @ptrCast(mapped_data))[0..byte_size], @as([*]const u8, @ptrCast(data.ptr))[0..byte_size]);
            c.sdl.SDL_UnmapGPUTransferBuffer(self.device, transfer_buffer);

            self.size = data.len;
            loggers.getRenderLog().info("buffer_upload", "Uploaded {} elements ({} bytes) to buffer '{s}'", .{ data.len, byte_size, self.name });
        }

        /// Upload data using copy pass (for more complex transfers)
        pub fn uploadViaCopyPass(self: *Self, command_buffer: *c.sdl.SDL_GPUCommandBuffer, data: []const T) !void {
            if (data.len > self.capacity) {
                return error.BufferOverflow;
            }

            const transfer_buffer = self.transfer_buffer orelse {
                return error.TransferBufferNotAvailable;
            };

            // Map and copy data to transfer buffer
            const mapped_data = c.sdl.SDL_MapGPUTransferBuffer(self.device, transfer_buffer, false) orelse {
                return error.BufferMapFailed;
            };

            const byte_size = data.len * @sizeOf(T);
            @memcpy(@as([*]u8, @ptrCast(mapped_data))[0..byte_size], @as([*]const u8, @ptrCast(data.ptr))[0..byte_size]);
            c.sdl.SDL_UnmapGPUTransferBuffer(self.device, transfer_buffer);

            // Create copy pass and upload
            const copy_pass = c.sdl.SDL_BeginGPUCopyPass(command_buffer) orelse {
                return error.CopyPassCreationFailed;
            };

            const buffer_transfer_info = c.sdl.SDL_GPUTransferBufferLocation{
                .transfer_buffer = transfer_buffer,
                .offset = 0,
            };

            const buffer_region = c.sdl.SDL_GPUBufferRegion{
                .buffer = self.buffer,
                .offset = 0,
                .size = @intCast(byte_size),
            };

            c.sdl.SDL_UploadToGPUBuffer(copy_pass, &buffer_transfer_info, &buffer_region, false);
            c.sdl.SDL_EndGPUCopyPass(copy_pass);

            self.size = data.len;
            loggers.getRenderLog().info("buffer_copy_upload", "Copy pass uploaded {} elements to buffer '{s}'", .{ data.len, self.name });
        }

        /// Download data from GPU to CPU (expensive operation)
        pub fn download(self: *Self, allocator: std.mem.Allocator, command_buffer: *c.sdl.SDL_GPUCommandBuffer) ![]T {
            if (self.size == 0) {
                return allocator.alloc(T, 0);
            }

            // Create download transfer buffer
            const byte_size = self.size * @sizeOf(T);
            const download_transfer_info = c.sdl.SDL_GPUTransferBufferCreateInfo{
                .usage = c.sdl.SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD,
                .size = @intCast(byte_size),
            };
            const download_transfer_buffer = c.sdl.SDL_CreateGPUTransferBuffer(self.device, &download_transfer_info) orelse {
                return error.DownloadTransferBufferCreationFailed;
            };
            defer c.sdl.SDL_ReleaseGPUTransferBuffer(self.device, download_transfer_buffer);

            // Create copy pass and download
            const copy_pass = c.sdl.SDL_BeginGPUCopyPass(command_buffer) orelse {
                return error.CopyPassCreationFailed;
            };

            const buffer_region = c.sdl.SDL_GPUBufferRegion{
                .buffer = self.buffer,
                .offset = 0,
                .size = @intCast(byte_size),
            };

            const transfer_location = c.sdl.SDL_GPUTransferBufferLocation{
                .transfer_buffer = download_transfer_buffer,
                .offset = 0,
            };

            c.sdl.SDL_DownloadFromGPUBuffer(copy_pass, &buffer_region, &transfer_location);
            c.sdl.SDL_EndGPUCopyPass(copy_pass);

            // Submit command buffer and wait for completion
            const fence = c.sdl.SDL_SubmitGPUCommandBuffer(command_buffer);
            c.sdl.SDL_WaitForGPUFences(self.device, true, &fence, 1);
            c.sdl.SDL_ReleaseGPUFence(self.device, fence);

            // Map download buffer and copy data
            const mapped_data = c.sdl.SDL_MapGPUTransferBuffer(self.device, download_transfer_buffer, false) orelse {
                return error.DownloadBufferMapFailed;
            };

            const result = try allocator.alloc(T, self.size);
            @memcpy(@as([*]u8, @ptrCast(result.ptr))[0..byte_size], @as([*]const u8, @ptrCast(mapped_data))[0..byte_size]);

            c.sdl.SDL_UnmapGPUTransferBuffer(self.device, download_transfer_buffer);

            loggers.getRenderLog().info("buffer_download", "Downloaded {} elements from buffer '{s}'", .{ self.size, self.name });
            return result;
        }

        /// Get the raw SDL buffer for binding to compute shaders
        pub fn getBuffer(self: *Self) *c.sdl.SDL_GPUBuffer {
            return self.buffer;
        }

        /// Get current size (number of elements)
        pub fn getSize(self: *Self) usize {
            return self.size;
        }

        /// Get capacity (maximum number of elements)
        pub fn getCapacity(self: *Self) usize {
            return self.capacity;
        }

        /// Check if buffer has capacity for more elements
        pub fn hasCapacity(self: *Self, additional_elements: usize) bool {
            return self.size + additional_elements <= self.capacity;
        }

        /// Clear the buffer (set size to 0)
        pub fn clear(self: *Self) void {
            self.size = 0;
        }

        /// Resize buffer (within capacity limits)
        pub fn resize(self: *Self, new_size: usize) !void {
            if (new_size > self.capacity) {
                return error.SizeExceedsCapacity;
            }
            self.size = new_size;
        }
    };
}

/// Double-buffered structured buffer for smooth updates
pub fn DoubleBufferedStructuredBuffer(comptime T: type) type {
    return struct {
        front_buffer: StructuredBuffer(T),
        back_buffer: StructuredBuffer(T),
        current_front: bool,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice, create_info: StructuredBuffer(T).CreateInfo) !Self {
            const front_info = StructuredBuffer(T).CreateInfo{
                .capacity = create_info.capacity,
                .usage = create_info.usage,
                .name = "front",
                .enable_transfer = create_info.enable_transfer,
            };

            const back_info = StructuredBuffer(T).CreateInfo{
                .capacity = create_info.capacity,
                .usage = create_info.usage,
                .name = "back",
                .enable_transfer = create_info.enable_transfer,
            };

            return Self{
                .front_buffer = try StructuredBuffer(T).init(allocator, device, front_info),
                .back_buffer = try StructuredBuffer(T).init(allocator, device, back_info),
                .current_front = true,
            };
        }

        pub fn deinit(self: *Self) void {
            self.front_buffer.deinit();
            self.back_buffer.deinit();
        }

        /// Get the current front buffer (for reading)
        pub fn getFrontBuffer(self: *Self) *StructuredBuffer(T) {
            return if (self.current_front) &self.front_buffer else &self.back_buffer;
        }

        /// Get the current back buffer (for writing)
        pub fn getBackBuffer(self: *Self) *StructuredBuffer(T) {
            return if (self.current_front) &self.back_buffer else &self.front_buffer;
        }

        /// Swap front and back buffers
        pub fn swap(self: *Self) void {
            self.current_front = !self.current_front;
        }

        /// Upload data to back buffer and swap
        pub fn uploadAndSwap(self: *Self, data: []const T) !void {
            try self.getBackBuffer().upload(data);
            self.swap();
        }
    };
}

/// Buffer pool for managing multiple structured buffers of the same type
pub fn BufferPool(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        device: *c.sdl.SDL_GPUDevice,
        buffers: std.ArrayList(*StructuredBuffer(T)),
        free_list: std.ArrayList(usize),
        buffer_size: usize,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice, buffer_size: usize, initial_count: usize) !Self {
            var pool = Self{
                .allocator = allocator,
                .device = device,
                .buffers = std.ArrayList(*StructuredBuffer(T)).init(allocator),
                .free_list = std.ArrayList(usize).init(allocator),
                .buffer_size = buffer_size,
            };

            // Pre-allocate initial buffers
            try pool.buffers.ensureTotalCapacity(initial_count);
            try pool.free_list.ensureTotalCapacity(initial_count);

            for (0..initial_count) |i| {
                const create_info = StructuredBuffer(T).CreateInfo{
                    .capacity = buffer_size,
                    .usage = c.sdl.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE,
                    .name = null,
                    .enable_transfer = true,
                };

                const buffer = try allocator.create(StructuredBuffer(T));
                buffer.* = try StructuredBuffer(T).init(allocator, device, create_info);

                pool.buffers.appendAssumeCapacity(buffer);
                pool.free_list.appendAssumeCapacity(i);
            }

            loggers.getRenderLog().info("buffer_pool_init", "Created buffer pool with {} buffers of {} elements each", .{ initial_count, buffer_size });
            return pool;
        }

        pub fn deinit(self: *Self) void {
            for (self.buffers.items) |buffer| {
                buffer.deinit();
                self.allocator.destroy(buffer);
            }
            self.buffers.deinit();
            self.free_list.deinit();
        }

        /// Acquire a buffer from the pool
        pub fn acquire(self: *Self) !*StructuredBuffer(T) {
            if (self.free_list.items.len > 0) {
                const index = self.free_list.pop();
                return self.buffers.items[index];
            }

            // Pool exhausted, create new buffer
            const create_info = StructuredBuffer(T).CreateInfo{
                .capacity = self.buffer_size,
                .usage = c.sdl.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE,
                .name = null,
                .enable_transfer = true,
            };

            const buffer = try self.allocator.create(StructuredBuffer(T));
            buffer.* = try StructuredBuffer(T).init(self.allocator, self.device, create_info);

            try self.buffers.append(buffer);
            loggers.getRenderLog().info("buffer_pool_expand", "Expanded buffer pool to {} buffers", .{self.buffers.items.len});

            return buffer;
        }

        /// Return a buffer to the pool
        pub fn release(self: *Self, buffer: *StructuredBuffer(T)) !void {
            // Find buffer index
            for (self.buffers.items, 0..) |pool_buffer, i| {
                if (pool_buffer == buffer) {
                    buffer.clear(); // Reset buffer
                    try self.free_list.append(i);
                    return;
                }
            }

            loggers.getRenderLog().err("buffer_pool_release", "Attempted to release buffer not owned by pool", .{});
            return error.BufferNotInPool;
        }

        /// Get pool statistics
        pub fn getStats(self: *Self) struct { total: usize, free: usize, used: usize } {
            return .{
                .total = self.buffers.items.len,
                .free = self.free_list.items.len,
                .used = self.buffers.items.len - self.free_list.items.len,
            };
        }
    };
}

// Tests
test "structured buffer creation" {
    const TestStruct = struct { x: f32, y: f32 };

    // This would fail in real usage due to mock device, but tests the API
    const create_info = StructuredBuffer(TestStruct).CreateInfo{
        .capacity = 100,
        .usage = c.sdl.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE,
        .name = "test_buffer",
        .enable_transfer = true,
    };

    // Just test that the types compile correctly
    _ = create_info;
}

test "buffer pool types" {
    const TestStruct = struct { value: u32 };
    _ = BufferPool(TestStruct);
    _ = DoubleBufferedStructuredBuffer(TestStruct);
}
