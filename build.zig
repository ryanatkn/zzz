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

    // Build SDL3 library inline
    const sdl3 = buildSDL3(b, target, optimize);
    exe.addIncludePath(b.path("deps/SDL/include"));
    
    // Build SDL_ttf library inline  
    const sdl_ttf = buildSDL_ttf(b, target, optimize);
    exe.addIncludePath(b.path("deps/SDL_ttf/include"));
    
    // Link libraries in correct order (SDL_ttf depends on SDL3)
    exe.linkLibrary(sdl_ttf);
    exe.linkLibrary(sdl3);
    
    exe.linkLibC();

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

    // Dependency management step
    const update_deps = b.addSystemCommand(&.{
        "bash", "scripts/update-deps.sh",
    });
    update_deps.setCwd(b.path("."));

    const update_deps_step = b.step("update-deps", "Update vendored SDL dependencies");
    update_deps_step.dependOn(&update_deps.step);

    // Check dependencies without updating
    const check_deps = b.addSystemCommand(&.{
        "bash", "scripts/update-deps.sh", "--check",
    });
    check_deps.setCwd(b.path("."));

    const check_deps_step = b.step("check-deps", "Check dependency status (CI-friendly)");
    check_deps_step.dependOn(&check_deps.step);

    // List dependencies
    const list_deps = b.addSystemCommand(&.{
        "bash", "scripts/update-deps.sh", "--list",
    });
    list_deps.setCwd(b.path("."));

    const list_deps_step = b.step("list-deps", "List all dependencies and their status");
    list_deps_step.dependOn(&list_deps.step);

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

// System library detection helpers
fn hasSystemLibrary(lib_name: []const u8) bool {
    // For FreeType, check the specific library names
    if (std.mem.eql(u8, lib_name, "freetype2")) {
        // Check for libfreetype.so specifically
        const lib_paths = [_][]const u8{
            "/usr/lib/x86_64-linux-gnu/libfreetype.so",
            "/usr/lib/x86_64-linux-gnu/libfreetype.so.6",
            "/usr/lib/libfreetype.so",
            "/usr/local/lib/libfreetype.so",
        };
        
        for (lib_paths) |path| {
            if (std.fs.cwd().access(path, .{})) {
                return true;
            } else |_| {}
        }
        return false;
    }
    
    // For other libraries, use the generic approach
    const lib_paths = [_][]const u8{
        "/usr/lib/x86_64-linux-gnu",
        "/usr/lib",
        "/lib/x86_64-linux-gnu", 
        "/lib",
        "/usr/local/lib",
    };
    
    const lib_prefixed = std.fmt.allocPrint(std.heap.page_allocator, "lib{s}.so", .{lib_name}) catch return false;
    defer std.heap.page_allocator.free(lib_prefixed);
    
    for (lib_paths) |path| {
        const shared_path = std.fmt.allocPrint(std.heap.page_allocator, "{s}/{s}", .{path, lib_prefixed}) catch continue;
        defer std.heap.page_allocator.free(shared_path);
        
        if (std.fs.cwd().access(shared_path, .{})) {
            return true;
        } else |_| {}
    }
    
    return false;
}

