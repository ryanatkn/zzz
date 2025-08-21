/// Standard Result type for explicit error handling
/// Provides a Rust-like Result(T, E) pattern for Zig
/// Result type that can be either Ok(T) or Err(E)
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        const Self = @This();

        ok: T,
        err: E,

        /// Create a successful result
        pub fn Ok(value: T) Self {
            return Self{ .ok = value };
        }

        /// Create an error result
        pub fn Err(error_value: E) Self {
            return Self{ .err = error_value };
        }

        /// Check if the result is successful
        pub fn isOk(self: Self) bool {
            return switch (self) {
                .ok => true,
                .err => false,
            };
        }

        /// Check if the result is an error
        pub fn isErr(self: Self) bool {
            return !self.isOk();
        }

        /// Get the value if Ok, panic if Err
        pub fn unwrap(self: Self) T {
            return switch (self) {
                .ok => |value| value,
                .err => |_| @panic("called unwrap() on an Err value"),
            };
        }

        /// Get the error value if Err, panic if Ok
        pub fn unwrapErr(self: Self) E {
            return switch (self) {
                .ok => @panic("called unwrapErr() on an Ok value"),
                .err => |error_value| error_value,
            };
        }

        /// Get the value if Ok, return default if Err
        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .ok => |value| value,
                .err => default,
            };
        }

        /// Get the value if Ok, compute default from error if Err
        pub fn unwrapOrElse(self: Self, default_fn: *const fn (E) T) T {
            return switch (self) {
                .ok => |value| value,
                .err => |error_value| default_fn(error_value),
            };
        }

        /// Transform the Ok value with a function, leave Err unchanged
        pub fn map(self: Self, comptime U: type, transform_fn: *const fn (T) U) Result(U, E) {
            return switch (self) {
                .ok => |value| Result(U, E).Ok(transform_fn(value)),
                .err => |error_value| Result(U, E).Err(error_value),
            };
        }

        /// Transform the Err value with a function, leave Ok unchanged
        pub fn mapErr(self: Self, comptime F: type, transform_fn: *const fn (E) F) Result(T, F) {
            return switch (self) {
                .ok => |value| Result(T, F).Ok(value),
                .err => |error_value| Result(T, F).Err(transform_fn(error_value)),
            };
        }

        /// Chain Result-returning operations
        pub fn andThen(self: Self, comptime U: type, next_fn: *const fn (T) Result(U, E)) Result(U, E) {
            return switch (self) {
                .ok => |value| next_fn(value),
                .err => |error_value| Result(U, E).Err(error_value),
            };
        }

        /// Chain operations that might recover from errors
        pub fn orElse(self: Self, recovery_fn: *const fn (E) Self) Self {
            return switch (self) {
                .ok => self,
                .err => |error_value| recovery_fn(error_value),
            };
        }

        /// Convert to Zig's standard error union type
        pub fn toErrorUnion(self: Self) E!T {
            return switch (self) {
                .ok => |value| value,
                .err => |error_value| error_value,
            };
        }

        /// Create Result from Zig's error union type
        pub fn fromErrorUnion(error_union: E!T) Self {
            return error_union catch |err| Self.Err(err);
        }
    };
}

/// Convenience type for Results with string errors
pub fn StringResult(comptime T: type) type {
    return Result(T, []const u8);
}

/// Convenience type for Results with standard error types
pub fn ErrorResult(comptime T: type, comptime ErrorSet: type) type {
    return Result(T, ErrorSet);
}

/// Utility functions for working with Results
/// Combine multiple Results - succeeds only if all succeed
pub fn all(comptime T: type, comptime E: type, results: []const Result(T, E)) Result([]const T, E) {
    var values = std.ArrayList(T).init(std.testing.allocator);
    defer values.deinit();

    for (results) |result| {
        switch (result) {
            .ok => |value| values.append(value) catch return Result([]const T, E).Err(E.OutOfMemory),
            .err => |error_value| return Result([]const T, E).Err(error_value),
        }
    }

    return Result([]const T, E).Ok(values.toOwnedSlice());
}

/// Return the first successful Result, or the last error if all fail
pub fn any(comptime T: type, comptime E: type, results: []const Result(T, E)) Result(T, E) {
    var last_error: ?E = null;

    for (results) |result| {
        switch (result) {
            .ok => |value| return Result(T, E).Ok(value),
            .err => |error_value| last_error = error_value,
        }
    }

    return Result(T, E).Err(last_error orelse return Result(T, E).Err(E.NoResults));
}

// Tests
const std = @import("std");
const testing = std.testing;

test "Result basic operations" {
    const IntResult = Result(i32, []const u8);

    const ok_result = IntResult.Ok(42);
    const err_result = IntResult.Err("something went wrong");

    try testing.expect(ok_result.isOk());
    try testing.expect(!ok_result.isErr());
    try testing.expect(!err_result.isOk());
    try testing.expect(err_result.isErr());

    try testing.expectEqual(@as(i32, 42), ok_result.unwrap());
    try testing.expectEqual(@as(i32, 0), err_result.unwrapOr(0));
}

test "Result map operations" {
    const IntResult = Result(i32, []const u8);

    const ok_result = IntResult.Ok(21);
    const doubled = ok_result.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try testing.expectEqual(@as(i32, 42), doubled.unwrap());
}
