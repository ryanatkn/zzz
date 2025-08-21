# TODO: GPU Layout Engine - Known Issues & Constraints

## Discovered During Planning Phase

### Shader Compilation
1. **Issue**: compile_shaders.sh doesn't support compute shaders yet
   - **Impact**: Cannot compile compute shaders without manual shadercross invocation
   - **Solution**: Add compute shader support with `-t compute` flag
   - **Priority**: HIGH - Blocking implementation

2. **Issue**: shadercross compute shader flag syntax unknown
   - **Impact**: Need to determine correct command line for compute compilation
   - **Solution**: Test shadercross with compute flag variations
   - **Priority**: HIGH

### SDL3 Integration
3. **Issue**: No existing compute pipeline infrastructure in codebase
   - **Impact**: Must build from scratch
   - **Solution**: Create compute.zig module following vertex/pixel pattern
   - **Priority**: HIGH

4. **Issue**: Storage buffer lifetime management unclear
   - **Impact**: Potential memory leaks or crashes
   - **Solution**: Study SDL3 documentation and examples
   - **Priority**: MEDIUM

### Data Structure Alignment
5. **Issue**: GPU struct alignment requirements not documented
   - **Impact**: Potential data corruption or shader failures
   - **Solution**: Use extern struct with explicit padding
   - **Priority**: HIGH
   - **Example Fix**:
   ```zig
   const UIElement = extern struct {
       position: [2]f32,      // 8 bytes
       size: [2]f32,          // 8 bytes
       padding: [4]f32,       // 16 bytes (TRBL)
       margin: [4]f32,        // 16 bytes (TRBL)
       parent_index: u32,     // 4 bytes
       layout_mode: u32,      // 4 bytes
       constraints: u32,      // 4 bytes
       dirty_flags: u32,      // 4 bytes
       // Total: 64 bytes (cache line aligned)
   };
   ```

### Performance Unknowns
6. **Issue**: GPU→CPU readback performance unknown
   - **Impact**: Could negate performance benefits
   - **Solution**: Minimize readback, use double buffering
   - **Priority**: MEDIUM

7. **Issue**: Optimal thread group size undetermined
   - **Impact**: Suboptimal GPU utilization
   - **Solution**: Profile different configurations (32, 64, 128)
   - **Priority**: LOW (can tune later)

### Platform Compatibility
8. **Issue**: Metal backend support status unknown
   - **Impact**: macOS users may not benefit
   - **Solution**: Test on macOS, potentially add Metal shaders
   - **Priority**: LOW (not primary platform)

9. **Issue**: Minimum GPU requirements undefined
   - **Impact**: May crash on older hardware
   - **Solution**: Add capability detection and CPU fallback
   - **Priority**: MEDIUM

### Integration Challenges
10. **Issue**: Reactive signal system expects CPU-side data
    - **Impact**: Major refactoring needed for GPU data
    - **Solution**: Create GPU-aware signal variants or proxy layer
    - **Priority**: HIGH

11. **Issue**: Text layout deeply integrated with CPU
    - **Impact**: Text cannot be fully GPU-accelerated initially
    - **Solution**: Hybrid approach - GPU for boxes, CPU for text
    - **Priority**: MEDIUM

### Memory Management
12. **Issue**: No buffer pooling system exists
    - **Impact**: Frequent allocations could hurt performance
    - **Solution**: Implement BufferPool with pre-allocated chunks
    - **Priority**: MEDIUM

13. **Issue**: Maximum buffer size limits unknown
    - **Impact**: Large UIs might exceed GPU memory
    - **Solution**: Implement chunking or streaming
    - **Priority**: LOW (1000s of elements fit easily)

## Mitigation Strategies

### Phase 1 Mitigations (Immediate)
- Keep existing CPU layout as fallback
- Start with simple box model only
- Use fixed-size buffers initially
- Focus on proof-of-concept over optimization

### Phase 2 Mitigations (Week 1)
- Add proper error handling and fallbacks
- Implement basic profiling
- Create compatibility detection
- Document all platform-specific behavior

### Phase 3 Mitigations (Week 2+)
- Optimize buffer usage patterns
- Add advanced GPU features gradually
- Profile and tune thread group sizes
- Implement proper memory management

## Testing Requirements

### Unit Tests Needed
- [ ] Compute shader compilation
- [ ] Buffer upload/download
- [ ] Struct alignment verification
- [ ] Dispatch command generation

### Integration Tests Needed
- [ ] Simple box layout
- [ ] Nested element hierarchy
- [ ] Constraint propagation
- [ ] Dirty flag optimization

### Performance Tests Needed
- [ ] 100 elements baseline
- [ ] 1000 elements stress test
- [ ] 10000 elements limit test
- [ ] CPU vs GPU comparison

## Risk Assessment

### High Risk
- Shader compilation failures (BLOCKING)
- Struct alignment issues (DATA CORRUPTION)
- Reactive system integration (MAJOR REFACTOR)

### Medium Risk
- Performance regression on small element counts
- Platform compatibility issues
- Memory management complexity

### Low Risk
- Suboptimal thread group sizes (TUNABLE)
- Missing Metal support (PLATFORM SPECIFIC)
- Advanced physics features (OPTIONAL)

## Decision Log

1. **Decision**: Start with compute shaders, not vertex/pixel tricks
   - **Rationale**: Cleaner architecture, better parallelism
   - **Date**: Planning phase

2. **Decision**: Use AoS (Array of Structures) initially
   - **Rationale**: Simpler to implement and debug
   - **Date**: Planning phase

3. **Decision**: Keep CPU implementation as permanent fallback
   - **Rationale**: Platform compatibility, debugging
   - **Date**: Planning phase

4. **Decision**: Focus on box model first, flexbox second
   - **Rationale**: Incremental complexity
   - **Date**: Planning phase

## Open Questions (Need Research)

1. How does shadercross handle compute shader entry points?
2. What's the maximum structured buffer size on common GPUs?
3. Can we use persistent mapped buffers with SDL3?
4. How do we handle dynamic element creation/deletion?
5. Should we batch layout updates across frames?

## Success Metrics

- Shader compiles successfully: **NOT YET**
- Basic compute dispatch works: **NOT YET**
- Box model on GPU: **NOT YET**
- Performance improvement: **NOT YET**
- No visual regressions: **NOT YET**

---

*Status: Issues Documented*
*Last Updated: End of Planning Session*
*Next Review: After Phase 1 Implementation*