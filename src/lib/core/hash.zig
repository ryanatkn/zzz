const std = @import("std");

/// Small focused hash utilities module
/// Provides common hashing functions used across the engine
/// Hash a text string using FNV-1a 64-bit
/// Fast, non-cryptographic hash suitable for cache keys and content identification
pub fn hashText(text: []const u8) u64 {
    var hasher = std.hash.Fnv1a_64.init();
    hasher.update(text);
    return hasher.final();
}

/// Hash arbitrary bytes using FNV-1a 64-bit
pub fn hashBytes(bytes: []const u8) u64 {
    var hasher = std.hash.Fnv1a_64.init();
    hasher.update(bytes);
    return hasher.final();
}

/// Hash a struct or any value by treating it as bytes
pub fn hashValue(comptime T: type, value: T) u64 {
    const bytes = std.mem.asBytes(&value);
    return hashBytes(bytes);
}

/// Create a content hash from multiple components
/// Useful for cache keys that depend on multiple parameters
pub fn hashComponents(components: []const []const u8) u64 {
    var hasher = std.hash.Fnv1a_64.init();
    for (components) |component| {
        hasher.update(component);
        // Add separator to avoid hash collisions between different component arrangements
        hasher.update(&[_]u8{0xFF});
    }
    return hasher.final();
}

test "hashText produces consistent results" {
    const testing = std.testing;

    const text = "Hello, World!";
    const hash1 = hashText(text);
    const hash2 = hashText(text);

    try testing.expectEqual(hash1, hash2);
    try testing.expect(hash1 != 0);
}

test "hashText produces different results for different text" {
    const testing = std.testing;

    const hash1 = hashText("Hello");
    const hash2 = hashText("World");

    try testing.expect(hash1 != hash2);
}

test "hashComponents avoids collisions" {
    const testing = std.testing;

    // These should produce different hashes despite same total content
    const hash1 = hashComponents(&[_][]const u8{ "ab", "cd" });
    const hash2 = hashComponents(&[_][]const u8{ "a", "bcd" });

    try testing.expect(hash1 != hash2);
}