// Build SDL3 static library from vendored sources
fn buildSDL3(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const sdl3 = b.addStaticLibrary(.{
        .name = "SDL3",
        .target = target,
        .optimize = optimize,
    });

    // Core SDL source files
    const core_files = [_][]const u8{
        "deps/SDL/src/SDL.c",
        "deps/SDL/src/SDL_assert.c", 
        "deps/SDL/src/SDL_error.c",
        "deps/SDL/src/SDL_guid.c",
        "deps/SDL/src/SDL_hashtable.c",
        "deps/SDL/src/SDL_hints.c",
        "deps/SDL/src/SDL_log.c",
        "deps/SDL/src/SDL_properties.c",
        "deps/SDL/src/SDL_utils.c",
        // Audio
        "deps/SDL/src/audio/SDL_audio.c",
        "deps/SDL/src/audio/SDL_audiocvt.c",
        "deps/SDL/src/audio/SDL_audiodev.c",
        "deps/SDL/src/audio/SDL_audioqueue.c",
        "deps/SDL/src/audio/SDL_audioresample.c",
        "deps/SDL/src/audio/SDL_audiotypecvt.c",
        "deps/SDL/src/audio/SDL_mixer.c",
        "deps/SDL/src/audio/SDL_wave.c",
        // Atomic
        "deps/SDL/src/atomic/SDL_atomic.c",
        "deps/SDL/src/atomic/SDL_spinlock.c",
        // CPU info
        "deps/SDL/src/cpuinfo/SDL_cpuinfo.c",
        // Events
        "deps/SDL/src/events/SDL_categories.c",
        "deps/SDL/src/events/SDL_clipboardevents.c",
        "deps/SDL/src/events/SDL_displayevents.c",
        "deps/SDL/src/events/SDL_dropevents.c",
        "deps/SDL/src/events/SDL_events.c",
        "deps/SDL/src/events/SDL_eventwatch.c",
        "deps/SDL/src/events/SDL_keyboard.c",
        "deps/SDL/src/events/SDL_keymap.c",
        "deps/SDL/src/events/SDL_keysym_to_keycode.c",
        "deps/SDL/src/events/SDL_keysym_to_scancode.c",
        "deps/SDL/src/events/SDL_mouse.c",
        "deps/SDL/src/events/SDL_pen.c",
        "deps/SDL/src/events/SDL_quit.c",
        "deps/SDL/src/events/SDL_scancode_tables.c",
        "deps/SDL/src/events/SDL_touch.c",
        "deps/SDL/src/events/SDL_windowevents.c",
        "deps/SDL/src/events/imKStoUCS.c",
        // GPU
        "deps/SDL/src/gpu/SDL_gpu.c",
        // Skip dynapi to avoid needing all subsystem implementations
        // GPU Vulkan backend  
        "deps/SDL/src/gpu/vulkan/SDL_gpu_vulkan.c",
        // Dummy drivers for disabled features
        "deps/SDL/src/audio/dummy/SDL_dummyaudio.c",
        "deps/SDL/src/joystick/dummy/SDL_sysjoystick.c",
        "deps/SDL/src/haptic/dummy/SDL_syshaptic.c",
        // Filesystem
        "deps/SDL/src/filesystem/SDL_filesystem.c",
        // IO
        "deps/SDL/src/io/SDL_asyncio.c",
        "deps/SDL/src/io/SDL_iostream.c",
        // Joystick
        "deps/SDL/src/joystick/SDL_gamepad.c",
        "deps/SDL/src/joystick/SDL_joystick.c", 
        "deps/SDL/src/joystick/SDL_steam_virtual_gamepad.c",
        "deps/SDL/src/joystick/controller_type.c",
        // Main
        "deps/SDL/src/main/SDL_main_callbacks.c",
        "deps/SDL/src/main/SDL_runapp.c",
        // Misc
        "deps/SDL/src/misc/SDL_url.c",
        // Camera
        "deps/SDL/src/camera/SDL_camera.c",
        // Dialog  
        "deps/SDL/src/dialog/SDL_dialog_utils.c",
        // Locale
        "deps/SDL/src/locale/SDL_locale.c",
        // Tray (system tray)
        "deps/SDL/src/tray/SDL_tray_utils.c",
        // Power
        "deps/SDL/src/power/SDL_power.c",
        // Process  
        "deps/SDL/src/process/SDL_process.c",
        // Render
        "deps/SDL/src/render/SDL_d3dmath.c",
        "deps/SDL/src/render/SDL_render.c",
        "deps/SDL/src/render/SDL_render_unsupported.c",
        "deps/SDL/src/render/SDL_yuv_sw.c",
        // Sensor
        "deps/SDL/src/sensor/SDL_sensor.c",
        // Stdlib
        "deps/SDL/src/stdlib/SDL_crc16.c",
        "deps/SDL/src/stdlib/SDL_crc32.c",
        "deps/SDL/src/stdlib/SDL_getenv.c",
        "deps/SDL/src/stdlib/SDL_iconv.c",
        "deps/SDL/src/stdlib/SDL_malloc.c",
        "deps/SDL/src/stdlib/SDL_memcpy.c",
        "deps/SDL/src/stdlib/SDL_memmove.c",
        "deps/SDL/src/stdlib/SDL_memset.c",
        "deps/SDL/src/stdlib/SDL_murmur3.c",
        "deps/SDL/src/stdlib/SDL_qsort.c",
        "deps/SDL/src/stdlib/SDL_random.c",
        "deps/SDL/src/stdlib/SDL_stdlib.c",
        "deps/SDL/src/stdlib/SDL_string.c",
        "deps/SDL/src/stdlib/SDL_strtokr.c",
        // Storage
        "deps/SDL/src/storage/SDL_storage.c",
        // Thread
        "deps/SDL/src/thread/SDL_thread.c",
        // Time
        "deps/SDL/src/time/SDL_time.c",
        // Timer
        "deps/SDL/src/timer/SDL_timer.c",
        // Video
        "deps/SDL/src/video/SDL_RLEaccel.c",
        "deps/SDL/src/video/SDL_blit.c",
        "deps/SDL/src/video/SDL_blit_0.c",
        "deps/SDL/src/video/SDL_blit_1.c",
        "deps/SDL/src/video/SDL_blit_A.c",
        "deps/SDL/src/video/SDL_blit_N.c",
        "deps/SDL/src/video/SDL_blit_auto.c",
        "deps/SDL/src/video/SDL_blit_copy.c", 
        "deps/SDL/src/video/SDL_blit_slow.c",
        "deps/SDL/src/video/SDL_bmp.c",
        "deps/SDL/src/video/SDL_clipboard.c",
        "deps/SDL/src/video/SDL_egl.c",
        "deps/SDL/src/video/SDL_fillrect.c",
        "deps/SDL/src/video/SDL_pixels.c",
        "deps/SDL/src/video/SDL_rect.c",
        "deps/SDL/src/video/SDL_stb.c",
        "deps/SDL/src/video/SDL_stretch.c",
        "deps/SDL/src/video/SDL_surface.c",
        "deps/SDL/src/video/SDL_video.c",
        "deps/SDL/src/video/SDL_video_unsupported.c",
        "deps/SDL/src/video/SDL_vulkan_utils.c",
        "deps/SDL/src/video/SDL_yuv.c",
    };

    // Add core source files
    const build_flags = if (target.result.os.tag == .linux) 
        &[_][]const u8{
            "-DSDL_BUILD_MAJOR_VERSION=3",
            "-DSDL_BUILD_MINOR_VERSION=3", 
            "-DSDL_BUILD_MICRO_VERSION=0",
            "-DSDL_STATIC_LIB=1",
            "-DSDL_PLATFORM_LINUX=1",
            "-DSDL_DYNAPI_DISABLED=1",
            "-USDL_DYNAMIC_API",
        }
    else 
        &[_][]const u8{
            "-DSDL_BUILD_MAJOR_VERSION=3",
            "-DSDL_BUILD_MINOR_VERSION=3", 
            "-DSDL_BUILD_MICRO_VERSION=0",
            "-DSDL_STATIC_LIB=1",
            "-DSDL_DYNAPI_DISABLED=1",
        };
        
    sdl3.addCSourceFiles(.{
        .files = &core_files,
        .flags = build_flags,
    });

    // Add platform-specific files for Linux
    if (target.result.os.tag == .linux) {
        const linux_files = [_][]const u8{
            // Skip ALSA audio - requires libasound-dev
            // "deps/SDL/src/audio/alsa/SDL_alsa_audio.c",
            // Core (excluding D-Bus dependent files)
            "deps/SDL/src/core/linux/SDL_evdev.c",
            "deps/SDL/src/core/linux/SDL_evdev_kbd.c",
            // Skip SDL_fcitx.c and SDL_ibus.c - they need D-Bus
            // Skip SDL_ime.c - depends on above
            "deps/SDL/src/core/linux/SDL_udev.c",
            // Filesystem
            "deps/SDL/src/filesystem/unix/SDL_sysfilesystem.c",
            // Skip haptic - may have similar evdev issues
            // "deps/SDL/src/haptic/linux/SDL_syshaptic.c",
            // Skip joystick - requires advanced Linux input/evdev headers
            // "deps/SDL/src/joystick/linux/SDL_sysjoystick.c",
            // Loadso
            "deps/SDL/src/loadso/dlopen/SDL_sysloadso.c",
            // Locale
            "deps/SDL/src/locale/unix/SDL_syslocale.c",
            // Camera
            "deps/SDL/src/camera/v4l2/SDL_camera_v4l2.c",
            // Dialog
            "deps/SDL/src/dialog/unix/SDL_portaldialog.c",
            "deps/SDL/src/dialog/unix/SDL_zenitydialog.c",
            // Tray
            "deps/SDL/src/tray/unix/SDL_tray.c",
            // Power
            "deps/SDL/src/power/linux/SDL_syspower.c",
            // Process
            "deps/SDL/src/process/posix/SDL_posixprocess.c",
            // Thread
            "deps/SDL/src/thread/pthread/SDL_syscond.c",
            "deps/SDL/src/thread/pthread/SDL_sysmutex.c",
            "deps/SDL/src/thread/pthread/SDL_sysrwlock.c",
            "deps/SDL/src/thread/pthread/SDL_syssem.c",
            "deps/SDL/src/thread/pthread/SDL_systhread.c",
            "deps/SDL/src/thread/pthread/SDL_systls.c",
            // Timer
            "deps/SDL/src/timer/unix/SDL_systimer.c",
            // Video - minimal X11 support
            "deps/SDL/src/video/x11/SDL_x11clipboard.c",
            "deps/SDL/src/video/x11/SDL_x11dyn.c",
            "deps/SDL/src/video/x11/SDL_x11framebuffer.c", 
            "deps/SDL/src/video/x11/SDL_x11keyboard.c",
            "deps/SDL/src/video/x11/SDL_x11messagebox.c",
            "deps/SDL/src/video/x11/SDL_x11modes.c",
            "deps/SDL/src/video/x11/SDL_x11opengl.c",
            "deps/SDL/src/video/x11/SDL_x11opengles.c",
            "deps/SDL/src/video/x11/SDL_x11shape.c",
            "deps/SDL/src/video/x11/SDL_x11vulkan.c",
            // Add back minimal video support (exclude xinput2-dependent files)
            // Skip files that include SDL_x11xinput2.h: SDL_x11events.c, SDL_x11mouse.c, 
            // SDL_x11pen.c, SDL_x11touch.c, SDL_x11video.c, SDL_x11window.c
        };
        
        sdl3.addCSourceFiles(.{
            .files = &linux_files,
            .flags = &[_][]const u8{
                "-DSDL_BUILD_MAJOR_VERSION=3",
                "-DSDL_BUILD_MINOR_VERSION=3",
                "-DSDL_BUILD_MICRO_VERSION=0", 
                "-DSDL_STATIC_LIB=1",
                "-DSDL_PLATFORM_LINUX=1",
                "-DSDL_DYNAPI_DISABLED=1",
                "-USDL_DYNAMIC_API",
            },
        });
    }

    // Include paths
    sdl3.addIncludePath(b.path("deps/SDL/include"));
    sdl3.addIncludePath(b.path("deps/SDL/include/build_config"));
    sdl3.addIncludePath(b.path("deps/SDL/src"));

    // Link system libraries with optional detection
    if (target.result.os.tag == .linux) {
        // Required libraries
        sdl3.linkSystemLibrary("m");
        sdl3.linkSystemLibrary("dl");
        sdl3.linkSystemLibrary("pthread");
        sdl3.linkSystemLibrary("rt");
        sdl3.linkSystemLibrary("X11");
        
        // Skip ALSA to avoid dev package requirements
        // if (hasSystemLibrary("asound")) {
        //     sdl3.linkSystemLibrary("asound");
        // }
        
        if (hasSystemLibrary("Xext")) {
            sdl3.linkSystemLibrary("Xext");
        }
        if (hasSystemLibrary("Xrandr")) {
            sdl3.linkSystemLibrary("Xrandr");
        }
        if (hasSystemLibrary("Xrender")) {
            sdl3.linkSystemLibrary("Xrender");
        }
        if (hasSystemLibrary("Xi")) {
            sdl3.linkSystemLibrary("Xi");
        }
        if (hasSystemLibrary("Xfixes")) {
            sdl3.linkSystemLibrary("Xfixes");
        }
        if (hasSystemLibrary("Xcursor")) {
            sdl3.linkSystemLibrary("Xcursor");
        }
        if (hasSystemLibrary("Xss")) {
            sdl3.linkSystemLibrary("Xss");
        }
        
        // Link Vulkan for GPU support
        if (hasSystemLibrary("vulkan")) {
            sdl3.linkSystemLibrary("vulkan");
        }
    }

    sdl3.linkLibC();
    return sdl3;
}

