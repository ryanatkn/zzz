# TODO: UI Performance & Future Architecture

**Status**: 🔄 **PLANNED**  
**Created**: 2025-01-21  
**Goal**: Maximum performance UI system with GPU-calculated layouts + enhanced developer experience

## 📊 Current State

- **Foundation**: Box model + flexbox primitives working
- **Reactive System**: Complete Svelte 5 implementation (335 tests passing)
- **UI Components**: 20+ working components (panels, buttons, text, trees)
- **Performance**: Dual-mode text rendering, arena allocation for HUD
- **Constraints**: No heavy CSS features, focus on refinement over expansion

## 🎯 Quick Wins (Immediate Tasks)

### 1. Test Coverage Improvements (30 min)
- [ ] Fix `lib/core/pool.zig` - Change `for (self.objects)` to `for (&self.objects)`
- [ ] Fix `lib/reactive/component.zig` - Update fmt specifiers `{}` to `{s}` or `{any}`
- [ ] Add 2-4 more UI components to test suite
- **Expected Impact**: 32→28 uncovered files, 335→350+ tests

### 2. UI Component Const Fixes (1 hour)
- [ ] Fix `lib/ui/button.zig` - Use `peek()` for const methods
- [ ] Fix `lib/ui/primitives.zig` - Similar const qualifier fixes
- [ ] Update reactive effect patterns to avoid const issues
- **Expected Impact**: Unlock 4+ UI components for testing

### 3. IDE Quick Enhancements (45 min)
- [ ] Re-enable syntax highlighting with error boundaries
  - Add timeout protection (max 100ms per file)
  - Limit file size for highlighting (e.g., first 10KB)
  - Graceful fallback to plain text on errors
- [ ] Add basic keyboard navigation (arrow keys for file tree)
- [ ] File: `src/roots/menu/ide/constants.zig` - `ENABLE_HIGHLIGHTING = true`

## 🚀 GPU-Calculated Layout System (Maximum Performance)

### Core Concept: All Layout on GPU

**Architecture Vision:**
- Layout calculations happen in compute shaders
- CPU only provides input constraints
- Zero CPU-side tree traversal for layout
- Batch all UI elements into single GPU dispatch

### GPU Layout Primitives

#### Phase 1: Basic GPU Box Model
```hlsl
// Layout data stored in structured buffers
struct UIElement {
    float2 position;      // Computed position
    float2 size;          // Computed size
    float4 padding;       // TRBL
    float4 margin;        // TRBL
    uint parent_index;    // Parent in hierarchy
    uint layout_mode;     // 0=absolute, 1=flex, 2=box
    uint constraints;     // Packed constraint flags
};

// Compute shader for box model calculation
[numthreads(64, 1, 1)]
void CalculateLayout(uint3 id : SV_DispatchThreadID) {
    UIElement elem = elements[id.x];
    UIElement parent = elements[elem.parent_index];
    
    // Calculate available space
    float2 available = parent.size - float2(
        parent.padding.y + parent.padding.w,
        parent.padding.x + parent.padding.z
    );
    
    // Apply constraints in parallel
    elem.size = ApplyConstraints(elem, available);
    elem.position = CalculatePosition(elem, parent);
    
    elements[id.x] = elem;
}
```

#### Phase 2: GPU Flexbox
- [ ] Implement flex container logic in compute shader
- [ ] Parallel calculation of flex item sizes
- [ ] Main/cross axis alignment in GPU
- [ ] Wrap detection and multi-line flex

#### Phase 3: Constraint Solver
- [ ] Spring-based constraint system (physics-inspired)
- [ ] Parallel constraint satisfaction
- [ ] Priority-based constraint resolution
- [ ] Animated constraint transitions

### API Constraints for GPU Layout

**Required API Changes:**
```zig
// All layout data must be GPU-friendly
const GPULayoutData = extern struct {
    elements: [*]UIElement,      // GPU buffer pointer
    count: u32,                   // Element count
    dirty_flags: u32,             // Bitfield of changed elements
    frame_number: u32,            // For double-buffering
};

// Simplified API that maps to GPU operations
pub fn setConstraint(element_id: u32, constraint: Constraint) void {
    // Queue constraint update for next GPU dispatch
}

pub fn requestLayout() void {
    // Trigger GPU layout calculation
}
```

### Performance Targets
- **Layout calculation**: <0.5ms for 1000 UI elements
- **Memory bandwidth**: Single read/write per element per frame
- **CPU overhead**: <0.1ms (just launching compute shader)
- **Scalability**: Linear with element count

## 🛠️ Track B: Developer Experience (Expanded)

### Hot Reload System v2

#### Architecture Options

