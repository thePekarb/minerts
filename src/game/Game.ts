import * as THREE from "three";
import { World } from "../world/World";
import { Materials } from "../rendering/Materials";
import { Lighting } from "../rendering/Lighting";
import { ParticleEffects } from "../rendering/ParticleEffects";
import { TerrainRenderer } from "../rendering/TerrainRenderer";
import { CameraController } from "../camera/CameraController";
import { RaycastManager } from "../input/RaycastManager";
import { SoundManager } from "../audio/SoundManager";
import { Unit } from "../entities/Unit";
import { Building } from "../entities/Building";
import { SelectionSystem } from "../systems/SelectionSystem";
import { MovementSystem } from "../systems/MovementSystem";
import { PathfindingSystem } from "../systems/PathfindingSystem";
import { GatheringSystem } from "../systems/GatheringSystem";
import { ConstructionSystem } from "../systems/ConstructionSystem";
import { CombatSystem } from "../systems/CombatSystem";
import { RaidSystem } from "../systems/RaidSystem";
import { TimeOfDaySystem } from "../systems/TimeOfDaySystem";
import { FogOfWarSystem } from "../systems/FogOfWarSystem";
import { EconomySystem } from "../systems/EconomySystem";
import { LumberZoneSystem, LumberZone } from "../systems/LumberZoneSystem";
import { SaveManager } from "./SaveManager";
import { HUD } from "../ui/HUD";
import { Minimap } from "../ui/Minimap";
import { eventBus } from "./EventBus";

export class Game {
  public scene: THREE.Scene;
  public camera: THREE.PerspectiveCamera;
  public renderer: THREE.WebGLRenderer;
  private canvas: HTMLCanvasElement;

  // Systems & Managers
  public world: World;
  public lighting: Lighting;
  public particles: ParticleEffects;
  public terrainRenderer: TerrainRenderer;
  public cameraCtrl: CameraController;
  public raycastMgr: RaycastManager;
  public soundMgr: SoundManager;

  public selectionSys: SelectionSystem;
  public movementSys: MovementSystem;
  public pathfindingSys: PathfindingSystem;
  public gatheringSys: GatheringSystem;
  public lumberZoneSys: LumberZoneSystem;
  public constructionSys: ConstructionSystem;
  public combatSys: CombatSystem;
  public raidSys: RaidSystem;
  public timeOfDaySys: TimeOfDaySystem;
  public fogOfWarSys: FogOfWarSystem;
  public economySys: EconomySystem;

  public hud: HUD;
  public minimap: Minimap;

  // Entities
  public units: Unit[] = [];
  public buildings: Building[] = [];
  public campfire: Building;

  // Loop & Performance
  private lastTime: number = 0;
  private frameCount: number = 0;
  private lastFpsTime: number = 0;
  private currentFps: number = 60;
  private isGameOver: boolean = false;

  // Ground click visual indicator
  private clickMarker: THREE.Mesh;
  private clickMarkerTimer: number = 0;
  private tempVec: THREE.Vector3 = new THREE.Vector3();

  constructor() {
    this.canvas = document.getElementById("game-canvas") as HTMLCanvasElement;

    // 1. Three.js Core
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x0f172a);
    this.scene.fog = new THREE.FogExp2(0x0f172a, 0.012);

