const std = @import("std");
const kernel = @import("../../kernel/mod.zig");
const BasicWriter = @import("basic_writer.zig").BasicWriter;

/// Buffered output capability - optimizes terminal output with batching
pub const BufferedOutput = struct {
    pub const name = "buffered_output";
    pub const capability_type = "output";
    pub const dependencies = &[_][]const u8{"basic_writer"};

    active: bool = false,
    initialized: bool = false,

    // Dependencies
    basic_writer: ?*@import("basic_writer.zig").BasicWriter = null,

    // Event bus
    event_bus: ?*kernel.EventBus = null,
    allocator: std.mem.Allocator,

    // Buffering configuration
    buffer_size: usize = 8192,
    flush_interval_ms: i64 = 16, // ~60fps
    auto_flush: bool = true,

    // Output buffer
    buffer: std.ArrayList(u8),
    last_flush_time: i64 = 0,
    pending_operations: usize = 0,

    // Performance metrics
    total_writes: usize = 0,
    total_flushes: usize = 0,
    bytes_written: usize = 0,
    bytes_buffered: usize = 0,

    const Self = @This();

    /// Initialize buffered output
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    /// Create a new buffered output capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = Self.init(allocator);
        try self.buffer.ensureTotalCapacity(self.buffer_size);
        return self;
    }

    /// Destroy buffered output capability
    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        self.deinit();
        allocator.destroy(self);
    }

    /// Get capability name
    pub fn getName(self: *Self) []const u8 {
        _ = self;
        return name;
    }

    /// Get capability type
    pub fn getType(self: *Self) []const u8 {
        _ = self;
        return capability_type;
    }

    /// Get dependencies
    pub fn getDependencies(self: *Self) []const []const u8 {
        _ = self;
        return dependencies;
    }

    /// Initialize with dependencies
    pub fn initialize(self: *Self, deps: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        // Resolve dependencies
        for (deps) |dep| {
            if (dep.cast(BasicWriter)) |bw| {
                self.basic_writer = bw;
            }
        }

        // Verify dependencies
        if (self.basic_writer == null) return error.MissingDependency;

        self.event_bus = event_bus;

        // Subscribe to output events
        try event_bus.subscribe(.output, handleOutputEvent, self);

        // Auto-flush will be handled by periodic output events
        // In a real implementation, we'd have a timer capability

        self.last_flush_time = std.time.milliTimestamp();
        self.initialized = true;
        self.active = true;
    }

    /// Deinitialize capability
    pub fn deinit(self: *Self) void {
        // Flush any remaining buffer
        self.flush() catch {};

        self.buffer.deinit();
        self.active = false;
        self.initialized = false;
    }

    /// Check if capability is active
    pub fn isActive(self: *Self) bool {
        return self.active;
    }

    /// Configure buffering parameters
    pub fn configure(self: *Self, config: BufferConfig) !void {
        self.buffer_size = config.buffer_size;
        self.flush_interval_ms = config.flush_interval_ms;
        self.auto_flush = config.auto_flush;

        // Resize buffer if needed
        try self.buffer.ensureTotalCapacity(self.buffer_size);
    }

    pub const BufferConfig = struct {
        buffer_size: usize = 8192,
        flush_interval_ms: i64 = 16,
        auto_flush: bool = true,
    };

    /// Write data to buffer
    pub fn write(self: *Self, data: []const u8) !void {
        self.total_writes += 1;

        // Check if buffer would overflow
        if (self.buffer.items.len + data.len > self.buffer_size) {
            // Flush current buffer
            try self.flush();
        }

        // Handle data larger than buffer
        if (data.len > self.buffer_size) {
            // Direct write for large data
            try self.directWrite(data);
            return;
        }

        // Add to buffer
        try self.buffer.appendSlice(data);
        self.bytes_buffered += data.len;
        self.pending_operations += 1;

        // Check if we should flush
        if (self.shouldFlush()) {
            try self.flush();
        }
    }

    /// Write formatted data to buffer
    pub fn print(self: *Self, comptime format: []const u8, args: anytype) !void {
        const data = try std.fmt.allocPrint(self.allocator, format, args);
        defer self.allocator.free(data);
        try self.write(data);
    }

    /// Write line to buffer
    pub fn writeLine(self: *Self, line: []const u8) !void {
        try self.write(line);
        try self.write("\n");
    }

    /// Flush buffer to output
    pub fn flush(self: *Self) !void {
        if (self.buffer.items.len == 0) return;

        const writer = self.basic_writer orelse return error.NoWriter;

        // Write buffer contents
        try writer.write(self.buffer.items);

        // Update metrics
        self.total_flushes += 1;
        self.bytes_written += self.buffer.items.len;

        // Clear buffer
        self.buffer.clearRetainingCapacity();
        self.pending_operations = 0;
        self.last_flush_time = std.time.milliTimestamp();
    }

    /// Force immediate flush
    pub fn forceFlush(self: *Self) !void {
        try self.flush();
    }

    /// Direct write bypassing buffer
    fn directWrite(self: *Self, data: []const u8) !void {
        // Flush any existing buffer first
        try self.flush();

        const writer = self.basic_writer orelse return error.NoWriter;
        try writer.write(data);

        self.bytes_written += data.len;
    }

    /// Check if buffer should be flushed
    fn shouldFlush(self: *Self) bool {
        // Flush if buffer is nearly full
        if (self.buffer.items.len >= self.buffer_size * 90 / 100) {
            return true;
        }

        // Flush if enough operations pending
        if (self.pending_operations >= 100) {
            return true;
        }

        // Flush if line-buffered and contains newline
        if (std.mem.indexOfScalar(u8, self.buffer.items, '\n') != null) {
            return true;
        }

        return false;
    }

    /// Get buffer statistics
    pub fn getStats(self: *Self) BufferStats {
        return BufferStats{
            .total_writes = self.total_writes,
            .total_flushes = self.total_flushes,
            .bytes_written = self.bytes_written,
            .bytes_buffered = self.bytes_buffered,
            .buffer_utilization = if (self.buffer_size > 0)
                @as(f32, @floatFromInt(self.buffer.items.len)) / @as(f32, @floatFromInt(self.buffer_size)) * 100.0
            else
                0.0,
            .avg_batch_size = if (self.total_flushes > 0)
                self.bytes_written / self.total_flushes
            else
                0,
        };
    }

    pub const BufferStats = struct {
        total_writes: usize,
        total_flushes: usize,
        bytes_written: usize,
        bytes_buffered: usize,
        buffer_utilization: f32,
        avg_batch_size: usize,
    };

    /// Handle output events
    fn handleOutputEvent(event: kernel.Event, context: ?*anyopaque) !void {
        const self = @as(*Self, @ptrCast(@alignCast(context.?)));

        if (event.data != .output) return;
        const output_data = event.data.output;

        // Buffer the output
        try self.write(output_data.text);
    }
};
