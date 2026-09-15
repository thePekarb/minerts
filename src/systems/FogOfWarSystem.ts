import { World } from "../world/World";
import { Unit } from "../entities/Unit";
import { Building } from "../entities/Building";

export class FogOfWarSystem {
  private world: World;

  constructor(world: World) {
    this.world = world;
  }

  public update(units: Unit[], buildings: Building[], isNight: boolean): void {
    const size = this.world.size;
    const visionFactor = isNight ? 0.75 : 1.0;

    // Reset current visibility flag
    for (let x = 0; x < size; x++) {
      for (let z = 0; z < size; z++) {
        this.world.tiles[x][z].visible = false;
      }
    }

    // Reveal around friendly units
    for (const u of units) {
      if (u.faction !== "player" || u.state === "dead") continue;
      const radius = Math.floor(u.config.visionRange * visionFactor);
      this.revealCircle(Math.floor(u.position.x), Math.floor(u.position.z), radius);
    }

    // Reveal around active buildings
    for (const b of buildings) {
      if (b.isConstructed) {
        const radius = Math.floor(b.config.visionRadius * visionFactor);
        this.revealCircle(b.gridX + Math.floor(b.config.size.x / 2), b.gridZ + Math.floor(b.config.size.z / 2), radius);
      }
    }
  }

  private revealCircle(cx: number, cz: number, radius: number): void {
    const size = this.world.size;
    const rSq = radius * radius;

    const minX = Math.max(0, cx - radius);
    const maxX = Math.min(size - 1, cx + radius);
    const minZ = Math.max(0, cz - radius);
    const maxZ = Math.min(size - 1, cz + radius);

    for (let x = minX; x <= maxX; x++) {
      for (let z = minZ; z <= maxZ; z++) {
        const distSq = (x - cx) * (x - cx) + (z - cz) * (z - cz);
        if (distSq <= rSq) {
          const tile = this.world.tiles[x][z];
          tile.visible = true;
          tile.explored = true;
        }
      }
    }
  }
}
