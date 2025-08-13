const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const use_llvm = b.option(bool, "use-llvm", "Use the LLVM backend");

    const exe = b.addExecutable(.{
        .name = "dealt",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .use_llvm = use_llvm,
        .use_lld = use_llvm,
    });

    // Add vendored SDL3 as a dependency
    const sdl_dep = b.dependency("vendored_sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    
    exe.linkLibrary(sdl_lib);
    exe.linkLibC();

    // Add SDL_ttf as a submodule
    const ttf_lib = b.addStaticLibrary(.{
        .name = "SDL3_ttf",
        .target = target,
        .optimize = optimize,
    });
    
    // Add SDL_ttf C source files
    ttf_lib.addCSourceFiles(.{
        .files = &.{
            "vendored/SDL_ttf/src/SDL_ttf.c",
            "vendored/SDL_ttf/src/SDL_gpu_textengine.c",
            "vendored/SDL_ttf/src/SDL_renderer_textengine.c",
            "vendored/SDL_ttf/src/SDL_surface_textengine.c",
            "vendored/SDL_ttf/src/SDL_hashtable.c",
            "vendored/SDL_ttf/src/SDL_hashtable_ttf.c",
        },
        .flags = &.{
            "-std=c11",
            "-DSDL_BUILD_MAJOR_VERSION=3",
            "-DSDL_BUILD_MINOR_VERSION=3",
            "-DSDL_BUILD_MICRO_VERSION=0",
            "-DTTF_USE_HARFBUZZ=0",
        },
    });
    
    // SDL_ttf needs SDL headers and FreeType  
    ttf_lib.linkLibrary(sdl_lib);
    ttf_lib.addIncludePath(b.path("vendored/SDL/include"));
    ttf_lib.addIncludePath(b.path("vendored/SDL_ttf/include"));
    ttf_lib.addIncludePath(b.path("vendored/SDL_ttf/src"));
    
    // Platform-specific FreeType configuration
    if (target.result.os.tag == .linux) {
        ttf_lib.addSystemIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
        ttf_lib.addSystemIncludePath(.{ .cwd_relative = "/usr/include/libpng16" });
    } else if (target.result.os.tag == .windows) {
        // For Windows, we'd need to vendor FreeType or use vcpkg/similar
        // This is a placeholder - would need actual Windows FreeType paths
        // ttf_lib.addIncludePath(b.path("vendored/freetype/include"));
        // ttf_lib.linkLibrary(freetype_lib);
    }
    ttf_lib.linkLibC();
    
    exe.linkLibrary(ttf_lib);
    exe.addIncludePath(b.path("vendored/SDL/include"));
    exe.addIncludePath(b.path("vendored/SDL_ttf/include"));
    
    // Link FreeType for font rendering
    if (target.result.os.tag == .linux) {
        exe.linkSystemLibrary("freetype2");
    } else if (target.result.os.tag == .windows) {
        // For Windows, would need to link against vendored FreeType
        // exe.linkLibrary(freetype_lib);
    }

    // System libraries (platform-specific)
    if (target.result.os.tag == .linux) {
        exe.linkSystemLibrary("GL");
        exe.linkSystemLibrary("m");
        exe.linkSystemLibrary("pthread");
        exe.linkSystemLibrary("dl");
        exe.linkSystemLibrary("rt");
        exe.linkSystemLibrary("X11");
    } else if (target.result.os.tag == .windows) {
        exe.linkSystemLibrary("opengl32");
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("kernel32");
    }
    exe.linkLibC();

    // Install executable
    b.installArtifact(exe);

    // Shader compilation step
    const compile_shaders = b.addSystemCommand(&.{
        "bash", "src/shaders/compile_shaders.sh",
    });
    compile_shaders.setCwd(b.path("."));

    const shaders_step = b.step("shaders", "Compile HLSL shaders to SPIRV/DXIL");
    shaders_step.dependOn(&compile_shaders.step);

    // Clean step for shaders
    const clean_shaders = b.addSystemCommand(&.{
        "bash", "src/shaders/compile_shaders.sh", "--clean",
    });
    clean_shaders.setCwd(b.path("."));

    const clean_step = b.step("clean-shaders", "Clean and rebuild all shaders");
    clean_step.dependOn(&clean_shaders.step);

    // Make install depend on shader compilation
    b.getInstallStep().dependOn(&compile_shaders.step);

    // Run step
    const run_step = b.step("run", "Run the game");
    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    
    if (b.args) |args| {
        run.addArgs(args);
    }
    
    run_step.dependOn(&run.step);

    // Test step
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
