import * as THREE from "three";
import { Unit } from "../entities/Unit";
import { Building } from "../entities/Building";
import { Projectile } from "../entities/Projectile";
import { PathfindingSystem } from "./PathfindingSystem";
import { ParticleEffects } from "../rendering/ParticleEffects";
import { eventBus } from "../game/EventBus";

export class CombatSystem {
  private scene: THREE.Scene;
  private pathfinder: PathfindingSystem;
  private particles: ParticleEffects;
  public projectiles: Projectile[] = [];

  constructor(scene: THREE.Scene, pathfinder: PathfindingSystem, particles: ParticleEffects) {
    this.scene = scene;
    this.pathfinder = pathfinder;
    this.particles = particles;
  }

  public orderAttack(unit: Unit, target: Unit | Building): void {
    unit.currentOrder = "attack";
    unit.target = target;

    const path = this.pathfinder.findPath(
      unit.position.x,
      unit.position.z,
      target.position.x,
      target.position.z
    );

    if (path.length > 0) {
      unit.path = path;
      unit.currentWaypointIndex = 0;
      unit.state = "moving";
    }
  }

  public update(
    allUnits: Unit[],
    buildings: Building[],
    dt: number
  ): { defeatedUnits: Unit[]; destroyedBuildings: Building[] } {
    const defeatedUnits: Unit[] = [];
    const destroyedBuildings: Building[] = [];

    // 1. Update active projectiles
    for (let i = this.projectiles.length - 1; i >= 0; i--) {
      const proj = this.projectiles[i];
      const hit = proj.update(dt);
      if (hit) {
        this.particles.spawnHitEffect(proj.mesh.position.x, proj.mesh.position.y, proj.mesh.position.z);
        eventBus.emit("sound", { soundName: "attack_hit" });
        this.projectiles.splice(i, 1);
      }
    }

    // 2. Towers & Defensive Buildings
    for (const b of buildings) {
      if (!b.isAlive || !b.isConstructed || !b.config.attackRange) continue;

      b.attackTimer -= dt;
      if (b.attackTimer <= 0) {
        // Find closest enemy in range
        let closestEnemy: Unit | null = null;
        let minDist = b.config.attackRange;

        for (const u of allUnits) {
          if (u.faction === "enemy" && u.isAlive) {
            const d = Math.hypot(u.position.x - b.position.x, u.position.z - b.position.z);
            if (d < minDist) {
              minDist = d;
              closestEnemy = u;
            }
          }
        }

        if (closestEnemy) {
          b.attackTimer = b.config.attackCooldown || 1.2;
          const launchPos = new THREE.Vector3(b.position.x, b.position.y + 2.4, b.position.z);
          const proj = new Projectile(this.scene, launchPos, closestEnemy, b.config.attackDamage || 15);
          this.projectiles.push(proj);
          eventBus.emit("sound", { soundName: "arrow_shot" });
        }
      }
    }

    // 3. Units Combat & AI
    for (const u of allUnits) {
      if (!u.isAlive) continue;

      u.attackTimer -= dt;

      // Friendly auto-acquire targets (Guard & Archer when idle or defending)
      if (u.faction === "player" && (u.state === "idle" || u.currentOrder === "defend")) {
        if (u.type === "guard" || u.type === "archer") {
          const scanRange = u.type === "archer" ? 8 : 5;
          const target = this.findNearestHostile(u, allUnits, scanRange);
          if (target) {
            this.orderAttack(u, target);
          }
        }
      }

      // Enemy AI: Find closest player unit or building
      if (u.faction === "enemy") {
        if (u.state === "idle" || !u.target || !(u.target as any).isAlive) {
          const target = this.findEnemyTarget(u, allUnits, buildings);
          if (target) {
            this.orderAttack(u, target);
          }
        }
      }

      // Execute attack if target is in range
      if (u.currentOrder === "attack" && u.target) {
        const target = u.target as Unit | Building;
        if (!target.isAlive) {
          u.state = "idle";
          u.target = null;
          continue;
        }

        const dist = Math.hypot(u.position.x - target.position.x, u.position.z - target.position.z);

        if (dist <= u.attackRange) {
          u.state = "attacking";
          u.path = []; // Stop moving

          // Look at target
          const dx = target.position.x - u.position.x;
          const dz = target.position.z - u.position.z;
          u.rotation = Math.atan2(dx, dz);

          if (u.attackTimer <= 0) {
            u.attackTimer = u.attackCooldown;

            if (u.type === "archer") {
              // Ranged projectile
              const launchPos = new THREE.Vector3(u.position.x, u.position.y + 0.8, u.position.z);
              const proj = new Projectile(this.scene, launchPos, target, u.attackDamage);
              this.projectiles.push(proj);
              eventBus.emit("sound", { soundName: "arrow_shot" });
            } else {
              // Melee attack
              const dead = target.takeDamage(u.attackDamage);
              this.particles.spawnHitEffect(target.position.x, target.position.y, target.position.z);
              eventBus.emit("sound", { soundName: "attack_hit" });

              if (dead) {
                if (target instanceof Unit) {
                  defeatedUnits.push(target);
                  eventBus.emit("sound", { soundName: "death" });
                } else if (target instanceof Building) {
                  destroyedBuildings.push(target);
                  eventBus.emit("toast", { message: `Building destroyed: ${target.config.name}!`, type: "danger" });
                }
                u.state = "idle";
                u.target = null;
              }
            }
          }
        } else {
          // Repath if target moved far from current path end
          if (u.state !== "moving" || u.path.length === 0) {
            this.orderAttack(u, target);
          }
        }
      }
    }

    // Clean up dead units
    for (const u of allUnits) {
      if (!u.isAlive && !defeatedUnits.includes(u)) {
        defeatedUnits.push(u);
      }
    }

    return { defeatedUnits, destroyedBuildings };
  }

  private findNearestHostile(fromUnit: Unit, allUnits: Unit[], maxRange: number): Unit | null {
    let closest: Unit | null = null;
    let minDist = maxRange;

    for (const u of allUnits) {
      if (u.faction !== fromUnit.faction && u.isAlive) {
        const d = Math.hypot(u.position.x - fromUnit.position.x, u.position.z - fromUnit.position.z);
        if (d < minDist) {
          minDist = d;
          closest = u;
        }
      }
    }

    return closest;
  }

  private findEnemyTarget(enemy: Unit, allUnits: Unit[], buildings: Building[]): Unit | Building | null {
    // Fast enemies prefer workers and archers; Melee enemies prefer buildings and camp
    let bestTarget: Unit | Building | null = null;
    let minScore = Infinity;

    // Evaluate friendly units
    for (const u of allUnits) {
      if (u.faction === "player" && u.isAlive) {
        const d = Math.hypot(u.position.x - enemy.position.x, u.position.z - enemy.position.z);
        let priority = 10;
        if (enemy.type === "enemy_fast" && (u.type === "worker" || u.type === "archer")) {
          priority = 2; // Fast enemies seek weak targets
        }
        const score = d * priority;
        if (score < minScore) {
          minScore = score;
          bestTarget = u;
        }
      }
    }

    // Evaluate buildings
    for (const b of buildings) {
      if (b.isAlive) {
        const d = Math.hypot(b.position.x - enemy.position.x, b.position.z - enemy.position.z);
        let priority = 8;
        if (b.type === "campfire") priority = 5; // High value target
        if (b.type === "wall" || b.type === "gate") priority = 12; // Wall is lower priority unless blocking

        const score = d * priority;
        if (score < minScore) {
          minScore = score;
          bestTarget = b;
        }
      }
    }

    return bestTarget;
  }
}
