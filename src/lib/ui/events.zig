const std = @import("std");
const math = @import("../math/mod.zig");
const c = @import("../platform/sdl.zig");

const Vec2 = math.Vec2;

/// Common UI event types
pub const UIEvent = union(enum) {
    /// Mouse events
    MouseDown: MouseButtonEvent,
    MouseUp: MouseButtonEvent,
    MouseMove: MouseMoveEvent,
    MouseEnter: MousePositionEvent,
    MouseLeave: MousePositionEvent,
    
    /// Keyboard events
    KeyDown: KeyEvent,
    KeyUp: KeyEvent,
    TextInput: TextInputEvent,
    
    /// Focus events
    FocusGained: FocusEvent,
    FocusLost: FocusEvent,
    
    /// Window events
    WindowResize: WindowResizeEvent,
    
    /// Custom events
    Custom: CustomEvent,
};

/// Mouse button event data
pub const MouseButtonEvent = struct {
    position: Vec2,
    button: MouseButton,
    clicks: u8 = 1,
    modifiers: EventModifiers = EventModifiers{},
};

/// Mouse movement event data
pub const MouseMoveEvent = struct {
    position: Vec2,
    delta: Vec2,
    modifiers: EventModifiers = EventModifiers{},
};

/// Mouse position event data (for enter/leave)
pub const MousePositionEvent = struct {
    position: Vec2,
};

/// Keyboard event data
pub const KeyEvent = struct {
    scancode: u32,
    keycode: u32,
    modifiers: EventModifiers = EventModifiers{},
    repeat: bool = false,
};

/// Text input event data
pub const TextInputEvent = struct {
    text: []const u8,
};

/// Focus event data
pub const FocusEvent = struct {
    component_id: ?u32 = null,
};

/// Window resize event data
pub const WindowResizeEvent = struct {
    new_size: Vec2,
};

/// Custom event data
pub const CustomEvent = struct {
    event_type: []const u8,
    data: ?*anyopaque = null,
};

/// Mouse button enumeration
pub const MouseButton = enum(u8) {
    Left = 1,
    Middle = 2,
    Right = 3,
    X1 = 4,
    X2 = 5,
    
    /// Convert from SDL mouse button
    pub fn fromSDL(sdl_button: u8) MouseButton {
        return switch (sdl_button) {
            c.sdl.SDL_BUTTON_LEFT => .Left,
            c.sdl.SDL_BUTTON_MIDDLE => .Middle,
            c.sdl.SDL_BUTTON_RIGHT => .Right,
            c.sdl.SDL_BUTTON_X1 => .X1,
            c.sdl.SDL_BUTTON_X2 => .X2,
            else => .Left, // Default fallback
        };
    }
};

/// Event modifier keys
pub const EventModifiers = packed struct {
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
    super: bool = false, // Windows key / Cmd key
    
    pub fn none() EventModifiers {
        return .{};
    }
    
    pub fn fromSDL(sdl_mod: u16) EventModifiers {
        return EventModifiers{
            .ctrl = (sdl_mod & c.sdl.SDL_KMOD_CTRL) != 0,
            .shift = (sdl_mod & c.sdl.SDL_KMOD_SHIFT) != 0,
            .alt = (sdl_mod & c.sdl.SDL_KMOD_ALT) != 0,
            .super = (sdl_mod & c.sdl.SDL_KMOD_GUI) != 0,
        };
    }
};

/// Event handling result
pub const EventResult = enum {
    Handled,      // Event was handled, stop propagation
    NotHandled,   // Event was not handled, continue propagation
    Consumed,     // Event was consumed but allow bubbling for side effects
};

/// Event propagation phase
pub const EventPhase = enum {
    Capture,   // Top-down phase (parent to child)
    Target,    // At the target component
    Bubble,    // Bottom-up phase (child to parent)
};

/// Event handler function signature
pub const EventHandler = fn (event: UIEvent) EventResult;

/// Event listener with phase control
pub const EventListener = struct {
    handler: *const EventHandler,
    phase: EventPhase = .Target,
    once: bool = false,
    enabled: bool = true,
};

