const std = @import("std");

/// Common types and interfaces for the reactive system
/// Provides consistent type definitions and reusable patterns
/// Maintains Svelte 5 semantics and conventions

/// Function callback types for consistency across modules
/// These match Svelte 5's function signature patterns
pub const CallbackTypes = struct {
    /// Basic effect function (Svelte 5 $effect)
    pub const EffectFn = *const fn () void;
    
    /// Cleanup function for effects and components
    pub const CleanupFn = *const fn () void;
    
    /// Update function for signals (transforms current value)
    pub fn UpdateFn(comptime T: type) type {
        return *const fn (T) T;
    }
    
    /// Batch function for grouping updates
    pub const BatchFn = *const fn () void;
    
    /// Derive function for computed values (Svelte 5 $derived)
    pub fn DeriveFn(comptime T: type) type {
        return *const fn () T;
    }
    
    /// Watch callback for signal changes
    pub fn WatchFn(comptime T: type) type {
        return *const fn (T) void;
    }
    
    /// Validation function for signals
    pub fn ValidatorFn(comptime T: type) type {
        return *const fn (T) bool;
    }
    
    /// Transform function for mapping values
    pub fn TransformFn(comptime T: type, comptime U: type) type {
        return *const fn (T) U;
    }
};

/// VTable pattern for type-erased reactive objects
/// Provides a reusable pattern for polymorphic reactive components
pub fn VTable(comptime Interface: type) type {
    return struct {
        const Self = @This();
        
        /// Initialize the object
        init_fn: *const fn (*anyopaque, std.mem.Allocator) anyerror!void,
        
        /// Cleanup the object
        deinit_fn: *const fn (*anyopaque) void,
        
        /// Type-specific interface methods
        interface: Interface,
        
        pub fn init(self: *const Self, ptr: *anyopaque, allocator: std.mem.Allocator) !void {
            try self.init_fn(ptr, allocator);
        }
        
        pub fn deinit(self: *const Self, ptr: *anyopaque) void {
            self.deinit_fn(ptr);
        }
    };
}

/// Component VTable interface for reactive UI components
/// This provides the standard lifecycle methods for Svelte-like components
pub const ComponentInterface = struct {
    /// Called when component is mounted
    onMount: *const fn (*anyopaque) anyerror!void,
    
    /// Called when component is unmounted
    onUnmount: *const fn (*anyopaque) void,
    
    /// Called when component needs to re-render (reactive dependencies changed)
    onRender: *const fn (*anyopaque) anyerror!void,
    
    /// Called to check if component should render (optimization)
    shouldRender: ?*const fn (*anyopaque) bool = null,
    
    /// Called when component props or state changes
    onUpdate: ?*const fn (*anyopaque) anyerror!void = null,
    
    /// Called to get component's current render data
    getRenderData: ?*const fn (*anyopaque) ?*anyopaque = null,
};

/// Component VTable type using the interface
pub const ComponentVTable = VTable(ComponentInterface);

/// Reactive object lifecycle states
/// Matches Svelte 5 component lifecycle semantics
pub const LifecycleState = enum {
    created,    // Object created but not initialized
    mounting,   // In the process of mounting
    mounted,    // Fully mounted and active
    updating,   // Processing updates
    unmounting, // In the process of unmounting
    destroyed,  // Fully cleaned up
    
    pub fn canMount(self: @This()) bool {
        return self == .created;
    }
    
    pub fn canUpdate(self: @This()) bool {
        return self == .mounted;
    }
    
    pub fn canUnmount(self: @This()) bool {
        return self == .mounted or self == .updating;
    }
};

/// Generic reactive container for any type
/// Provides a unified interface for reactive values
pub fn ReactiveContainer(comptime T: type) type {
    return struct {
        const Self = @This();
        
        value: T,
        version: u64 = 0,
        lifecycle: LifecycleState = .created,
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator, initial_value: T) Self {
            return Self{
                .value = initial_value,
                .version = 0,
                .lifecycle = .created,
                .allocator = allocator,
            };
        }
        
        pub fn mount(self: *Self) void {
            if (self.lifecycle.canMount()) {
                self.lifecycle = .mounting;
                // Subclasses can override this
                self.lifecycle = .mounted;
            }
        }
        
        pub fn unmount(self: *Self) void {
            if (self.lifecycle.canUnmount()) {
                self.lifecycle = .unmounting;
                // Subclasses can override this
                self.lifecycle = .destroyed;
            }
        }
        
        pub fn getValue(self: *const Self) T {
            return self.value;
        }
        
        pub fn setValue(self: *Self, new_value: T) void {
            self.value = new_value;
            self.version +%= 1;
        }
        
        pub fn getVersion(self: *const Self) u64 {
            return self.version;
        }
        
        pub fn getLifecycleState(self: *const Self) LifecycleState {
            return self.lifecycle;
        }
    };
}

