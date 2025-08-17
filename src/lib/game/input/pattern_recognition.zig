const std = @import("std");
const timer = @import("../../core/timer.zig");

/// Input pattern recognition for complex input sequences
/// Supports combos, gestures, and timing-based input patterns

/// Input event types
pub const InputEvent = struct {
    event_type: EventType,
    timestamp: f32,
    position: ?@Vector(2, f32) = null, // For mouse/touch events
    
    pub const EventType = enum {
        key_down,
        key_up,
        mouse_down,
        mouse_up,
        mouse_move,
        mouse_wheel,
        // Add more as needed by games
    };
};

/// Pattern matching configuration
pub const PatternConfig = struct {
    max_time_between_inputs: f32 = 1.0, // Maximum time between inputs in a sequence
    min_input_duration: f32 = 0.05,     // Minimum time to hold an input
    max_input_duration: f32 = 2.0,      // Maximum time to hold an input
    position_tolerance: f32 = 10.0,     // Pixel tolerance for position matching
    require_exact_order: bool = true,    // Whether inputs must be in exact order
};

/// Pattern recognition result
pub const PatternMatch = struct {
    pattern_id: u32,
    confidence: f32,        // 0.0 to 1.0
    duration: f32,          // Total time taken for pattern
    start_timestamp: f32,
    end_timestamp: f32,
};

