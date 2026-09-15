import { Tile } from "./Tile";
import { PRNG } from "./TerrainGenerator";

export interface POIData {
  id: string;
  type: "cave" | "abandoned_camp" | "chest";
  x: number;
  z: number;
  height: number;
  loot?: { wood?: number; stone?: number; food?: number; ore?: number };
  isOpened?: boolean;
}

export class POIGenerator {
  private size: number;
  private prng: PRNG;

  constructor(size: number, seed: number = 888) {
    this.size = size;
    this.prng = new PRNG(seed);
  }

  public generatePOIs(tiles: Tile[][]): POIData[] {
    const pois: POIData[] = [];
    const center = this.size / 2;

    // 1. Cave Entrance: Find a rocky tile in the outer quadrant
    let caveFound = false;
    for (let attempts = 0; attempts < 100; attempts++) {
      const rx = Math.floor(10 + this.prng.next() * (this.size - 20));
      const rz = Math.floor(10 + this.prng.next() * (this.size - 20));
      const distToCenter = Math.hypot(rx - center, rz - center);

      if (distToCenter > 16 && tiles[rx][rz].biome === "rock" && tiles[rx][rz].walkable) {
        pois.push({
          id: "poi_cave_1",
          type: "cave",
          x: rx,
          z: rz,
          height: tiles[rx][rz].height
        });
        tiles[rx][rz].walkable = false;
        caveFound = true;
        break;
      }
    }

    // Fallback if no rock tile found
    if (!caveFound) {
      const cx = this.size - 12;
      const cz = 12;
      pois.push({
        id: "poi_cave_1",
        type: "cave",
        x: cx,
        z: cz,
        height: tiles[cx][cz].height
      });
      tiles[cx][cz].walkable = false;
    }

    // 2. Abandoned Camp: In forest or meadow
    let campFound = false;
    for (let attempts = 0; attempts < 100; attempts++) {
      const rx = Math.floor(8 + this.prng.next() * (this.size - 16));
      const rz = Math.floor(8 + this.prng.next() * (this.size - 16));
      const distToCenter = Math.hypot(rx - center, rz - center);

      if (distToCenter > 12 && (tiles[rx][rz].biome === "forest" || tiles[rx][rz].biome === "plains") && tiles[rx][rz].walkable && !tiles[rx][rz].isOccupied()) {
        pois.push({
          id: "poi_abandoned_camp",
          type: "abandoned_camp",
          x: rx,
          z: rz,
          height: tiles[rx][rz].height,
          loot: { wood: 40, stone: 20, food: 30 }
        });
        tiles[rx][rz].walkable = false;
        campFound = true;
        break;
      }
    }

    // 3. Loot Chests (3-5 chests across the map)
    const chestCount = 4;
    for (let i = 0; i < chestCount; i++) {
      for (let attempts = 0; attempts < 50; attempts++) {
        const rx = Math.floor(6 + this.prng.next() * (this.size - 12));
        const rz = Math.floor(6 + this.prng.next() * (this.size - 12));
        const distToCenter = Math.hypot(rx - center, rz - center);

        if (distToCenter > 9 && tiles[rx][rz].walkable && !tiles[rx][rz].isOccupied()) {
          pois.push({
            id: `poi_chest_${i + 1}`,
            type: "chest",
            x: rx,
            z: rz,
            height: tiles[rx][rz].height,
            loot: {
              wood: 15 + Math.floor(this.prng.next() * 25),
              stone: 10 + Math.floor(this.prng.next() * 20),
              food: 15 + Math.floor(this.prng.next() * 20),
              ore: Math.floor(this.prng.next() * 8)
            },
            isOpened: false
          });
          tiles[rx][rz].walkable = false;
          break;
        }
      }
    }

    return pois;
  }
}
