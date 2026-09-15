import { Tile } from "./Tile";
import { TerrainGenerator } from "./TerrainGenerator";
import { ResourceSpawner, ResourceData } from "./ResourceSpawner";
import { POIGenerator, POIData } from "./POIGenerator";

export class World {
  public size: number;
  public tiles: Tile[][] = [];
  public resources: Map<string, ResourceData> = new Map();
  public pois: Map<string, POIData> = new Map();

  constructor(size: number = 64, seed: number = 42) {
    this.size = size;
    const terrainGen = new TerrainGenerator(size, seed);
    this.tiles = terrainGen.generate();

    const resSpawner = new ResourceSpawner(size, seed + 100);
    const spawnedRes = resSpawner.spawnResources(this.tiles);
    for (const r of spawnedRes) {
      this.resources.set(r.id, r);
    }

    const poiGen = new POIGenerator(size, seed + 200);
    const spawnedPOIs = poiGen.generatePOIs(this.tiles);
    for (const p of spawnedPOIs) {
      this.pois.set(p.id, p);
    }
  }

  public getTile(x: number, z: number): Tile | null {
    const ix = Math.floor(x);
    const iz = Math.floor(z);
    if (ix < 0 || ix >= this.size || iz < 0 || iz >= this.size) {
      return null;
    }
    return this.tiles[ix][iz];
  }

  public getHeight(x: number, z: number): number {
    const tile = this.getTile(x, z);
    return tile ? tile.height : 0;
  }

  public isWalkable(x: number, z: number, faction: "player" | "enemy" = "player"): boolean {
    const tile = this.getTile(x, z);
    if (!tile) return false;
    return tile.isWalkableFor(faction);
  }

  public setTileOccupied(x: number, z: number, buildingId: string | null, isGate: boolean = false): void {
    const tile = this.getTile(x, z);
    if (tile) {
      tile.buildingId = buildingId;
      tile.isGate = isGate;
      tile.walkable = buildingId === null || isGate;
    }
  }
}
