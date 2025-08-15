#!/usr/bin/env python3
"""
Example AI control script for Hex game.
Demonstrates how to write commands to the memory-mapped input buffer.
"""

import struct
import mmap
import time
import math
import os

class AIController:
    """Interface to the game's AI input buffer."""
    
    BUFFER_SIZE = 256
    COMMAND_SIZE = 20
    HEADER_SIZE = 20  # magic(4) + version(4) + write_index(4) + read_index(4) + current_frame(4)
    TOTAL_SIZE = HEADER_SIZE + (BUFFER_SIZE * COMMAND_SIZE)
    
    def __init__(self, path=".ai_commands"):
        self.path = path
        self.file = None
        self.mmap = None
        self.write_index = 0
        
    def __enter__(self):
        # Create/open the file
        if not os.path.exists(self.path):
            # Create with correct size
            with open(self.path, 'wb') as f:
                f.write(b'\x00' * self.TOTAL_SIZE)
        
        self.file = open(self.path, 'r+b')
        self.mmap = mmap.mmap(self.file.fileno(), self.TOTAL_SIZE)
        
        # Check magic and version
        magic = struct.unpack('<I', self.mmap[0:4])[0]
        if magic != 0xA1C0DE42:
            # Initialize buffer
            self.mmap[0:4] = struct.pack('<I', 0xA1C0DE42)  # magic
            self.mmap[4:8] = struct.pack('<I', 1)           # version
            self.mmap[8:12] = struct.pack('<I', 0)          # write_index
            self.mmap[12:16] = struct.pack('<I', 0)         # read_index
            self.mmap[16:20] = struct.pack('<I', 0)         # current_frame
        
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.mmap:
            self.mmap.close()
        if self.file:
            self.file.close()
    
    def send_command(self, frame=0, keys=0, mouse_x=0.0, mouse_y=0.0, buttons=0):
        """Send a command to the game."""
        # Read current indices
        write_idx = struct.unpack('<I', self.mmap[8:12])[0]
        read_idx = struct.unpack('<I', self.mmap[12:16])[0]
        
        # Check if buffer is full
        next_write = (write_idx + 1) % self.BUFFER_SIZE
        if next_write == read_idx:
            print("Buffer full, skipping command")
            return False
        
        # Calculate command offset
        cmd_offset = self.HEADER_SIZE + (write_idx * self.COMMAND_SIZE)
        
        # Set valid flag
        buttons |= 0x80
        
        # Pack command: frame(u32) + keys(u64) + mouse_x(f32) + mouse_y(f32) + buttons(u8) + padding(3)
        cmd_data = struct.pack('<IQffBBBB', frame, keys, mouse_x, mouse_y, buttons, 0, 0, 0)
        
        # Write command
        self.mmap[cmd_offset:cmd_offset + self.COMMAND_SIZE] = cmd_data
        
        # Update write index
        self.mmap[8:12] = struct.pack('<I', next_write)
        
        return True
    
    def get_current_frame(self):
        """Get the current frame number from the game."""
        return struct.unpack('<I', self.mmap[16:20])[0]
    
    def clear(self):
        """Clear all pending commands."""
        write_idx = struct.unpack('<I', self.mmap[8:12])[0]
        self.mmap[12:16] = struct.pack('<I', write_idx)  # Set read_index = write_index

# Key mappings
KEY_W = 26
KEY_A = 4
KEY_S = 22
KEY_D = 7
KEY_SPACE = 44
KEY_1 = 30
KEY_2 = 31
KEY_3 = 32
KEY_4 = 33

MOUSE_LEFT = 0x01
MOUSE_RIGHT = 0x02

def demo_movement():
    """Demonstrate basic movement commands."""
    with AIController() as ai:
        print("AI Control Demo - Moving in a square pattern")
        
        # Move right
        print("Moving right...")
        for _ in range(60):  # 1 second at 60 FPS
            ai.send_command(keys=(1 << KEY_D), mouse_x=400, mouse_y=300)
            time.sleep(1/60)
        
        # Move down
        print("Moving down...")
        for _ in range(60):
            ai.send_command(keys=(1 << KEY_S), mouse_x=400, mouse_y=300)
            time.sleep(1/60)
        
        # Move left
        print("Moving left...")
        for _ in range(60):
            ai.send_command(keys=(1 << KEY_A), mouse_x=400, mouse_y=300)
            time.sleep(1/60)
        
        # Move up
        print("Moving up...")
        for _ in range(60):
            ai.send_command(keys=(1 << KEY_W), mouse_x=400, mouse_y=300)
            time.sleep(1/60)
        
        print("Movement demo complete!")

def demo_combat():
    """Demonstrate shooting at enemies."""
    with AIController() as ai:
        print("AI Control Demo - Combat")
        
        # Shoot in a circle pattern
        for angle in range(0, 360, 10):
            rad = math.radians(angle)
            target_x = 400 + 200 * math.cos(rad)
            target_y = 300 + 200 * math.sin(rad)
            
            print(f"Shooting at ({target_x:.0f}, {target_y:.0f})")
            
            # Hold left mouse for burst fire
            for _ in range(10):
                ai.send_command(mouse_x=target_x, mouse_y=target_y, buttons=MOUSE_LEFT)
                time.sleep(1/60)
            
            # Release
            ai.send_command(mouse_x=target_x, mouse_y=target_y, buttons=0)
            time.sleep(0.1)

if __name__ == "__main__":
    print("Hex Game AI Control Example")
    print("Make sure the game is running with AI control enabled (press G in game)")
    print("")
    print("1. Movement demo")
    print("2. Combat demo")
    
    choice = input("Select demo (1-2): ")
    
    if choice == "1":
        demo_movement()
    elif choice == "2":
        demo_combat()
    else:
        print("Invalid choice")