**Option 1: Memory-Mapped State Preservation**
```zig
// Shared memory region survives recompilation
const SharedState = struct {
    magic: u32 = 0xDEADBEEF,
    version: u32,
    game_state: GameState,
    ui_state: UIState,
    reactive_snapshot: [4096]u8, // Serialized reactive state
};

// Map shared memory on startup
var shared: *SharedState = mapSharedMemory("zzz_hot_state");
if (shared.magic == 0xDEADBEEF) {
    restoreState(shared);
}
```

**Option 2: IPC-Based Hot Reload**
- Parent process monitors files
- Child process runs game
- State transferred via pipes on reload
- Zero-copy transfer using shared memory

**Option 3: WASM Module Hot Swap**
- Compile UI components to WASM
- Hot-swap WASM modules at runtime
- Keep core engine in native code
- Instant UI iteration without restart

#### File Watcher Implementation
```zig
// Efficient file watching with inotify (Linux) / FSEvents (macOS)
const FileWatcher = struct {
    watch_fd: i32,
    paths: std.ArrayList([]const u8),
    callbacks: std.ArrayList(*const fn(path: []const u8) void),
    
    pub fn watch(self: *FileWatcher, path: []const u8, callback: *const fn([]const u8) void) !void {
        // Register path with OS file watching API
    }
    
    pub fn processEvents(self: *FileWatcher) !void {
        // Non-blocking check for file changes
    }
};
```

### Enhanced IDE Features

#### Alternative Approaches

**Approach 1: LSP Integration**
- [ ] Embed LSP client in game
- [ ] Connect to zls (Zig Language Server)
- [ ] Real-time error highlighting
- [ ] Autocomplete and go-to-definition
- [ ] Hover documentation

**Approach 2: Incremental Compilation Display**
- [ ] Show compilation progress in IDE
- [ ] Display error locations inline
- [ ] Quick-fix suggestions
- [ ] Compilation cache visualization

**Approach 3: Visual Debugging Tools**
- [ ] Live variable inspection
- [ ] Breakpoint setting from IDE
- [ ] Memory usage visualization
- [ ] Performance profiler integration

#### Text Editing Architecture
```zig
// Rope data structure for efficient text editing
const TextRope = struct {
    root: *Node,
    total_length: usize,
    line_cache: LineCache, // Fast line number lookup
    
    const Node = union(enum) {
        leaf: []u8,
        branch: struct {
            left: *Node,
            right: *Node,
            weight: usize, // Left subtree size
        },
    };
    
    pub fn insert(self: *TextRope, pos: usize, text: []const u8) !void {
        // O(log n) insertion
    }
    
    pub fn delete(self: *TextRope, start: usize, end: usize) !void {
        // O(log n) deletion
    }
};
```

### Development Tool Suite

**Performance Profiler HUD**
- [ ] GPU timing per render pass
- [ ] CPU function timing with call stacks
- [ ] Memory allocation tracking
- [ ] Frame time histogram
- [ ] Heatmap overlay for expensive operations

**State Inspector**
- [ ] Live reactive signal viewer
- [ ] Component hierarchy browser
- [ ] Event stream monitor
- [ ] Input replay system
- [ ] State diff between frames

## 🎨 Track D: Graphics/Rendering (Expanded)

### Advanced Text Rendering

#### GPU-Accelerated Text Layout

**Option 1: Compute Shader Text Shaping**
```hlsl
// Text layout in compute shader
struct Glyph {
    uint codepoint;
    float2 position;
    float2 size;
    float advance;
    uint texture_index;
};

[numthreads(256, 1, 1)]
void ShapeText(uint3 id : SV_DispatchThreadID) {
    uint glyph_index = id.x;
    Glyph g = glyphs[glyph_index];
    
    // Kerning lookup
    if (glyph_index > 0) {
        uint prev = glyphs[glyph_index - 1].codepoint;
        float kern = GetKerning(prev, g.codepoint);
        g.position.x += kern;
    }
    
    // Line breaking
    if (g.position.x + g.advance > line_width) {
        g.position.x = 0;
        g.position.y += line_height;
    }
    
    shaped_glyphs[glyph_index] = g;
}
```

**Option 2: SDF Text with Subpixel Rendering**
- [ ] RGB subpixel anti-aliasing
- [ ] Adaptive SDF range based on zoom
- [ ] Outline and shadow in single pass
- [ ] Emoji support via multi-channel SDF

**Option 3: Variable Fonts**
- [ ] Weight interpolation on GPU
- [ ] Responsive typography (auto-adjust to container)
- [ ] Animated font variations
- [ ] Custom axes for game-specific effects

#### Rich Text Implementation

```zig
// Rich text with inline styles
const RichText = struct {
    segments: []Segment,
    
    const Segment = struct {
        text: []const u8,
        style: Style,
        
        const Style = struct {
            font_id: u32,
            size: f32,
            color: Color,
            weight: f32,  // 100-900
            italic: bool,
            underline: bool,
            effects: Effects,
            
            const Effects = packed struct {
                shadow: bool,
                outline: bool,
                gradient: bool,
                animation: u3, // 8 animation types
            };
        };
    };
};
```