// Build SDL_ttf static library from vendored sources
fn buildSDL_ttf(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const sdl_ttf = b.addStaticLibrary(.{
        .name = "SDL3_ttf",
        .target = target,
        .optimize = optimize,
    });

    // SDL_ttf source files
    const ttf_files = [_][]const u8{
        "deps/SDL_ttf/src/SDL_ttf.c",
        "deps/SDL_ttf/src/SDL_hashtable.c",
        "deps/SDL_ttf/src/SDL_hashtable_ttf.c",
        "deps/SDL_ttf/src/SDL_gpu_textengine.c",
        "deps/SDL_ttf/src/SDL_renderer_textengine.c", 
        "deps/SDL_ttf/src/SDL_surface_textengine.c",
    };

    // Add source files (disable advanced features for simplicity)
    sdl_ttf.addCSourceFiles(.{
        .files = &ttf_files,
        .flags = &[_][]const u8{
            "-DTTF_USE_HARFBUZZ=0",
            "-DTTF_USE_SDF=0",
        },
    });

    // Include paths
    sdl_ttf.addIncludePath(b.path("deps/SDL_ttf/include"));
    sdl_ttf.addIncludePath(b.path("deps/SDL_ttf/src"));
    sdl_ttf.addIncludePath(b.path("deps/SDL/include")); // SDL3 headers

    // Link system libraries with optional detection
    if (target.result.os.tag == .linux) {
        if (hasSystemLibrary("freetype2")) {
            sdl_ttf.linkSystemLibrary("freetype2");
            // Add FreeType include paths (use addIncludePath to avoid -isystem vs -I conflicts)
            sdl_ttf.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
            sdl_ttf.addIncludePath(.{ .cwd_relative = "/usr/include/libpng16" });
        } else {
            // Could add basic bitmap font fallback here
            std.log.warn("FreeType not found, TTF support may be limited", .{});
        }
        sdl_ttf.linkSystemLibrary("m");
    }

    sdl_ttf.linkLibC();
    return sdl_ttf;
}
