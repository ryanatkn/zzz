# AI Control System - Instructions

## Quick Start

1. **Start the game**: `zig build run`
2. **Enable AI control in game**: Press `G` key
   - You should see "AI control: true" in the console
3. **Start the web interface**: `npm run dev` (in another terminal)
4. **Open browser**: http://localhost:3000
5. **Use the AI control interface** to send commands

## Important Notes

- **AI mode MUST be enabled** (press G) for commands to work
- The game reads from `.ai_commands` file when AI mode is active
- Commands are being sent successfully (check Node.js console logs)
- The issue you're seeing is that AI mode wasn't enabled in the game

## Debugging

To verify the system is working:

1. Check the Node.js console for command logs:
   ```
   📤 Command #1: Frame=0 Mouse=(400,300) Buttons=0 Keys: [W]
   ```

2. Check if AI mode is enabled in game:
   - Press G and look for: `info: ai_toggle AI control: true`

3. Check the command buffer file:
   ```bash
   hexdump -C .ai_commands | head -5
   ```
   Should show magic number `42 de c0 a1`

## Key Mappings

The system only supports SDL scancodes 0-63 in the bitfield:
- A = bit 4
- D = bit 7  
- S = bit 22
- W = bit 26
- SPACE = bit 44
- Number keys 1-9 = bits 30-38

Note: Modifier keys (Shift, Ctrl) are beyond the 64-bit range and cannot be used.