### Procedural UI Graphics System

#### Alternative Rendering Approaches

**Approach 1: Distance Field UI**
```hlsl
// Everything is a distance field
float UIElementSDF(float2 pos, UIElement elem) {
    float d = RoundedRectSDF(pos, elem.bounds, elem.corner_radius);
    
    // Borders
    float border = abs(d) - elem.border_width;
    
    // Shadows
    float shadow = smoothstep(0, elem.shadow_blur, d - elem.shadow_offset);
    
    // Combine
    return min(d, border);
}
```

**Approach 2: Mesh-Based UI**
- [ ] Generate meshes for UI elements
- [ ] Instanced rendering for repeated elements
- [ ] 9-slice scaling for panels
- [ ] Bézier curve borders

**Approach 3: Raymarched UI**
- [ ] Full UI in fragment shader
- [ ] Infinite resolution
- [ ] Complex shapes with boolean operations
- [ ] Procedural textures and patterns

#### Visual Effects Library

**Shader Effects Collection:**
```hlsl
// Glassmorphism effect
float4 GlassEffect(float2 uv, float4 bg_color) {
    float4 blur = GaussianBlur(bg_color, 8.0);
    float4 tint = float4(1, 1, 1, 0.2);
    float noise = SimplexNoise(uv * 100.0) * 0.02;
    return lerp(blur, tint, 0.6) + noise;
}

// Neumorphism shadow
float NeumorphismShadow(float2 pos, float2 center, float radius) {
    float d = length(pos - center) - radius;
    float light = exp(-max(d + 2, 0) * 0.5);
    float dark = exp(-max(-d + 2, 0) * 0.5);
    return light - dark;
}

// Holographic effect
float4 HolographicEffect(float2 uv, float time) {
    float rainbow = sin(uv.y * 10 + time) * 0.5 + 0.5;
    float3 color = HSVtoRGB(float3(rainbow, 0.8, 1.0));
    float scanline = sin(uv.y * 200) * 0.1 + 0.9;
    return float4(color * scanline, 0.8);
}
```

### Theme Engine Architecture

```zig
// GPU-friendly theme data
const Theme = extern struct {
    // Primary colors (GPU-friendly layout)
    primary: [4]f32,
    secondary: [4]f32,
    background: [4]f32,
    surface: [4]f32,
    error: [4]f32,
    
    // Spacing scale (powers of 2)
    spacing_scale: f32,  // Base unit
    
    // Typography
    font_scale: f32,
    line_height: f32,
    
    // Effects
    blur_radius: f32,
    shadow_distance: f32,
    animation_speed: f32,
    
    // Feature flags
    features: packed struct {
        dark_mode: bool,
        high_contrast: bool,
        reduce_motion: bool,
        colorblind_mode: u2,
        _padding: u27,
    },
};

// Runtime theme switching
pub fn setTheme(theme: Theme) void {
    // Upload to GPU constant buffer
    updateThemeBuffer(&theme);
    // Trigger reactive updates
    theme_signal.set(theme);
}
```

## 📈 Performance Metrics & Goals

### Target Performance
- **Layout**: <0.5ms for 1000 elements (GPU)
- **Text Rendering**: <1ms for 10,000 glyphs
- **Theme Switch**: <16ms (single frame)
- **Hot Reload**: <100ms from save to running
- **Memory**: <10MB for entire UI system

### Optimization Strategies
1. **Batch Everything**: Single draw call per UI layer
2. **Cache Aggressively**: Persistent text, compiled shaders
3. **Compute Once**: Layout on GPU, reuse until dirty
4. **Profile Continuously**: Built-in performance HUD
5. **Preallocate**: Fixed-size pools for common elements

## 🗓️ Implementation Phases

### Phase 1: Foundation (Week 1)
- Quick wins from test coverage
- Basic GPU layout prototype
- Hot reload design document

### Phase 2: Core Systems (Week 2-3)
- GPU box model implementation
- File watcher integration
- Text editing in IDE

### Phase 3: Polish (Week 4)
- Theme engine
- Visual effects
- Performance profiling HUD

### Phase 4: Advanced Features (Future)
- Full GPU flexbox
- LSP integration
- Rich text system

## 📝 Notes

- **GPU Layout**: Requires rethinking entire UI update pipeline
- **Hot Reload**: Choose approach based on platform capabilities
- **Text Rendering**: SDF provides best quality/performance ratio
- **Theme Engine**: Must be reactive-system aware

---

*This TODO represents a vision for maximum performance UI with GPU acceleration and world-class developer experience.*