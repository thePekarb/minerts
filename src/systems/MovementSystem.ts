import * as THREE from "three";
import { Unit } from "../entities/Unit";
import { World } from "../world/World";

export class MovementSystem {
  private world: World;

  constructor(world: World) {
    this.world = world;
  }

  public update(units: Unit[], dt: number): void {
    for (let i = 0; i < units.length; i++) {
      const u = units[i];
      if (!u.isAlive) continue;

      // Waypoint following
      if (
        (u.state === "moving" || u.state === "returningToStorage" || u.state === "fleeing") &&
        u.path.length > 0
      ) {
        const wp = u.path[u.currentWaypointIndex];
        if (wp) {
          const dx = wp.x - u.position.x;
          const dz = wp.z - u.position.z;
          const dist = Math.hypot(dx, dz);

          if (dist < 0.25) {
            // Reached waypoint
            u.currentWaypointIndex++;
            if (u.currentWaypointIndex >= u.path.length) {
              // Path completed
              u.path = [];
              u.currentWaypointIndex = 0;
              if (u.state === "moving") {
                u.state = "idle";
              }
            }
          } else {
            // Move toward waypoint
            const moveDist = Math.min(dist, u.speed * dt);
            const moveX = (dx / dist) * moveDist;
            const moveZ = (dz / dist) * moveDist;

            u.position.x += moveX;
            u.position.z += moveZ;

            // Align height to terrain
            u.position.y = this.world.getHeight(u.position.x, u.position.z);

            // Smooth rotation towards movement direction
            const targetRot = Math.atan2(dx, dz);
            u.rotation = THREE.MathUtils.lerp(u.rotation, targetRot, dt * 10);
          }
        }
      }

      // Simple crowd separation (push overlapping units apart)
      for (let j = i + 1; j < units.length; j++) {
        const other = units[j];
        if (!other.isAlive) continue;

        const sepDx = other.position.x - u.position.x;
        const sepDz = other.position.z - u.position.z;
        const sepDistSq = sepDx * sepDx + sepDz * sepDz;
        const minSep = 0.55;

        if (sepDistSq < minSep * minSep && sepDistSq > 0.001) {
          const sepDist = Math.sqrt(sepDistSq);
          const overlap = (minSep - sepDist) * 0.5;
          const pushX = (sepDx / sepDist) * overlap;
          const pushZ = (sepDz / sepDist) * overlap;

          u.position.x -= pushX * 0.4;
          u.position.z -= pushZ * 0.4;
          other.position.x += pushX * 0.4;
          other.position.z += pushZ * 0.4;
        }
      }
    }
  }
}
