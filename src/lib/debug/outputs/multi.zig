const std = @import("std");

/// Multi-destination output compositor that sends logs to multiple outputs
pub fn Multi(comptime outputs: anytype) type {
    const Console = outputs[0];
    const FileOutput = outputs[1];

    return struct {
        const Self = @This();

        console: Console,
        file: FileOutput,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .console = if (@hasDecl(Console, "init")) Console.init(allocator) else Console{},
                .file = if (@hasDecl(FileOutput, "init")) FileOutput.init(allocator) else FileOutput{},
            };
        }

        pub fn deinit(self: *Self) void {
            if (@hasDecl(Console, "deinit")) {
                self.console.deinit();
            }
            if (@hasDecl(FileOutput, "deinit")) {
                self.file.deinit();
            }
        }

        /// Write message to all configured outputs
        pub fn write(self: *Self, level: std.log.Level, message: []const u8) void {
            self.console.write(level, message);
            self.file.write(level, message);
        }
    };
}
