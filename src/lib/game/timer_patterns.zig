const timer = @import("../core/timer.zig");

/// Game-specific timer patterns and aliases
/// This module provides game-specific naming and patterns built on core timers

// Re-export core timer types
pub const Timer = timer.Timer;
pub const Cooldown = timer.Cooldown;
pub const CooldownTimer = timer.CooldownTimer;
pub const RechargeTimer = timer.RechargeTimer;
pub const TimerManager = timer.TimerManager;
pub const SpellTimerSystem = timer.SpellTimerSystem;
pub const GlobalTimer = timer.GlobalTimer;

/// Ability cooldown patterns specifically for game systems
pub const AbilityCooldown = Cooldown;

/// Resource regeneration timer patterns
pub const ResourceRechargeTimer = RechargeTimer;

/// Multi-ability cooldown manager for game systems
pub fn CooldownManager(comptime max_cooldowns: usize) type {
    return TimerManager(max_cooldowns);
}

/// Spell cooldown system compatible with existing patterns
pub const SpellCooldownSystem = struct {
    spell_timers: SpellTimerSystem,

    pub fn init() SpellCooldownSystem {
        return .{
            .spell_timers = SpellTimerSystem.init(),
        };
    }

    /// Set cooldown duration for a spell slot
    pub fn setSlotCooldown(self: *SpellCooldownSystem, slot: usize, duration: f32) void {
        self.spell_timers.setSlotDuration(slot, duration);
    }

    /// Check if spell slot can be cast
    pub fn canCast(self: *const SpellCooldownSystem, slot: usize) bool {
        return self.spell_timers.canUse(slot);
    }

    /// Start cooldown for a spell slot
    pub fn startCooldown(self: *SpellCooldownSystem, slot: usize) void {
        self.spell_timers.startTimer(slot);
    }

    /// Update all spell cooldowns
    pub fn update(self: *SpellCooldownSystem, delta_time: f32) void {
        self.spell_timers.update(delta_time);
    }

    /// Get remaining cooldown time for a spell slot
    pub fn getRemainingTime(self: *const SpellCooldownSystem, slot: usize) f32 {
        return self.spell_timers.getRemainingTime(slot);
    }

    /// Get cooldown progress for a spell slot (0.0 = ready, 1.0 = just cast)
    pub fn getProgress(self: *const SpellCooldownSystem, slot: usize) f32 {
        return self.spell_timers.getProgress(slot);
    }
};

/// Global cooldown tracker for system-wide abilities
pub const GlobalCooldown = GlobalTimer;
