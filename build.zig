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

    // Add SDL3 from deps as a dependency
    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    
    // Add SDL_ttf from deps as a dependency
    const sdl_ttf_dep = b.dependency("sdl_ttf", .{
        .target = target,
        .optimize = optimize,
    });
    const ttf_lib = sdl_ttf_dep.artifact("SDL3_ttf");
    
    exe.linkLibrary(sdl_lib);
    exe.linkLibrary(ttf_lib);
    exe.linkLibC();
    
    // Add include paths for SDL and SDL_ttf
    exe.addIncludePath(sdl_dep.path("include"));
    exe.addIncludePath(sdl_ttf_dep.path("include"));
    
    // FreeType is now handled entirely by SDL_ttf - remove duplicate linking
    // if (target.result.os.tag == .linux) {
    //     exe.linkSystemLibrary("freetype2");
    // } else if (target.result.os.tag == .windows) {
    //     // For Windows, would need to link against vendored FreeType
    //     // exe.linkLibrary(freetype_lib);
    // }

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