/// Error types for reactive system operations
pub const ReactiveError = error{
    /// No reactive context available for tracking
    NoReactiveContext,
    
    /// Object is in wrong lifecycle state for operation
    InvalidLifecycleState,
    
    /// Circular dependency detected
    CircularDependency,
    
    /// Observer already exists
    DuplicateObserver,
    
    /// Observer not found
    ObserverNotFound,
    
    /// Maximum dependency depth exceeded
    MaxDepthExceeded,
    
    /// Operation not supported in current state
    OperationNotSupported,
    
    /// Memory allocation failed
    OutOfMemory,
};

/// Result type for reactive operations
pub fn ReactiveResult(comptime T: type) type {
    return ReactiveError!T;
}

/// Metadata for reactive values
/// Provides debugging and optimization information
pub const ReactiveMetadata = struct {
    created_at: u64,
    last_updated: u64,
    update_count: u64 = 0,
    observer_count: u32 = 0,
    dependency_count: u32 = 0,
    name: ?[]const u8 = null, // For debugging
    
    pub fn init(name: ?[]const u8) @This() {
        const now = @as(u64, @intCast(std.time.milliTimestamp()));
        return @This(){
            .created_at = now,
            .last_updated = now,
            .update_count = 0,
            .observer_count = 0,
            .dependency_count = 0,
            .name = name,
        };
    }
    
    pub fn recordUpdate(self: *@This()) void {
        self.last_updated = @as(u64, @intCast(std.time.milliTimestamp()));
        self.update_count += 1;
    }
    
    pub fn setObserverCount(self: *@This(), count: u32) void {
        self.observer_count = count;
    }
    
    pub fn setDependencyCount(self: *@This(), count: u32) void {
        self.dependency_count = count;
    }
    
    pub fn getAge(self: *const @This()) u64 {
        const now = @as(u64, @intCast(std.time.milliTimestamp()));
        return now - self.created_at;
    }
    
    pub fn getTimeSinceUpdate(self: *const @This()) u64 {
        const now = @as(u64, @intCast(std.time.milliTimestamp()));
        return now - self.last_updated;
    }
};

/// Configuration for reactive objects
/// Allows customization of reactive behavior
pub const ReactiveConfig = struct {
    /// Enable debugging/metadata collection
    debug_mode: bool = false,
    
    /// Maximum dependency depth to prevent infinite recursion
    max_dependency_depth: u32 = 100,
    
    /// Enable automatic cleanup on scope exit
    auto_cleanup: bool = true,
    
    /// Batch notifications by default
    batch_notifications: bool = true,
    
    /// Enable lazy evaluation for derived values
    lazy_evaluation: bool = true,
    
    /// Maximum observer count per signal
    max_observers: u32 = 1000,
    
    /// Enable performance monitoring
    performance_monitoring: bool = false,
    
    pub fn default() @This() {
        return @This(){};
    }
    
    pub fn debug() @This() {
        return @This(){
            .debug_mode = true,
            .performance_monitoring = true,
        };
    }
    
    pub fn production() @This() {
        return @This(){
            .debug_mode = false,
            .performance_monitoring = false,
            .max_dependency_depth = 50, // Lower for production
        };
    }
};

/// Type helpers for working with reactive values
pub const TypeHelpers = struct {
    /// Check if a type is a reactive signal
    pub fn isSignal(comptime T: type) bool {
        return @hasDecl(T, "get") and @hasDecl(T, "set") and @hasDecl(T, "addObserver");
    }
    
    /// Check if a type is a derived value
    pub fn isDerived(comptime T: type) bool {
        return @hasDecl(T, "get") and @hasDecl(T, "rederive") and !@hasDecl(T, "set");
    }
    
    /// Check if a type is an effect
    pub fn isEffect(comptime T: type) bool {
        return @hasDecl(T, "run") and @hasDecl(T, "stop");
    }
    
    /// Extract the value type from a reactive wrapper
    pub fn ValueType(comptime ReactiveType: type) type {
        if (@hasDecl(ReactiveType, "get")) {
            const get_fn = @TypeOf(ReactiveType.get);
            const return_type = @typeInfo(get_fn).Fn.return_type.?;
            return return_type;
        }
        @compileError("Type is not a reactive value with get() method");
    }
};