    this.camera = new THREE.PerspectiveCamera(
      45,
      window.innerWidth / window.innerHeight,
      0.5,
      300
    );

    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: true,
      powerPreference: "high-performance"
    });
    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    // 2. Initialize Materials & Procedural World
    Materials.init();
    const mapSize = 64;
    this.world = new World(mapSize, 12345);

    this.lighting = new Lighting(this.scene, mapSize);
    this.particles = new ParticleEffects(this.scene);
    this.terrainRenderer = new TerrainRenderer(this.world, this.scene);
    this.soundMgr = new SoundManager();

    // 3. Camera & Input
    this.cameraCtrl = new CameraController(this.camera, this.canvas, mapSize);
    this.raycastMgr = new RaycastManager();
    this.selectionSys = new SelectionSystem();

    // 4. Gameplay Systems
    this.economySys = new EconomySystem();
    this.pathfindingSys = new PathfindingSystem(this.world);
    this.movementSys = new MovementSystem(this.world);
    this.gatheringSys = new GatheringSystem(this.world, this.economySys, this.pathfindingSys, this.particles, this.terrainRenderer);
    this.lumberZoneSys = new LumberZoneSystem(this.scene, this.world, this.gatheringSys);
    this.constructionSys = new ConstructionSystem(this.scene, this.world, this.economySys, this.pathfindingSys, this.particles);
    this.combatSys = new CombatSystem(this.scene, this.pathfindingSys, this.particles);
    this.raidSys = new RaidSystem(this.world);
    this.timeOfDaySys = new TimeOfDaySystem();
    this.fogOfWarSys = new FogOfWarSystem(this.world);

    // 5. Spawn Starting Settlement
    const cx = Math.floor(mapSize / 2);
    const cz = Math.floor(mapSize / 2);
    const cy = this.world.getHeight(cx, cz);

    // Central Campfire
    this.campfire = new Building("b_campfire_main", "campfire", cx - 1, cy, cz - 1, true);
    this.buildings.push(this.campfire);
    this.scene.add(this.campfire.mesh);
    this.lighting.addCampfireLight(this.scene, cx, cy, cz);

    // Mark campfire tiles
    for (let x = cx - 1; x <= cx + 1; x++) {
      for (let z = cz - 1; z <= cz + 1; z++) {
        this.world.setTileOccupied(x, z, this.campfire.id);
      }
    }

    // 4 Starting Units: 3 Workers + 1 Guard
    this.spawnUnit("worker", cx + 2.5, cz + 1.5, "player");
    this.spawnUnit("worker", cx - 2.5, cz + 1.5, "player");
    this.spawnUnit("worker", cx + 2.5, cz - 1.5, "player");
    this.spawnUnit("guard", cx, cz + 3.0, "player");

    // Camera initial focus
    this.cameraCtrl.focusOn(cx, cz);

    // Ground order click marker
    const markerGeo = new THREE.RingGeometry(0.35, 0.45, 16);
    markerGeo.rotateX(-Math.PI / 2);
    const markerMat = new THREE.MeshBasicMaterial({ color: 0x38bdf8, transparent: true, opacity: 0 });
    this.clickMarker = new THREE.Mesh(markerGeo, markerMat);
    this.scene.add(this.clickMarker);

    // 6. UI & HUD
    this.hud = new HUD();
    this.minimap = new Minimap("minimap-canvas", this.world, this.cameraCtrl);

    this.setupUIHandlers();
    this.setupMouseEvents();
    this.setupResize();

    // Initial event dispatch
    eventBus.emit("toast", { message: "🏰 Welcome to Frontier Blocks! Gather resources and defend against the night!", type: "success" });

    // Start loop
    requestAnimationFrame(this.loop.bind(this));
  }

  private spawnUnit(type: any, x: number, z: number, faction: "player" | "enemy"): Unit {
    const y = this.world.getHeight(x, z);
    const id = `u_${type}_${this.units.length + 1}`;
    const unit = new Unit(id, type, x, y, z, faction);
    this.units.push(unit);
    this.scene.add(unit.meshHierarchy.root);

    this.updatePopulationCounters();
    return unit;
  }

  private updatePopulationCounters(): void {
    const playerUnits = this.units.filter((u) => u.faction === "player" && u.isAlive).length;
    let maxPop = 6;
    for (const b of this.buildings) {
      if (b.isConstructed && b.isAlive && b.config.populationCapacity) {
        maxPop += b.config.populationCapacity;
      }
    }
    this.economySys.updatePopulation(playerUnits, maxPop);
  }

  private setupUIHandlers(): void {
    // HUD build selection
    this.hud.onBuildSelect = (type) => {
      this.lumberZoneSys.cancelPreview();
      this.hud.setLumberZoneActive(false);
      this.constructionSys.setGhostBuilding(type);
    };

    // HUD Lumber Zone tool toggle
    this.hud.onLumberZoneToggle = () => {
      this.constructionSys.setGhostBuilding(null);
      const active = this.lumberZoneSys.togglePlacingMode();
      this.hud.setLumberZoneActive(active);
      if (active) {
        eventBus.emit("toast", {
          message: "🪓 Lumber Mode: Drag LMB on ground near trees to create a logging zone",
          type: "info"
        });
      }
    };

    // Mine building upgrade
    this.hud.onUpgradeBuilding = (building: Building) => {
      if (building.type === "mine" && building.level === 1) {
        const cost = { wood: 40, stone: 30 };
        if (this.economySys.resources.wood < cost.wood || this.economySys.resources.stone < cost.stone) {
          eventBus.emit("toast", { message: "Need 40 Wood and 30 Stone to upgrade to Deep Ore Mine!", type: "warn" });
          return;
        }
        this.economySys.deductCost(cost);
        building.upgradeMine();
        eventBus.emit("toast", { message: "⛏️ Mine upgraded to Deep Ore Mine! Now produces Stone and Ore.", type: "success" });
        eventBus.emit("sound", { soundName: "build_done" });
        this.hud.showBuildingInspect(building);
      }
    };

    // Gate door toggle
    this.hud.onToggleGate = (building: Building) => {
      if (building.type === "gate" && building.isConstructed) {
        const nowOpen = building.toggleGate(this.world);
        this.hud.updateGateButtonText(building);
        eventBus.emit("toast", {
          message: nowOpen ? "🚪 Gate opened (Passable)" : "🔒 Gate closed & locked",
          type: "info"
        });
        eventBus.emit("sound", { soundName: "click" });
      }
    };

    // HUD unit recruitment
    this.hud.onTrainUnit = (type, building) => {
      const check = this.economySys.canTrainUnit(type);
      if (!check.ok) {
        eventBus.emit("toast", { message: check.reason!, type: "warn" });
        return;
      }

      this.economySys.deductCost(unitCostForType(type));
      eventBus.emit("toast", { message: `Training ${type.toUpperCase()}...`, type: "info" });
      eventBus.emit("sound", { soundName: "click" });

      setTimeout(() => {
        if (building.isAlive) {
          this.spawnUnit(type, building.position.x + 1.5, building.position.z + 1.5, "player");
          eventBus.emit("toast", { message: `${type.toUpperCase()} ready for service!`, type: "success" });
          eventBus.emit("sound", { soundName: "select_unit" });
        }
      }, 3000);
    };

    // Unit actions (Stop, Hold, Retreat)
    this.hud.onUnitAction = (action) => {
      for (const u of this.selectionSys.selectedUnits) {
        this.lumberZoneSys.unassignWorker(u);
        this.unassignMiner(u);
        if (action === "stop") {
          u.path = [];
          u.state = "idle";
          u.target = null;
        } else if (action === "hold") {
          u.path = [];
          u.currentOrder = "defend";
          u.state = "idle";
        } else if (action === "retreat") {
          // Path back to campfire
          const path = this.pathfindingSys.findPath(u.position.x, u.position.z, this.campfire.position.x, this.campfire.position.z);
          if (path.length > 0) {
            u.path = path;
            u.currentWaypointIndex = 0;
            u.state = "fleeing";
          }
        }
      }
      eventBus.emit("sound", { soundName: "click" });
    };

    // Direct lumber zone click event from DOM badge
    eventBus.on("lumber_zone_clicked", ({ zoneId }) => {
      this.handleLumberZoneClicked(zoneId);
    });

    // Lumber zone worker stepper events (+ and -)
    eventBus.on("lumber_zone_add_worker", ({ zoneId }) => {
      const zone = this.lumberZoneSys.zones.get(zoneId);
      if (zone) {
        this.lumberZoneSys.addSingleWorker(zone, this.units);
      }
    });

    eventBus.on("lumber_zone_remove_worker", ({ zoneId }) => {
      const zone = this.lumberZoneSys.zones.get(zoneId);
      if (zone) {
        this.lumberZoneSys.removeSingleWorker(zone, this.units);
      }
    });

    // Mine constructed event
    eventBus.on("buildingConstructed", ({ building }) => {
      if (building.type === "mine") {
        this.createMineBadge(building);
      }
    });

    // Pause, Speed, Sound, Save, Load
    document.getElementById("btn-pause")?.addEventListener("click", () => {
      this.timeOfDaySys.isPaused = !this.timeOfDaySys.isPaused;
      document.getElementById("btn-pause")!.textContent = this.timeOfDaySys.isPaused ? "▶️" : "⏸️";
      eventBus.emit("toast", { message: this.timeOfDaySys.isPaused ? "Game Paused" : "Game Resumed", type: "info" });
    });

    let speedToggle = 1;
    document.getElementById("btn-speed")?.addEventListener("click", () => {
      speedToggle = speedToggle === 1 ? 2 : (speedToggle === 2 ? 3 : 1);
      this.timeOfDaySys.timeScale = speedToggle;
      document.getElementById("btn-speed")!.textContent = `${speedToggle}x`;
    });

    document.getElementById("btn-sound")?.addEventListener("click", () => {
      const muted = this.soundMgr.toggleMute();
      document.getElementById("btn-sound")!.textContent = muted ? "🔇" : "🔊";
    });

    document.getElementById("btn-save")?.addEventListener("click", () => {
      SaveManager.saveGame(this.economySys, this.timeOfDaySys, this.units, this.buildings, this.world);
    });

    document.getElementById("btn-load")?.addEventListener("click", () => {
      const saved = SaveManager.loadGame();
      if (saved) {
        this.applySaveGame(saved);
      }
    });

    document.getElementById("btn-restart")?.addEventListener("click", () => {
      window.location.reload();
    });

    // Night wave trigger
    eventBus.on("raidStarted", (data: { day: number }) => {
      this.raidSys.spawnNightWave(data.day, this.units, this.buildings, (enemy) => {
        this.units.push(enemy);
        this.scene.add(enemy.meshHierarchy.root);
      });
    });
  }

  private applySaveGame(saved: any): void {
    this.economySys.resources = { ...saved.resources };
    this.timeOfDaySys.day = saved.day;
    this.timeOfDaySys.elapsedSeconds = saved.elapsedSeconds;
    eventBus.emit("toast", { message: "Loaded game state from save!", type: "success" });
  }

  private handleLumberZoneClicked(zoneId: string): void {
    const zone = this.lumberZoneSys.zones.get(zoneId);
    if (!zone) return;

    // Activate selection visibility for this zone
    for (const z of this.lumberZoneSys.zones.values()) {
      z.isSelected = (z.id === zoneId);
      this.lumberZoneSys.updateZoneVisibility(z);
    }

    let workers = this.selectionSys.selectedUnits.filter((u) => u.type === "worker" && u.isAlive);

    // If no workers are currently selected, find all idle workers or any alive player workers
    if (workers.length === 0) {
      const idleWorkers = this.units.filter((u) => u.type === "worker" && u.faction === "player" && u.isAlive && u.state === "idle");
      const allWorkers = this.units.filter((u) => u.type === "worker" && u.faction === "player" && u.isAlive);
      workers = idleWorkers.length > 0 ? idleWorkers : allWorkers;

      if (workers.length > 0) {
        this.selectionSys.clearSelection();
        for (const w of workers) {
          this.selectionSys.selectUnit(w, true);
        }
      }
    }

    if (workers.length > 0) {
      for (const w of workers) {
        this.unassignMiner(w);
      }
      this.lumberZoneSys.assignWorkersToZone(zone, workers);
    } else {
      eventBus.emit("toast", { message: "No workers available! Train workers at a Hut [1].", type: "warn" });
    }
  }

  private unassignMiner(u: Unit): void {
    const mineId = (u as any).miningBuildingId;
    if (mineId) {
      const mine = this.buildings.find((b) => b.id === mineId);
      if (mine) {
        mine.assignedMinerIds.delete(u.id);
        this.gatheringSys.updateMineBadgeCount(mine);
      }
      delete (u as any).miningBuildingId;
    }
    u.meshHierarchy.root.visible = true;
  }

  private createMineBadge(building: Building): void {
    if (building.domBadge || building.type !== "mine") return;

    const overlay = document.getElementById("lumber-zones-overlay");
    if (!overlay) return;

    const domBadge = document.createElement("div");
    domBadge.className = "floating-badge mine";
    domBadge.dataset.buildingId = building.id;

    const circleEl = document.createElement("div");
    circleEl.className = "badge-circle mine";
    circleEl.textContent = "⛏️";
    circleEl.title = "Stone Mine — Click to inspect, or use +/- to adjust miners";

    const labelEl = document.createElement("div");
    labelEl.className = "badge-label mine";
    labelEl.textContent = building.level >= 2 ? "DEEP MINE" : "MINE";

    const stepperEl = document.createElement("div");
    stepperEl.className = "stepper-panel mine";

    const btnMinus = document.createElement("button");
    btnMinus.className = "btn-stepper btn-minus mine";
    btnMinus.textContent = "−";
    btnMinus.title = "Eject 1 miner from mine";

    const countBox = document.createElement("div");
    countBox.className = "stepper-count-box";
    const countNum = document.createElement("span");
    countNum.className = "stepper-num";
    countNum.textContent = `${building.assignedMinerIds.size}`;
    const countIcon = document.createElement("span");
    countIcon.className = "stepper-icon";
    countIcon.textContent = "🧑‍🌾";
    countBox.appendChild(countNum);
    countBox.appendChild(countIcon);

    const btnPlus = document.createElement("button");
    btnPlus.className = "btn-stepper btn-plus mine";
    btnPlus.textContent = "+";
    btnPlus.title = "Send 1 idle worker to mine";

    stepperEl.appendChild(btnMinus);
    stepperEl.appendChild(countBox);
    stepperEl.appendChild(btnPlus);

    domBadge.appendChild(circleEl);
    domBadge.appendChild(labelEl);
    domBadge.appendChild(stepperEl);

    // Stepper button events
    btnPlus.addEventListener("click", (e) => {
      e.stopPropagation();
      e.preventDefault();
      this.gatheringSys.addWorkerToMine(building, this.units);
    });

    btnMinus.addEventListener("click", (e) => {
      e.stopPropagation();
      e.preventDefault();
      this.gatheringSys.ejectMiner(building, this.units);
    });

    // Badge click selects building
    circleEl.addEventListener("click", (e) => {
      e.stopPropagation();
      e.preventDefault();
      this.selectionSys.selectBuilding(building);
    });

    circleEl.addEventListener("contextmenu", (e) => {
      e.stopPropagation();
      e.preventDefault();
      const workers = this.selectionSys.selectedUnits.filter((u) => u.type === "worker" && u.isAlive);
      if (workers.length > 0) {
        for (const w of workers) {
          if (building.assignedMinerIds.size < building.maxMiners) {
            this.lumberZoneSys.unassignWorker(w);
            this.gatheringSys.orderEnterMine(w, building);
          }
        }
      } else {
        this.gatheringSys.addWorkerToMine(building, this.units);
      }
    });

    overlay.appendChild(domBadge);
    building.domBadge = domBadge;
    building.domCountNum = countNum;
    building.domLabel = labelEl;
  }

  private getRaycastTargets(): THREE.Object3D[] {
    const targets: THREE.Object3D[] = [this.terrainRenderer.terrainGroup];
    for (const u of this.units) {
      if (u.isAlive) targets.push(u.meshHierarchy.root);
    }
    for (const b of this.buildings) {
      if (b.isAlive) targets.push(b.mesh);
    }
    for (const z of this.lumberZoneSys.zones.values()) {
      targets.push(z.hitBox);
      targets.push(z.badgeSprite);
      targets.push(z.axeMesh);
      targets.push(z.beamMesh);
      targets.push(z.centerRing);
    }
    return targets;
  }

  private setupMouseEvents(): void {
    // Left Click / Drag selection
    this.canvas.addEventListener("mousedown", (e) => {
      if (e.button === 0) {
        // Lumber zone circle drag start
        if (this.lumberZoneSys.isPlacingMode) {
          const hit = this.raycastMgr.getGroundHit(
            e.clientX,
            e.clientY,
            this.camera,
            window.innerWidth,
            window.innerHeight,
            this.world,
            this.units,
            this.buildings,
            this.getRaycastTargets()
          );
          this.lumberZoneSys.startCircleDrag(hit.point.x, hit.point.z);
          return;
        }

        // If building ghost active, confirm placement on left click
        if (this.constructionSys.activeGhostType) {
          const placed = this.constructionSys.confirmPlacement(this.units, this.buildings);
          if (placed) {
            this.hud.clearBuildActive();
            this.updatePopulationCounters();
          }
          return;
        }

        // Start marquee drag
        this.selectionSys.startDrag(e.clientX, e.clientY);
      }
    });

    window.addEventListener("mousemove", (e) => {
      // Update Lumber Zone drag circle preview if dragging
      if (this.lumberZoneSys.isDraggingCircle) {
        const hit = this.raycastMgr.getGroundHit(
          e.clientX,
          e.clientY,
          this.camera,
          window.innerWidth,
          window.innerHeight,
          this.world,
          this.units,
          this.buildings,
          this.getRaycastTargets()
        );
        this.lumberZoneSys.updateCircleDrag(hit.point.x, hit.point.z);
        return;
      }

      if (this.selectionSys.isDragging) {
        this.selectionSys.updateDrag(e.clientX, e.clientY);
      }

      // Update ghost placement position if active
      if (this.constructionSys.activeGhostType) {
        const hit = this.raycastMgr.getGroundHit(
          e.clientX,
          e.clientY,
          this.camera,
          window.innerWidth,
          window.innerHeight,
          this.world,
          this.units,
          this.buildings,
          this.getRaycastTargets()
        );
        this.constructionSys.updateGhostPosition(hit.point.x, hit.point.z, this.buildings);
      }
    });

    window.addEventListener("mouseup", (e) => {
      if (e.button === 0) {
        // Complete Lumber Zone drag
        if (this.lumberZoneSys.isDraggingCircle) {
          this.lumberZoneSys.endCircleDrag();
          this.hud.setLumberZoneActive(false);
          return;
        }

        if (this.constructionSys.activeGhostType) return;

        const didDragSelect = this.selectionSys.endDrag(
          e.clientX,
          e.clientY,
          this.camera,
          window.innerWidth,
          window.innerHeight,
          this.units,
          e.shiftKey
        );

        if (!didDragSelect) {
          // Single click raycast
          const hit = this.raycastMgr.getGroundHit(
            e.clientX,
            e.clientY,
            this.camera,
            window.innerWidth,
            window.innerHeight,
            this.world,
            this.units,
            this.buildings,
            this.getRaycastTargets()
          );

          let clickedZoneId: string | null = hit.lumberZoneId || null;
          if (!clickedZoneId) {
            for (const z of this.lumberZoneSys.zones.values()) {
              if (Math.hypot(hit.point.x - z.centerX, hit.point.z - z.centerZ) <= 2.0) {
                clickedZoneId = z.id;
                break;
              }
            }
          }

          if (clickedZoneId) {
            this.handleLumberZoneClicked(clickedZoneId);
          } else if (hit.unit) {
            this.lumberZoneSys.clearSelections();
            this.selectionSys.selectUnit(hit.unit, e.shiftKey);
          } else if (hit.building) {
            this.lumberZoneSys.clearSelections();
            this.selectionSys.selectBuilding(hit.building);
          } else {
            this.lumberZoneSys.clearSelections();
            this.selectionSys.clearSelection();
          }
        }
      }
    });

    // Right Click: Contextual RTS Orders
    this.canvas.addEventListener("contextmenu", (e) => {
      e.preventDefault();

      // Cancel Lumber Zone placement on right click
      if (this.lumberZoneSys.isPlacingMode) {
        this.lumberZoneSys.cancelPreview();
        this.hud.setLumberZoneActive(false);
        return;
      }

      // Cancel ghost placement on right click
      if (this.constructionSys.activeGhostType) {
        this.constructionSys.setGhostBuilding(null);
        this.hud.clearBuildActive();
        return;
      }

      const hit = this.raycastMgr.getGroundHit(
        e.clientX,
        e.clientY,
        this.camera,
        window.innerWidth,
        window.innerHeight,
        this.world,
        this.units,
        this.buildings,
        this.getRaycastTargets()
      );

      // Check Lumber Zone right-click (assigned directly whether units were selected before or not)
      let clickedZone: LumberZone | null = null;
      if (hit.lumberZoneId) {
        clickedZone = this.lumberZoneSys.zones.get(hit.lumberZoneId) || null;
      } else {
        // Also check if clicked near center pillar (within 2.2 tiles)
        for (const z of this.lumberZoneSys.zones.values()) {
          if (Math.hypot(hit.point.x - z.centerX, hit.point.z - z.centerZ) <= 2.2) {
            clickedZone = z;
            break;
          }
        }
      }

      if (clickedZone) {
        this.handleLumberZoneClicked(clickedZone.id);
        this.showClickMarker(hit.point.x, hit.point.y + 0.05, hit.point.z);
        return;
      }

      const selected = this.selectionSys.selectedUnits;
      if (selected.length === 0) {
        // Direct right-click on constructed Gate toggles open/close
        if (hit.building && hit.building.type === "gate" && hit.building.isConstructed) {
          const nowOpen = hit.building.toggleGate(this.world);
          this.hud.updateGateButtonText(hit.building);
          eventBus.emit("toast", {
            message: nowOpen ? "🚪 Gate opened (Passable)" : "🔒 Gate closed & locked",
            type: "info"
          });
          eventBus.emit("sound", { soundName: "click" });
          this.showClickMarker(hit.point.x, hit.point.y + 0.05, hit.point.z);
        }
        return;
      }

      // Check if clicked ground is on or right next to a resource node
      if (!hit.resource) {
        const directTile = this.world.getTile(hit.gridX, hit.gridZ);
        if (directTile?.resourceId) {
          hit.resource = this.world.resources.get(directTile.resourceId) || null;
        }
      }

      // Show click marker animation
      this.showClickMarker(hit.point.x, hit.point.y + 0.05, hit.point.z);

      // 1. Click on Enemy -> Attack
      if (hit.unit && hit.unit.faction === "enemy") {
        for (const u of selected) {
          this.lumberZoneSys.unassignWorker(u);
          this.unassignMiner(u);
          this.combatSys.orderAttack(u, hit.unit);
        }
        eventBus.emit("sound", { soundName: "order_move" });
        return;
      }

      // 2. Click on Mine Building -> Mine Stone / Ore (Workers)
      if (hit.building && hit.building.type === "mine" && hit.building.isConstructed) {
        let anyWorker = false;
        for (const u of selected) {
          if (u.type === "worker") {
            if (hit.building.assignedMinerIds.size < hit.building.maxMiners) {
              anyWorker = true;
              this.lumberZoneSys.unassignWorker(u);
              this.gatheringSys.orderEnterMine(u, hit.building);
            } else {
              eventBus.emit("toast", { message: `Mine is at full capacity (${hit.building.maxMiners}/${hit.building.maxMiners})!`, type: "warn" });
              break;
            }
          }
        }
        if (anyWorker) {
          eventBus.emit("sound", { soundName: "order_move" });
        } else if (selected.every((u) => u.type !== "worker")) {
          eventBus.emit("toast", { message: "Only workers can enter and work in the Mine!", type: "warn" });
        }
        return;
      }

      // 3. Click on Resource -> Gather (Workers)
      if (hit.resource) {
        // If clicking a tree inside a lumber zone, assign to the whole zone
        const zoneAtTree = this.lumberZoneSys.getZoneAt(hit.resource.x + 0.5, hit.resource.z + 0.5);
        if (zoneAtTree) {
          const workers = selected.filter((u) => u.type === "worker");
          if (workers.length > 0) {
            for (const w of workers) {
              this.unassignMiner(w);
            }
            this.lumberZoneSys.assignWorkersToZone(zoneAtTree, workers);
            return;
          }
        }

        let anyWorker = false;
        for (const u of selected) {
          if (u.type === "worker") {
            anyWorker = true;
            this.lumberZoneSys.unassignWorker(u);
            this.unassignMiner(u);
            this.gatheringSys.orderGather(u, hit.resource);
          }
        }
        if (anyWorker) {
          eventBus.emit("sound", { soundName: "order_move" });
        } else {
          eventBus.emit("toast", { message: "Only workers can gather resources!", type: "warn" });
        }
        return;
      }

      // 4. Click on Unfinished Building -> Build
      if (hit.building && !hit.building.isConstructed) {
        for (const u of selected) {
          if (u.type === "worker") {
            this.lumberZoneSys.unassignWorker(u);
            this.unassignMiner(u);
            this.constructionSys.orderBuild(u, hit.building);
          }
        }
        eventBus.emit("sound", { soundName: "order_move" });
        return;
      }

      // 4. Click on Chest / POI -> Interact / Loot
      if (hit.poi && hit.poi.type === "chest" && !hit.poi.isOpened) {
        const u = selected[0];
        this.lumberZoneSys.unassignWorker(u);
        this.unassignMiner(u);
        const path = this.pathfindingSys.findPath(u.position.x, u.position.z, hit.poi.x, hit.poi.z);
        if (path.length > 0) {
          u.path = path;
          u.currentWaypointIndex = 0;
          u.state = "moving";

          const checkArrival = setInterval(() => {
            if (Math.hypot(u.position.x - hit.poi!.x, u.position.z - hit.poi!.z) < 1.6) {
              clearInterval(checkArrival);
              hit.poi!.isOpened = true;
              this.terrainRenderer.openChestMesh(hit.poi!.id);
              if (hit.poi!.loot) {
                if (hit.poi!.loot.wood) this.economySys.addResource("wood", hit.poi!.loot.wood);
                if (hit.poi!.loot.stone) this.economySys.addResource("stone", hit.poi!.loot.stone);
                if (hit.poi!.loot.food) this.economySys.addResource("food", hit.poi!.loot.food);
                if (hit.poi!.loot.ore) this.economySys.addResource("ore", hit.poi!.loot.ore);
              }
              eventBus.emit("toast", { message: "💎 Found Treasure Chest! Resources added!", type: "success" });
              eventBus.emit("sound", { soundName: "chest" });
            }
          }, 300);
        }
        return;
      }

      // 5. Move to Ground with Squad Formation
      const formationOffsets = PathfindingSystem.getFormationOffsets(selected.length, 1.2);
      for (let i = 0; i < selected.length; i++) {
        const u = selected[i];
        this.lumberZoneSys.unassignWorker(u);
        this.unassignMiner(u);
        const off = formationOffsets[i];
        const tx = Math.max(1, Math.min(this.world.size - 2, hit.point.x + off.x));
        const tz = Math.max(1, Math.min(this.world.size - 2, hit.point.z + off.z));

        const path = this.pathfindingSys.findPath(u.position.x, u.position.z, tx, tz);
        if (path.length > 0) {
          u.path = path;
          u.currentWaypointIndex = 0;
          u.currentOrder = "move";
          u.state = "moving";
          u.target = null;
        }
      }

      eventBus.emit("sound", { soundName: "order_move" });
    });

    // Keyboard Hotkeys
    window.addEventListener("keydown", (e) => {
      if (e.code === "Space") {
        this.timeOfDaySys.isPaused = !this.timeOfDaySys.isPaused;
      } else if (e.code === "Escape") {
        this.constructionSys.setGhostBuilding(null);
        this.lumberZoneSys.cancelPreview();
        this.lumberZoneSys.clearSelections();
        this.hud.setLumberZoneActive(false);
        this.hud.clearBuildActive();
        this.selectionSys.clearSelection();
      } else if (e.code === "Digit1" && !e.ctrlKey) {
        this.constructionSys.setGhostBuilding("hut");
      } else if (e.code === "Digit2" && !e.ctrlKey) {
        this.constructionSys.setGhostBuilding("storage");
      } else if (e.code === "Digit3" && !e.ctrlKey) {
        this.constructionSys.setGhostBuilding("wall");
      } else if (e.code === "Digit4" && !e.ctrlKey) {
        this.constructionSys.setGhostBuilding("gate");
      } else if (e.code === "Digit5" && !e.ctrlKey) {
        this.constructionSys.setGhostBuilding("tower");
      } else if (e.code === "Digit6" && !e.ctrlKey) {
        this.constructionSys.setGhostBuilding("workshop");
      } else if (e.code === "Digit7" && !e.ctrlKey) {
        this.lumberZoneSys.cancelPreview();
        this.hud.setLumberZoneActive(false);
        this.constructionSys.setGhostBuilding("mine");
      } else if (e.code === "KeyZ" && !e.ctrlKey) {
        this.constructionSys.setGhostBuilding(null);
        const active = this.lumberZoneSys.togglePlacingMode();
        this.hud.setLumberZoneActive(active);
        if (active) {
          eventBus.emit("toast", {
            message: "🪓 Lumber Mode: Drag LMB on ground near trees to create a logging zone",
            type: "info"
          });
        }
      } else if (e.code === "KeyO" && !e.ctrlKey) {
        if (this.selectionSys.selectedBuilding && this.selectionSys.selectedBuilding.type === "gate") {
          const b = this.selectionSys.selectedBuilding;
          const nowOpen = b.toggleGate(this.world);
          this.hud.updateGateButtonText(b);
          eventBus.emit("toast", {
            message: nowOpen ? "🚪 Gate opened (Passable)" : "🔒 Gate closed & locked",
            type: "info"
          });
          eventBus.emit("sound", { soundName: "click" });
        }
      }
    });
  }

  private showClickMarker(x: number, y: number, z: number): void {
    this.clickMarker.position.set(x, y, z);
    this.clickMarker.scale.set(1, 1, 1);
    (this.clickMarker.material as THREE.MeshBasicMaterial).opacity = 0.9;
    this.clickMarkerTimer = 0.4;
  }

  private setupResize(): void {
    window.addEventListener("resize", () => {
      this.camera.aspect = window.innerWidth / window.innerHeight;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(window.innerWidth, window.innerHeight);
    });
  }

  private loop(time: number): void {
    requestAnimationFrame(this.loop.bind(this));

    const dt = Math.min((time - this.lastTime) / 1000, 0.1);
    this.lastTime = time;

    // Performance FPS calculation
    this.frameCount++;
    if (time - this.lastFpsTime >= 500) {
      this.currentFps = (this.frameCount * 1000) / (time - this.lastFpsTime);
      this.frameCount = 0;
      this.lastFpsTime = time;
    }

    const simStart = performance.now();

    if (!this.isGameOver) {
      // 1. Camera
      this.cameraCtrl.update(dt, (x, z) => this.world.getHeight(x, z));

      // 2. Day / Night cycle
      this.timeOfDaySys.update(dt);
      const timeState = this.timeOfDaySys.getTimeState();
      this.lighting.updateTime(timeState.timeOfDay, timeState.cycleProgress, this.world.size);

      // Gate proximity auto-open for friendly units (unless locked closed)
      for (const b of this.buildings) {
        if (b.type === "gate" && b.isConstructed && b.isAlive) {
          if (!b.isGateLocked) {
            const hasNearbyFriendly = this.units.some(
              (u) => u.faction === "player" && u.isAlive && Math.hypot(u.position.x - b.position.x, u.position.z - b.position.z) <= 2.5
            );
            b.setGateOpen(hasNearbyFriendly, this.world);
          }
        }
      }

      // 3. Movement
      this.movementSys.update(this.units, dt);

      // 4. Gathering, Lumber Zones & Construction
      this.lumberZoneSys.update(this.units, dt, this.camera);
      this.gatheringSys.update(this.units, this.buildings, dt);
      this.constructionSys.update(this.units, dt);

      // Mine Badges screen projection
      for (const b of this.buildings) {
        if (b.type === "mine") {
          if (b.isConstructed && b.isAlive) {
            if (!b.domBadge) {
              this.createMineBadge(b);
            }
            if (b.domBadge) {
              this.tempVec.set(b.position.x, b.position.y + 3.2, b.position.z);
              this.tempVec.project(this.camera);

              if (this.tempVec.z < 1.0) {
                const screenX = (this.tempVec.x * 0.5 + 0.5) * window.innerWidth;
                const screenY = (-(this.tempVec.y * 0.5) + 0.5) * window.innerHeight;
                b.domBadge.style.display = "flex";
                b.domBadge.style.left = `${screenX}px`;
                b.domBadge.style.top = `${screenY}px`;
              } else {
                b.domBadge.style.display = "none";
              }
            }
          } else if (b.domBadge) {
            b.domBadge.remove();
            b.domBadge = undefined;
          }
        }
      }

      // 5. Combat & Defense
      const { defeatedUnits, destroyedBuildings } = this.combatSys.update(this.units, this.buildings, dt);

      for (const du of defeatedUnits) {
        if (du.faction === "enemy") {
          this.raidSys.onEnemyDefeated();
        }
      }

      for (const db of destroyedBuildings) {
        if (db.type === "mine") {
          db.ejectAllMiners(this.units, this.world);
          if (db.domBadge) {
            db.domBadge.remove();
            db.domBadge = undefined;
          }
        }
      }

      // Check Game Over
      if (!this.campfire.isAlive) {
        this.triggerGameOver(false, "Your Central Campfire has fallen!");
      } else {
        const alivePlayers = this.units.filter((u) => u.faction === "player" && u.isAlive);
        if (alivePlayers.length === 0 && this.economySys.resources.food < 20) {
          this.triggerGameOver(false, "All villagers perished and not enough food to train more!");
        }
      }

      // 6. Fog of War
      this.fogOfWarSys.update(this.units, this.buildings, timeState.isNight);

      // 7. Animations & Visual effects
      for (const u of this.units) {
        u.updateAnimation(dt);
      }
      this.particles.update(dt);

      // Real-time HUD selection updates
      if (this.selectionSys.selectedUnits.length === 1) {
        this.hud.refreshSelectedUnit(this.selectionSys.selectedUnits[0]);
      }

      // Click marker animation
      if (this.clickMarkerTimer > 0) {
        this.clickMarkerTimer -= dt;
        const progress = 1.0 - this.clickMarkerTimer / 0.4;
        const scale = 1.0 + progress * 0.8;
        this.clickMarker.scale.set(scale, scale, scale);
        (this.clickMarker.material as THREE.MeshBasicMaterial).opacity = 0.9 * (1.0 - progress);
      }
    }

    const simMs = performance.now() - simStart;

    // 8. Render 3D Scene
    this.renderer.render(this.scene, this.camera);

    // 9. Render Minimap
    this.minimap.render(this.units, this.buildings);

    // 10. Update Debug Overlay
    const playerUnitsCount = this.units.filter(u => u.faction === "player" && u.isAlive).length;
    const enemiesCount = this.units.filter(u => u.faction === "enemy" && u.isAlive).length;
    this.hud.updateDebug(
      this.currentFps,
      this.renderer.info.render.calls,
      this.renderer.info.render.triangles,
      playerUnitsCount,
      enemiesCount,
      simMs,
      this.cameraCtrl.target.x,
      this.cameraCtrl.target.z
    );
  }

  private triggerGameOver(victory: boolean, reason: string): void {
    if (this.isGameOver) return;
    this.isGameOver = true;

    const modal = document.getElementById("game-over-modal");
    const title = document.getElementById("game-over-title");
    const desc = document.getElementById("game-over-desc");
    const stats = document.getElementById("game-over-stats");

    if (modal && title && desc && stats) {
      title.textContent = victory ? "Victory!" : "Defeat!";
      title.style.color = victory ? "#22c55e" : "#ef4444";
      desc.textContent = reason;
      stats.innerHTML = `<p>Survived until Day ${this.timeOfDaySys.day}</p>`;
      modal.classList.remove("hidden");
    }
  }
}

function unitCostForType(type: "worker" | "guard" | "archer"): { food?: number; wood?: number; stone?: number } {
  if (type === "worker") return { food: 20 };
  if (type === "guard") return { food: 30, wood: 15, stone: 5 };
  return { food: 25, wood: 25 };
}
