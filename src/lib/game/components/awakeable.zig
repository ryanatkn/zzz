/// Awakeable - enables terrain/objects to come alive
/// Sparse storage - only potentially living entities have this
pub const Awakeable = struct {
    pub const TriggerType = enum {
        damage_threshold,
        spell_target,
        proximity,
        time_elapsed,
        player_touch,
    };

    pub const EntityType = enum {
        basic_creature,
        animated_wall,
        living_floor,
        guardian_statue,
    };

    trigger_condition: TriggerType,
    awakened_entity_type: EntityType,
    trigger_value: f32, // Threshold/timer/distance etc.
    current_value: f32,

    pub fn init(trigger: TriggerType, entity_type: EntityType, trigger_value: f32) Awakeable {
        return .{
            .trigger_condition = trigger,
            .awakened_entity_type = entity_type,
            .trigger_value = trigger_value,
            .current_value = 0,
        };
    }

    pub fn checkTrigger(self: *Awakeable, value: f32) bool {
        self.current_value = value;
        return switch (self.trigger_condition) {
            .damage_threshold, .time_elapsed => value >= self.trigger_value,
            .proximity => value <= self.trigger_value,
            .spell_target, .player_touch => value > 0,
        };
    }
};
