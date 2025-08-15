# SDL Vendoring Credits

## SDL Build Configuration

The Zig build configuration for SDL in `deps/SDL/build.zig` and `deps/SDL/build.zig.zon` is based on work by:

- **Carl Åstholm** (castholm)
  - Repository: https://github.com/castholm/SDL
  - License: MIT
  - © 2024 Carl Åstholm

This build configuration has been adapted for the Zzz project with the following modifications:
- Disabled Wayland and KMS/DRM video drivers for simplified vendoring
- Disabled joystick and haptic subsystems per project requirements
- Added dummy implementations for unsupported subsystems
- Fixed missing configuration values for xkbcommon and X11 extensions

## SDL

The SDL library itself is:
- **SDL**: Copyright (C) 1997-2024 Sam Lantinga and contributors
  - Repository: https://github.com/libsdl-org/SDL
  - License: zlib license

## webref

Machine-readable references of terms defined in web browser specifications -
https://github.com/w3c/webref

## Current Versions

- **webref**: main
  - Repository: https://github.com/w3c/webref.git
  - Commit: 17f080039cfa6e14044c292d1643af0a3ddd86ce
  - Last Updated: 2025-08-15 02:54:51 UTC

- **SDL**: main
  - Repository: https://github.com/libsdl-org/SDL.git
  - Commit: 29cff6e2645cd7d637c502af11a9e3cf8063ccdf
  - Last Updated: 2025-08-13 17:55:50 UTC


## Note

The source code in deps/SDL has been kept unmodified from the original repository to maintain compatibility and ease of updates. Only the build configuration files have been modified.