/// Convert SDL event to UI event
pub fn fromSDLEvent(sdl_event: c.sdl.SDL_Event, mouse_pos: Vec2) ?UIEvent {
    return switch (sdl_event.type) {
        c.sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => UIEvent{
            .MouseDown = MouseButtonEvent{
                .position = Vec2{ .x = sdl_event.button.x, .y = sdl_event.button.y },
                .button = MouseButton.fromSDL(sdl_event.button.button),
                .clicks = sdl_event.button.clicks,
                .modifiers = EventModifiers.fromSDL(sdl_event.button.mod),
            },
        },
        c.sdl.SDL_EVENT_MOUSE_BUTTON_UP => UIEvent{
            .MouseUp = MouseButtonEvent{
                .position = Vec2{ .x = sdl_event.button.x, .y = sdl_event.button.y },
                .button = MouseButton.fromSDL(sdl_event.button.button),
                .clicks = sdl_event.button.clicks,
                .modifiers = EventModifiers.fromSDL(sdl_event.button.mod),
            },
        },
        c.sdl.SDL_EVENT_MOUSE_MOTION => UIEvent{
            .MouseMove = MouseMoveEvent{
                .position = Vec2{ .x = sdl_event.motion.x, .y = sdl_event.motion.y },
                .delta = Vec2{ .x = sdl_event.motion.xrel, .y = sdl_event.motion.yrel },
                .modifiers = EventModifiers.fromSDL(sdl_event.motion.mod),
            },
        },
        c.sdl.SDL_EVENT_KEY_DOWN => UIEvent{
            .KeyDown = KeyEvent{
                .scancode = sdl_event.key.scancode,
                .keycode = sdl_event.key.key,
                .modifiers = EventModifiers.fromSDL(sdl_event.key.mod),
                .repeat = sdl_event.key.repeat != 0,
            },
        },
        c.sdl.SDL_EVENT_KEY_UP => UIEvent{
            .KeyUp = KeyEvent{
                .scancode = sdl_event.key.scancode,
                .keycode = sdl_event.key.key,
                .modifiers = EventModifiers.fromSDL(sdl_event.key.mod),
                .repeat = false,
            },
        },
        c.sdl.SDL_EVENT_TEXT_INPUT => UIEvent{
            .TextInput = TextInputEvent{
                .text = std.mem.span(@as([*:0]const u8, @ptrCast(&sdl_event.text.text))),
            },
        },
        else => null,
    };
}

/// Hit testing for UI components
pub const HitTest = struct {
    /// Check if point is inside rectangle
    pub fn pointInRect(point: Vec2, rect: math.Rectangle) bool {
        return point.x >= rect.x and point.x <= rect.x + rect.width and
               point.y >= rect.y and point.y <= rect.y + rect.height;
    }
    
    /// Check if point is inside circle
    pub fn pointInCircle(point: Vec2, center: Vec2, radius: f32) bool {
        const dx = point.x - center.x;
        const dy = point.y - center.y;
        return (dx * dx + dy * dy) <= (radius * radius);
    }
};

/// Event dispatcher for managing event propagation
pub const EventDispatcher = struct {
    /// Dispatch event through component hierarchy
    pub fn dispatchEvent(
        event: UIEvent,
        target_component: anytype,
        parent_components: []const *anytype,
    ) EventResult {
        // Capture phase: parent to child
        for (parent_components) |parent| {
            if (parent.handleEvent) |handler| {
                const result = handler(event, .Capture);
                if (result == .Handled) return .Handled;
            }
        }
        
        // Target phase
        if (target_component.handleEvent) |handler| {
            const result = handler(event, .Target);
            if (result == .Handled) return .Handled;
        }
        
        // Bubble phase: child to parent
        var i = parent_components.len;
        while (i > 0) {
            i -= 1;
            const parent = parent_components[i];
            if (parent.handleEvent) |handler| {
                const result = handler(event, .Bubble);
                if (result == .Handled) return .Handled;
            }
        }
        
        return .NotHandled;
    }
};

/// Focus management for UI components
pub const FocusManager = struct {
    current_focus: ?u32 = null,
    focus_chain: std.ArrayList(u32),
    
    pub fn init(allocator: std.mem.Allocator) FocusManager {
        return FocusManager{
            .focus_chain = std.ArrayList(u32).init(allocator),
        };
    }
    
    pub fn deinit(self: *FocusManager) void {
        self.focus_chain.deinit();
    }
    
    /// Set focus to a component
    pub fn setFocus(self: *FocusManager, component_id: u32) !UIEvent {
        const old_focus = self.current_focus;
        self.current_focus = component_id;
        
        // Add to focus chain if not already present
        for (self.focus_chain.items) |id| {
            if (id == component_id) break;
        } else {
            try self.focus_chain.append(component_id);
        }
        
        if (old_focus) |old_id| {
            if (old_id != component_id) {
                return UIEvent{ .FocusLost = FocusEvent{ .component_id = old_id } };
            }
        }
        
        return UIEvent{ .FocusGained = FocusEvent{ .component_id = component_id } };
    }
    
    /// Move focus to next component in chain
    pub fn focusNext(self: *FocusManager) ?UIEvent {
        if (self.focus_chain.items.len == 0) return null;
        
        if (self.current_focus) |current| {
            for (self.focus_chain.items, 0..) |id, i| {
                if (id == current) {
                    const next_index = (i + 1) % self.focus_chain.items.len;
                    const next_id = self.focus_chain.items[next_index];
                    self.current_focus = next_id;
                    return UIEvent{ .FocusGained = FocusEvent{ .component_id = next_id } };
                }
            }
        }
        
        // Focus first component if no current focus
        const first_id = self.focus_chain.items[0];
        self.current_focus = first_id;
        return UIEvent{ .FocusGained = FocusEvent{ .component_id = first_id } };
    }
    
    /// Remove component from focus management
    pub fn removeFocus(self: *FocusManager, component_id: u32) void {
        if (self.current_focus == component_id) {
            self.current_focus = null;
        }
        
        for (self.focus_chain.items, 0..) |id, i| {
            if (id == component_id) {
                _ = self.focus_chain.swapRemove(i);
                break;
            }
        }
    }
};