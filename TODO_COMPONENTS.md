# TODO: Runtime Composable Component System

**Status:** Architecture design and implementation plan  
**Priority:** High - foundational UI system enhancement  
**Created:** 2025-01-22  
**Target:** Enable dynamic behavior composition for UI components  

## Executive Summary

### Problem Statement

Current component architecture has significant composability limitations:
- **Monolithic components**: Behaviors hardcoded into component types
- **Poor reusability**: Must create new component types for each behavior combination  
- **Static composition**: No runtime attachment/detachment of behaviors
- **Code duplication**: Similar behaviors reimplemented across component types

### Proposed Solution

Implement a **Runtime Composable Component System** that allows:
- Dynamic attachment/detachment of behaviors at runtime
- Clean separation of rendering logic and interactive behaviors  
- Reusable behavior library (click, hover, tooltip, animation, etc.)
- Gradual migration from existing VTable-based architecture
- Performance equal to or better than current system

### Success Criteria

- [ ] Dynamic behavior attachment without component type changes
- [ ] Zero-allocation attachment for common cases (≤4 behaviors)
- [ ] Performance within 5% of current VTable system
- [ ] Clean migration path for existing components
- [ ] Comprehensive behavior library with 10+ common behaviors
- [ ] Full reactive system integration

## Architecture Overview

### Core Design Principles

