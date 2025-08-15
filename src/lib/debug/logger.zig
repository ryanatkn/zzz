const std = @import("std");

/// Generic logger with compile-time composition of outputs, filters, and formatters
pub fn Logger(comptime config: LoggerConfig) type {
    return struct {
        const Self = @This();
        
        allocator: std.mem.Allocator,
        output: config.output,
        filter: config.filter,
        formatter: config.formatter,
        
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .output = if (@hasDecl(config.output, "init")) 
                    config.output.init(allocator) 
                else 
                    config.output{},
                .filter = if (@hasDecl(config.filter, "init"))
                    config.filter.init(allocator)
                else
                    config.filter{},
                .formatter = if (@hasDecl(config.formatter, "init"))
                    config.formatter.init(allocator)
                else
                    config.formatter{},
            };
        }
        
        pub fn deinit(self: *Self) void {
            if (@hasDecl(@TypeOf(self.output), "deinit")) {
                self.output.deinit();
            }
            if (@hasDecl(@TypeOf(self.filter), "deinit")) {
                self.filter.deinit();
            }
            if (@hasDecl(@TypeOf(self.formatter), "deinit")) {
                self.formatter.deinit();
            }
        }
        
        /// Log info message
        pub fn info(self: *Self, key: []const u8, comptime fmt: []const u8, args: anytype) void {
            self.log(.info, key, fmt, args);
        }
        
        /// Log debug message  
        pub fn debug(self: *Self, key: []const u8, comptime fmt: []const u8, args: anytype) void {
            self.log(.debug, key, fmt, args);
        }
        
        /// Log warning message
        pub fn warn(self: *Self, key: []const u8, comptime fmt: []const u8, args: anytype) void {
            self.log(.warn, key, fmt, args);
        }
        
        /// Log error message
        pub fn err(self: *Self, key: []const u8, comptime fmt: []const u8, args: anytype) void {
            self.log(.err, key, fmt, args);
        }
        
        /// Core logging implementation
        fn log(self: *Self, level: std.log.Level, key: []const u8, comptime fmt: []const u8, args: anytype) void {
            // Format the base message
            var buffer: [512]u8 = undefined;
            const message = std.fmt.bufPrint(&buffer, fmt, args) catch "format error";
            
            // Check if filter allows this message
            const should_log = if (@hasDecl(@TypeOf(self.filter), "shouldLog"))
                self.filter.shouldLog(key, message)
            else
                true;
                
            if (!should_log) return;
            
            // Format the final message with key prefix
            var final_buffer: [768]u8 = undefined;
            const final_message = std.fmt.bufPrint(&final_buffer, "{s} {s}", .{ key, message }) catch "format error";
            
            // Apply formatter if present
            const formatted_message = if (@hasDecl(@TypeOf(self.formatter), "format")) blk: {
                var format_buffer: [1024]u8 = undefined;
                break :blk self.formatter.format(format_buffer[0..], level, final_message) catch final_message;
            } else final_message;
            
            // Send to output
            self.output.write(level, formatted_message);
        }
    };
}

/// Configuration structure for Logger
pub const LoggerConfig = struct {
    output: type,
    filter: type = DefaultFilter,
    formatter: type = DefaultFormatter,
};

/// Default passthrough filter
const DefaultFilter = struct {
    pub fn shouldLog(_: @This(), _: []const u8, _: []const u8) bool {
        return true;
    }
};

/// Default passthrough formatter  
const DefaultFormatter = struct {
    pub fn format(_: @This(), buffer: []u8, _: std.log.Level, message: []const u8) ![]const u8 {
        if (message.len > buffer.len) return message[0..buffer.len];
        @memcpy(buffer[0..message.len], message);
        return buffer[0..message.len];
    }
};