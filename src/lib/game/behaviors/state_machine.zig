const std = @import("std");
const timer = @import("../../core/timer.zig");

/// Generic state machine for AI behaviors
/// Games define their own state types and implement transition logic
pub fn StateMachine(comptime StateType: type, comptime max_states: usize) type {
    return struct {
        const Self = @This();

        current_state: StateType,
        previous_state: StateType,
        state_timer: timer.Timer,
        transition_history: [max_states]StateTransition,
        history_count: usize,

        pub const StateTransition = struct {
            from: StateType,
            to: StateType,
            reason: TransitionReason,
            timestamp: f32,
        };

        pub const TransitionReason = enum {
            manual,
            timeout,
            condition_met,
            interrupt,
            priority_override,
            external_trigger,
        };

        pub fn init(initial_state: StateType) Self {
            return .{
                .current_state = initial_state,
                .previous_state = initial_state,
                .state_timer = timer.Timer.init(0.0),
                .transition_history = undefined,
                .history_count = 0,
            };
        }

        /// Get current state
        pub fn getCurrentState(self: *const Self) StateType {
            return self.current_state;
        }

        /// Get previous state
        pub fn getPreviousState(self: *const Self) StateType {
            return self.previous_state;
        }

        /// Get time in current state
        pub fn getTimeInState(self: *const Self) f32 {
            return self.state_timer.getProgress() * self.state_timer.duration;
        }

        /// Transition to a new state
        pub fn transitionTo(
            self: *Self,
            new_state: StateType,
            reason: TransitionReason,
            min_duration: f32,
        ) void {
            if (self.current_state == new_state) return;

            // Record transition in history
            if (self.history_count < max_states) {
                self.transition_history[self.history_count] = StateTransition{
                    .from = self.current_state,
                    .to = new_state,
                    .reason = reason,
                    .timestamp = self.getTimeInState(),
                };
                self.history_count += 1;
            } else {
                // Shift history to make room for new transition
                for (1..max_states) |i| {
                    self.transition_history[i - 1] = self.transition_history[i];
                }
                self.transition_history[max_states - 1] = StateTransition{
                    .from = self.current_state,
                    .to = new_state,
                    .reason = reason,
                    .timestamp = self.getTimeInState(),
                };
            }

            // Execute transition
            self.previous_state = self.current_state;
            self.current_state = new_state;
            self.state_timer = timer.Timer.init(min_duration);
            self.state_timer.start();
        }

        /// Force immediate transition (ignoring minimum duration)
        pub fn forceTransition(self: *Self, new_state: StateType, reason: TransitionReason) void {
            self.transitionTo(new_state, reason, 0.0);
        }

        /// Check if minimum time in state has elapsed
        pub fn canTransition(self: *const Self) bool {
            return self.state_timer.isFinished();
        }

        /// Update state timer
        pub fn update(self: *Self, delta_time: f32) void {
            self.state_timer.update(delta_time);
        }

        /// Check if we recently transitioned from a specific state
        pub fn wasInState(self: *const Self, state: StateType, within_transitions: usize) bool {
            const check_count = @min(within_transitions, self.history_count);
            var i: usize = 0;
            while (i < check_count) : (i += 1) {
                const history_index = self.history_count - 1 - i;
                if (self.transition_history[history_index].from == state) {
                    return true;
                }
            }
            return false;
        }

        /// Get transition count for a specific state pair
        pub fn getTransitionCount(self: *const Self, from: StateType, to: StateType) usize {
            var count: usize = 0;
            for (0..self.history_count) |i| {
                const transition = self.transition_history[i];
                if (transition.from == from and transition.to == to) {
                    count += 1;
                }
            }
            return count;
        }

        /// Clear transition history
        pub fn clearHistory(self: *Self) void {
            self.history_count = 0;
        }
    };
}

/// Behavior priority system for state machine decisions
pub const BehaviorPriority = enum(u8) {
    critical = 255,
    high = 192,
    normal = 128,
    low = 64,
    lowest = 32,
    disabled = 0,

    pub fn fromInt(value: u8) BehaviorPriority {
        return @enumFromInt(value);
    }

    pub fn toInt(self: BehaviorPriority) u8 {
        return @intFromEnum(self);
    }

    pub fn higherThan(self: BehaviorPriority, other: BehaviorPriority) bool {
        return self.toInt() > other.toInt();
    }
};