1. **Hybrid Storage**: Inline storage for common cases, dynamic for exceptional cases
2. **Hook-Based Lifecycle**: Clear execution points with predictable ordering
3. **Event Chain**: Chain of responsibility with optional event consumption
4. **Type Safety**: Compile-time checks where possible, runtime flexibility where needed
5. **Migration Friendly**: Works alongside existing VTable system

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    ComposableComponent                     │
├─────────────────────────────────────────────────────────────┤
│  Core Component (existing)     │  Attachment System (new)   │
│  ┌─────────────────────────┐   │  ┌─────────────────────────┐ │
│  │ ComponentProps (reactive)│   │  │ InlineAttachments[4]    │ │
│  │ VTable (render/update)   │   │  │ OverflowAttachments[]   │ │
│  │ Children hierarchy       │   │  │ AttachmentManager       │ │
│  └─────────────────────────┘   │  └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                 Attachment Lifecycle                       │
├─────────────────────────────────────────────────────────────┤
│ onMount → onPreUpdate → onUpdate → onPostUpdate → onRender │
│    ▲                                                    │   │
│    └────── onEvent ◄─── onPreRender ◄──────────────────┘   │
│                    ▼                                        │
│              onPostRender → onUnmount                       │
└─────────────────────────────────────────────────────────────┘
```

## Key Design Choices

### 1. Attachment Storage Strategy

#### Primary Choice: Hybrid Storage
```zig
pub const AttachmentStorage = struct {
    // Fast path: inline storage for common cases
    inline_count: u8 = 0,
    inline_attachments: [4]Attachment = undefined,
    
    // Overflow: dynamic storage for exceptional cases  
    overflow: ?std.ArrayList(Attachment) = null,
    
    pub fn attach(self: *AttachmentStorage, attachment: Attachment) !void {
        if (self.inline_count < 4) {
            self.inline_attachments[self.inline_count] = attachment;
            self.inline_count += 1;
        } else {
            if (self.overflow == null) {
                self.overflow = std.ArrayList(Attachment).init(allocator);
            }
            try self.overflow.?.append(attachment);
        }
    }
};
```

**Rationale:**
- 95% of components need ≤4 behaviors (click, hover, tooltip, animation)
- Zero allocations for common case
- Scales to unlimited behaviors when needed
- Cache-friendly for hot paths

#### Alternative A: Pure ArrayList
```zig
pub const AttachmentStorage = struct {
    attachments: std.ArrayList(Attachment),
};
```
**Pros:** Simple, unlimited size  
**Cons:** Always heap-allocated, pointer indirection  

#### Alternative B: Fixed-Size Array
```zig
pub const AttachmentStorage = struct {
    count: u8 = 0,
    attachments: [8]Attachment = undefined,
};
```
**Pros:** Fastest, no allocations  
**Cons:** Hard limit, wastes space for simple components  

### 2. Attachment Execution Model

#### Primary Choice: Hook-Based Lifecycle
```zig
pub const AttachmentHooks = struct {
    onMount: ?*const fn(attachment: *anyopaque, component: *ComposableComponent) void = null,
    onUnmount: ?*const fn(attachment: *anyopaque, component: *ComposableComponent) void = null,
    onPreUpdate: ?*const fn(attachment: *anyopaque, component: *ComposableComponent, dt: f32) void = null,
    onPostUpdate: ?*const fn(attachment: *anyopaque, component: *ComposableComponent, dt: f32) void = null,
    onPreRender: ?*const fn(attachment: *anyopaque, component: *ComposableComponent, renderer: anytype) void = null,
    onPostRender: ?*const fn(attachment: *anyopaque, component: *ComposableComponent, renderer: anytype) void = null,
    onEvent: ?*const fn(attachment: *anyopaque, component: *ComposableComponent, event: anytype) bool = null,
};
```

**Execution Order:**
1. **Mount**: Component creation → attachment mounting
2. **Update**: Pre-update hooks → component update → post-update hooks
3. **Render**: Pre-render hooks → component render → post-render hooks  
4. **Event**: Event hooks (can consume) → component event handling
5. **Unmount**: Component cleanup → attachment cleanup

**Rationale:**
- Clear, predictable execution order
- Familiar from React/Vue hook systems
- Each hook serves specific purpose
- Optional hooks minimize overhead

#### Alternative A: Event-Driven Pub/Sub
```zig
pub const AttachmentEventBus = struct {
    subscribers: std.HashMap(EventType, std.ArrayList(*const fn(event: anytype) void)),
    
    pub fn subscribe(self: *AttachmentEventBus, event_type: EventType, handler: anytype) void;
    pub fn publish(self: *AttachmentEventBus, event: anytype) void;
};
```
**Pros:** Flexible, decoupled  
**Cons:** Harder to reason about, performance overhead  

#### Alternative B: Aspect-Oriented Programming
```zig
pub const AttachmentAspect = struct {
    before: ?*const fn(attachment: *anyopaque, context: anytype) void = null,
    after: ?*const fn(attachment: *anyopaque, context: anytype) void = null,
    around: ?*const fn(attachment: *anyopaque, context: anytype, next: anytype) void = null,
};
```
**Pros:** Maximum flexibility  
**Cons:** Complex execution model, hard to optimize  

### 3. Event Handling Architecture

#### Primary Choice: Chain of Responsibility with Consumption
```zig
pub fn handleEvent(self: *ComposableComponent, event: anytype) bool {
    // 1. Attachment event handlers (can consume)
    for (self.attachment_storage.getAll()) |attachment| {
        if (attachment.hooks.onEvent) |handler| {
            if (handler(attachment.data, self, event)) {
                return true; // Event consumed
            }
        }
    }
    
    // 2. Component's own event handling (if not consumed)
    return self.base_component.vtable.handle_event(self.base_component, event);
}
```

**Event Flow:**
1. Attachments handle event in registration order
2. Any attachment can consume event (return true)
3. If not consumed, component handles event
4. Return whether event was handled

**Rationale:**
- Simple to understand and debug
- Attachments can optionally consume events
- Preserves existing component event handling
- Clear execution order

#### Alternative A: Priority-Based Dispatch
```zig
pub const PriorityAttachment = struct {
    attachment: Attachment,
    priority: i32, // Higher = earlier execution
};
```
**Pros:** Fine-grained control over execution order  
**Cons:** Complex priority management, harder to reason about  

#### Alternative B: Type-Based Routing
```zig
pub const EventRouter = struct {
    click_handlers: std.ArrayList(*const fn(ClickEvent) bool),
    key_handlers: std.ArrayList(*const fn(KeyEvent) bool),
    hover_handlers: std.ArrayList(*const fn(HoverEvent) bool),
};
```
**Pros:** Type safety, performance  
**Cons:** Less flexible, must know all event types upfront  

### 4. Performance Optimizations

#### Primary Choice: Type-Erased Attachments with Inline VTable
```zig
pub const Attachment = struct {
    // Type-erased data pointer
    data: *anyopaque,
    
    // Inline function pointers (no vtable indirection)
    hooks: AttachmentHooks,
    
    // Cleanup function
    cleanup: *const fn(data: *anyopaque, allocator: std.mem.Allocator) void,
    
    // Optional: attachment metadata
    type_name: []const u8, // For debugging
    size: usize, // For memory tracking
};
```

**Performance Benefits:**
- No heap allocation for attachment vtables
- Direct function calls (no vtable indirection)
- Compact memory layout
- Cache-friendly iteration

**Rationale:**
- Balance between flexibility and performance
- Type erasure allows any data type
- Inline hooks avoid indirection overhead
- Metadata aids debugging and profiling

#### Alternative A: Generic Attachments with Comptime Dispatch
```zig
pub fn TypedAttachment(comptime T: type) type {
    return struct {
        data: T,
        hooks: TypedAttachmentHooks(T),
    };
}
```
**Pros:** Maximum performance, type safety  
**Cons:** Compile-time known types only, complex storage  

#### Alternative B: Tagged Union for Common Types
```zig
pub const AttachmentData = union(enum) {
    click_handler: ClickHandler,
    tooltip: TooltipData,
    animation: AnimationData,
    custom: *anyopaque,
};
```
**Pros:** Fast dispatch for common types  
**Cons:** Limited extensibility, large union size  

### 5. Integration Strategy

#### Primary Choice: Wrapper Approach - ComposableComponent
```zig
pub const ComposableComponent = struct {
    base_component: *Component, // Existing component
    attachment_storage: AttachmentStorage,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, base: *Component) ComposableComponent {
        return .{
            .base_component = base,
            .attachment_storage = AttachmentStorage.init(),
            .allocator = allocator,
        };
    }
    
    pub fn attach(self: *ComposableComponent, comptime T: type, data: T, hooks: AttachmentHooks) !void {
        const attachment_data = try self.allocator.create(T);
        attachment_data.* = data;
        
        try self.attachment_storage.attach(Attachment{
            .data = @as(*anyopaque, @ptrCast(attachment_data)),
            .hooks = hooks,
            .cleanup = createCleanupFn(T),
            .type_name = @typeName(T),
            .size = @sizeOf(T),
        });
    }
};
```

**Migration Benefits:**
- Existing components work unchanged
- Gradual adoption possible
- No breaking changes
- Easy A/B testing

**Rationale:**
- Non-breaking migration path
- Preserves existing architecture investment
- Allows performance comparison
- Risk mitigation

#### Alternative A: Mixin Approach - Add Fields to Existing Components
```zig
pub const ComponentWithAttachments = struct {
    base: Component,
    attachment_storage: AttachmentStorage,
    
    // All existing Component methods plus attachment methods
};
```
**Pros:** Single component type, better performance  
**Cons:** Breaking changes, complex migration  

#### Alternative B: Complete Replacement - New Component Base Class
```zig
pub const ComposableComponentBase = struct {
    props: ComponentProps,
    attachment_storage: AttachmentStorage,
    vtable: ComponentVTable,
    
    // Completely new component system
};
```
**Pros:** Clean slate, optimal design  
**Cons:** Complete rewrite required, high risk  

## Implementation Plan

### Phase 1: Core Infrastructure (Week 1-2)

#### Milestone 1.1: Attachment Storage
- [ ] Implement `AttachmentStorage` with hybrid inline/overflow strategy
- [ ] Create `Attachment` struct with type-erased data and inline hooks
- [ ] Add attachment lifecycle management (add/remove/iterate)
- [ ] Write comprehensive tests for storage edge cases

#### Milestone 1.2: ComposableComponent Wrapper
- [ ] Create `ComposableComponent` wrapper for existing components
- [ ] Implement lifecycle forwarding (update/render/event → attachments → base)
- [ ] Add attachment API (`attach`, `detach`, `hasAttachment`)
- [ ] Integration tests with existing component types

#### Milestone 1.3: Basic Behavior Library
- [ ] `ClickBehavior`: Handle click events with bounds checking
- [ ] `TooltipBehavior`: Show/hide tooltips on hover with delay
- [ ] `HoverBehavior`: Track hover state and trigger style changes
- [ ] `DebugBehavior`: Visual debugging aids (bounds, event visualization)

### Phase 2: Advanced Behaviors (Week 3-4)

#### Milestone 2.1: Animation System Integration
- [ ] `SpringAnimationBehavior`: Smooth position/size transitions
- [ ] `FadeAnimationBehavior`: Opacity transitions for show/hide
- [ ] `ColorAnimationBehavior`: Color interpolation for theme changes
- [ ] Integration with existing animation systems

#### Milestone 2.2: Input and Focus Management
- [ ] `KeyboardBehavior`: Handle keyboard shortcuts and navigation
- [ ] `FocusBehavior`: Visual focus indicators and focus management
- [ ] `DragBehavior`: Drag and drop with visual feedback
- [ ] `ResizeBehavior`: Interactive resize handles

#### Milestone 2.3: Layout and Styling
- [ ] `LayoutBehavior`: Responsive layout adjustments
- [ ] `ThemeBehavior`: Dynamic theming and style switching
- [ ] `AccessibilityBehavior`: ARIA labels and keyboard navigation
- [ ] `PerformanceBehavior`: Render optimization and batching

### Phase 3: Performance and Polish (Week 5-6)

#### Milestone 3.1: Performance Optimization
- [ ] Benchmark attachment system vs VTable system
- [ ] Optimize hot paths (inline storage, function calls)
- [ ] Memory usage profiling and optimization
- [ ] Cache efficiency analysis and improvements

#### Milestone 3.2: Developer Experience
- [ ] Attachment debugging tools and inspector
- [ ] Error handling and validation
- [ ] Documentation and usage examples
- [ ] Migration guide for existing components

#### Milestone 3.3: Production Integration
- [ ] Migrate 2-3 existing components to demonstrate pattern
- [ ] A/B testing framework for performance comparison
- [ ] Gradual rollout strategy
- [ ] Performance monitoring and alerting

### Phase 4: Advanced Features (Week 7-8)

#### Milestone 4.1: Dynamic Composition
- [ ] Runtime attachment modification (enable/disable/reconfigure)
- [ ] Attachment dependency system (attachment A requires B)
- [ ] Conditional attachments (attach based on component state)
- [ ] Attachment templates and presets

#### Milestone 4.2: Integration Features
- [ ] Reactive attachment properties (attachments can use signals)
- [ ] Cross-component communication through attachments
- [ ] Global attachment registry and sharing
- [ ] Attachment serialization for state persistence

## Detailed API Reference

### Core Types

```zig
/// Hybrid storage for attachments with inline optimization
pub const AttachmentStorage = struct {
    inline_count: u8 = 0,
    inline_attachments: [4]Attachment = undefined,
    overflow: ?std.ArrayList(Attachment) = null,
    
    pub fn attach(self: *AttachmentStorage, attachment: Attachment) !void;
    pub fn detach(self: *AttachmentStorage, attachment_id: AttachmentId) bool;
    pub fn getAll(self: *const AttachmentStorage) Iterator;
    pub fn count(self: *const AttachmentStorage) usize;
    pub fn deinit(self: *AttachmentStorage, allocator: std.mem.Allocator) void;
};

