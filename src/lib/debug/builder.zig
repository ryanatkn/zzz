const std = @import("std");
const Logger = @import("logger.zig").Logger;
const outputs = @import("outputs.zig");
const filters = @import("filters.zig");
const formatters = @import("formatters.zig");
const profiles = @import("profiles.zig");

const Profile = profiles.Profile;

/// Logger builder that creates loggers from profiles
/// Uses compile-time composition for zero-cost abstractions
pub const LoggerBuilder = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LoggerBuilder {
        return .{ .allocator = allocator };
    }

    /// Build a logger from a profile name
    pub fn fromProfile(self: LoggerBuilder, profile_name: []const u8) !LoggerInstance {
        const profile = profiles.getProfile(profile_name) orelse {
            return error.ProfileNotFound;
        };

        return self.fromProfileStruct(profile);
    }

    /// Build a logger from a profile struct
    pub fn fromProfileStruct(self: LoggerBuilder, profile: Profile) !LoggerInstance {
        // Determine output configuration
        const output_config = try self.buildOutputConfig(profile);

        // Determine filter configuration
        const filter_config = self.buildFilterConfig(profile);

        // Determine formatter configuration
        const formatter_config = self.buildFormatterConfig(profile);

        // Create the logger with dynamic composition
        return LoggerInstance{
            .allocator = self.allocator,
            .output = output_config,
            .filter = filter_config,
            .formatter = formatter_config,
            .profile = profile,
        };
    }

    fn buildOutputConfig(self: LoggerBuilder, profile: Profile) !OutputConfig {
        if (profile.outputs.len == 1) {
            const parsed = try Profile.OutputType.parse(profile.outputs[0]);
            return switch (parsed.type) {
                .console => OutputConfig{ .console = outputs.Console.init(self.allocator) },
                .file => OutputConfig{ .file = outputs.File(.{ .path = parsed.path.? }).init(self.allocator) },
            };
        } else {
            // Multiple outputs - create Multi output
            var output_list = std.ArrayList(OutputConfig).init(self.allocator);
            defer output_list.deinit();

            for (profile.outputs) |output_str| {
                const parsed = try Profile.OutputType.parse(output_str);
                const config = switch (parsed.type) {
                    .console => OutputConfig{ .console = outputs.Console.init(self.allocator) },
                    .file => OutputConfig{ .file = outputs.File(.{ .path = parsed.path.? }).init(self.allocator) },
                };
                try output_list.append(config);
            }

            return OutputConfig{ .multi = try output_list.toOwnedSlice() };
        }
    }

    fn buildFilterConfig(_: LoggerBuilder, profile: Profile) FilterConfig {
        if (profile.throttle_ms) |throttle_ms| {
            return FilterConfig{ .throttle = .{ .interval_ms = throttle_ms } };
        } else {
            return FilterConfig{ .passthrough = {} };
        }
    }

    fn buildFormatterConfig(_: LoggerBuilder, profile: Profile) FormatterConfig {
        if (profile.timestamps) {
            return FormatterConfig{ .timestamped = {} };
        } else {
            return FormatterConfig{ .passthrough = {} };
        }
    }
};

/// Runtime logger instance with dynamic configuration
pub const LoggerInstance = struct {
    allocator: std.mem.Allocator,
    output: OutputConfig,
    filter: FilterConfig,
    formatter: FormatterConfig,
    profile: Profile,

    pub fn deinit(self: *LoggerInstance) void {
        self.output.deinit();
        self.filter.deinit();
        self.formatter.deinit();
    }

    /// Log info message
    pub fn info(self: *LoggerInstance, key: []const u8, comptime fmt: []const u8, args: anytype) void {
        self.log(.info, key, fmt, args);
    }

    /// Log debug message
    pub fn debug(self: *LoggerInstance, key: []const u8, comptime fmt: []const u8, args: anytype) void {
        self.log(.debug, key, fmt, args);
    }

    /// Log warning message
    pub fn warn(self: *LoggerInstance, key: []const u8, comptime fmt: []const u8, args: anytype) void {
        self.log(.warn, key, fmt, args);
    }

    /// Log error message
    pub fn err(self: *LoggerInstance, key: []const u8, comptime fmt: []const u8, args: anytype) void {
        self.log(.err, key, fmt, args);
    }

    /// Core logging implementation
    fn log(self: *LoggerInstance, level: std.log.Level, key: []const u8, comptime fmt: []const u8, args: anytype) void {
        // Check minimum level first
        if (@intFromEnum(level) < @intFromEnum(self.profile.min_level)) {
            return;
        }

        // Format the base message
        var buffer: [512]u8 = undefined;
        const message = std.fmt.bufPrint(&buffer, fmt, args) catch "format error";

        // Check filter
        const should_log = self.filter.shouldLog(key, message);
        if (!should_log) return;

        // Format final message with key prefix
        var final_buffer: [768]u8 = undefined;
        const final_message = std.fmt.bufPrint(&final_buffer, "{s} {s}", .{ key, message }) catch "format error";

        // Apply formatter
        var format_buffer: [1024]u8 = undefined;
        const formatted_message = self.formatter.format(format_buffer[0..], level, final_message) catch final_message;

        // Send to output
        self.output.write(level, formatted_message);
    }
};

/// Union type for different output configurations
const OutputConfig = union(enum) {
    console: outputs.Console,
    file: outputs.File(.{ .path = "default.log" }),
    multi: []OutputConfig,

    pub fn deinit(self: *OutputConfig) void {
        switch (self.*) {
            .console => |*c| c.deinit(),
            .file => |*f| f.deinit(),
            .multi => |configs| {
                for (configs) |*config| {
                    config.deinit();
                }
            },
        }
    }

    pub fn write(self: *OutputConfig, level: std.log.Level, message: []const u8) void {
        switch (self.*) {
            .console => |*c| c.write(level, message),
            .file => |*f| f.write(level, message),
            .multi => |configs| {
                for (configs) |*config| {
                    config.write(level, message);
                }
            },
        }
    }
};

/// Union type for different filter configurations
const FilterConfig = union(enum) {
    passthrough: void,
    throttle: struct { interval_ms: u32 },

    pub fn deinit(self: *FilterConfig) void {
        switch (self.*) {
            .passthrough => {},
            .throttle => {}, // No cleanup needed for throttle config
        }
    }

    pub fn shouldLog(self: *FilterConfig, key: []const u8, message: []const u8) bool {
        return switch (self.*) {
            .passthrough => true,
            .throttle => {
                // Throttling logic not yet implemented - use filters.Throttle for actual throttling
                _ = key;
                _ = message;
                return true; // Allow all until throttling is implemented
            },
        };
    }
};

/// Union type for different formatter configurations
const FormatterConfig = union(enum) {
    passthrough: void,
    timestamped: void,

    pub fn deinit(self: *FormatterConfig) void {
        switch (self.*) {
            .passthrough => {},
            .timestamped => {},
        }
    }

    pub fn format(self: *FormatterConfig, buffer: []u8, level: std.log.Level, message: []const u8) ![]const u8 {
        return switch (self.*) {
            .passthrough => message,
            .timestamped => {
                const timestamp = std.time.timestamp();
                const level_str = switch (level) {
                    .debug => "DEBUG",
                    .info => "INFO",
                    .warn => "WARN",
                    .err => "ERROR",
                };

                const formatted = try std.fmt.bufPrint(buffer, "[{}] {s}: {s}", .{ timestamp, level_str, message });
                return formatted;
            },
        };
    }
};
