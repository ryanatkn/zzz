/**
 * AI Behavior Patterns
 * Reusable behavior modules for the story controller
 */

import type { Vec2, ActionSequence } from '../core/types.js';
import { Keys } from '../core/types.js';
import { ZONES, COMBAT, PATTERNS, AI_BEHAVIOR } from '../core/constants.js';

export class Behaviors {
  /**
   * Exploration behavior - methodically search an area
   */
  static explore(center: Vec2, radius: number = 200): ActionSequence {
    const actions: ActionSequence = [];
    
    // Spiral outward pattern
    const spiralPoints = this.generateSpiral(center, radius);
    
    for (const point of spiralPoints) {
      actions.push({
        type: 'move',
        data: { position: point, speed: 1 }
      });
      
      // Look around at each point
      actions.push({
        type: 'wait',
        duration: 500
      });
    }
    
    return actions;
  }

  /**
   * Combat engagement - fight enemies intelligently
   */
  static combat(enemyPositions: Vec2[], playerPos: Vec2): ActionSequence {
    const actions: ActionSequence = [];
    
    for (const enemy of enemyPositions) {
      // Strafe while shooting
      const strafePoints = PATTERNS.CIRCLE_STRAFE(enemy, AI_BEHAVIOR.KITING_DISTANCE, 8);
      
      for (let i = 0; i < strafePoints.length; i++) {
        // Move to strafe position
        actions.push({
          type: 'move',
          data: { position: strafePoints[i], speed: 2 }
        });
        
        // Shoot at enemy
        actions.push({
          type: 'shoot',
          data: { target: enemy, burst: true }
        });
        
        // Small pause between positions
        actions.push({
          type: 'wait',
          duration: 200
        });
      }
    }
    
    return actions;
  }

  /**
   * Retreat behavior - escape from danger
   */
  static retreat(threatPos: Vec2): ActionSequence {
    const actions: ActionSequence = [];
    
    // Calculate retreat position
    const retreatPos = PATTERNS.RETREAT(threatPos, AI_BEHAVIOR.RETREAT_DISTANCE);
    
    // Use zigzag pattern for evasion
    const zigzagPath = PATTERNS.ZIGZAG(
      { x: 400, y: 300 },
      retreatPos,
      50
    );
    
    for (const point of zigzagPath) {
      actions.push({
        type: 'move',
        data: { position: point, speed: 3 }
      });
    }
    
    // Cast defensive spell if available
    actions.push({
      type: 'spell',
      data: { slot: 0, target: threatPos, selfCast: false } // Lull
    });
    
    return actions;
  }

  /**
   * Boss fight behavior - complex combat pattern
   */
  static bossFight(bossPos: Vec2): ActionSequence {
    const actions: ActionSequence = [];
    
    // Phase 1: Initial positioning
    actions.push({
      type: 'move',
      data: { position: { x: bossPos.x, y: bossPos.y + 200 }, speed: 1 }
    });
    
    // Phase 2: Opening salvo
    for (let i = 0; i < 3; i++) {
      actions.push({
        type: 'shoot',
        data: { target: bossPos, burst: true }
      });
      actions.push({
        type: 'wait',
        duration: 500
      });
    }
    
    // Phase 3: Kiting pattern
    const kitePoints = PATTERNS.CIRCLE_STRAFE(bossPos, 250, 12);
    for (let i = 0; i < kitePoints.length; i++) {
      actions.push({
        type: 'move',
        data: { position: kitePoints[i], speed: 2 }
      });
      
      // Shoot every other position
      if (i % 2 === 0) {
        actions.push({
          type: 'shoot',
          data: { target: bossPos, burst: false }
        });
      }
      
      // Cast spell at quarter points
      if (i % 3 === 0) {
        const spellSlot = Math.floor(i / 3) % 4;
        actions.push({
          type: 'spell',
          data: { slot: spellSlot + 3, target: bossPos, selfCast: false }
        });
      }
    }
    
    // Phase 4: Final burst
    actions.push({
      type: 'spell',
      data: { slot: 7, target: bossPos, selfCast: false } // Lightning
    });
    
    for (let i = 0; i < 5; i++) {
      actions.push({
        type: 'shoot',
        data: { target: bossPos, burst: true }
      });
      actions.push({
        type: 'wait',
        duration: 300
      });
    }
    
    return actions;
  }