/// Type-erased attachment with inline hooks for performance
pub const Attachment = struct {
    id: AttachmentId, // Unique identifier for detachment
    data: *anyopaque, // Type-erased attachment data
    hooks: AttachmentHooks, // Lifecycle hooks
    cleanup: *const fn(data: *anyopaque, allocator: std.mem.Allocator) void,
    
    // Metadata for debugging and introspection
    type_name: []const u8,
    size: usize,
    created_at: u64, // Timestamp for debugging
};

/// Attachment lifecycle hooks
pub const AttachmentHooks = struct {
    onMount: ?*const fn(attachment: *anyopaque, component: *ComposableComponent) void = null,
    onUnmount: ?*const fn(attachment: *anyopaque, component: *ComposableComponent) void = null,
    onPreUpdate: ?*const fn(attachment: *anyopaque, component: *ComposableComponent, dt: f32) void = null,
    onPostUpdate: ?*const fn(attachment: *anyopaque, component: *ComposableComponent, dt: f32) void = null,
    onPreRender: ?*const fn(attachment: *anyopaque, component: *ComposableComponent, renderer: anytype) void = null,
    onPostRender: ?*const fn(attachment: *anyopaque, component: *ComposableComponent, renderer: anytype) void = null,
    onEvent: ?*const fn(attachment: *anyopaque, component: *ComposableComponent, event: anytype) bool = null,
};

