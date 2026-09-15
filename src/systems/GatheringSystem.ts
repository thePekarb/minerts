import { Unit } from "../entities/Unit";
import { Building } from "../entities/Building";
import { World } from "../world/World";
import { ResourceData } from "../world/ResourceSpawner";
import { RESOURCE_CONFIGS } from "../data/resourceConfigs";
import { EconomySystem } from "./EconomySystem";
import { PathfindingSystem } from "./PathfindingSystem";
import { ParticleEffects } from "../rendering/ParticleEffects";
import { TerrainRenderer } from "../rendering/TerrainRenderer";
import { eventBus } from "../game/EventBus";

export class GatheringSystem {
  private world: World;
  private economy: EconomySystem;
  private pathfinder: PathfindingSystem;
  private particles: ParticleEffects;
  private terrainRenderer?: TerrainRenderer;

  constructor(
    world: World,
    economy: EconomySystem,
    pathfinder: PathfindingSystem,
    particles: ParticleEffects,
    terrainRenderer?: TerrainRenderer
  ) {
    this.world = world;
    this.economy = economy;
    this.pathfinder = pathfinder;
    this.particles = particles;
    this.terrainRenderer = terrainRenderer;
  }

  public setTerrainRenderer(renderer: TerrainRenderer): void {
    this.terrainRenderer = renderer;
  }

  public orderGather(unit: Unit, resource: ResourceData | Building): void {
    if (unit.type !== "worker") {
      eventBus.emit("toast", { message: "Only workers can gather resources!", type: "warn" });
      return;
    }

    if (resource instanceof Building && resource.type === "mine") {
      this.orderGatherMine(unit, resource);
      return;
    }

    const res = resource as ResourceData;
    unit.currentOrder = "gather";
    unit.target = res;
    (unit as any).harvestNodeId = res.id;
    (unit as any).harvestMineId = null;

    const centerX = res.x + 0.5;
    const centerZ = res.z + 0.5;
    const dist = Math.hypot(unit.position.x - centerX, unit.position.z - centerZ);

    if (dist <= 2.2) {
      unit.path = [];
      unit.state = "gathering";
      unit.gatherTimer = 0;
      eventBus.emit("toast", { message: `Worker harvesting ${res.type.toUpperCase()}`, type: "info" });
      return;
    }

    // Path to adjacent tile of the resource
    const path = this.pathfinder.findPath(unit.position.x, unit.position.z, res.x, res.z);
    if (path.length > 0) {
      unit.path = path;
      unit.currentWaypointIndex = 0;
      unit.state = "moving";
      eventBus.emit("toast", { message: `Worker moving to ${res.type.toUpperCase()}`, type: "info" });
    } else if (dist <= 2.6) {
      unit.path = [];
      unit.state = "gathering";
      unit.gatherTimer = 0;
      eventBus.emit("toast", { message: `Worker harvesting ${res.type.toUpperCase()}`, type: "info" });
    } else {
      unit.path = [];
      unit.state = "idle";
      unit.target = null;
      eventBus.emit("toast", { message: `Cannot reach ${res.type.toUpperCase()} - path blocked!`, type: "warn" });
    }
  }

  public orderGatherMine(unit: Unit, mine: Building): void {
    this.orderEnterMine(unit, mine);
  }

