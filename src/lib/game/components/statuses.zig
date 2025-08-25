const std = @import("std");
const BoundedArray = std.BoundedArray;

const EntityId = u32;

/// Generic Status system - games define their own ModifierType enum
/// Example: const MyStatuses = StatusSystem(MyModifierType, 16);
pub fn StatusSystem(comptime ModifierType: type, comptime max_modifiers: usize) type {
    return struct {
        const Self = @This();

        pub const StackType = enum {
            replace, // New replaces old
            add, // Values add together
            multiply, // Values multiply
            max, // Take maximum value
            min, // Take minimum value
        };

        pub const Modifier = struct {
            type: ModifierType,
            value: f32,
            duration: f32,
            stack_type: StackType,
            source: EntityId,
        };

        modifiers: BoundedArray(Modifier, max_modifiers),

        pub fn init() Self {
            return .{
                // Safe: initializing with 0 elements when capacity is max_modifiers
                .modifiers = BoundedArray(Modifier, max_modifiers).init(0) catch unreachable,
            };
        }

        pub fn addModifier(self: *Self, modifier: Modifier) !void {
            try self.modifiers.append(modifier);
        }

        pub fn update(self: *Self, dt: f32) void {
            var i: usize = 0;
            while (i < self.modifiers.len) {
                self.modifiers.buffer[i].duration -= dt;
                if (self.modifiers.buffer[i].duration <= 0) {
                    _ = self.modifiers.swapRemove(i);
                } else {
                    i += 1;
                }
            }
        }

        pub fn getModifiedValue(self: Self, base: f32, modifier_type: ModifierType) f32 {
            var result = base;
            var multiplicative: f32 = 1.0;

            for (self.modifiers.slice()) |mod| {
                if (!std.meta.eql(mod.type, modifier_type)) continue;

                switch (mod.stack_type) {
                    .replace => result = mod.value,
                    .add => result += mod.value - base,
                    .multiply => multiplicative *= mod.value,
                    .max => result = @max(result, mod.value),
                    .min => result = @min(result, mod.value),
                }
            }

            return result * multiplicative;
        }

        /// Count modifiers of a specific type
        pub fn countModifiersOfType(self: Self, modifier_type: ModifierType) u32 {
            var count: u32 = 0;
            for (self.modifiers.slice()) |mod| {
                if (std.meta.eql(mod.type, modifier_type)) {
                    count += 1;
                }
            }
            return count;
        }

        /// Remove all modifiers of a specific type
        pub fn removeModifiersOfType(self: *Self, modifier_type: ModifierType) void {
            var i: usize = 0;
            while (i < self.modifiers.len) {
                if (std.meta.eql(self.modifiers.buffer[i].type, modifier_type)) {
                    _ = self.modifiers.swapRemove(i);
                } else {
                    i += 1;
                }
            }
        }
    };
}

// Generic StatusSystem is ready for use by games
// Games should create their own StatusSystem instances with game-specific ModifierType enums
// Example: const MyStatuses = StatusSystem(MyModifierType, 16);