/// Main composable component wrapper
pub const ComposableComponent = struct {
    base_component: *Component,
    attachment_storage: AttachmentStorage,
    allocator: std.mem.Allocator,
    next_attachment_id: AttachmentId = 1,
    
    pub fn init(allocator: std.mem.Allocator, base: *Component) ComposableComponent;
    pub fn deinit(self: *ComposableComponent) void;
    
    // Attachment management
    pub fn attach(self: *ComposableComponent, comptime T: type, data: T, hooks: AttachmentHooks) !AttachmentId;
    pub fn detach(self: *ComposableComponent, attachment_id: AttachmentId) bool;
    pub fn hasAttachment(self: *const ComposableComponent, comptime T: type) bool;
    pub fn getAttachment(self: *ComposableComponent, comptime T: type) ?*T;
    
    // Component interface forwarding
    pub fn update(self: *ComposableComponent, dt: f32) void;
    pub fn render(self: *const ComposableComponent, renderer: anytype) !void;
    pub fn handleEvent(self: *ComposableComponent, event: anytype) bool;
};
```

### Behavior Library

```zig
/// Click handling with bounds checking and multi-click support
pub const ClickBehavior = struct {
    handler: *const fn() void,
    double_click_handler: ?*const fn() void = null,
    right_click_handler: ?*const fn() void = null,
    double_click_time_ms: u32 = 300,
    
    // Internal state
    last_click_time: u64 = 0,
    click_count: u32 = 0,
    
    pub const hooks = AttachmentHooks{
        .onEvent = onEvent,
    };
    
    fn onEvent(attachment: *anyopaque, component: *ComposableComponent, event: anytype) bool;
};

