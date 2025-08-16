#!/usr/bin/env tsx
/**
 * Command-line demo runner for AI control
 * Usage: tsx ai_control_demo.ts [movement|combat]
 */

import { demoMovement, demoCombat } from './ai_control_example.ts';

async function main() {
  const command = process.argv[2];
  
  console.log('🎮 Hex Game AI Control Demo');
  console.log('Make sure the game is running and AI control is enabled (press G in game)\n');
  
  switch (command) {
    case 'movement':
      await demoMovement();
      break;
    case 'combat':
      await demoCombat();
      break;
    default:
      console.log('Usage: tsx ai_control_demo.ts [movement|combat]');
      console.log('  movement - Move in a square pattern');
      console.log('  combat   - Shoot in a circle pattern');
      process.exit(1);
  }
  
  process.exit(0);
}

main().catch(console.error);