  public orderEnterMine(unit: Unit, mine: Building): void {
    unit.currentOrder = "gather";
    unit.target = mine;
    (unit as any).miningBuildingId = mine.id;
    (unit as any).harvestMineId = null;
    (unit as any).harvestNodeId = null;
    mine.assignedMinerIds.add(unit.id);

    const dist = Math.hypot(unit.position.x - mine.position.x, unit.position.z - mine.position.z);
    if (dist <= 1.8) {
      // Enter immediately
      unit.meshHierarchy.root.visible = false;
      unit.state = "mining_inside";
      unit.path = [];
      unit.position = { x: mine.position.x, y: mine.position.y, z: mine.position.z };
      unit.meshHierarchy.root.position.set(mine.position.x, mine.position.y, mine.position.z);
      this.updateMineBadgeCount(mine);
      eventBus.emit("toast", { message: `⛏️ Worker entered the Mine! (${mine.assignedMinerIds.size}/${mine.maxMiners})`, type: "info" });
      eventBus.emit("sound", { soundName: "mine" });
      return;
    }

    const path = this.pathfinder.findPath(unit.position.x, unit.position.z, mine.position.x, mine.position.z);
    if (path.length > 0) {
      unit.path = path;
      unit.currentWaypointIndex = 0;
      unit.state = "moving";
      eventBus.emit("toast", { message: `🧑‍🌾 Worker heading into the Mine...`, type: "info" });
      eventBus.emit("sound", { soundName: "order_move" });
    } else {
      // If pathfinding can't reach exactly, warp into mine
      unit.meshHierarchy.root.visible = false;
      unit.state = "mining_inside";
      unit.path = [];
      unit.position = { x: mine.position.x, y: mine.position.y, z: mine.position.z };
      unit.meshHierarchy.root.position.set(mine.position.x, mine.position.y, mine.position.z);
      eventBus.emit("toast", { message: `⛏️ Worker entered the Mine! (${mine.assignedMinerIds.size}/${mine.maxMiners})`, type: "info" });
      eventBus.emit("sound", { soundName: "mine" });
    }
    this.updateMineBadgeCount(mine);
  }

  public addWorkerToMine(mine: Building, units: Unit[]): boolean {
    if (!mine.isConstructed) {
      eventBus.emit("toast", { message: "Mine is still under construction!", type: "warn" });
      return false;
    }
    if (mine.assignedMinerIds.size >= mine.maxMiners) {
      eventBus.emit("toast", { message: `Mine is at full capacity (${mine.maxMiners}/${mine.maxMiners})!`, type: "warn" });
      return false;
    }

    // Find closest idle player worker not assigned to this mine
    let candidate: Unit | null = null;
    let minDist = Infinity;

    for (const u of units) {
      if (
        u.type === "worker" &&
        u.faction === "player" &&
        u.isAlive &&
        u.state === "idle" &&
        !mine.assignedMinerIds.has(u.id)
      ) {
        const d = Math.hypot(u.position.x - mine.position.x, u.position.z - mine.position.z);
        if (d < minDist) {
          minDist = d;
          candidate = u;
        }
      }
    }

    if (!candidate) {
      eventBus.emit("toast", { message: "No idle workers available! Train workers at a Hut [1].", type: "warn" });
      return false;
    }

    this.orderEnterMine(candidate, mine);
    return true;
  }

  public ejectMiner(mine: Building, units: Unit[]): boolean {
    if (mine.assignedMinerIds.size === 0) {
      eventBus.emit("toast", { message: "No miners assigned to this Mine.", type: "info" });
      return false;
    }

    const uid = Array.from(mine.assignedMinerIds).pop()!;
    mine.assignedMinerIds.delete(uid);

    const worker = units.find((u) => u.id === uid && u.isAlive);
    if (worker) {
      worker.meshHierarchy.root.visible = true;
      const outX = mine.position.x + 1.6;
      const outZ = mine.position.z + 1.6;
      worker.position = { x: outX, y: this.world.getHeight(outX, outZ), z: outZ };
      worker.meshHierarchy.root.position.set(outX, worker.position.y, outZ);
      worker.state = "idle";
      worker.currentOrder = "move";
      worker.target = null;
      worker.path = [];
      delete (worker as any).miningBuildingId;

      eventBus.emit("toast", { message: `🧑‍🌾 Worker emerged from the Mine.`, type: "info" });
      eventBus.emit("sound", { soundName: "click" });
    }

    this.updateMineBadgeCount(mine);
    return true;
  }

  public updateMineBadgeCount(mine: Building): void {
    if (mine.domCountNum) {
      mine.domCountNum.textContent = `${mine.assignedMinerIds.size}`;
    }
  }