/// Tooltip with customizable positioning and delay
pub const TooltipBehavior = struct {
    text: []const u8,
    show_delay_ms: u32 = 500,
    hide_delay_ms: u32 = 100,
    position: TooltipPosition = .auto,
    style: TooltipStyle = .default,
    
    // Internal state
    hover_start_time: ?u64 = null,
    is_showing: bool = false,
    
    pub const hooks = AttachmentHooks{
        .onMount = onMount,
        .onUnmount = onUnmount,
        .onEvent = onEvent,
        .onPostRender = onPostRender,
    };
    
    fn onMount(attachment: *anyopaque, component: *ComposableComponent) void;
    fn onUnmount(attachment: *anyopaque, component: *ComposableComponent) void;
    fn onEvent(attachment: *anyopaque, component: *ComposableComponent, event: anytype) bool;
    fn onPostRender(attachment: *anyopaque, component: *ComposableComponent, renderer: anytype) void;
};

/// Spring-based animation for smooth transitions
pub const SpringAnimationBehavior = struct {
    property: AnimatedProperty, // position, size, color, etc.
    spring_config: SpringConfig,
    target_value: f32,
    
    // Animation state
    current_value: f32,
    velocity: f32 = 0.0,
    is_animating: bool = false,
    
    pub const hooks = AttachmentHooks{
        .onMount = onMount,
        .onPreUpdate = onPreUpdate,
    };
    
    fn onMount(attachment: *anyopaque, component: *ComposableComponent) void;
    fn onPreUpdate(attachment: *anyopaque, component: *ComposableComponent, dt: f32) void;
    
    pub fn setTarget(self: *SpringAnimationBehavior, target: f32) void;
    pub fn isAnimating(self: *const SpringAnimationBehavior) bool;
};

