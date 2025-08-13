// Centralized C library imports to prevent type mismatches across modules
// All C imports should be added here to maintain type consistency

// SDL3 - Core graphics, input, and windowing + TTF
pub const sdl = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
    @cInclude("SDL3_ttf/SDL_textengine.h");
});

// For compatibility, alias ttf to sdl
pub const ttf = sdl;

// Future C libraries can be added here as separate constants:
// pub const opengl = @cImport({ @cInclude("GL/gl.h"); });
// pub const curl = @cImport({ @cInclude("curl/curl.h"); });
