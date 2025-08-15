const std = @import("std");

/// Logger profile configuration - defines how a logger should behave
pub const Profile = struct {
    name: []const u8,
    outputs: []const []const u8, // e.g. ["console", "file:game.log"]
    min_level: std.log.Level = .debug,
    throttle_ms: ?u32 = null, // null = no throttling
    timestamps: bool = false,
    
    pub const OutputType = enum {
        console,
        file,
        
        pub fn parse(output_str: []const u8) !struct { type: OutputType, path: ?[]const u8 } {
            if (std.mem.eql(u8, output_str, "console")) {
                return .{ .type = .console, .path = null };
            }
            
            if (std.mem.startsWith(u8, output_str, "file:")) {
                const path = output_str[5..]; // Skip "file:"
                return .{ .type = .file, .path = path };
            }
            
            return error.InvalidOutputFormat;
        }
    };
};

/// Default profiles embedded in binary
pub const default_profiles = [_]Profile{
    .{
        .name = "game",
        .outputs = &[_][]const u8{ "console", "file:game.log" },
        .min_level = .debug,
        .throttle_ms = 30000,
        .timestamps = true,
    },
    .{
        .name = "ui", 
        .outputs = &[_][]const u8{"console"},
        .min_level = .debug,
        .throttle_ms = 1000,
        .timestamps = false,
    },
    .{
        .name = "render",
        .outputs = &[_][]const u8{"console"}, 
        .min_level = .warn,
        .throttle_ms = null, // No throttling for performance
        .timestamps = false,
    },
    .{
        .name = "font",
        .outputs = &[_][]const u8{"console"},
        .min_level = .info,
        .throttle_ms = 5000,
        .timestamps = false,
    },
    .{
        .name = "debug",
        .outputs = &[_][]const u8{ "console", "file:debug.log" },
        .min_level = .debug,
        .throttle_ms = null, // No throttling for debug
        .timestamps = true,
    },
};

/// Get profile by name, falling back to defaults
pub fn getProfile(name: []const u8) ?Profile {
    // First check loaded profiles (TODO: implement ZON loading)
    // For now, just return defaults
    return getDefaultProfile(name);
}

/// Get default profile by name
pub fn getDefaultProfile(name: []const u8) ?Profile {
    for (default_profiles) |profile| {
        if (std.mem.eql(u8, profile.name, name)) {
            return profile;
        }
    }
    return null;
}

/// Parse log level from string
pub fn parseLogLevel(level_str: []const u8) std.log.Level {
    if (std.mem.eql(u8, level_str, "debug")) return .debug;
    if (std.mem.eql(u8, level_str, "info")) return .info;
    if (std.mem.eql(u8, level_str, "warn")) return .warn;
    if (std.mem.eql(u8, level_str, "err")) return .err;
    return .debug; // Default fallback
}