/// Debug visualization for development
pub const DebugBehavior = struct {
    show_bounds: bool = true,
    show_events: bool = false,
    show_attachment_count: bool = false,
    bounds_color: Color = .red,
    event_duration_ms: u32 = 200,
    
    // Debug state
    recent_events: [8]DebugEvent = undefined,
    event_count: u8 = 0,
    
    pub const hooks = AttachmentHooks{
        .onEvent = onEvent,
        .onPostRender = onPostRender,
    };
    
    fn onEvent(attachment: *anyopaque, component: *ComposableComponent, event: anytype) bool;
    fn onPostRender(attachment: *anyopaque, component: *ComposableComponent, renderer: anytype) void;
};
```

### Usage Examples

```zig
// Example 1: Basic button with click and tooltip
fn createEnhancedButton() !*ComposableComponent {
    // Create base button component
    var base_button = try Button.create(allocator, .{
        .text = "Submit",
        .position = .{ .x = 100, .y = 50 },
        .size = .{ .x = 120, .y = 40 },
    });
    
    // Wrap in composable component
    var composable = try allocator.create(ComposableComponent);
    composable.* = ComposableComponent.init(allocator, base_button);
    
    // Attach behaviors
    _ = try composable.attach(ClickBehavior, .{
        .handler = submitForm,
    }, ClickBehavior.hooks);
    
    _ = try composable.attach(TooltipBehavior, .{
        .text = "Submit the form",
        .show_delay_ms = 300,
    }, TooltipBehavior.hooks);
    
    _ = try composable.attach(SpringAnimationBehavior, .{
        .property = .scale,
        .spring_config = .{ .stiffness = 200, .damping = 20 },
        .target_value = 1.0,
    }, SpringAnimationBehavior.hooks);
    
    return composable;
}

// Example 2: Text input with keyboard shortcuts and validation
fn createSmartTextInput() !*ComposableComponent {
    var base_input = try TextInput.create(allocator, .{
        .placeholder = "Enter text...",
        .position = .{ .x = 50, .y = 100 },
        .size = .{ .x = 200, .y = 30 },
    });
    
    var composable = try allocator.create(ComposableComponent);
    composable.* = ComposableComponent.init(allocator, base_input);
    
    // Multiple keyboard shortcuts
    _ = try composable.attach(KeyboardBehavior, .{
        .key = KEY_ENTER,
        .modifiers = .{},
        .handler = submitInput,
    }, KeyboardBehavior.hooks);
    
    _ = try composable.attach(KeyboardBehavior, .{
        .key = KEY_ESCAPE,
        .modifiers = .{},
        .handler = clearInput,
    }, KeyboardBehavior.hooks);
    
    // Focus management
    _ = try composable.attach(FocusBehavior, .{
        .focus_color = .blue,
        .focus_width = 2.0,
    }, FocusBehavior.hooks);
    
    // Live validation
    _ = try composable.attach(ValidationBehavior, .{
        .validator = validateEmail,
        .error_color = .red,
        .success_color = .green,
    }, ValidationBehavior.hooks);
    
    return composable;
}