/// Constants for reactive system limits
pub const Limits = struct {
    /// Maximum nesting depth for effects
    pub const MAX_EFFECT_DEPTH: u32 = 100;
    
    /// Maximum number of dependencies per reactive value
    pub const MAX_DEPENDENCIES: u32 = 1000;
    
    /// Maximum number of observers per signal
    pub const MAX_OBSERVERS: u32 = 1000;
    
    /// Maximum batch size for notifications
    pub const MAX_BATCH_SIZE: u32 = 10000;
    
    /// Default timeout for reactive operations (milliseconds)
    pub const DEFAULT_TIMEOUT_MS: u64 = 5000;
};

// Tests for type utilities
test "callback types compilation" {
    // Test that all callback types compile correctly
    const effect_fn: CallbackTypes.EffectFn = struct {
        fn effect() void {}
    }.effect;
    
    const cleanup_fn: CallbackTypes.CleanupFn = struct {
        fn cleanup() void {}
    }.cleanup;
    
    const update_fn: CallbackTypes.UpdateFn(i32) = struct {
        fn update(value: i32) i32 { return value + 1; }
    }.update;
    
    const derive_fn: CallbackTypes.DeriveFn(i32) = struct {
        fn derive() i32 { return 42; }
    }.derive;
    
    // Ensure functions can be called
    effect_fn();
    cleanup_fn();
    _ = update_fn(10);
    _ = derive_fn();
}

test "reactive container basic operations" {
    var container = ReactiveContainer(i32).init(std.testing.allocator, 42);
    
    try std.testing.expect(container.getValue() == 42);
    try std.testing.expect(container.getVersion() == 0);
    try std.testing.expect(container.getLifecycleState() == .created);
    
    container.mount();
    try std.testing.expect(container.getLifecycleState() == .mounted);
    
    container.setValue(100);
    try std.testing.expect(container.getValue() == 100);
    try std.testing.expect(container.getVersion() == 1);
    
    container.unmount();
    try std.testing.expect(container.getLifecycleState() == .destroyed);
}

test "reactive metadata tracking" {
    var metadata = ReactiveMetadata.init("test_signal");
    
    try std.testing.expect(metadata.update_count == 0);
    try std.testing.expect(metadata.observer_count == 0);
    try std.testing.expect(std.mem.eql(u8, metadata.name.?, "test_signal"));
    
    metadata.recordUpdate();
    try std.testing.expect(metadata.update_count == 1);
    
    metadata.setObserverCount(5);
    try std.testing.expect(metadata.observer_count == 5);
    
    metadata.setDependencyCount(3);
    try std.testing.expect(metadata.dependency_count == 3);
}

test "type helpers" {
    const MockSignal = struct {
        pub fn get(self: *@This()) i32 { _ = self; return 0; }
        pub fn set(self: *@This(), value: i32) void { _ = self; _ = value; }
        pub fn addObserver(self: *@This(), observer: *const anyopaque) void { _ = self; _ = observer; }
    };
    
    const MockDerived = struct {
        pub fn get(self: *@This()) i32 { _ = self; return 0; }
        pub fn rederive(self: *@This()) void { _ = self; }
    };
    
    const MockEffect = struct {
        pub fn run(self: *@This()) void { _ = self; }
        pub fn stop(self: *@This()) void { _ = self; }
    };
    
    try std.testing.expect(TypeHelpers.isSignal(MockSignal));
    try std.testing.expect(!TypeHelpers.isSignal(MockDerived));
    
    try std.testing.expect(TypeHelpers.isDerived(MockDerived));
    try std.testing.expect(!TypeHelpers.isDerived(MockSignal));
    
    try std.testing.expect(TypeHelpers.isEffect(MockEffect));
    try std.testing.expect(!TypeHelpers.isEffect(MockSignal));
}

test "configuration presets" {
    const default_config = ReactiveConfig.default();
    const debug_config = ReactiveConfig.debug();
    const prod_config = ReactiveConfig.production();
    
    try std.testing.expect(!default_config.debug_mode);
    try std.testing.expect(debug_config.debug_mode);
    try std.testing.expect(!prod_config.debug_mode);
    
    try std.testing.expect(debug_config.performance_monitoring);
    try std.testing.expect(!prod_config.performance_monitoring);
    
    try std.testing.expect(prod_config.max_dependency_depth < default_config.max_dependency_depth);
}