# SDL Vendoring Credits

## SDL Build Configuration

The Zig build configuration for SDL in `deps/SDL/build.zig` and `deps/SDL/build.zig.zon` is based on work by:

- **Carl Åstholm** (castholm)
  - Repository: https://github.com/castholm/SDL
  - License: MIT
  - © 2024 Carl Åstholm

This build configuration has been adapted for the Dealt project with the following modifications:
- Disabled Wayland and KMS/DRM video drivers for simplified vendoring
- Disabled joystick and haptic subsystems per project requirements
- Added dummy implementations for unsupported subsystems
- Fixed missing configuration values for xkbcommon and X11 extensions

## SDL and SDL_ttf

The SDL and SDL_ttf libraries themselves are:
- **SDL**: Copyright (C) 1997-2024 Sam Lantinga and contributors
  - Repository: https://github.com/libsdl-org/SDL
  - License: zlib license
- **SDL_ttf**: Copyright (C) 1997-2024 Sam Lantinga and contributors
  - Repository: https://github.com/libsdl-org/SDL_ttf
  - License: zlib license

## Current Versions

- **SDL**: main
  - Repository: https://github.com/libsdl-org/SDL.git
  - Commit: 29cff6e2645cd7d637c502af11a9e3cf8063ccdf
  - Last Updated: 2025-08-13 17:55:50 UTC

- **SDL_ttf**: main
  - Repository: https://github.com/libsdl-org/SDL_ttf.git
  - Commit: 67eced52533771474d38e38c348eba7c1fc2bbea
  - Last Updated: 2025-08-13 17:55:50 UTC


## Note

The source code in deps/SDL and deps/SDL_ttf has been kept unmodified from the original repositories to maintain compatibility and ease of updates. Only the build configuration files have been modified.