  /**
   * Portal navigation - move to and enter portal
   */
  static enterPortal(portalPos: Vec2): ActionSequence {
    return [
      {
        type: 'move',
        data: { position: portalPos, speed: 1 }
      },
      {
        type: 'wait',
        duration: 1000
      },
      // Move into portal
      {
        type: 'move',
        data: { position: portalPos, speed: 0.5 }
      },
      {
        type: 'wait',
        duration: 500
      }
    ];
  }

  /**
   * Puzzle solving - interact with environment
   */
  static solvePuzzle(positions: Vec2[]): ActionSequence {
    const actions: ActionSequence = [];
    
    for (const pos of positions) {
      // Move to interaction point
      actions.push({
        type: 'move',
        data: { position: pos, speed: 1 }
      });
      
      // Interact
      actions.push({
        type: 'interact',
        data: { key: Keys.E }
      });
      
      actions.push({
        type: 'wait',
        duration: 1000
      });
    }
    
    return actions;
  }

  /**
   * Patrol behavior - move between waypoints
   */
  static patrol(waypoints: Vec2[]): ActionSequence {
    const actions: ActionSequence = [];
    const patrolPath = PATTERNS.PATROL(waypoints);
    
    for (const point of patrolPath) {
      actions.push({
        type: 'move',
        data: { position: point, speed: 1, walk: true }
      });
      
      // Brief pause at each waypoint
      actions.push({
        type: 'wait',
        duration: 500
      });
    }
    
    return actions;
  }

  /**
   * Stealth movement - avoid enemies
   */
  static stealth(start: Vec2, end: Vec2, enemies: Vec2[]): ActionSequence {
    const actions: ActionSequence = [];
    
    // Calculate path avoiding enemies
    const avoidancePoints = this.calculateAvoidancePath(start, end, enemies);
    
    for (const point of avoidancePoints) {
      actions.push({
        type: 'move',
        data: { position: point, speed: 0.5, walk: true }
      });
    }
    
    // Cast Lull spell if too close to enemies
    const nearbyEnemy = enemies.find(e => 
      Math.hypot(e.x - end.x, e.y - end.y) < AI_BEHAVIOR.ENGAGEMENT_DISTANCE
    );
    
    if (nearbyEnemy) {
      actions.push({
        type: 'spell',
        data: { slot: 0, target: nearbyEnemy, selfCast: false }
      });
    }
    
    return actions;
  }

  /**
   * Helper: Generate spiral points for exploration
   */
  private static generateSpiral(center: Vec2, maxRadius: number): Vec2[] {
    const points: Vec2[] = [];
    const steps = 20;
    const rotations = 3;
    
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      const angle = t * Math.PI * 2 * rotations;
      const radius = t * maxRadius;
      
      points.push({
        x: center.x + Math.cos(angle) * radius,
        y: center.y + Math.sin(angle) * radius
      });
    }
    
    return points;
  }

  /**
   * Helper: Calculate path avoiding enemies
   */
  private static calculateAvoidancePath(start: Vec2, end: Vec2, enemies: Vec2[]): Vec2[] {
    const points: Vec2[] = [];
    const directPath = 10;
    
    for (let i = 0; i <= directPath; i++) {
      const t = i / directPath;
      let x = start.x + (end.x - start.x) * t;
      let y = start.y + (end.y - start.y) * t;
      
      // Adjust position away from nearby enemies
      for (const enemy of enemies) {
        const dist = Math.hypot(enemy.x - x, enemy.y - y);
        if (dist < AI_BEHAVIOR.SAFE_DISTANCE) {
          // Push point away from enemy
          const pushAngle = Math.atan2(y - enemy.y, x - enemy.x);
          const pushForce = (AI_BEHAVIOR.SAFE_DISTANCE - dist) / 2;
          x += Math.cos(pushAngle) * pushForce;
          y += Math.sin(pushAngle) * pushForce;
        }
      }
      
      points.push({ x, y });
    }
    
    return points;
  }
}