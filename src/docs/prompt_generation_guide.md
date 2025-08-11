# Prompt Generation with zz Tool

This document describes how we used the `zz` CLI tool to generate LLM prompts from the Hex game project codebase.

## What We Did

### 1. Created Configuration File
Created `zz.zon` to configure the zz tool's behavior:
- **Purpose**: Exclude compiled shaders from prompts while keeping source files
- **Key addition**: Added `"src/shaders/compiled"` to ignored patterns
- **Effect**: Prevents binary shader files from cluttering the prompt

### 2. Generated Project Prompt
Used the following command to create a comprehensive project prompt:
```bash
../zz/zig-out/bin/zz prompt CLAUDE.md README.md "src/**/*.zig" "src/**/*.hlsl" "src/**/*.sh" > hex_project_prompt.md
```

**What this includes:**
- `CLAUDE.md` - AI assistant instructions and project context
- `README.md` - User-facing documentation
- All Zig source files (`src/**/*.zig`) - Core game logic
- All HLSL shader sources (`src/**/*.hlsl`) - GPU shaders
- All shell scripts (`src/**/*.sh`) - Build automation

**What this excludes:**
- Compiled shader binaries (`src/shaders/compiled/`)
- Build artifacts (`zig-out/`, `.zig-cache/`)
- Version control files (`.git/`)

## Example Variations

### Focused Development Prompts

```bash
# GPU/Rendering focused prompt
../zz/zig-out/bin/zz prompt CLAUDE.md src/renderer.zig src/simple_gpu_renderer.zig "src/shaders/source/*.hlsl" src/docs/gpu.md

# Gameplay systems prompt
../zz/zig-out/bin/zz prompt CLAUDE.md src/game.zig src/entities.zig src/behaviors.zig src/combat.zig src/player.zig

# ECS architecture prompt  
../zz/zig-out/bin/zz prompt CLAUDE.md src/entities.zig src/docs/ecs.md src/types.zig

# Shader development prompt
../zz/zig-out/bin/zz prompt CLAUDE.md "src/shaders/source/*.hlsl" src/docs/shader_compilation.md src/shaders/compile_shaders.sh
```

### Documentation and Context Prompts

```bash
# Full documentation context
../zz/zig-out/bin/zz prompt "*.md" "src/docs/*.md"

# Project structure overview
../zz/zig-out/bin/zz prompt CLAUDE.md README.md build.zig build.zig.zon

# Configuration and data files
../zz/zig-out/bin/zz prompt CLAUDE.md "*.zon" "src/*.zon"
```

### Specific Feature Prompts

```bash
# Camera system analysis
../zz/zig-out/bin/zz prompt CLAUDE.md src/camera.zig src/renderer.zig

# Input and controls
../zz/zig-out/bin/zz prompt CLAUDE.md src/input.zig src/controls.zig src/player.zig

# Physics and collision
../zz/zig-out/bin/zz prompt CLAUDE.md src/physics.zig src/maths.zig

# Zone system and world
../zz/zig-out/bin/zz prompt CLAUDE.md src/entities.zig src/portals.zig src/game_data.zon
```

### Development Workflow Prompts

```bash
# Build system analysis
../zz/zig-out/bin/zz prompt CLAUDE.md build.zig hex src/shaders/compile_shaders.sh

# Testing and debugging
../zz/zig-out/bin/zz prompt CLAUDE.md src/hud.zig --prepend="Debug and testing context:"

# Performance optimization context
../zz/zig-out/bin/zz prompt CLAUDE.md src/renderer.zig src/simple_gpu_renderer.zig src/docs/gpu.md --prepend="Performance optimization focus:"
```

## Advanced Usage Patterns

### Using Prepend/Append for Context

```bash
# Add specific instructions
../zz/zig-out/bin/zz prompt --prepend="Refactor the following code for better performance:" src/renderer.zig

# Add questions at the end
../zz/zig-out/bin/zz prompt CLAUDE.md src/game.zig --append="How can we optimize the game loop?"
```

### Flexible File Selection

```bash
# Multiple specific files
../zz/zig-out/bin/zz prompt CLAUDE.md src/main.zig src/game.zig src/renderer.zig

# Mixed patterns and files
../zz/zig-out/bin/zz prompt CLAUDE.md README.md "src/entities.zig" "src/shaders/source/*.hlsl"

# All source excluding specific files (use zz.zon configuration)
../zz/zig-out/bin/zz prompt "**/*.zig" "**/*.hlsl" --allow-empty-glob
```

## Benefits of This Approach

1. **Selective Inclusion**: Only relevant source files, no binary artifacts
2. **Configurable**: zz.zon allows project-specific ignore patterns  
3. **Comprehensive**: Single command captures entire codebase context
4. **Maintainable**: Glob patterns automatically include new files
5. **LLM Optimized**: Proper markdown formatting with code fences

## Configuration Tips

- Add project-specific patterns to `zz.zon` ignored patterns
- Use glob patterns for automatic file discovery
- Separate documentation from implementation prompts as needed
- Consider prompt size limits when including large codebases