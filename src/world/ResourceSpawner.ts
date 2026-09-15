import { Tile } from "./Tile";
import { ResourceType, RESOURCE_CONFIGS } from "../data/resourceConfigs";
import { PRNG } from "./TerrainGenerator";

export interface ResourceData {
  id: string;
  type: ResourceType;
  x: number;
  z: number;
  height: number;
  amount: number;
  maxAmount: number;
}

export class ResourceSpawner {
  private size: number;
  private prng: PRNG;

  constructor(size: number, seed: number = 777) {
    this.size = size;
    this.prng = new PRNG(seed);
  }

  public spawnResources(tiles: Tile[][]): ResourceData[] {
    const resources: ResourceData[] = [];
    const center = this.size / 2;
    let resIdCounter = 1;

    for (let x = 3; x < this.size - 3; x++) {
      for (let z = 3; z < this.size - 3; z++) {
        const tile = tiles[x][z];
        if (!tile.walkable || tile.isOccupied()) continue;

        // Leave camp clearing empty (radius 5)
        const distToCenterSq = (x - center) * (x - center) + (z - center) * (z - center);
        if (distToCenterSq < 36) continue;

        const roll = this.prng.next();

        if (tile.biome === "forest") {
          // 40% chance of tree
          if (roll < 0.38) {
            const res: ResourceData = {
              id: `res_wood_${resIdCounter++}`,
              type: "wood",
              x,
              z,
              height: tile.height,
              amount: RESOURCE_CONFIGS.wood.maxAmount,
              maxAmount: RESOURCE_CONFIGS.wood.maxAmount
            };
            tile.resourceId = res.id;
            tile.walkable = false; // Trees block movement
            resources.push(res);
          }
        } else if (tile.biome === "rock") {
          // Rocky high ground - clear of loose boulders as stone/ore is extracted via Mines
        } else if (tile.biome === "plains") {
          // 12% chance of berry bush, 8% chance of solitary tree
          if (roll < 0.12) {
            const res: ResourceData = {
              id: `res_food_${resIdCounter++}`,
              type: "food",
              x,
              z,
              height: tile.height,
              amount: RESOURCE_CONFIGS.food.maxAmount,
              maxAmount: RESOURCE_CONFIGS.food.maxAmount
            };
            tile.resourceId = res.id;
            tile.walkable = false;
            resources.push(res);
          } else if (roll < 0.20) {
            const res: ResourceData = {
              id: `res_wood_${resIdCounter++}`,
              type: "wood",
              x,
              z,
              height: tile.height,
              amount: RESOURCE_CONFIGS.wood.maxAmount,
              maxAmount: RESOURCE_CONFIGS.wood.maxAmount
            };
            tile.resourceId = res.id;
            tile.walkable = false;
            resources.push(res);
          }
        }
      }
    }

    return resources;
  }
}
