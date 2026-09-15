import * as THREE from "three";
import { Building } from "../entities/Building";
import { Unit } from "../entities/Unit";
import { BuildingType, BUILDING_CONFIGS } from "../data/buildingConfigs";
import { World } from "../world/World";
import { EconomySystem } from "./EconomySystem";
import { PathfindingSystem } from "./PathfindingSystem";
import { ParticleEffects } from "../rendering/ParticleEffects";
import { VoxelMeshes } from "../rendering/VoxelMeshes";
import { eventBus } from "../game/EventBus";

export class ConstructionSystem {
  private scene: THREE.Scene;
  private world: World;
  private economy: EconomySystem;
  private pathfinder: PathfindingSystem;
  private particles: ParticleEffects;

  // Active ghost preview
  public activeGhostType: BuildingType | null = null;
  public ghostMesh: THREE.Group | null = null;
  public currentGridPos: { x: number; z: number } = { x: 0, z: 0 };
  public isValidPlacement: boolean = false;

  private buildingCounter = 1;

  constructor(
    scene: THREE.Scene,
    world: World,
    economy: EconomySystem,
    pathfinder: PathfindingSystem,
    particles: ParticleEffects
  ) {
    this.scene = scene;
    this.world = world;
    this.economy = economy;
    this.pathfinder = pathfinder;
    this.particles = particles;
  }

  public setGhostBuilding(type: BuildingType | null): void {
    if (this.ghostMesh) {
      this.scene.remove(this.ghostMesh);
      this.ghostMesh = null;
    }

    this.activeGhostType = type;

    if (type) {
      this.ghostMesh = VoxelMeshes.createBuildingMesh(type, true, true);
      this.scene.add(this.ghostMesh);
      eventBus.emit("sound", { soundName: "click" });
    }
  }

  public updateGhostPosition(groundX: number, groundZ: number, buildings: Building[]): void {
    if (!this.ghostMesh || !this.activeGhostType) return;

    const config = BUILDING_CONFIGS[this.activeGhostType];
    const gx = Math.floor(groundX - config.size.x / 2);
    const gz = Math.floor(groundZ - config.size.z / 2);

    this.currentGridPos = { x: gx, z: gz };

    // Check validity
    this.isValidPlacement = this.canPlaceBuilding(this.activeGhostType, gx, gz, buildings);

    // Update ghost mesh color/materials
    this.scene.remove(this.ghostMesh);
    this.ghostMesh = VoxelMeshes.createBuildingMesh(this.activeGhostType, true, this.isValidPlacement);

    const posY = this.world.getHeight(gx + config.size.x / 2, gz + config.size.z / 2);
    this.ghostMesh.position.set(gx + config.size.x / 2, posY, gz + config.size.z / 2);
    this.scene.add(this.ghostMesh);
  }

  public canPlaceBuilding(
    type: BuildingType,
    gx: number,
    gz: number,
    buildings: Building[]
  ): boolean {
    const config = BUILDING_CONFIGS[type];

    // Check resources
    if (!this.economy.canAfford(config.cost)) {
      return false;
    }

    // Check bounds
    if (gx < 2 || gx + config.size.x >= this.world.size - 2 || gz < 2 || gz + config.size.z >= this.world.size - 2) {
      return false;
    }

    // Check each tile in footprint
    for (let x = gx; x < gx + config.size.x; x++) {
      for (let z = gz; z < gz + config.size.z; z++) {
        const tile = this.world.getTile(x, z);
        if (!tile || !tile.walkable || tile.biome === "water" || tile.isOccupied()) {
          return false;
        }
      }
    }

    return true;
  }

  public confirmPlacement(allUnits: Unit[], buildings: Building[]): Building | null {
    if (!this.activeGhostType || !this.isValidPlacement) return null;

    const type = this.activeGhostType;
    const config = BUILDING_CONFIGS[type];
    const { x: gx, z: gz } = this.currentGridPos;

    // Deduct cost
    if (!this.economy.deductCost(config.cost)) {
      eventBus.emit("toast", { message: "Not enough resources to build!", type: "warn" });
      return null;
    }

    // Mark tiles occupied
    const buildingId = `b_${type}_${this.buildingCounter++}`;
    for (let x = gx; x < gx + config.size.x; x++) {
      for (let z = gz; z < gz + config.size.z; z++) {
        this.world.setTileOccupied(x, z, buildingId, type === "gate");
      }
    }

    const posY = this.world.getHeight(gx + config.size.x / 2, gz + config.size.z / 2);
    const newBuilding = new Building(buildingId, type, gx, posY, gz, false);
    buildings.push(newBuilding);
    this.scene.add(newBuilding.mesh);

    eventBus.emit("toast", { message: `Started construction: ${config.name}`, type: "info" });
    eventBus.emit("sound", { soundName: "build" });

    // Assign worker to build it
    this.assignNearestWorker(newBuilding, allUnits);

    // Reset ghost
    this.setGhostBuilding(null);
    return newBuilding;
  }