/// Input pattern recognizer
pub fn PatternRecognizer(comptime max_events: usize, comptime max_patterns: usize) type {
    return struct {
        const Self = @This();
        
        events: [max_events]InputEvent,
        event_count: usize,
        patterns: [max_patterns]InputPattern,
        pattern_count: usize,
        config: PatternConfig,
        current_time: f32,
        
        pub const InputPattern = struct {
            id: u32,
            name: []const u8,
            events: []const InputEvent.EventType,
            timing_constraints: []const TimingConstraint,
            position_constraints: []const PositionConstraint,
            
            pub const TimingConstraint = struct {
                event_index: usize,
                min_time_from_start: f32,
                max_time_from_start: f32,
            };
            
            pub const PositionConstraint = struct {
                event_index: usize,
                relative_to: usize, // Index of event to compare position to
                min_distance: f32,
                max_distance: f32,
            };
        };
        
        pub fn init(config: PatternConfig) Self {
            return .{
                .events = undefined,
                .event_count = 0,
                .patterns = undefined,
                .pattern_count = 0,
                .config = config,
                .current_time = 0.0,
            };
        }
        
        /// Register a new input pattern
        pub fn registerPattern(self: *Self, pattern: InputPattern) bool {
            if (self.pattern_count >= max_patterns) return false;
            
            self.patterns[self.pattern_count] = pattern;
            self.pattern_count += 1;
            return true;
        }
        
        /// Add an input event
        pub fn addEvent(self: *Self, event_type: InputEvent.EventType, position: ?@Vector(2, f32)) void {
            // Remove old events that are too old
            self.cleanOldEvents();
            
            if (self.event_count >= max_events) {
                // Shift events to make room
                for (1..max_events) |i| {
                    self.events[i - 1] = self.events[i];
                }
                self.event_count = max_events - 1;
            }
            
            // Add new event
            self.events[self.event_count] = InputEvent{
                .event_type = event_type,
                .timestamp = self.current_time,
                .position = position,
            };
            self.event_count += 1;
        }
        
        /// Update timing and check for pattern matches
        pub fn update(self: *Self, delta_time: f32) std.ArrayList(PatternMatch) {
            self.current_time += delta_time;
            
            var matches = std.ArrayList(PatternMatch).init(std.heap.page_allocator);
            
            // Check each registered pattern
            for (0..self.pattern_count) |pattern_idx| {
                if (self.checkPattern(pattern_idx)) |match| {
                    matches.append(match) catch continue;
                }
            }
            
            return matches;
        }
        
        /// Check if a specific pattern matches current events
        fn checkPattern(self: *const Self, pattern_idx: usize) ?PatternMatch {
            if (pattern_idx >= self.pattern_count) return null;
            
            const pattern = &self.patterns[pattern_idx];
            if (pattern.events.len == 0) return null;
            
            // Find the most recent sequence that could match this pattern
            var match_start: usize = 0;
            var confidence: f32 = 0.0;
            
            // Search backwards through events for potential matches
            var event_idx: i32 = @intCast(self.event_count - 1);
            while (event_idx >= 0) : (event_idx -= 1) {
                const start_idx: usize = @intCast(event_idx);
                
                if (self.tryMatchFromPosition(pattern, start_idx)) |match_confidence| {
                    if (match_confidence > confidence) {
                        confidence = match_confidence;
                        match_start = start_idx;
                    }
                }
                
                // If we found a perfect match, stop looking
                if (confidence >= 1.0) break;
            }
            
            // Return match if confidence is high enough
            if (confidence > 0.7) {
                const start_event = self.events[match_start];
                const end_event = self.events[self.event_count - 1];
                
                return PatternMatch{
                    .pattern_id = pattern.id,
                    .confidence = confidence,
                    .duration = end_event.timestamp - start_event.timestamp,
                    .start_timestamp = start_event.timestamp,
                    .end_timestamp = end_event.timestamp,
                };
            }
            
            return null;
        }
        
        /// Try to match pattern starting from a specific event position
        fn tryMatchFromPosition(self: *const Self, pattern: *const InputPattern, start_idx: usize) ?f32 {
            if (start_idx + pattern.events.len > self.event_count) return null;
            
            var matches: usize = 0;
            var timing_score: f32 = 1.0;
            var position_score: f32 = 1.0;
            
            // Check event type matches
            for (pattern.events, 0..) |expected_type, i| {
                const event_idx = start_idx + i;
                if (event_idx >= self.event_count) break;
                
                if (self.events[event_idx].event_type == expected_type) {
                    matches += 1;
                } else {
                    // Partial match penalty
                    timing_score *= 0.8;
                }
            }
            
            // Check timing constraints
            for (pattern.timing_constraints) |constraint| {
                const event_idx = start_idx + constraint.event_index;
                if (event_idx >= self.event_count) continue;
                
                const start_time = self.events[start_idx].timestamp;
                const event_time = self.events[event_idx].timestamp;
                const time_from_start = event_time - start_time;
                
                if (time_from_start < constraint.min_time_from_start or 
                   time_from_start > constraint.max_time_from_start) {
                    timing_score *= 0.5;
                }
            }
            
            // Check position constraints
            for (pattern.position_constraints) |constraint| {
                const event_idx = start_idx + constraint.event_index;
                const ref_idx = start_idx + constraint.relative_to;
                
                if (event_idx >= self.event_count or ref_idx >= self.event_count) continue;
                
                const event_pos = self.events[event_idx].position;
                const ref_pos = self.events[ref_idx].position;
                
                if (event_pos != null and ref_pos != null) {
                    const distance = @sqrt(
                        (event_pos.?[0] - ref_pos.?[0]) * (event_pos.?[0] - ref_pos.?[0]) +
                        (event_pos.?[1] - ref_pos.?[1]) * (event_pos.?[1] - ref_pos.?[1])
                    );
                    
                    if (distance < constraint.min_distance or distance > constraint.max_distance) {
                        position_score *= 0.5;
                    }
                }
            }
            
            // Calculate overall confidence
            const type_match_ratio = @as(f32, @floatFromInt(matches)) / @as(f32, @floatFromInt(pattern.events.len));
            const overall_confidence = type_match_ratio * timing_score * position_score;
            
            return overall_confidence;
        }
        
        /// Remove events that are too old to be part of any pattern
        fn cleanOldEvents(self: *Self) void {
            const cutoff_time = self.current_time - self.config.max_time_between_inputs;
            var write_idx: usize = 0;
            
            for (0..self.event_count) |i| {
                if (self.events[i].timestamp >= cutoff_time) {
                    if (write_idx != i) {
                        self.events[write_idx] = self.events[i];
                    }
                    write_idx += 1;
                }
            }
            
            self.event_count = write_idx;
        }
        
        /// Clear all events
        pub fn clearEvents(self: *Self) void {
            self.event_count = 0;
        }
        
        /// Get recent events for debugging
        pub fn getRecentEvents(self: *const Self, buffer: []InputEvent) usize {
            const copy_count = @min(buffer.len, self.event_count);
            for (0..copy_count) |i| {
                buffer[i] = self.events[self.event_count - copy_count + i];
            }
            return copy_count;
        }
    };
}

