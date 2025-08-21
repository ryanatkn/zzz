# TODO: GPU Layout Engine Implementation Plan

## Vision
Transform our CPU-based layout system into a fully GPU-accelerated layout engine using HLSL compute shaders, enabling physics-based animations and handling thousands of UI elements at 60+ FPS.

## Current State Assessment

### Existing Infrastructure
- **Layout System**: `src/lib/layout/` - Full CPU implementation
  - BoxModel with reactive signals
  - Flexbox with gap, alignment, justification
  - Text baseline positioning
  - Spacing/sizing/positioning primitives
- **GPU Pipeline**: SDL3 GPU with vertex/pixel shaders only
  - No compute shader support yet
  - Instanced rendering for shapes
  - Structured buffer support exists
- **Shader System**: HLSL → SPIRV/DXIL compilation
  - `compile_shaders.sh` handles compilation
  - Procedural vertex generation pattern established

### Critical Unknowns (UPDATED)
- [x] **SDL3 Compute Support**: ✅ YES! Full compute shader support confirmed
  - SDL_CreateGPUComputePipeline()
  - SDL_BeginGPUComputePass() / SDL_EndGPUComputePass()
  - SDL_BindGPUComputePipeline()
  - SDL_BindGPUComputeStorageBuffers() / SDL_BindGPUComputeStorageTextures()
  - SDL_DispatchGPUCompute() / SDL_DispatchGPUComputeIndirect()
- [ ] **Shader Model Requirements**: Likely CS 5.0 minimum (needs testing)
- [ ] **Buffer Synchronization**: SDL provides storage buffer R/W support
- [ ] **Platform Compatibility**: SPIRV (Vulkan) + DXIL (D3D12) confirmed
- [ ] **Memory Limits**: Platform-dependent (needs profiling)
- [ ] **Dispatch Limits**: Standard 65535 x 65535 x 65535 groups expected

## Module Structure

### Phase 1: Compute Infrastructure
```
src/lib/rendering/
├── compute.zig                 # NEW: Compute pipeline management
│   ├── ComputePipeline
│   ├── ComputeShader
│   └── DispatchCommand
├── structured_buffers.zig      # NEW: GPU buffer management
│   ├── StructuredBuffer(T)
│   ├── ReadWriteBuffer(T)
│   └── BufferPool
└── gpu.zig                     # MODIFY: Add compute support

src/shaders/source/
├── layout_box_model.hlsl      # NEW: Box model compute shader
├── layout_flexbox.hlsl        # NEW: Flexbox compute shader
├── layout_constraints.hlsl    # NEW: Constraint solver
└── layout_spring_physics.hlsl # NEW: Spring physics system
```

### Phase 2: GPU Layout Core
```
src/lib/layout/gpu/
├── mod.zig                     # NEW: GPU layout module entry
├── layout_engine.zig           # NEW: Main GPU layout engine
│   ├── GPULayoutEngine
│   ├── ElementBuffer
│   └── ConstraintBuffer
├── element_types.zig           # NEW: GPU-compatible element structs
│   ├── UIElement (extern struct)
│   ├── FlexContainer
│   └── TextElement
├── constraint_types.zig        # NEW: Constraint definitions
│   ├── SizeConstraint
│   ├── PositionConstraint
│   └── AlignmentConstraint
└── spring_solver.zig           # NEW: Physics-based solver
    ├── SpringConstraint
    ├── Damping
    └── IterativeSolver
```

### Phase 3: Integration Layer
```
src/lib/layout/
├── hybrid_layout.zig           # NEW: CPU/GPU coordination
│   ├── HybridLayoutManager
│   ├── DirtyTracking
│   └── BatchUpdater
├── migration.zig               # NEW: Migration helpers
│   ├── BoxModelAdapter
│   ├── FlexboxAdapter
│   └── CompatibilityLayer
└── mod.zig                     # MODIFY: Export GPU variants
```

## Implementation Phases

### Phase 1: Foundation (Week 1)
1. **Research SDL3 Compute API**
   - [ ] Check SDL3 headers for compute functions
   - [ ] Test basic compute shader compilation
   - [ ] Verify platform support

2. **Build Compute Infrastructure**
   - [ ] Create compute.zig with pipeline setup
   - [ ] Implement structured buffer management
   - [ ] Write test compute shader

3. **Shader Compilation Pipeline**
   - [ ] Extend compile_shaders.sh for compute
   - [ ] Add HLSL compute shader templates
   - [ ] Test SPIRV/DXIL generation

### Phase 2: Core Layout (Week 2)
1. **GPU Data Structures**
   - [ ] Define UIElement struct (GPU-compatible)
   - [ ] Create element buffer layout
   - [ ] Implement dirty flag system

2. **Box Model Compute Shader**
   - [ ] Parallel position calculation
   - [ ] Constraint application
   - [ ] Padding/margin/border computation

3. **Basic Integration**
   - [ ] GPU buffer upload/download
   - [ ] Simple test cases
   - [ ] Performance benchmarking

### Phase 3: Advanced Features (Week 3)
1. **Flexbox on GPU**
   - [ ] Main axis calculation
   - [ ] Cross axis alignment
   - [ ] Multi-pass for wrap

2. **Spring Physics**
   - [ ] Constraint graph representation
   - [ ] Iterative solver
   - [ ] Damping and animation

3. **Optimization**
   - [ ] Dirty rectangle tracking
   - [ ] Incremental updates
   - [ ] Memory pooling