/// Interrupt/resume pattern for state machines
pub fn InterruptibleStateMachine(comptime StateType: type, comptime max_states: usize) type {
    return struct {
        const Self = @This();
        const BaseStateMachine = StateMachine(StateType, max_states);

        state_machine: BaseStateMachine,
        interrupt_stack: [8]InterruptContext,
        interrupt_count: usize,

        pub const InterruptContext = struct {
            state: StateType,
            remaining_time: f32,
            priority: BehaviorPriority,
            can_be_interrupted: bool,
        };

        pub fn init(initial_state: StateType) Self {
            return .{
                .state_machine = BaseStateMachine.init(initial_state),
                .interrupt_stack = undefined,
                .interrupt_count = 0,
            };
        }

        /// Push current state and transition to interrupt state
        pub fn interrupt(
            self: *Self,
            interrupt_state: StateType,
            priority: BehaviorPriority,
            can_be_interrupted: bool,
        ) bool {
            if (self.interrupt_count >= 8) return false; // Stack full

            // Check if current state can be interrupted
            if (self.interrupt_count > 0) {
                const top_context = &self.interrupt_stack[self.interrupt_count - 1];
                if (!top_context.can_be_interrupted and
                    !priority.higherThan(top_context.priority))
                {
                    return false; // Cannot interrupt
                }
            }

            // Push current state to interrupt stack
            self.interrupt_stack[self.interrupt_count] = InterruptContext{
                .state = self.state_machine.current_state,
                .remaining_time = self.state_machine.state_timer.getRemaining(),
                .priority = priority,
                .can_be_interrupted = can_be_interrupted,
            };
            self.interrupt_count += 1;

            // Transition to interrupt state
            self.state_machine.forceTransition(interrupt_state, .interrupt);
            return true;
        }

        /// Resume previous state from interrupt stack
        pub fn resumeFromInterrupt(self: *Self) bool {
            if (self.interrupt_count == 0) return false; // No state to resume

            self.interrupt_count -= 1;
            const resume_context = self.interrupt_stack[self.interrupt_count];

            // Restore previous state
            self.state_machine.transitionTo(
                resume_context.state,
                .interrupt,
                resume_context.remaining_time,
            );

            return true;
        }

        /// Get current interrupt priority
        pub fn getCurrentPriority(self: *const Self) BehaviorPriority {
            if (self.interrupt_count == 0) return .normal;
            return self.interrupt_stack[self.interrupt_count - 1].priority;
        }

        /// Forward state machine methods
        pub fn getCurrentState(self: *const Self) StateType {
            return self.state_machine.getCurrentState();
        }

        pub fn transitionTo(
            self: *Self,
            new_state: StateType,
            reason: BaseStateMachine.TransitionReason,
            min_duration: f32,
        ) void {
            self.state_machine.transitionTo(new_state, reason, min_duration);
        }

        pub fn update(self: *Self, delta_time: f32) void {
            self.state_machine.update(delta_time);
        }

        pub fn canTransition(self: *const Self) bool {
            return self.state_machine.canTransition();
        }
    };
}

/// Utility patterns for common state machine behaviors
pub const StatePatterns = struct {
    /// Timeout transition pattern
    pub fn timeoutTransition(
        state_machine: anytype,
        timeout_state: anytype,
        timeout_duration: f32,
        delta_time: f32,
    ) bool {
        _ = delta_time; // TODO: Use for more complex timing logic if needed
        if (state_machine.getTimeInState() >= timeout_duration) {
            state_machine.transitionTo(timeout_state, .timeout, 0.0);
            return true;
        }
        return false;
    }

    /// Cooldown pattern for preventing rapid state changes
    pub fn cooldownTransition(
        state_machine: anytype,
        new_state: anytype,
        cooldown_timer: *timer.Cooldown,
        reason: anytype,
    ) bool {
        if (cooldown_timer.isReady()) {
            state_machine.forceTransition(new_state, reason);
            cooldown_timer.start();
            return true;
        }
        return false;
    }

    /// Probability-based state transition
    pub fn probabilityTransition(
        state_machine: anytype,
        new_state: anytype,
        probability: f32,
        random: std.Random,
        reason: anytype,
    ) bool {
        if (random.float(f32) < probability) {
            state_machine.forceTransition(new_state, reason);
            return true;
        }
        return false;
    }
};

test "StateMachine basic functionality" {
    const TestState = enum { idle, moving, attacking, fleeing };
    var sm = StateMachine(TestState, 10).init(.idle);

    // Initial state
    try std.testing.expectEqual(TestState.idle, sm.getCurrentState());
    try std.testing.expect(sm.canTransition());

    // Transition to moving
    sm.transitionTo(.moving, .manual, 1.0);
    try std.testing.expectEqual(TestState.moving, sm.getCurrentState());
    try std.testing.expectEqual(TestState.idle, sm.getPreviousState());
    try std.testing.expect(!sm.canTransition()); // Still in minimum duration

    // Update timer
    sm.update(1.5);
    try std.testing.expect(sm.canTransition());

    // Check transition history
    try std.testing.expect(sm.wasInState(.idle, 1));
    try std.testing.expectEqual(@as(usize, 1), sm.getTransitionCount(.idle, .moving));
}

test "InterruptibleStateMachine functionality" {
    const TestState = enum { idle, patrolling, chasing, stunned };
    var ism = InterruptibleStateMachine(TestState, 10).init(.idle);

    // Start in idle, transition to patrolling
    ism.transitionTo(.patrolling, .manual, 2.0);
    try std.testing.expectEqual(TestState.patrolling, ism.getCurrentState());

    // Interrupt with chasing
    try std.testing.expect(ism.interrupt(.chasing, .high, true));
    try std.testing.expectEqual(TestState.chasing, ism.getCurrentState());

    // Try to interrupt chasing with stun (higher priority)
    try std.testing.expect(ism.interrupt(.stunned, .critical, false));
    try std.testing.expectEqual(TestState.stunned, ism.getCurrentState());

    // Resume from stun (should go back to chasing)
    try std.testing.expect(ism.resumeFromInterrupt());
    try std.testing.expectEqual(TestState.chasing, ism.getCurrentState());

    // Resume from chasing (should go back to patrolling)
    try std.testing.expect(ism.resumeFromInterrupt());
    try std.testing.expectEqual(TestState.patrolling, ism.getCurrentState());
}