  public update(units: Unit[], buildings: Building[], dt: number): void {
    // 1. Process Mine production cycles
    for (const b of buildings) {
      if (b.type === "mine" && b.isConstructed && b.isAlive) {
        // Clean up any dead miners
        for (const uid of Array.from(b.assignedMinerIds)) {
          const u = units.find((x) => x.id === uid && x.isAlive);
          if (!u) {
            b.assignedMinerIds.delete(uid);
          }
        }

        const insideMiners = units.filter(
          (u) => u.isAlive && (u as any).miningBuildingId === b.id && u.state === "mining_inside"
        );

        if (insideMiners.length > 0) {
          b.mineCycleTimer += dt;
          if (b.mineCycleTimer >= 2.5) {
            b.mineCycleTimer = 0;
            const count = insideMiners.length;
            const isDeep = b.level >= 2;
            const stoneYield = (isDeep ? 4 : 5) * count;
            this.economy.addResource("stone", stoneYield);

            if (isDeep) {
              const oreYield = 2 * count;
              this.economy.addResource("ore", oreYield);
              eventBus.emit("toast", {
                message: `⛏️ Deep Mine produced +${stoneYield} STONE & +${oreYield} ORE (${count} miners)`,
                type: "info"
              });
            } else {
              eventBus.emit("toast", {
                message: `⛏️ Mine produced +${stoneYield} STONE (${count} miners)`,
                type: "info"
              });
            }

            this.particles.spawnHarvestEffect(
              isDeep ? "ore" : "stone",
              b.position.x,
              b.position.y + 1.2,
              b.position.z
            );
            eventBus.emit("sound", { soundName: "mine" });
          }
        } else {
          b.mineCycleTimer = 0;
        }

        this.updateMineBadgeCount(b);
      }
    }

    // 2. Process Units
    for (const u of units) {
      if (u.type !== "worker" || !u.isAlive) continue;

      // Handle worker walking to or inside Mine (only for gathering orders)
      if (u.currentOrder === "gather" && u.target instanceof Building && u.target.type === "mine") {
        const mine = u.target as Building;
        if (!mine.isAlive || !mine.isConstructed) {
          u.state = "idle";
          u.target = null;
          u.meshHierarchy.root.visible = true;
          mine.assignedMinerIds.delete(u.id);
          delete (u as any).miningBuildingId;
          continue;
        }

        if (u.state === "mining_inside") {
          u.meshHierarchy.root.visible = false;
          continue;
        }

        // Check arrival at mine entrance
        const dist = Math.hypot(u.position.x - mine.position.x, u.position.z - mine.position.z);
        if (dist <= 1.8) {
          u.meshHierarchy.root.visible = false;
          u.state = "mining_inside";
          u.path = [];
          u.position = { x: mine.position.x, y: mine.position.y, z: mine.position.z };
          u.meshHierarchy.root.position.set(mine.position.x, mine.position.y, mine.position.z);
          mine.assignedMinerIds.add(u.id);
          this.updateMineBadgeCount(mine);
          eventBus.emit("toast", {
            message: `⛏️ Worker entered the Mine! (${mine.assignedMinerIds.size}/${mine.maxMiners})`,
            type: "info"
          });
          eventBus.emit("sound", { soundName: "mine" });
        }
        continue;
      }

      // If unit is supposed to be inside a mine, keep hidden
      if (u.state === "mining_inside") {
        u.meshHierarchy.root.visible = false;
        continue;
      }

      // 1. Moving to resource
      if (u.currentOrder === "gather" && u.target && u.state !== "returningToStorage") {
        const res = u.target as ResourceData;
        if (!res || res.amount <= 0) {
          // Depleted
          const tile = this.world.getTile(res.x, res.z);
          if (tile) {
            tile.resourceId = null;
            tile.walkable = true;
          }
          if (this.terrainRenderer) {
            this.terrainRenderer.removeResourceMesh(res.id);
          }

          if (u.inventory && u.inventory.amount > 0) {
            this.sendToStorage(u, buildings);
          } else {
            u.state = "idle";
            u.target = null;
          }
          continue;
        }

        // Face the resource
        const dx = (res.x + 0.5) - u.position.x;
        const dz = (res.z + 0.5) - u.position.z;
        u.rotation = Math.atan2(dx, dz);

        u.gatherTimer += dt;
        const config = RESOURCE_CONFIGS[res.type];

        // Periodic gather cycle
        if (u.gatherTimer >= config.harvestTimePerUnit) {
          u.gatherTimer = 0;

          const harvestAmount = Math.min(config.yieldPerCycle, res.amount);
          res.amount -= harvestAmount;

          if (!u.inventory) {
            u.inventory = { type: res.type, amount: harvestAmount };
          } else {
            u.inventory.amount += harvestAmount;
          }

          // Sound and particles
          this.particles.spawnHarvestEffect(res.type, res.x + 0.5, res.height, res.z + 0.5);
          eventBus.emit("sound", {
            soundName: res.type === "wood" ? "chop" : (res.type === "stone" ? "mine" : "click")
          });

          eventBus.emit("toast", {
            message: `Harvested +${harvestAmount} ${res.type.toUpperCase()} (${u.inventory.amount}/${u.config.inventoryCapacity})`,
            type: "info"
          });

          // Check if node got depleted on this hit
          if (res.amount <= 0) {
            const tile = this.world.getTile(res.x, res.z);
            if (tile) {
              tile.resourceId = null;
              tile.walkable = true;
            }
            if (this.terrainRenderer) {
              this.terrainRenderer.removeResourceMesh(res.id);
            }
          }

          // If inventory is full or node depleted, return to storage
          if (u.inventory.amount >= u.config.inventoryCapacity || res.amount <= 0) {
            this.sendToStorage(u, buildings);
          }
        }
      }

      // 3. Returning to storage
      if (u.state === "returningToStorage") {
        const dropBuilding = u.target as Building;
        if (dropBuilding && dropBuilding.isAlive) {
          const dist = Math.hypot(u.position.x - dropBuilding.position.x, u.position.z - dropBuilding.position.z);
          if (dist <= 2.8) {
            // Deposit inventory
            if (u.inventory) {
              this.economy.addResource(u.inventory.type, u.inventory.amount);
              eventBus.emit("toast", {
                message: `📦 Deposited +${u.inventory.amount} ${u.inventory.type.toUpperCase()}!`,
                type: "success"
              });
              eventBus.emit("sound", { soundName: "click" });
              u.inventory = null;
            }

            // Return to harvest if node still has resources or mine
            const origMineId = (u as any).harvestMineId;
            const origMine = origMineId ? buildings.find(b => b.id === origMineId && b.isAlive && b.isConstructed) : null;
            const origResId = (u as any).harvestNodeId;
            const origRes = origResId ? this.world.resources.get(origResId) : null;

            if (origMine) {
              this.orderGatherMine(u, origMine);
            } else if (origRes && origRes.amount > 0) {
              this.orderGather(u, origRes);
            } else {
              u.state = "idle";
              u.currentOrder = "move";
              u.target = null;
            }
          }
        } else {
          u.state = "idle";
          u.target = null;
        }
      }
    }
  }

  private sendToStorage(unit: Unit, buildings: Building[]): void {
    // Find closest constructed storage or campfire
    let closestDrop: Building | null = null;
    let minDist = Infinity;

    for (const b of buildings) {
      if ((b.type === "storage" || b.type === "campfire") && b.isConstructed && b.isAlive) {
        const d = Math.hypot(unit.position.x - b.position.x, unit.position.z - b.position.z);
        if (d < minDist) {
          minDist = d;
          closestDrop = b;
        }
      }
    }

    if (closestDrop) {
      if (unit.target) {
        if (unit.target instanceof Building && unit.target.type === "mine") {
          (unit as any).harvestMineId = unit.target.id;
          (unit as any).harvestNodeId = null;
        } else if ((unit.target as ResourceData).id) {
          (unit as any).harvestNodeId = (unit.target as ResourceData).id;
        }
      }
      unit.state = "returningToStorage";
      unit.target = closestDrop;

      const path = this.pathfinder.findPath(
        unit.position.x,
        unit.position.z,
        closestDrop.position.x,
        closestDrop.position.z
      );
      if (path.length > 0) {
        unit.path = path;
        unit.currentWaypointIndex = 0;
      }
    } else {
      unit.state = "idle";
    }
  }
}
