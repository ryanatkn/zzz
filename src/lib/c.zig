// Centralized C library imports to prevent type mismatches across modules
// All C imports should be added here to maintain type consistency

// SDL3 - Core graphics, input, and windowing
pub const sdl = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});

// Future C libraries can be added here as separate constants:
// pub const opengl = @cImport({ @cInclude("GL/gl.h"); });
// pub const curl = @cImport({ @cInclude("curl/curl.h"); });