// Example 3: Runtime behavior modification
fn demonstrateRuntimeModification() !void {
    var button = try createEnhancedButton();
    defer button.deinit();
    
    // Component works normally
    try button.render(&renderer);
    _ = button.handleEvent(.{ .click = .{ .position = .{ .x = 110, .y = 60 } } });
    
    // Dynamically add debug behavior
    const debug_id = try button.attach(DebugBehavior, .{
        .show_bounds = true,
        .show_events = true,
    }, DebugBehavior.hooks);
    
    // Use for debugging...
    try button.render(&renderer); // Now shows debug info
    
    // Remove debug behavior
    _ = button.detach(debug_id);
    
    // Back to normal
    try button.render(&renderer); // No debug info
}
```

## Performance Analysis

### Benchmarking Plan

#### Memory Usage
- [ ] Baseline: Current VTable component memory footprint
- [ ] Target: ≤20% increase for common cases (≤4 attachments)
- [ ] Measure: Peak memory, allocation patterns, fragmentation

#### CPU Performance
- [ ] Baseline: Component update/render cycles per second
- [ ] Target: ≥95% of baseline performance
- [ ] Measure: Hot path profiling, instruction cache misses

#### Scalability
- [ ] Test: 1, 10, 100, 1000 components with varying attachment counts
- [ ] Measure: Linear scaling, performance degradation points
- [ ] Optimize: Batch operations, cache locality

### Expected Performance Characteristics

```
Attachment Count | Memory Overhead | CPU Overhead | Notes
0               | 32 bytes        | 0%           | Empty inline storage
1-4             | 32 bytes        | <2%          | Inline storage, no allocation
5-8             | 96 bytes        | <5%          | One allocation for overflow
9+              | 96+ bytes       | <10%         | Dynamic growth
```

### Optimization Strategies

#### Memory Optimizations
- **Inline storage**: Zero allocations for ≤4 attachments
- **Type erasure**: No vtable allocations per attachment
- **Packed data**: Minimize padding and alignment waste
- **Lazy cleanup**: Defer expensive cleanup to idle time

#### CPU Optimizations
- **Direct function calls**: No vtable indirection for hooks
- **Branch prediction**: Optimize hook existence checks
- **Cache locality**: Keep related data together
- **SIMD potential**: Batch operations where possible

## Migration Guide

### Gradual Migration Strategy

#### Phase 1: Opt-in Wrapper (Weeks 1-2)
```zig
// Existing code continues to work unchanged
var button = try Button.create(allocator, button_props);

// New composable wrapper for enhanced functionality
var composable = ComposableComponent.init(allocator, button);
_ = try composable.attach(ClickBehavior, click_data, ClickBehavior.hooks);
```

#### Phase 2: Factory Pattern (Weeks 3-4)
```zig
// Introduce factory functions that return composable components
pub fn createButton(allocator: std.mem.Allocator, props: ButtonProps) !*ComposableComponent {
    var base = try Button.create(allocator, props);
    var composable = try allocator.create(ComposableComponent);
    composable.* = ComposableComponent.init(allocator, base);
    return composable;
}

