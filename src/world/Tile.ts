export type BiomeType = "plains" | "forest" | "rock" | "sand" | "water";

export class Tile {
  public x: number;
  public z: number;
  public height: number;
  public biome: BiomeType;
  public walkable: boolean;
  public resourceId: string | null = null;
  public buildingId: string | null = null;
  public isGate: boolean = false;
  public isGateOpen: boolean = false;
  public isGateLocked: boolean = false;
  public unitId: string | null = null;

  // Fog of war states
  public explored: boolean = false;
  public visible: boolean = false;

  constructor(x: number, z: number, height: number, biome: BiomeType, walkable: boolean) {
    this.x = x;
    this.z = z;
    this.height = height;
    this.biome = biome;
    this.walkable = walkable;
  }

  public isOccupied(): boolean {
    return !this.walkable || this.resourceId !== null || (this.buildingId !== null && !this.isGate);
  }

  public isWalkableFor(faction: "player" | "enemy" = "player"): boolean {
    if (!this.walkable || this.resourceId !== null) return false;
    if (this.buildingId !== null) {
      if (this.isGate) {
        if (this.isGateLocked) return false;
        return faction === "player";
      }
      return false;
    }
    return true;
  }
}
