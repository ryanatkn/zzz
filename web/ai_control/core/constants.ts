/**
 * Game Constants and Knowledge Base for AI
 * Contains hardcoded game information for intelligent gameplay
 */

import type { Vec2 } from './types.js';

// Screen dimensions
export const SCREEN = {
  WIDTH: 800,
  HEIGHT: 600,
  CENTER: { x: 400, y: 300 } as Vec2
};

// Zone information
export const ZONES = {
  OVERWORLD: {
    name: 'Overworld',
    spawns: [
      { x: 600, y: 300 },  // Right spawn
      { x: 200, y: 300 },  // Left spawn
      { x: 400, y: 150 },  // Top spawn
      { x: 400, y: 450 },  // Bottom spawn
    ],
    portals: [
      { position: { x: 750, y: 300 }, leadsTo: 'DUNGEON_1' },
      { position: { x: 50, y: 300 }, leadsTo: 'FOREST' },
    ],
    safeZones: [
      { x: 400, y: 300, radius: 100 }  // Starting area
    ]
  },
  DUNGEON_1: {
    name: 'Dungeon Level 1',
    spawns: [
      { x: 200, y: 200 },
      { x: 600, y: 200 },
      { x: 200, y: 400 },
      { x: 600, y: 400 },
    ],
    portals: [
      { position: { x: 50, y: 300 }, leadsTo: 'OVERWORLD' },
      { position: { x: 400, y: 50 }, leadsTo: 'DUNGEON_2' },
    ],
    hazards: [
      { x: 400, y: 300, radius: 50 }  // Central trap
    ]
  },
  DUNGEON_2: {
    name: 'Boss Chamber',
    spawns: [
      { x: 400, y: 200 },  // Boss spawn
    ],
    portals: [
      { position: { x: 400, y: 550 }, leadsTo: 'DUNGEON_1' },
    ],
    bossArea: { x: 400, y: 200, radius: 150 }
  },
  FOREST: {
    name: 'Dark Forest',
    spawns: [
      { x: 300, y: 200 },
      { x: 500, y: 200 },
      { x: 300, y: 400 },
      { x: 500, y: 400 },
      { x: 400, y: 300 },
    ],
    portals: [
      { position: { x: 750, y: 300 }, leadsTo: 'OVERWORLD' },
    ],
    ambushPoints: [
      { x: 400, y: 250 },
      { x: 400, y: 350 },
    ]
  }
};

// Combat constants
export const COMBAT = {
  BULLET_SPEED: 300,  // Units per second
  BULLET_LIFETIME: 4000,  // Milliseconds
  BULLET_POOL_SIZE: 6,
  BULLET_RECHARGE_RATE: 2,  // Per second
  RHYTHM_INTERVAL: 150,  // Milliseconds between rhythm shots
  ENEMY_AGGRO_RANGE: 200,
  ENEMY_ATTACK_RANGE: 150,
  PLAYER_SPEED: 100,  // Units per second
  PLAYER_WALK_SPEED: 50,  // Units per second
};

// Spell information
export const SPELLS = {
  SLOTS: {
    0: { name: 'Lull', cooldown: 5000, range: 150, effect: 'reduce_aggro' },
    1: { name: 'Blink', cooldown: 3000, range: 200, effect: 'teleport' },
    2: { name: 'Shield', cooldown: 8000, range: 0, effect: 'damage_reduction' },
    3: { name: 'Burst', cooldown: 6000, range: 100, effect: 'aoe_damage' },
    4: { name: 'Heal', cooldown: 10000, range: 0, effect: 'restore_health' },
    5: { name: 'Speed', cooldown: 7000, range: 0, effect: 'movement_boost' },
    6: { name: 'Freeze', cooldown: 5000, range: 200, effect: 'enemy_slow' },
    7: { name: 'Lightning', cooldown: 4000, range: 300, effect: 'chain_damage' },
  }
};

// Common movement patterns
export const PATTERNS = {
  CIRCLE_STRAFE: (center: Vec2, radius: number, steps: number = 36) => {
    const points: Vec2[] = [];
    for (let i = 0; i < steps; i++) {
      const angle = (i / steps) * Math.PI * 2;
      points.push({
        x: center.x + Math.cos(angle) * radius,
        y: center.y + Math.sin(angle) * radius
      });
    }
    return points;
  },
  
  ZIGZAG: (start: Vec2, end: Vec2, amplitude: number = 50) => {
    const points: Vec2[] = [];
    const steps = 10;
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      const x = start.x + (end.x - start.x) * t;
      const y = start.y + (end.y - start.y) * t;
      const offset = (i % 2 === 0 ? 1 : -1) * amplitude;
      // Perpendicular offset
      const dx = end.x - start.x;
      const dy = end.y - start.y;
      const len = Math.sqrt(dx * dx + dy * dy);
      points.push({
        x: x + (-dy / len) * offset,
        y: y + (dx / len) * offset
      });
    }
    return points;
  },
  
  RETREAT: (threat: Vec2, distance: number = 200) => {
    // Move away from threat
    const angle = Math.atan2(SCREEN.CENTER.y - threat.y, SCREEN.CENTER.x - threat.x);
    return {
      x: SCREEN.CENTER.x + Math.cos(angle) * distance,
      y: SCREEN.CENTER.y + Math.sin(angle) * distance
    };
  },
  
  PATROL: (waypoints: Vec2[]) => {
    // Cycle through waypoints
    return [...waypoints, ...waypoints.slice().reverse()];
  }
};

// AI behavior thresholds
export const AI_BEHAVIOR = {
  LOW_HEALTH: 30,  // Percent
  RETREAT_DISTANCE: 300,
  SAFE_DISTANCE: 400,
  ENGAGEMENT_DISTANCE: 150,
  KITING_DISTANCE: 200,
  EXPLORATION_RADIUS: 250,
};

// Story checkpoints
export const STORY_CHECKPOINTS = {
  START: 'game_start',
  FIRST_COMBAT: 'first_enemy_defeated',
  ENTERED_DUNGEON: 'dungeon_entered',
  BOSS_ENCOUNTERED: 'boss_fight_started',
  BOSS_DEFEATED: 'boss_defeated',
  FOREST_EXPLORED: 'forest_completed',
  ALL_ZONES_VISITED: 'world_explored',
};