// Optionally attach common behaviors by default
pub fn createClickableButton(allocator: std.mem.Allocator, props: ButtonProps, click_handler: *const fn() void) !*ComposableComponent {
    var button = try createButton(allocator, props);
    _ = try button.attach(ClickBehavior, .{ .handler = click_handler }, ClickBehavior.hooks);
    return button;
}
```

#### Phase 3: Component Library Update (Weeks 5-6)
```zig
// Update existing component creation to return composable by default
pub const Button = struct {
    pub fn create(allocator: std.mem.Allocator, props: ButtonProps) !*ComposableComponent {
        // Create base button
        var base = try createBaseButton(allocator, props);
        
        // Wrap in composable
        var composable = try allocator.create(ComposableComponent);
        composable.* = ComposableComponent.init(allocator, base);
        
        // Attach default behaviors based on props
        if (props.on_click) |handler| {
            _ = try composable.attach(ClickBehavior, .{ .handler = handler }, ClickBehavior.hooks);
        }
        
        return composable;
    }
};
```

### Migration Checklist for Existing Components

#### For Each Component Type:
- [ ] **Audit current behaviors**: List all interactive behaviors (click, hover, etc.)
- [ ] **Extract behavior logic**: Move behavior code to attachment implementations
- [ ] **Create wrapper factory**: Function that creates composable version
- [ ] **Update component interface**: Maintain API compatibility
- [ ] **Add attachment APIs**: Allow runtime behavior modification
- [ ] **Performance testing**: Verify no regression
- [ ] **Documentation update**: Show new usage patterns

#### Breaking Changes to Avoid:
- [ ] Existing component creation APIs still work
- [ ] Component method signatures unchanged
- [ ] Event handling behavior preserved
- [ ] Memory layout changes internal only
- [ ] Performance characteristics maintained

## Open Questions and Decisions

### 1. Attachment Ordering and Dependencies

**Question**: How should we handle attachment execution order and dependencies?

**Options:**
- **A**: Registration order (simple, predictable)
- **B**: Priority-based (flexible, complex)
- **C**: Dependency graph (powerful, complicated)

**Recommendation**: Start with A (registration order), add B (priority) if needed

### 2. Event Bubbling and Capture

**Question**: Should we support event capture (parent → child) in addition to bubbling?

**Options:**
- **A**: Bubbling only (simple, covers most cases)
- **B**: Capture and bubbling (complex, flexible)
- **C**: Configurable per attachment (very flexible, very complex)

**Recommendation**: Start with A, evaluate need for B based on usage

### 3. Reactive Integration

**Question**: How deeply should attachments integrate with the reactive system?

**Options:**
- **A**: Attachments are observers only (simple, one-way)
- **B**: Attachments can create signals (complex, two-way)
- **C**: Attachments are reactive components themselves (very complex, very powerful)

**Recommendation**: Start with A, explore B for specific use cases

### 4. Attachment Lifecycle Management

**Question**: Who is responsible for attachment cleanup?

**Options:**
- **A**: Component auto-cleanup on deinit (safe, limited control)
- **B**: Manual cleanup required (flexible, error-prone)
- **C**: Reference counting (automatic, complex)

**Recommendation**: A with optional manual cleanup for advanced cases

### 5. Type Safety vs Flexibility

**Question**: How much type safety should we enforce at compile time?

**Options:**
- **A**: Full type erasure (maximum flexibility, runtime errors)
- **B**: Typed attachment registry (balanced, some compile-time checking)
- **C**: Fully typed attachments (maximum safety, reduced flexibility)

**Recommendation**: A with optional B for common attachment types

## Success Metrics and Timeline

### Key Performance Indicators

#### Technical Metrics
- [ ] **Performance**: ≥95% of current VTable system performance
- [ ] **Memory**: ≤20% memory overhead for common cases
- [ ] **Reliability**: Zero crashes related to attachment system
- [ ] **Compatibility**: 100% backwards compatibility with existing components

#### Developer Experience Metrics
- [ ] **Migration effort**: ≤2 hours per existing component
- [ ] **Learning curve**: Productive usage within 1 day for new developers
- [ ] **Code reduction**: ≥30% reduction in behavior-related code duplication
- [ ] **Flexibility**: ≥90% of current use cases covered with standard behaviors

#### Adoption Metrics
- [ ] **Component coverage**: ≥50% of UI components using attachment system
- [ ] **Behavior library**: ≥20 standard behaviors available
- [ ] **Developer satisfaction**: ≥8/10 rating in developer surveys
- [ ] **Performance wins**: ≥3 measurable performance improvements

### Timeline Summary

| Phase | Duration | Key Deliverables | Success Criteria |
|-------|----------|------------------|------------------|
| 1     | 2 weeks  | Core infrastructure | Basic attachment system working |
| 2     | 2 weeks  | Behavior library | 10+ behaviors implemented |
| 3     | 2 weeks  | Performance optimization | ≥95% performance maintained |
| 4     | 2 weeks  | Advanced features | Full feature set complete |

### Risk Mitigation

#### High-Risk Items
1. **Performance regression**: Continuous benchmarking, optimization sprints
2. **Complexity explosion**: Regular architecture reviews, simplification passes
3. **Migration difficulty**: Comprehensive tooling, documentation, examples
4. **Adoption resistance**: Champion early wins, gather feedback, iterate

#### Contingency Plans
- **Performance issues**: Fall back to opt-in model, optimize hot paths
- **Design flaws**: Rapid iteration cycles, willingness to redesign core elements
- **Migration problems**: Extended parallel support, automated migration tools
- **Low adoption**: Better documentation, training sessions, success showcases

---

**Next Steps:**
1. Review and approve architecture decisions
2. Create proof-of-concept implementation
3. Performance benchmark against current system
4. Begin Phase 1 development
5. Establish regular review and feedback cycles