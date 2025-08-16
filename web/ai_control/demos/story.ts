#!/usr/bin/env npx tsx
/**
 * Story-Driven AI Demo
 * Run autonomous playthroughs with narrative
 */

import { StoryController } from '../story/story_controller.js';
import { Scenarios, type ScenarioType } from '../story/scenarios.js';

async function main() {
  const args = process.argv.slice(2);
  const scenario = (args[0] as ScenarioType) || 'hero';
  const narrative = args[1] !== '--quiet';
  
  console.log('🎮 Hex Game - Story AI Controller');
  console.log('==================================');
  console.log('');
  console.log('📋 Available scenarios:');
  
  for (const s of Scenarios.getAllScenarios()) {
    const desc = Scenarios.getDescription(s);
    const marker = s === scenario ? '➤' : ' ';
    console.log(`${marker} ${s.padEnd(10)} - ${desc}`);
  }
  
  console.log('');
  console.log('🎯 Make sure the game is running first!');
  console.log('');
  console.log('─'.repeat(50));
  console.log('');
  
  const controller = new StoryController();
  
  try {
    await controller.play(scenario, narrative);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

// Show usage if help requested
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log('Usage: npx tsx story.ts [scenario] [--quiet]');
  console.log('');
  console.log('Scenarios:');
  console.log('  hero      - Classic hero\'s journey (default)');
  console.log('  speedrun  - Optimized boss rush');
  console.log('  pacifist  - No combat playthrough');
  console.log('  warrior   - Maximum aggression');
  console.log('  explorer  - Complete exploration');
  console.log('');
  console.log('Options:');
  console.log('  --quiet   - Disable narrative output');
  process.exit(0);
}

main().catch(console.error);