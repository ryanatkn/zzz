const std = @import("std");
const cooldowns = @import("../cooldowns.zig");

/// Generic spell slot management system
/// Games define their own spell types and implement casting logic
pub fn SpellSlotSystem(comptime SpellType: type, comptime slot_count: usize) type {
    return struct {
        const Self = @This();

        slots: [slot_count]SpellSlot(SpellType),
        active_slot: usize,

        pub fn init() Self {
            var system = Self{
                .slots = undefined,
                .active_slot = 0,
            };

            // Initialize all slots
            for (&system.slots) |*slot| {
                slot.* = SpellSlot(SpellType).init(@as(SpellType, @enumFromInt(0))); // Default to first enum value
            }

            return system;
        }

        pub fn setSpell(self: *Self, slot_index: usize, spell_type: SpellType, cooldown_duration: f32) void {
            if (slot_index >= slot_count) return;
            self.slots[slot_index] = SpellSlot(SpellType).initWithCooldown(spell_type, cooldown_duration);
        }

        pub fn setActiveSlot(self: *Self, slot_index: usize) void {
            if (slot_index < slot_count) {
                self.active_slot = slot_index;
            }
        }

        pub fn getActiveSlot(self: *const Self) *const SpellSlot(SpellType) {
            return &self.slots[self.active_slot];
        }

        pub fn getActiveSlotMut(self: *Self) *SpellSlot(SpellType) {
            return &self.slots[self.active_slot];
        }

        pub fn getSlot(self: *const Self, slot_index: usize) ?*const SpellSlot(SpellType) {
            if (slot_index >= slot_count) return null;
            return &self.slots[slot_index];
        }

        pub fn getSlotMut(self: *Self, slot_index: usize) ?*SpellSlot(SpellType) {
            if (slot_index >= slot_count) return null;
            return &self.slots[slot_index];
        }

        pub fn update(self: *Self, delta_time: f32) void {
            for (&self.slots) |*slot| {
                slot.update(delta_time);
            }
        }

        /// Try to cast active spell, returns true if cast was initiated
        /// Games implement their own casting logic
        pub fn tryCastActive(self: *Self, cast_fn: anytype, args: anytype) bool {
            const slot = self.getActiveSlotMut();
            if (!slot.canCast()) return false;

            // Call game-specific casting function
            const cast_result = @call(.auto, cast_fn, args);
            if (cast_result) {
                slot.startCooldown();
                return true;
            }
            return false;
        }
    };
}

/// Generic spell slot with cooldown management
pub fn SpellSlot(comptime SpellType: type) type {
    return struct {
        const Self = @This();

        spell_type: SpellType,
        cooldown_timer: cooldowns.Cooldown,

        pub fn init(spell_type: SpellType) Self {
            return .{
                .spell_type = spell_type,
                .cooldown_timer = cooldowns.Cooldown.init(0.0), // No cooldown by default
            };
        }

        pub fn initWithCooldown(spell_type: SpellType, cooldown_duration: f32) Self {
            return .{
                .spell_type = spell_type,
                .cooldown_timer = cooldowns.Cooldown.init(cooldown_duration),
            };
        }

        pub fn canCast(self: *const Self) bool {
            return self.cooldown_timer.isReady();
        }

        pub fn startCooldown(self: *Self) void {
            self.cooldown_timer.start();
        }

        pub fn update(self: *Self, delta_time: f32) void {
            self.cooldown_timer.update(delta_time);
        }

        pub fn getRemainingTime(self: *const Self) f32 {
            return self.cooldown_timer.getRemaining();
        }

        pub fn getProgress(self: *const Self) f32 {
            return self.cooldown_timer.getProgress();
        }

        pub fn isOnCooldown(self: *const Self) bool {
            return !self.cooldown_timer.isReady();
        }
    };
}

/// Example spell type for reference
pub const ExampleSpellType = enum {
    None,
    Fireball,
    Heal,
    Teleport,
};

/// Example 8-slot system like hex game uses
pub const Example8SlotSystem = SpellSlotSystem(ExampleSpellType, 8);
