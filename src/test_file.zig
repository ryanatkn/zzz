// Test file for file explorer content preview
const std = @import("std");

pub fn main() !void {
    std.log.info("Hello from test file!", .{});
    
    const message = "This is a test file to demonstrate " ++
                   "the file content preview functionality " ++
                   "in our modern file explorer!";
    
    std.debug.print("{s}\n", .{message});
}

// Some example code structures
const MyStruct = struct {
    value: i32,
    name: []const u8,
    
    pub fn init(value: i32, name: []const u8) MyStruct {
        return MyStruct{
            .value = value,
            .name = name,
        };
    }
    
    pub fn getValue(self: *const MyStruct) i32 {
        return self.value;
    }
};

// This file should be visible in the file explorer
// and when clicked, its contents should appear 
// in the center panel with line numbers!