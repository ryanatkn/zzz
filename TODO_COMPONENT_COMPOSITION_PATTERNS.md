# TODO: Component Composition Patterns for Zig UI System

**Status:** Architecture exploration
**Priority:** High - fundamental design decision needed
**Created:** 2025-01-22
**Goal:** Design a composable, performant, Zig-idiomatic component system inspired by modern UI patterns

## Context

We need a component architecture that:
1. Supports functional composition and prop spreading (like Svelte 5's attachments)
2. Maintains peak performance (zero-cost abstractions where possible)
3. Works within Zig 0.15's constraints (no `usingnamespace`)
4. Enables clean separation of concerns
5. Allows both compile-time and runtime composition

## Current State Analysis

### Existing Patterns in Codebase
- **VTable-based polymorphism:** Runtime dispatch with function pointers
- **Embedded structs:** Composition through nesting
- **Reactive signals:** Push-pull reactivity system
- **Simple structs:** Direct data with methods

### Problems to Solve
- Runtime overhead from vtables in hot paths
- Poor composability - can't spread props with behaviors
- No clean way to attach behaviors to components
- Mixing of concerns (rendering, behavior, state in one place)

## Architecture Patterns

### Pattern A: Comptime Type-Tagged Attachments (Svelte 5-Inspired)

Use comptime types as "symbols" for attachments that can be spread with props.

```zig
// Attachment keys using comptime types as symbols
pub fn AttachmentKey(comptime T: type) type {
    return struct {
        pub const ValueType = T;
        pub const id = @typeName(@This());
    };
}

// Props with attachment storage
pub const Props = struct {
    // Core properties
    position: Vec2,
    size: Vec2,
    visible: bool = true,
    
    // Attachments as tuple of (Key, Value) pairs
    attachments: anytype = .{},
    
    pub fn attach(self: Props, comptime Key: type, value: Key.ValueType) Props {
        return .{
            .position = self.position,
            .size = self.size,
            .visible = self.visible,
            .attachments = self.attachments ++ .{.{ Key, value }},
        };
    }
    
    pub fn getAttachment(self: Props, comptime Key: type) ?Key.ValueType {
        inline for (self.attachments) |pair| {
            if (pair[0] == Key) return pair[1];
        }
        return null;
    }
};

// Define behavior attachments
pub const OnClick = AttachmentKey(*const fn() void);
pub const Tooltip = AttachmentKey([]const u8);
pub const SpringAnimation = AttachmentKey(SpringConfig);

// Usage - functional composition
const button = Button.init(
    props
        .attach(OnClick, handleClick)
        .attach(Tooltip, "Submit form")
        .attach(SpringAnimation, .{ .stiffness = 200 })
);
```

**Pros:**
- Zero runtime cost for comptime-known attachments
- Natural functional composition
- Props spread with behaviors intact
- Type-safe attachment system

**Cons:**
- Complex type signatures with anytype
- Compile time overhead for attachment resolution
- Learning curve for developers

**Performance:** ⭐⭐⭐⭐⭐ (comptime) / ⭐⭐⭐⭐ (runtime)

### Pattern B: Zero-Bit Field Mixins (Zig 0.15 Compatible)

Since `usingnamespace` is removed, use zero-bit fields with `@fieldParentPtr` for composition.

```zig
// Mixin behaviors as zero-bit fields
pub fn ClickableMixin(comptime Parent: type) type {
    return struct {
        pub fn onClick(self: *@This()) void {
            const parent: *Parent = @alignCast(@fieldParentPtr("clickable", self));
            if (parent.on_click_handler) |handler| {
                handler();
            }
        }
    };
}

pub fn TooltipMixin(comptime Parent: type) type {
    return struct {
        pub fn showTooltip(self: *@This()) void {
            const parent: *Parent = @alignCast(@fieldParentPtr("tooltip", self));
            // Show tooltip with parent.tooltip_text
        }
    };
}

// Component with mixins
pub const Button = struct {
    // Core data
    position: Vec2,
    size: Vec2,
    text: []const u8,
    
    // Mixin state
    on_click_handler: ?*const fn() void = null,
    tooltip_text: []const u8 = "",
    
    // Zero-bit mixin fields
    clickable: ClickableMixin(Button) = .{},
    tooltip: TooltipMixin(Button) = .{},
    
    pub fn handleEvent(self: *Button, event: Event) void {
        switch (event) {
            .click => self.clickable.onClick(),
            .hover => self.tooltip.showTooltip(),
            else => {},
        }
    }
};
```

**Pros:**
- Works within Zig 0.15 constraints
- Clear namespacing of behaviors
- Zero memory overhead for mixins
- Explicit behavior composition

**Cons:**
- More verbose than old `usingnamespace`
- Requires careful pointer alignment
- Fixed at compile time

**Performance:** ⭐⭐⭐⭐⭐

### Pattern C: Capability Protocols with Comptime Interfaces

Define capabilities as comptime protocols that components can implement.

```zig
// Define capability protocols
pub const Renderable = struct {
    pub fn implements(comptime T: type) bool {
        return @hasDecl(T, "render") and 
               @hasField(T, "bounds");
    }
};

pub const Interactive = struct {
    pub fn implements(comptime T: type) bool {
        return @hasDecl(T, "handleEvent") and
               @hasField(T, "enabled");
    }
};

pub const Composable = struct {
    pub fn implements(comptime T: type) bool {
        return @hasDecl(T, "getProps") and
               @hasDecl(T, "withProps");
    }
};

// Component factory with capability checking
pub fn Component(comptime Data: type, comptime capabilities: []const type) type {
    return struct {
        data: Data,
        
        pub fn init(data: Data) @This() {
            // Compile-time verification
            inline for (capabilities) |cap| {
                comptime {
                    if (!cap.implements(Data)) {
                        @compileError("Missing capability: " ++ @typeName(cap));
                    }
                }
            }
            return .{ .data = data };
        }
        
        // Forward capability methods
        pub fn render(self: *const @This(), renderer: anytype) !void {
            if (comptime Renderable.implements(Data)) {
                return self.data.render(renderer);
            }
        }
    };
}

// Usage
const InteractiveButton = Component(ButtonData, &.{ Renderable, Interactive, Composable });
```

**Pros:**
- Clear capability contracts
- Compile-time verification
- Flexible protocol composition
- Good error messages

**Cons:**
- More boilerplate
- Indirect method calls
- Need to define all protocols upfront

**Performance:** ⭐⭐⭐⭐

### Pattern D: Entity-Attachment-System (EAS)

Separate entities, attachments, and systems for maximum flexibility.

```zig
// Entities are just IDs
pub const Entity = u32;

// Attachments are data bags
pub const AttachmentStorage = struct {
    positions: std.AutoHashMap(Entity, Vec2),
    sizes: std.AutoHashMap(Entity, Vec2),
    texts: std.AutoHashMap(Entity, []const u8),
    click_handlers: std.AutoHashMap(Entity, *const fn() void),
    animations: std.AutoHashMap(Entity, Animation),
    
    pub fn attach(self: *AttachmentStorage, entity: Entity, comptime T: type, value: T) !void {
        const map = self.getMap(T);
        try map.put(entity, value);
    }
    
    pub fn get(self: *AttachmentStorage, entity: Entity, comptime T: type) ?T {
        const map = self.getMap(T);
        return map.get(entity);
    }
};

// Systems operate on entities with specific attachments
pub const RenderSystem = struct {
    pub fn process(storage: *AttachmentStorage, entities: []Entity, renderer: anytype) !void {
        for (entities) |entity| {
            if (storage.get(entity, Vec2)) |pos| {
                if (storage.get(entity, []const u8)) |text| {
                    try renderer.drawText(text, pos);
                }
            }
        }
    }
};

// Usage - maximum flexibility
var storage = AttachmentStorage.init(allocator);
const button = storage.createEntity();
try storage.attach(button, Vec2, .{ .x = 100, .y = 50 });
try storage.attach(button, []const u8, "Click me");
try storage.attach(button, *const fn() void, handleClick);
```

**Pros:**
- Maximum runtime flexibility
- Easy to add/remove behaviors
- Cache-friendly for batch operations
- Similar to ECS patterns

**Cons:**
- Runtime overhead for lookups
- Less type safety
- More complex mental model
- Memory fragmentation

**Performance:** ⭐⭐⭐

### Pattern E: Hybrid Static/Dynamic Attachments

Combine compile-time and runtime approaches for different use cases.

```zig
// Static attachments for core UI (compile-time)
pub fn StaticComponent(comptime attachments: anytype) type {
    return struct {
        props: CoreProps,
        
        pub fn render(self: *const @This(), renderer: anytype) !void {
            // All attachments inlined at compile time
            inline for (attachments) |attachment| {
                if (@hasDecl(attachment, "beforeRender")) {
                    attachment.beforeRender(&self);
                }
            }
            
            // Core rendering
            try renderer.drawRect(self.props.bounds);
            
            inline for (attachments) |attachment| {
                if (@hasDecl(attachment, "afterRender")) {
                    attachment.afterRender(&self);
                }
            }
        }
    };
}

// Dynamic attachments for extensions (runtime)
pub const DynamicComponent = struct {
    props: CoreProps,
    attachments: std.ArrayList(Attachment),
    
    const Attachment = struct {
        beforeRender: ?*const fn(*DynamicComponent) void = null,
        afterRender: ?*const fn(*DynamicComponent) void = null,
        handleEvent: ?*const fn(*DynamicComponent, Event) bool = null,
    };
    
    pub fn attach(self: *DynamicComponent, attachment: Attachment) !void {
        try self.attachments.append(attachment);
    }
};

// Usage - choose based on requirements
const CoreButton = StaticComponent(.{ ClickHandler, Tooltip }); // Fast path
const ExtensionWidget = DynamicComponent.init(allocator);      // Flexible path
```

**Pros:**
- Best of both worlds
- Core UI stays fast
- Extensions remain flexible
- Clear performance tradeoffs

**Cons:**
- Two mental models
- Code duplication
- Migration complexity

**Performance:** ⭐⭐⭐⭐⭐ (static) / ⭐⭐⭐ (dynamic)

### Pattern F: Functional Composition with Closures

Pure functional approach using closures for behavior composition.

```zig
// Components are functions that return render functions
pub const Component = fn(Props) RenderFn;
pub const RenderFn = fn(renderer: anytype) anyerror!void;

// Higher-order components for composition
pub fn withClick(comptime handler: fn() void) fn(Component) Component {
    return struct {
        fn wrap(inner: Component) Component {
            return struct {
                fn component(props: Props) RenderFn {
                    const innerRender = inner(props);
                    return struct {
                        fn render(renderer: anytype) !void {
                            // Add click region
                            try renderer.addClickRegion(props.bounds, handler);
                            // Render inner component
                            try innerRender(renderer);
                        }
                    }.render;
                }
            }.component;
        }
    }.wrap;
}

// Usage - functional composition
const Button = withClick(handleClick)(
    withTooltip("Submit")(
        withAnimation(spring)(
            BaseButton
        )
    )
);

const button = Button(props);
try button(renderer);
```

**Pros:**
- Pure functional composition
- Highly composable
- No mutable state
- Clear data flow

**Cons:**
- Heavy use of closures
- Potential memory overhead
- Less familiar to systems programmers
- Harder to optimize

**Performance:** ⭐⭐⭐

## Recommendation Matrix

| Pattern | Performance | Composability | Simplicity | Flexibility | Zig-Idiomatic |
|---------|------------|---------------|------------|-------------|---------------|
| A: Type-Tagged Attachments | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| B: Zero-Bit Mixins | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| C: Capability Protocols | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| D: Entity-Attachment | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| E: Hybrid Static/Dynamic | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| F: Functional Closures | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |

## Implementation Considerations

### Memory Layout
- Keep hot data contiguous for cache efficiency
- Use SOA (Structure of Arrays) for batch processing
- Minimize pointer chasing

### Compile-Time vs Runtime
- Use comptime for known UI structure (menus, HUD)
- Use runtime for dynamic content (game entities)
- Profile to find the right balance

### Integration with Reactive System
- Attachments should work with signals/effects
- Consider attachment lifecycle (mount/unmount)
- Handle cleanup properly

## Proposed Path Forward

### Phase 1: Proof of Concept
1. Implement Pattern A (Type-Tagged Attachments) for a simple component
2. Benchmark against current vtable approach
3. Test composability with complex UI scenarios

### Phase 2: Core Implementation
4. If performance is acceptable, refactor core components
5. Create attachment library with common behaviors
6. Document patterns and best practices

### Phase 3: Advanced Features
7. Add reactive attachments for dynamic behavior
8. Implement transition/animation attachments
9. Create debugging tools for attachment inspection

## Success Criteria

- [ ] Performance equal or better than current vtable system
- [ ] Natural prop spreading with behaviors preserved
- [ ] Works within Zig 0.15 constraints
- [ ] Clear separation of rendering and behavior
- [ ] Easy to understand and use
- [ ] Supports both static and dynamic composition
- [ ] Integrates cleanly with reactive system

## Open Questions

1. How do we handle attachment ordering/priority?
2. Should attachments be able to communicate?
3. How do we type-check spread props at compile time?
4. What's the migration path from current architecture?
5. How do we handle attachment conflicts?

## References

- Svelte 5 Attachments: Functional composition with effects
- React Hooks: Composable behaviors with rules
- Vue Composition API: Setup function pattern
- Solid.js Directives: Use-based composition
- Entity Component Systems: Data-oriented design

---

**Next Steps:** 
1. Review and discuss patterns with team
2. Build proof of concept for top candidates
3. Benchmark and profile performance
4. Make architectural decision
5. Plan migration strategy