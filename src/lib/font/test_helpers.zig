const std = @import("std");
const loggers = @import("../debug/loggers.zig");

/// Test helper to initialize global loggers for font tests
/// Call this at the beginning of any font test that uses glyph extraction or font atlas
pub fn initTestLoggers(allocator: std.mem.Allocator) !void {
    try loggers.initGlobalLoggers(allocator);
}

/// Test helper to clean up global loggers
/// Call this at the end of font tests (use defer)
pub fn deinitTestLoggers() void {
    loggers.deinitGlobalLoggers();
}

/// Convenience wrapper for tests that need logger initialization
/// Usage:
/// test "my font test" {
///     try withTestLoggers(testing.allocator, testFontFunction);
/// }
pub fn withTestLoggers(allocator: std.mem.Allocator, testFn: fn () anyerror!void) !void {
    try initTestLoggers(allocator);
    defer deinitTestLoggers();
    try testFn();
}
