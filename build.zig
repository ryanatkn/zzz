const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const use_llvm = b.option(bool, "use-llvm", "Use the LLVM backend");

    const exe = b.addExecutable(.{
        .name = "zzz",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .use_llvm = use_llvm,
        .use_lld = use_llvm,
    });

    // Build SDL3 library inline
    const sdl3 = buildSDL3(b, target, optimize);
    exe.addIncludePath(b.path("deps/SDL/include"));

    // Link SDL3
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

    // Test step with filtering support
    const test_filter = b.option([]const u8, "test-filter", "Run only tests matching this pattern");

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
        .filters = if (test_filter) |filter| &.{filter} else &.{},
    });

    // Link minimal dependencies for tests (avoiding SDL linking issues)
    exe_unit_tests.linkLibC();

    const test_step = b.step("test", "Run unit tests");

    // Run tests with filtering feedback
    if (test_filter) |filter| {
        // Show filter being applied
        const filter_info_cmd = b.addSystemCommand(&.{ "echo", b.fmt("Running tests matching filter: '{s}'", .{filter}) });
        test_step.dependOn(&filter_info_cmd.step);

        const run_test = b.addRunArtifact(exe_unit_tests);
        run_test.step.dependOn(&filter_info_cmd.step);
        test_step.dependOn(&run_test.step);
    } else {
        // Normal test run without filter
        const run_test = b.addRunArtifact(exe_unit_tests);
        test_step.dependOn(&run_test.step);
    }
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
        const shared_path = std.fmt.allocPrint(std.heap.page_allocator, "{s}/{s}", .{ path, lib_prefixed }) catch continue;
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

    // Common C flags following castholm's approach
    const sdl_c_flags = &[_][]const u8{
        "-Wall",
        "-Wundef",
        "-Wfloat-conversion",
        "-fno-strict-aliasing",
        "-Wshadow",
        "-Wno-unused-local-typedefs",
        "-Wimplicit-fallthrough",
        "-pthread",
        // Add build configuration - critical for proper compilation
        "-DSDL_BUILD_MAJOR_VERSION=3",
        "-DSDL_BUILD_MINOR_VERSION=3",
        "-DSDL_BUILD_MICRO_VERSION=0",
        "-DSDL_STATIC_LIB=1",
    };

    // Core SDL source files (based on castholm's proven list)
    const core_files = [_][]const u8{
        "deps/SDL/src/SDL.c",
        "deps/SDL/src/SDL_assert.c",
        "deps/SDL/src/SDL_error.c",
        "deps/SDL/src/SDL_guid.c",
        "deps/SDL/src/SDL_hashtable.c",
        "deps/SDL/src/SDL_hints.c",
        "deps/SDL/src/SDL_list.c", // MISSING - critical
        "deps/SDL/src/SDL_log.c",
        "deps/SDL/src/SDL_properties.c",
        "deps/SDL/src/SDL_utils.c",
        // Atomic
        "deps/SDL/src/atomic/SDL_atomic.c",
        "deps/SDL/src/atomic/SDL_spinlock.c",
        // Audio
        "deps/SDL/src/audio/SDL_audio.c",
        "deps/SDL/src/audio/SDL_audiocvt.c",
        "deps/SDL/src/audio/SDL_audiodev.c",
        "deps/SDL/src/audio/SDL_audioqueue.c",
        "deps/SDL/src/audio/SDL_audioresample.c",
        "deps/SDL/src/audio/SDL_audiotypecvt.c",
        "deps/SDL/src/audio/SDL_mixer.c",
        "deps/SDL/src/audio/SDL_wave.c",
        // Camera
        "deps/SDL/src/camera/SDL_camera.c",
        // Core
        "deps/SDL/src/core/SDL_core_unsupported.c", // MISSING - critical
        // CPU info
        "deps/SDL/src/cpuinfo/SDL_cpuinfo.c",
        // Dynamic API (needed for proper symbol exports)
        "deps/SDL/src/dynapi/SDL_dynapi.c",
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
        // Filesystem
        "deps/SDL/src/filesystem/SDL_filesystem.c",
        // GPU
        "deps/SDL/src/gpu/SDL_gpu.c",
        // Haptic
        "deps/SDL/src/haptic/SDL_haptic.c",
        // HID API (minimal stub implementation)
        "deps/SDL/src/hidapi/SDL_hidapi.c",
        // IO
        "deps/SDL/src/io/SDL_asyncio.c",
        "deps/SDL/src/io/SDL_iostream.c",
        "deps/SDL/src/io/generic/SDL_asyncio_generic.c",
        // Joystick
        "deps/SDL/src/joystick/SDL_gamepad.c",
        "deps/SDL/src/joystick/SDL_joystick.c",
        "deps/SDL/src/joystick/SDL_steam_virtual_gamepad.c",
        "deps/SDL/src/joystick/controller_type.c",
        // Locale
        "deps/SDL/src/locale/SDL_locale.c",
        // Main
        "deps/SDL/src/main/SDL_main_callbacks.c",
        "deps/SDL/src/main/SDL_runapp.c",
        // Misc
        "deps/SDL/src/misc/SDL_url.c",
        // Power
        "deps/SDL/src/power/SDL_power.c",
        // Render
        "deps/SDL/src/render/SDL_d3dmath.c",
        "deps/SDL/src/render/SDL_render.c",
        "deps/SDL/src/render/SDL_render_unsupported.c",
        "deps/SDL/src/render/SDL_yuv_sw.c",
        // Software Renderer (MISSING - critical for SW_CreateRendererForSurface)
        "deps/SDL/src/render/software/SDL_blendfillrect.c",
        "deps/SDL/src/render/software/SDL_blendline.c",
        "deps/SDL/src/render/software/SDL_blendpoint.c",
        "deps/SDL/src/render/software/SDL_drawline.c",
        "deps/SDL/src/render/software/SDL_drawpoint.c",
        "deps/SDL/src/render/software/SDL_render_sw.c",
        "deps/SDL/src/render/software/SDL_rotate.c",
        "deps/SDL/src/render/software/SDL_triangle.c",
        // GPU Renderers
        "deps/SDL/src/render/gpu/SDL_pipeline_gpu.c",
        "deps/SDL/src/render/gpu/SDL_render_gpu.c",
        "deps/SDL/src/render/gpu/SDL_shaders_gpu.c",
        // OpenGL Renderers
        "deps/SDL/src/render/opengl/SDL_render_gl.c",
        "deps/SDL/src/render/opengl/SDL_shaders_gl.c",
        "deps/SDL/src/render/opengles2/SDL_render_gles2.c",
        "deps/SDL/src/render/opengles2/SDL_shaders_gles2.c",
        // Vulkan Renderer
        "deps/SDL/src/render/vulkan/SDL_render_vulkan.c",
        "deps/SDL/src/render/vulkan/SDL_shaders_vulkan.c",
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
        "deps/SDL/src/stdlib/SDL_mslibc.c", // MISSING - critical for Windows
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
        // YUV to RGB converters
        "deps/SDL/src/video/yuv2rgb/yuv_rgb_lsx.c",
        "deps/SDL/src/video/yuv2rgb/yuv_rgb_sse.c",
        "deps/SDL/src/video/yuv2rgb/yuv_rgb_std.c",
        // Dialog
        "deps/SDL/src/dialog/SDL_dialog.c",
        "deps/SDL/src/dialog/SDL_dialog_utils.c",
        // Process
        "deps/SDL/src/process/SDL_process.c",
        // Tray
        "deps/SDL/src/tray/SDL_tray_utils.c",
    };

    // Add libm math functions (CRITICAL - provides SDL_uclibc_* functions)
    const libm_files = [_][]const u8{
        "deps/SDL/src/libm/e_atan2.c",
        "deps/SDL/src/libm/e_exp.c",
        "deps/SDL/src/libm/e_fmod.c",
        "deps/SDL/src/libm/e_log.c",
        "deps/SDL/src/libm/e_log10.c",
        "deps/SDL/src/libm/e_pow.c",
        "deps/SDL/src/libm/e_rem_pio2.c",
        "deps/SDL/src/libm/e_sqrt.c",
        "deps/SDL/src/libm/k_cos.c",
        "deps/SDL/src/libm/k_rem_pio2.c",
        "deps/SDL/src/libm/k_sin.c",
        "deps/SDL/src/libm/k_tan.c",
        "deps/SDL/src/libm/s_atan.c",
        "deps/SDL/src/libm/s_copysign.c",
        "deps/SDL/src/libm/s_cos.c",
        "deps/SDL/src/libm/s_fabs.c",
        "deps/SDL/src/libm/s_floor.c",
        "deps/SDL/src/libm/s_isinf.c",
        "deps/SDL/src/libm/s_isinff.c",
        "deps/SDL/src/libm/s_isnan.c",
        "deps/SDL/src/libm/s_isnanf.c",
        "deps/SDL/src/libm/s_modf.c",
        "deps/SDL/src/libm/s_scalbn.c",
        "deps/SDL/src/libm/s_sin.c",
        "deps/SDL/src/libm/s_tan.c",
    };

    // Add all core files
    sdl3.addCSourceFiles(.{
        .files = &core_files,
        .flags = sdl_c_flags,
    });

    // Add libm files for static library (provides SDL_uclibc_* functions)
    sdl3.addCSourceFiles(.{
        .files = &libm_files,
        .flags = sdl_c_flags,
    });

    // Add platform-specific files for Linux
    if (target.result.os.tag == .linux) {
        const linux_files = [_][]const u8{
            // Audio drivers (only dummy and disk)
            "deps/SDL/src/audio/dummy/SDL_dummyaudio.c",
            "deps/SDL/src/audio/disk/SDL_diskaudio.c",
            // Camera (only dummy)
            "deps/SDL/src/camera/dummy/SDL_camera_dummy.c",
            // "deps/SDL/src/camera/v4l2/SDL_camera_v4l2.c", // Disabled
            // Core Unix/Linux
            "deps/SDL/src/core/unix/SDL_appid.c",
            "deps/SDL/src/core/unix/SDL_poll.c",
            "deps/SDL/src/core/unix/SDL_gtk.c", // CRITICAL - provides SDL_Gtk_Quit
            // Skip DBUS-dependent files since we disabled DBUS support
            // "deps/SDL/src/core/linux/SDL_dbus.c",
            // "deps/SDL/src/core/linux/SDL_system_theme.c",
            // "deps/SDL/src/core/linux/SDL_ime.c",
            // "deps/SDL/src/core/linux/SDL_ibus.c",
            // "deps/SDL/src/core/linux/SDL_fcitx.c",
            // "deps/SDL/src/core/linux/SDL_udev.c", // Disabled (requires libudev)
            "deps/SDL/src/core/linux/SDL_evdev.c",
            "deps/SDL/src/core/linux/SDL_evdev_kbd.c",
            "deps/SDL/src/core/linux/SDL_evdev_capabilities.c",
            "deps/SDL/src/core/linux/SDL_threadprio.c", // CRITICAL - provides SDL_SetLinuxThreadPriorityAndPolicy_REAL
            // Dummy drivers
            "deps/SDL/src/joystick/virtual/SDL_virtualjoystick.c",
            "deps/SDL/src/video/dummy/SDL_nullevents.c",
            "deps/SDL/src/video/dummy/SDL_nullframebuffer.c",
            "deps/SDL/src/video/dummy/SDL_nullvideo.c",
            "deps/SDL/src/sensor/dummy/SDL_dummysensor.c",
            // Filesystem
            "deps/SDL/src/filesystem/unix/SDL_sysfilesystem.c",
            "deps/SDL/src/filesystem/posix/SDL_sysfsops.c",
            // Haptic
            "deps/SDL/src/haptic/linux/SDL_syshaptic.c",
            // Skip HIDAPI (disabled to avoid libudev dependency)
            "deps/SDL/src/joystick/linux/SDL_sysjoystick.c",
            // IO
            "deps/SDL/src/io/io_uring/SDL_asyncio_liburing.c",
            // Loadso
            "deps/SDL/src/loadso/dlopen/SDL_sysloadso.c",
            // Locale
            "deps/SDL/src/locale/unix/SDL_syslocale.c",
            // Main
            "deps/SDL/src/main/generic/SDL_sysmain_callbacks.c",
            // Misc
            "deps/SDL/src/misc/unix/SDL_sysurl.c",
            // Power
            "deps/SDL/src/power/linux/SDL_syspower.c",
            // Process
            "deps/SDL/src/process/posix/SDL_posixprocess.c",
            // Storage
            "deps/SDL/src/storage/generic/SDL_genericstorage.c",
            "deps/SDL/src/storage/steam/SDL_steamstorage.c",
            // Thread
            "deps/SDL/src/thread/pthread/SDL_systhread.c",
            "deps/SDL/src/thread/pthread/SDL_sysmutex.c",
            "deps/SDL/src/thread/pthread/SDL_syscond.c",
            "deps/SDL/src/thread/pthread/SDL_sysrwlock.c",
            "deps/SDL/src/thread/pthread/SDL_systls.c",
            "deps/SDL/src/thread/pthread/SDL_syssem.c",
            // Time
            "deps/SDL/src/time/unix/SDL_systime.c",
            // Timer
            "deps/SDL/src/timer/unix/SDL_systimer.c",
            // Tray
            "deps/SDL/src/tray/unix/SDL_tray.c",
            // Dialog
            "deps/SDL/src/dialog/unix/SDL_unixdialog.c",
            "deps/SDL/src/dialog/unix/SDL_portaldialog.c",
            "deps/SDL/src/dialog/unix/SDL_zenitydialog.c",
            // Video drivers (X11 core, some extensions disabled)
            "deps/SDL/src/video/x11/SDL_x11stubs.c", // Stubs for disabled extensions
            "deps/SDL/src/video/x11/SDL_x11clipboard.c",
            "deps/SDL/src/video/x11/SDL_x11dyn.c",
            "deps/SDL/src/video/x11/SDL_x11events.c",
            "deps/SDL/src/video/x11/SDL_x11framebuffer.c",
            "deps/SDL/src/video/x11/SDL_x11keyboard.c",
            "deps/SDL/src/video/x11/SDL_x11messagebox.c",
            "deps/SDL/src/video/x11/SDL_x11modes.c",
            "deps/SDL/src/video/x11/SDL_x11mouse.c",
            "deps/SDL/src/video/x11/SDL_x11opengl.c",
            "deps/SDL/src/video/x11/SDL_x11opengles.c",
            "deps/SDL/src/video/x11/SDL_x11pen.c",
            "deps/SDL/src/video/x11/SDL_x11settings.c",
            // "deps/SDL/src/video/x11/SDL_x11shape.c",     // Disabled (XSHAPE)
            "deps/SDL/src/video/x11/SDL_x11touch.c",
            "deps/SDL/src/video/x11/SDL_x11video.c",
            "deps/SDL/src/video/x11/SDL_x11vulkan.c",
            "deps/SDL/src/video/x11/SDL_x11window.c",
            // "deps/SDL/src/video/x11/SDL_x11xfixes.c",    // Disabled (XFIXES)
            "deps/SDL/src/video/x11/SDL_x11xinput2.c",
            // "deps/SDL/src/video/x11/SDL_x11xsync.c",     // Disabled (XSYNC)
            "deps/SDL/src/video/x11/edid-parse.c",
            "deps/SDL/src/video/x11/xsettings-client.c",
            // Skip KMS/DRM and Wayland video drivers (external dependencies disabled)
            // Offscreen
            "deps/SDL/src/video/offscreen/SDL_offscreenevents.c",
            "deps/SDL/src/video/offscreen/SDL_offscreenframebuffer.c",
            "deps/SDL/src/video/offscreen/SDL_offscreenopengles.c",
            "deps/SDL/src/video/offscreen/SDL_offscreenvideo.c",
            "deps/SDL/src/video/offscreen/SDL_offscreenvulkan.c",
            "deps/SDL/src/video/offscreen/SDL_offscreenwindow.c",
            // GPU backends
            "deps/SDL/src/gpu/vulkan/SDL_gpu_vulkan.c",
        };

        sdl3.addCSourceFiles(.{
            .files = &linux_files,
            .flags = sdl_c_flags,
        });
    }

    // Include paths (critical for compilation)
    sdl3.addIncludePath(b.path("deps/SDL/include"));
    sdl3.addIncludePath(b.path("deps/SDL/src"));
    // Use our custom build config instead of generated one
    sdl3.addIncludePath(b.path("deps/SDL/include/build_config"));
    // Add system include for Khronos headers
    sdl3.addSystemIncludePath(b.path("deps/SDL/src/video/khronos"));

    // Link system libraries
    if (target.result.os.tag == .linux) {
        // Required libraries (no optional detection - just link what we need)
        sdl3.linkSystemLibrary("m");
        sdl3.linkSystemLibrary("dl");
        sdl3.linkSystemLibrary("pthread");
        sdl3.linkSystemLibrary("rt");
        sdl3.linkSystemLibrary("X11");
        sdl3.linkSystemLibrary("Xext");
        sdl3.linkSystemLibrary("Xrandr");
        sdl3.linkSystemLibrary("Xrender");
        sdl3.linkSystemLibrary("Xi");
        sdl3.linkSystemLibrary("Xfixes");
        sdl3.linkSystemLibrary("Xcursor");
        // Audio libraries (dynamic linking)
        // We skip these to avoid dependency issues but keep dummy drivers working
        // GPU libraries
        sdl3.linkSystemLibrary("vulkan");
    }

    sdl3.linkLibC();
    return sdl3;
}