  public assignNearestWorker(building: Building, allUnits: Unit[]): void {
    let bestWorker: Unit | null = null;
    let minDist = Infinity;

    for (const u of allUnits) {
      if (u.type === "worker" && u.faction === "player" && u.isAlive) {
        // Prefer idle workers
        const dist = Math.hypot(u.position.x - building.position.x, u.position.z - building.position.z);
        const score = dist + (u.state === "idle" ? 0 : 20);
        if (score < minDist) {
          minDist = score;
          bestWorker = u;
        }
      }
    }

    if (bestWorker) {
      this.orderBuild(bestWorker, building);
    }
  }

  public findAdjacentWalkableTile(building: Building, fromX: number, fromZ: number): { x: number; z: number } | null {
    const minX = building.gridX;
    const maxX = building.gridX + building.config.size.x - 1;
    const minZ = building.gridZ;
    const maxZ = building.gridZ + building.config.size.z - 1;

    let bestTile: { x: number; z: number } | null = null;
    let minDist = Infinity;

    for (let x = minX - 1; x <= maxX + 1; x++) {
      for (let z = minZ - 1; z <= maxZ + 1; z++) {
        if (x >= minX && x <= maxX && z >= minZ && z <= maxZ) continue;
        if (this.world.isWalkable(x, z, "player")) {
          const d = Math.hypot(fromX - (x + 0.5), fromZ - (z + 0.5));
          if (d < minDist) {
            minDist = d;
            bestTile = { x: x + 0.5, z: z + 0.5 };
          }
        }
      }
    }

    return bestTile;
  }

  public orderBuild(worker: Unit, building: Building): void {
    worker.currentOrder = "build";
    worker.target = building;

    const minX = building.gridX;
    const maxX = building.gridX + building.config.size.x;
    const minZ = building.gridZ;
    const maxZ = building.gridZ + building.config.size.z;
    const nearestX = Math.max(minX, Math.min(maxX, worker.position.x));
    const nearestZ = Math.max(minZ, Math.min(maxZ, worker.position.z));
    const distToEdge = Math.hypot(worker.position.x - nearestX, worker.position.z - nearestZ);

    if (distToEdge <= 2.2) {
      worker.state = "building";
      worker.path = [];
      return;
    }

    const adjTile = this.findAdjacentWalkableTile(building, worker.position.x, worker.position.z);
    const targetX = adjTile ? adjTile.x : building.position.x;
    const targetZ = adjTile ? adjTile.z : building.position.z;

    const path = this.pathfinder.findPath(
      worker.position.x,
      worker.position.z,
      targetX,
      targetZ
    );

    if (path.length > 0) {
      worker.path = path;
      worker.currentWaypointIndex = 0;
      worker.state = "moving";
    } else if (distToEdge <= 2.8) {
      worker.state = "building";
      worker.path = [];
    }
  }

  public update(units: Unit[], dt: number): void {
    for (const u of units) {
      if (u.type !== "worker" || !u.isAlive) continue;

      if (u.currentOrder === "build" && u.target instanceof Building) {
        const building = u.target as Building;

        if (building.isConstructed) {
          u.state = "idle";
          u.target = null;
          continue;
        }

        const minX = building.gridX;
        const maxX = building.gridX + building.config.size.x;
        const minZ = building.gridZ;
        const maxZ = building.gridZ + building.config.size.z;
        const nearestX = Math.max(minX, Math.min(maxX, u.position.x));
        const nearestZ = Math.max(minZ, Math.min(maxZ, u.position.z));
        const distToEdge = Math.hypot(u.position.x - nearestX, u.position.z - nearestZ);

        if (distToEdge <= 2.2) {
          u.state = "building";
          u.buildTimer += dt;

          if (u.buildTimer >= 0.4) {
            u.buildTimer = 0;
            const buildRate = (100 / (building.config.buildTime || 5)) * 0.4;
            const completed = building.advanceConstruction(buildRate);

            this.particles.spawnBuildEffect(building.position.x, building.position.y, building.position.z);
            eventBus.emit("sound", { soundName: "build" });

            if (completed) {
              eventBus.emit("toast", { message: `Completed: ${building.config.name}!`, type: "success" });
              eventBus.emit("sound", { soundName: "build_done" });
              eventBus.emit("buildingConstructed", { building });
              u.state = "idle";
              u.target = null;
            }
          }
        }
      }
    }
  }
}
