const std = @import("std");
const loggers = @import("../debug/loggers.zig");

/// Output capture for real-time command output streaming
pub const OutputCapture = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),
    max_buffer_size: usize = 1024 * 1024, // 1MB default limit

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }

    /// Capture output from a stream with real-time processing
    pub fn captureStream(self: *Self, stream: std.fs.File, callback: *const fn (data: []const u8) void) ![]u8 {
        self.buffer.clearRetainingCapacity();

        var read_buffer: [4096]u8 = undefined;

        while (true) {
            const bytes_read = stream.read(&read_buffer) catch |err| switch (err) {
                error.WouldBlock => {
                    // No more data available right now
                    std.time.sleep(std.time.ns_per_ms); // Sleep 1ms
                    continue;
                },
                else => return err,
            };

            if (bytes_read == 0) break; // EOF

            const data = read_buffer[0..bytes_read];

            // Call callback for real-time processing
            callback(data);

            // Add to buffer for final result
            try self.buffer.appendSlice(data);

            // Prevent buffer overflow
            if (self.buffer.items.len > self.max_buffer_size) {
                // Truncate older data, keep newer data
                const keep_size = self.max_buffer_size / 2;
                const start_offset = self.buffer.items.len - keep_size;
                std.mem.copyForwards(u8, self.buffer.items[0..keep_size], self.buffer.items[start_offset..]);
                self.buffer.shrinkRetainingCapacity(keep_size);
            }
        }

        return try self.allocator.dupe(u8, self.buffer.items);
    }

    /// Simple capture without streaming (for compatibility)
    pub fn captureAll(self: *Self, stream: std.fs.File) ![]u8 {
        self.buffer.clearRetainingCapacity();
        return stream.readToEndAlloc(self.allocator, self.max_buffer_size);
    }

    /// Set maximum buffer size
    pub fn setMaxBufferSize(self: *Self, size: usize) void {
        self.max_buffer_size = size;
    }
};

/// Output handler for progressive display
pub const ProgressiveOutput = struct {
    allocator: std.mem.Allocator,
    write_callback: *const fn (context: *anyopaque, data: []const u8) anyerror!void,
    write_context: *anyopaque,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        write_callback: *const fn (context: *anyopaque, data: []const u8) anyerror!void,
        write_context: *anyopaque,
    ) Self {
        return Self{
            .allocator = allocator,
            .write_callback = write_callback,
            .write_context = write_context,
        };
    }

    /// Handle incoming data chunk
    pub fn handleData(self: *Self, data: []const u8) void {
        self.write_callback(self.write_context, data) catch |err| {
            const ui_log = loggers.getUILog();
            ui_log.err("terminal_output", "Failed to write progressive output: {}", .{err});
        };
    }

    /// Create callback function for OutputCapture
    pub fn createCallback(self: *Self) *const fn (data: []const u8) void {
        _ = self;
        return struct {
            fn callback(data: []const u8) void {
                // Access self through global context (this is a limitation of the callback design)
                // For now, we'll just handle this in the calling code
                _ = data;
            }
        }.callback;
    }
};

/// Stream reader for non-blocking output capture
pub const StreamReader = struct {
    allocator: std.mem.Allocator,
    stream: std.fs.File,
    buffer: [4096]u8 = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, stream: std.fs.File) Self {
        return Self{
            .allocator = allocator,
            .stream = stream,
        };
    }

    /// Try to read available data (non-blocking)
    pub fn readAvailable(self: *Self) !?[]u8 {
        const bytes_read = self.stream.read(&self.buffer) catch |err| switch (err) {
            error.WouldBlock => return null, // No data available
            else => return err,
        };

        if (bytes_read == 0) return null; // EOF or no data

        return try self.allocator.dupe(u8, self.buffer[0..bytes_read]);
    }

    /// Check if stream has data available
    pub fn hasData(self: *Self) bool {
        // This is a simplified check - in a real implementation,
        // we'd use select() or poll() for proper non-blocking detection
        _ = self;
        return true; // For now, assume data might be available
    }
};