/// Common input patterns
pub const CommonPatterns = struct {
    /// Double-tap pattern
    pub fn doubleTap(allocator: std.mem.Allocator, event_type: InputEvent.EventType) !PatternRecognizer(32, 8).InputPattern {
        var events = try allocator.alloc(InputEvent.EventType, 2);
        events[0] = event_type;
        events[1] = event_type;
        
        var timing = try allocator.alloc(PatternRecognizer(32, 8).InputPattern.TimingConstraint, 1);
        timing[0] = .{
            .event_index = 1,
            .min_time_from_start = 0.05,
            .max_time_from_start = 0.3,
        };
        
        return .{
            .id = 1,
            .name = "double_tap",
            .events = events,
            .timing_constraints = timing,
            .position_constraints = &[_]PatternRecognizer(32, 8).InputPattern.PositionConstraint{},
        };
    }
    
    /// Hold pattern
    pub fn holdPattern(allocator: std.mem.Allocator, event_type: InputEvent.EventType, hold_time: f32) !PatternRecognizer(32, 8).InputPattern {
        var events = try allocator.alloc(InputEvent.EventType, 1);
        events[0] = event_type;
        
        var timing = try allocator.alloc(PatternRecognizer(32, 8).InputPattern.TimingConstraint, 1);
        timing[0] = .{
            .event_index = 0,
            .min_time_from_start = hold_time,
            .max_time_from_start = hold_time + 1.0,
        };
        
        return .{
            .id = 2,
            .name = "hold",
            .events = events,
            .timing_constraints = timing,
            .position_constraints = &[_]PatternRecognizer(32, 8).InputPattern.PositionConstraint{},
        };
    }
};

/// Action queue for buffering inputs
pub fn ActionQueue(comptime ActionType: type, comptime max_actions: usize) type {
    return struct {
        const Self = @This();
        
        actions: [max_actions]QueuedAction,
        count: usize,
        
        pub const QueuedAction = struct {
            action: ActionType,
            timestamp: f32,
            priority: u8,
            expires_at: f32,
        };
        
        pub fn init() Self {
            return .{
                .actions = undefined,
                .count = 0,
            };
        }
        
        /// Queue an action with expiration time
        pub fn queueAction(
            self: *Self,
            action: ActionType,
            current_time: f32,
            priority: u8,
            expiration_time: f32,
        ) bool {
            if (self.count >= max_actions) {
                // Try to replace lower priority action
                for (0..self.count) |i| {
                    if (self.actions[i].priority < priority) {
                        self.actions[i] = QueuedAction{
                            .action = action,
                            .timestamp = current_time,
                            .priority = priority,
                            .expires_at = current_time + expiration_time,
                        };
                        return true;
                    }
                }
                return false; // Queue full, couldn't replace
            }
            
            self.actions[self.count] = QueuedAction{
                .action = action,
                .timestamp = current_time,
                .priority = priority,
                .expires_at = current_time + expiration_time,
            };
            self.count += 1;
            return true;
        }
        
        /// Get next action to execute
        pub fn getNextAction(self: *Self, current_time: f32) ?ActionType {
            if (self.count == 0) return null;
            
            // Remove expired actions
            self.removeExpired(current_time);
            if (self.count == 0) return null;
            
            // Find highest priority action
            var best_idx: usize = 0;
            var best_priority: u8 = self.actions[0].priority;
            
            for (1..self.count) |i| {
                if (self.actions[i].priority > best_priority) {
                    best_priority = self.actions[i].priority;
                    best_idx = i;
                }
            }
            
            const action = self.actions[best_idx].action;
            
            // Remove the action from queue
            for (best_idx..self.count - 1) |i| {
                self.actions[i] = self.actions[i + 1];
            }
            self.count -= 1;
            
            return action;
        }
        
        /// Remove expired actions
        fn removeExpired(self: *Self, current_time: f32) void {
            var write_idx: usize = 0;
            
            for (0..self.count) |i| {
                if (self.actions[i].expires_at > current_time) {
                    if (write_idx != i) {
                        self.actions[write_idx] = self.actions[i];
                    }
                    write_idx += 1;
                }
            }
            
            self.count = write_idx;
        }
        
        /// Clear all actions
        pub fn clear(self: *Self) void {
            self.count = 0;
        }
        
        /// Check if queue is empty
        pub fn isEmpty(self: *const Self) bool {
            return self.count == 0;
        }
    };
}