### Phase 4: Migration (Week 4)
1. **Compatibility Layer**
   - [ ] Adapter for existing BoxModel
   - [ ] Flexbox migration path
   - [ ] Reactive signal integration

2. **Testing & Validation**
   - [ ] Unit tests for GPU layout
   - [ ] Visual regression tests
   - [ ] Performance comparison

3. **Documentation**
   - [ ] API documentation
   - [ ] Migration guide
   - [ ] Performance tuning guide

## Technical Decisions

### Buffer Layout Strategy
```hlsl
// Option A: Array of Structures (AoS)
struct UIElement {
    float2 position;
    float2 size;
    float4 padding;
    float4 margin;
    uint flags;
};

// Option B: Structure of Arrays (SoA)
struct UIElements {
    float2 positions[MAX_ELEMENTS];
    float2 sizes[MAX_ELEMENTS];
    float4 paddings[MAX_ELEMENTS];
    float4 margins[MAX_ELEMENTS];
    uint flags[MAX_ELEMENTS];
};
```
**Decision**: Start with AoS for simplicity, profile and switch to SoA if needed

### Synchronization Model
- **Option A**: Full GPU→CPU readback each frame
- **Option B**: Lazy readback on demand
- **Option C**: Double buffering with async readback
**Decision**: Start with B, implement C for production

### Constraint Resolution
- **Option A**: Direct algebraic solver
- **Option B**: Iterative relaxation
- **Option C**: Spring physics simulation
**Decision**: Implement B first, add C for animations

## Performance Targets

### Benchmarks
- **1,000 elements**: <0.5ms total layout time
- **10,000 elements**: <5ms total layout time
- **Memory bandwidth**: <10MB/frame
- **CPU overhead**: <0.1ms

### Measurement Points
1. Buffer upload time
2. Compute dispatch time
3. GPU execution time
4. Buffer readback time (if needed)
5. Total frame time impact

## Risk Mitigation

### High Risk Areas
1. **SDL3 Compute Support Missing**
   - Fallback: Use compute via native APIs
   - Fallback: Hybrid CPU/GPU approach

2. **Platform Incompatibility**
   - Fallback: CPU path for unsupported platforms
   - Fallback: Simplified GPU path

3. **Performance Regression**
   - Fallback: Keep CPU implementation
   - Fallback: Selective GPU acceleration

### Testing Strategy
1. Unit tests for each compute shader
2. Integration tests for full layout
3. Stress tests with thousands of elements
4. Visual regression tests
5. Platform compatibility matrix

## Open Questions

### API Design
- How to handle dynamic element creation/deletion?
- Should constraints be explicit or implicit?
- How to expose spring physics parameters?

### Performance
- When to trigger GPU layout recalculation?
- How to batch multiple layout changes?
- Should we use persistent mapped buffers?

### Integration
- How to integrate with reactive signals?
- Should GPU layout be opt-in or default?
- How to handle text layout on GPU?

## Success Criteria

### Minimum Viable Product
- [ ] Box model layout on GPU
- [ ] 2x performance improvement
- [ ] Zero visual regressions
- [ ] Works on Vulkan + D3D12

### Full Implementation
- [ ] Complete flexbox on GPU
- [ ] Spring physics animations
- [ ] 10x performance improvement
- [ ] Sub-millisecond layout for 1000 elements

## Next Steps - Updated Status

### ✅ Foundation Complete
1. **Immediate**: ✅ SDL3 compute API confirmed available
2. **Day 1**: ✅ Compute infrastructure demonstrated working 
3. **Day 2**: ✅ Test compute shader compiled and operational (test_compute.hlsl)
4. **Day 3**: ✅ Layout benchmarking system with backend abstraction implemented
5. **Week 1**: ✅ Backend architecture complete with hybrid CPU/GPU foundation

### 🎯 Ready for GPU Compute Implementation
- **Layout Backend Architecture**: ✅ Complete modular system ready
- **Benchmark Infrastructure**: ✅ Production-ready performance analysis tools
- **Honest GPU Detection**: ✅ Fixed misleading fallback results  
- **Cross-Validation System**: ✅ Ensures GPU compute will match CPU results
- **Modular Organization**: ✅ Clean helper modules for maintainability

### 🚀 Next Phase: Real GPU Compute Shaders
1. **Enable Real GPU Compute**: Update `setGPUDevice()` to use actual compute shaders
2. **Implement Box Model Shader**: Convert CPU BoxModel calculations to HLSL compute
3. **Validation Testing**: Use existing cross-validation to verify GPU vs CPU consistency  
4. **Performance Analysis**: Leverage benchmark system to measure real performance gains

## Notes

- Keep CPU implementation as fallback
- Profile early and often
- Document GPU-specific constraints
- Consider WebGPU compatibility for future

## Discovery Session Results

### Confirmed Capabilities
1. **SDL3 Compute Shaders**: Full support including all necessary APIs
2. **Shader Compilation**: shadercross tool supports compute shaders (needs script update)
3. **Buffer Management**: SDL3 provides structured buffer support with R/W capabilities
4. **Current Architecture**: Clean separation allows parallel GPU implementation

### Immediate Action Items
1. Update compile_shaders.sh to handle compute shaders (-t compute flag)
2. Create compute.zig module with SDL3 compute pipeline bindings
3. Design UIElement struct for GPU compatibility (16-byte alignment)
4. Implement basic compute dispatch test

---

*Status: Planning Phase → Implementation Ready*
*Last Updated: Discovery Session Complete*
*Owner: GPU Layout Team*