import * as THREE from "three";
import { World } from "../world/World";
import { Unit } from "../entities/Unit";
import { ResourceData } from "../world/ResourceSpawner";
import { GatheringSystem } from "./GatheringSystem";
import { eventBus } from "../game/EventBus";

export interface LumberZone {
  id: string;
  centerX: number;
  centerZ: number;
  radius: number;
  markerY: number;
  badgeSprite: THREE.Sprite;
  axeMesh: THREE.Group;
  beamMesh: THREE.Mesh;
  centerRing: THREE.Mesh;
  hitBox: THREE.Mesh;
  boundaryRing: THREE.Mesh;
  domBadge: HTMLElement;
  domLabel: HTMLElement;
  domCountNum: HTMLElement;
  assignedWorkerIds: Set<string>;
  isSelected: boolean;
  isHovered: boolean;
}

export class LumberZoneSystem {
  private scene: THREE.Scene;
  private world: World;
  private gatheringSys: GatheringSystem;

  public zones: Map<string, LumberZone> = new Map();
  private zoneCounter = 1;

  // Drag creation state
  public isPlacingMode: boolean = false;
  public isDraggingCircle: boolean = false;
  public dragCenter: { x: number; z: number } = { x: 0, z: 0 };
  public currentRadius: number = 3.0;
  private previewMesh: THREE.Mesh | null = null;
  private overlayContainer: HTMLElement | null = null;

  constructor(scene: THREE.Scene, world: World, gatheringSys: GatheringSystem) {
    this.scene = scene;
    this.world = world;
    this.gatheringSys = gatheringSys;
    this.overlayContainer = document.getElementById("lumber-zones-overlay");
  }

  public togglePlacingMode(): boolean {
    this.isPlacingMode = !this.isPlacingMode;
    if (!this.isPlacingMode) {
      this.cancelPreview();
    }
    return this.isPlacingMode;
  }

  public startCircleDrag(x: number, z: number): void {
    if (!this.isPlacingMode) return;
    this.isDraggingCircle = true;
    this.dragCenter = { x, z };
    this.currentRadius = 3.0;

    if (!this.previewMesh) {
      const geo = new THREE.RingGeometry(0.1, 1, 32);
      geo.rotateX(-Math.PI / 2);
      const mat = new THREE.MeshBasicMaterial({
        color: 0x22c55e,
        transparent: true,
        opacity: 0.45,
        side: THREE.DoubleSide
      });
      this.previewMesh = new THREE.Mesh(geo, mat);
      this.scene.add(this.previewMesh);
    }

    const y = this.world.getHeight(x, z) + 0.05;
    this.previewMesh.position.set(x, y, z);
    this.previewMesh.scale.set(this.currentRadius, 1, this.currentRadius);
    this.previewMesh.visible = true;
  }

  public updateCircleDrag(x: number, z: number): void {
    if (!this.isDraggingCircle || !this.previewMesh) return;

    const dist = Math.hypot(x - this.dragCenter.x, z - this.dragCenter.z);
    this.currentRadius = Math.max(2.0, Math.min(16.0, dist));

    this.previewMesh.scale.set(this.currentRadius, 1, this.currentRadius);
  }

  public endCircleDrag(): LumberZone | null {
    if (!this.isDraggingCircle) return null;
    this.isDraggingCircle = false;
    this.isPlacingMode = false;

    if (this.previewMesh) {
      this.previewMesh.visible = false;
    }

    const zone = this.createZone(this.dragCenter.x, this.dragCenter.z, this.currentRadius);
    const trees = this.getTreesInZone(zone);

    eventBus.emit("toast", {
      message: `🪓 Lumber Zone placed (${trees.length} trees)! Right-click the floating axe icon to assign workers.`,
      type: "success"
    });
    eventBus.emit("sound", { soundName: "click" });

    return zone;
  }

  public cancelPreview(): void {
    this.isPlacingMode = false;
    this.isDraggingCircle = false;
    if (this.previewMesh) {
      this.previewMesh.visible = false;
    }
  }

  public createZone(cx: number, cz: number, radius: number): LumberZone {
    const id = `lumber_zone_${this.zoneCounter++}`;
    const cy = this.world.getHeight(cx, cz);

    // Tree tops are ~2.8 units above ground. Position marker comfortably right above them
    const markerY = cy + 3.4;

    // 1. Vertical glowing pillar beam from ground to icon
    const beamHeight = markerY - cy + 0.4;
    const beamGeo = new THREE.CylinderGeometry(0.12, 0.12, beamHeight, 8);
    const beamMat = new THREE.MeshBasicMaterial({
      color: 0xf59e0b,
      transparent: true,
      opacity: 0.75
    });
    const beamMesh = new THREE.Mesh(beamGeo, beamMat);
    beamMesh.position.set(cx, cy + beamHeight / 2, cz);
    beamMesh.userData = { lumberZoneId: id };
    this.scene.add(beamMesh);

    // 2. Ground Center Pulsing Disc
    const centerRingGeo = new THREE.RingGeometry(0.2, 1.2, 24);
    centerRingGeo.rotateX(-Math.PI / 2);
    const centerRingMat = new THREE.MeshBasicMaterial({
      color: 0xf59e0b,
      transparent: true,
      opacity: 0.8,
      side: THREE.DoubleSide
    });
    const centerRing = new THREE.Mesh(centerRingGeo, centerRingMat);
    centerRing.position.set(cx, cy + 0.06, cz);
    centerRing.userData = { lumberZoneId: id };
    this.scene.add(centerRing);

    // 3. High-definition Canvas Texture for 3D Sprite (Vector Axe, 100% OS/browser compatible)
    const canvas = document.createElement("canvas");
    canvas.width = 256;
    canvas.height = 256;
    const ctx = canvas.getContext("2d")!;

    // Circle background with dark gradient
    const grad = ctx.createRadialGradient(128, 128, 10, 128, 128, 116);
    grad.addColorStop(0, "#1e293b");
    grad.addColorStop(1, "#090d16");
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(128, 128, 116, 0, Math.PI * 2);
    ctx.fill();

    // Outer golden glow ring
    ctx.lineWidth = 14;
    ctx.strokeStyle = "#f59e0b";
    ctx.stroke();

    // Inner bright gold highlight ring
    ctx.lineWidth = 4;
    ctx.strokeStyle = "#fef08a";
    ctx.stroke();

    // Draw Vector Axe (Blade + Handle)
    ctx.save();
    ctx.translate(128, 105);
    ctx.rotate(-Math.PI / 6);

    // Wooden handle
    ctx.fillStyle = "#b45309";
    ctx.fillRect(-10, -50, 20, 100);
    ctx.strokeStyle = "#78350f";
    ctx.lineWidth = 3;
    ctx.strokeRect(-10, -50, 20, 100);

    // Steel Axe Blade
    ctx.fillStyle = "#cbd5e1";
    ctx.beginPath();
    ctx.moveTo(0, -45);
    ctx.lineTo(45, -60);
    ctx.bezierCurveTo(55, -20, 55, -10, 45, 10);
    ctx.lineTo(0, -15);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = "#475569";
    ctx.lineWidth = 4;
    ctx.stroke();

    // Blade sharp edge highlight
    ctx.strokeStyle = "#ffffff";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(45, -60);
    ctx.bezierCurveTo(55, -20, 55, -10, 45, 10);
    ctx.stroke();

    ctx.restore();

    // Text label "LOGGING"
    ctx.fillStyle = "#fbbf24";
    ctx.font = "bold 30px 'Segoe UI', Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.shadowColor = "rgba(0, 0, 0, 0.9)";
    ctx.shadowBlur = 6;
    ctx.fillText("LOGGING", 128, 198);

    const spriteTexture = new THREE.CanvasTexture(canvas);
    const spriteMat = new THREE.SpriteMaterial({
      map: spriteTexture,
      transparent: true,
      depthTest: false,
      depthWrite: false
    });
    const badgeSprite = new THREE.Sprite(spriteMat);
    badgeSprite.scale.set(3.2, 3.2, 1.0);
    badgeSprite.position.set(cx, markerY + 0.6, cz);
    badgeSprite.renderOrder = 9999;
    badgeSprite.userData = { lumberZoneId: id };
    this.scene.add(badgeSprite);

    // 4. 3D Floating rotating Axe model beneath badge
    const axeGroup = new THREE.Group();
    axeGroup.position.set(cx, markerY - 0.7, cz);
    axeGroup.scale.set(2.0, 2.0, 2.0);
    axeGroup.userData = { lumberZoneId: id };

    const handle = new THREE.Mesh(
      new THREE.BoxGeometry(0.1, 0.8, 0.1),
      new THREE.MeshLambertMaterial({ color: 0xd97706 })
    );
    handle.rotation.z = Math.PI / 4;
    handle.userData = { lumberZoneId: id };
    axeGroup.add(handle);

    const blade = new THREE.Mesh(
      new THREE.BoxGeometry(0.36, 0.28, 0.09),
      new THREE.MeshStandardMaterial({ color: 0xe2e8f0, metalness: 0.85, roughness: 0.15 })
    );
    blade.position.set(0.18, 0.18, 0);
    blade.userData = { lumberZoneId: id };
    axeGroup.add(blade);
    this.scene.add(axeGroup);

    // 5. Full-height cylinder raycast hitbox covering ground to above badge
    const hitHeight = beamHeight + 3.0;
    const hitGeo = new THREE.CylinderGeometry(2.5, 2.5, hitHeight, 12);
    const hitMat = new THREE.MeshBasicMaterial({
      transparent: true,
      opacity: 0.001,
      depthWrite: false
    });
    const hitBox = new THREE.Mesh(hitGeo, hitMat);
    hitBox.position.set(cx, cy + hitHeight / 2, cz);
    hitBox.userData = { lumberZoneId: id };
    this.scene.add(hitBox);

    // 6. Ground boundary ring (hidden by default, shown on hover/selection)
    const ringGeo = new THREE.RingGeometry(radius - 0.2, radius, 48);
    ringGeo.rotateX(-Math.PI / 2);
    const ringMat = new THREE.MeshBasicMaterial({
      color: 0xf59e0b,
      transparent: true,
      opacity: 0.85,
      side: THREE.DoubleSide
    });
    const boundaryRing = new THREE.Mesh(ringGeo, ringMat);
    boundaryRing.position.set(cx, cy + 0.05, cz);
    boundaryRing.visible = false;
    this.scene.add(boundaryRing);

    // Ground center ring also hidden by default
    centerRing.visible = false;

    // 7. Interactive Screen-Space DOM Overlay Badge with +/- Stepper
    if (!this.overlayContainer) {
      this.overlayContainer = document.getElementById("lumber-zones-overlay");
    }

    const domBadge = document.createElement("div");
    domBadge.className = "floating-badge";
    domBadge.dataset.zoneId = id;

    const circleEl = document.createElement("div");
    circleEl.className = "badge-circle";
    circleEl.textContent = "🪓";
    circleEl.title = "Lumber Zone — Click to toggle boundary, or use +/- to adjust workers";

    const labelEl = document.createElement("div");
    labelEl.className = "badge-label";
    labelEl.textContent = "WOOD";

    // Stepper Panel [-] [Count] [+]
    const stepperEl = document.createElement("div");
    stepperEl.className = "stepper-panel";

    const btnMinus = document.createElement("button");
    btnMinus.className = "btn-stepper btn-minus";
    btnMinus.textContent = "−";
    btnMinus.title = "Release 1 worker";

    const countBox = document.createElement("div");
    countBox.className = "stepper-count-box";
    const countNum = document.createElement("span");
    countNum.className = "stepper-num";
    countNum.textContent = "0";
    const countIcon = document.createElement("span");
    countIcon.className = "stepper-icon";
    countIcon.textContent = "🧑‍🌾";
    countBox.appendChild(countNum);
    countBox.appendChild(countIcon);

    const btnPlus = document.createElement("button");
    btnPlus.className = "btn-stepper btn-plus";
    btnPlus.textContent = "+";
    btnPlus.title = "Send 1 idle worker to chop";

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
      eventBus.emit("lumber_zone_add_worker", { zoneId: id });
    });

    btnMinus.addEventListener("click", (e) => {
      e.stopPropagation();
      e.preventDefault();
      eventBus.emit("lumber_zone_remove_worker", { zoneId: id });
    });

    // Badge click toggles selection/boundary visibility
    circleEl.addEventListener("click", (e) => {
      e.stopPropagation();
      e.preventDefault();
      const z = this.zones.get(id);
      if (z) {
        z.isSelected = !z.isSelected;
        this.updateZoneVisibility(z);
      }
    });

    circleEl.addEventListener("contextmenu", (e) => {
      e.stopPropagation();
      e.preventDefault();
      eventBus.emit("lumber_zone_clicked", { zoneId: id });
    });

    // Hover reveals boundary ring on ground
    domBadge.addEventListener("mouseenter", () => {
      const z = this.zones.get(id);
      if (z) {
        z.isHovered = true;
        this.updateZoneVisibility(z);
      }
    });

    domBadge.addEventListener("mouseleave", () => {
      const z = this.zones.get(id);
      if (z) {
        z.isHovered = false;
        this.updateZoneVisibility(z);
      }
    });

    if (this.overlayContainer) {
      this.overlayContainer.appendChild(domBadge);
    }

    const zone: LumberZone = {
      id,
      centerX: cx,
      centerZ: cz,
      radius,
      markerY,
      badgeSprite,
      axeMesh: axeGroup,
      beamMesh,
      centerRing,
      hitBox,
      boundaryRing,
      domBadge,
      domLabel: labelEl,
      domCountNum: countNum,
      assignedWorkerIds: new Set(),
      isSelected: false,
      isHovered: false
    };

    this.zones.set(id, zone);
    return zone;
  }

  public getTreesInZone(zone: LumberZone): ResourceData[] {
    const trees: ResourceData[] = [];
    const rSq = zone.radius * zone.radius;

    for (const res of this.world.resources.values()) {
      if (res.type === "wood" && res.amount > 0) {
        const dx = (res.x + 0.5) - zone.centerX;
        const dz = (res.z + 0.5) - zone.centerZ;
        if (dx * dx + dz * dz <= rSq) {
          trees.push(res);
        }
      }
    }
    return trees;
  }

  public assignWorkersToZone(zone: LumberZone, workers: Unit[]): void {
    const validWorkers = workers.filter((u) => u.type === "worker" && u.isAlive);
    if (validWorkers.length === 0) return;

    for (const w of validWorkers) {
      // Unassign from any previous zone
      this.unassignWorker(w);

      zone.assignedWorkerIds.add(w.id);
      (w as any).assignedLumberZoneId = zone.id;

      // Assign to closest accessible tree in zone
      const nextTree = this.findClosestTreeInZone(zone, w.position.x, w.position.z);
      if (nextTree) {
        this.gatheringSys.orderGather(w, nextTree);
      }
    }

    this.updateBadgeWorkerCount(zone);

    eventBus.emit("toast", {
      message: `🪓 ${validWorkers.length} worker(s) assigned to Lumber Zone!`,
      type: "info"
    });
    eventBus.emit("sound", { soundName: "order_move" });
  }

  public addSingleWorker(zone: LumberZone, units: Unit[]): boolean {
    let candidate: Unit | null = null;
    let minDist = Infinity;

    for (const u of units) {
      if (
        u.type === "worker" &&
        u.faction === "player" &&
        u.isAlive &&
        u.state === "idle" &&
        !zone.assignedWorkerIds.has(u.id)
      ) {
        const d = Math.hypot(u.position.x - zone.centerX, u.position.z - zone.centerZ);
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

    this.assignWorkersToZone(zone, [candidate]);
    return true;
  }

  public removeSingleWorker(zone: LumberZone, units: Unit[]): boolean {
    if (zone.assignedWorkerIds.size === 0) {
      eventBus.emit("toast", { message: "No workers currently assigned to this zone.", type: "info" });
      return false;
    }

    const uid = Array.from(zone.assignedWorkerIds)[0];
    zone.assignedWorkerIds.delete(uid);

    const worker = units.find((u) => u.id === uid && u.isAlive);
    if (worker) {
      (worker as any).assignedLumberZoneId = null;
      worker.state = "idle";
      worker.currentOrder = "move";
      worker.target = null;
      worker.path = [];
      eventBus.emit("toast", { message: "🧑‍🌾 Worker released from Lumber Zone", type: "info" });
      eventBus.emit("sound", { soundName: "click" });
    }

    this.updateBadgeWorkerCount(zone);
    return true;
  }

  public updateZoneVisibility(zone: LumberZone): void {
    const show = zone.isHovered || zone.isSelected;
    zone.boundaryRing.visible = show;
    zone.centerRing.visible = show;
  }

  public clearSelections(): void {
    for (const z of this.zones.values()) {
      if (z.isSelected) {
        z.isSelected = false;
        this.updateZoneVisibility(z);
      }
    }
  }

  public updateBadgeWorkerCount(zone: LumberZone): void {
    if (zone.domCountNum) {
      zone.domCountNum.textContent = `${zone.assignedWorkerIds.size}`;
    }
  }

  public unassignWorker(unit: Unit): void {
    const zoneId = (unit as any).assignedLumberZoneId;
    if (zoneId) {
      const zone = this.zones.get(zoneId);
      if (zone) {
        zone.assignedWorkerIds.delete(unit.id);
        this.updateBadgeWorkerCount(zone);
      }
      (unit as any).assignedLumberZoneId = null;
    }
    for (const zone of this.zones.values()) {
      zone.assignedWorkerIds.delete(unit.id);
      this.updateBadgeWorkerCount(zone);
    }
  }

  private hasWalkableNeighbor(x: number, z: number): boolean {
    const neighbors = [
      { dx: 1, dz: 0 },
      { dx: -1, dz: 0 },
      { dx: 0, dz: 1 },
      { dx: 0, dz: -1 },
      { dx: 1, dz: 1 },
      { dx: -1, dz: 1 },
      { dx: 1, dz: -1 },
      { dx: -1, dz: -1 }
    ];
    for (const n of neighbors) {
      if (this.world.isWalkable(x + n.dx, z + n.dz, "player")) {
        return true;
      }
    }
    return false;
  }

  public findClosestTreeInZone(zone: LumberZone, fromX: number, fromZ: number): ResourceData | null {
    const trees = this.getTreesInZone(zone);
    if (trees.length === 0) return null;

    let closestAccessible: ResourceData | null = null;
    let minAccDist = Infinity;

    let closestAny: ResourceData | null = null;
    let minAnyDist = Infinity;

    for (const t of trees) {
      const d = Math.hypot(t.x + 0.5 - fromX, t.z + 0.5 - fromZ);
      if (d < minAnyDist) {
        minAnyDist = d;
        closestAny = t;
      }

      if (this.hasWalkableNeighbor(t.x, t.z) && d < minAccDist) {
        minAccDist = d;
        closestAccessible = t;
      }
    }

    // Prefer accessible perimeter trees so workers clear inward
    return closestAccessible || closestAny;
  }

  public update(units: Unit[], dt: number, camera?: THREE.Camera): void {
    const now = performance.now();
    const tempVec = new THREE.Vector3();

    for (const zone of this.zones.values()) {
      // 1. Animate hovering 3D meshes
      zone.badgeSprite.position.y = zone.markerY + 0.6 + Math.sin(now * 0.003) * 0.15;
      zone.axeMesh.rotation.y += dt * 2.2;
      zone.axeMesh.position.y = zone.markerY - 0.7 + Math.sin(now * 0.003) * 0.12;

      // Pulse ground ring
      const ringScale = 1.0 + Math.sin(now * 0.004) * 0.15;
      zone.centerRing.scale.set(ringScale, 1, ringScale);

      // Check remaining trees
      const remainingTrees = this.getTreesInZone(zone);

      if (remainingTrees.length === 0) {
        // Zone cleared!
        eventBus.emit("toast", {
          message: `🎉 Lumber Zone cleared completely! All trees harvested.`,
          type: "success"
        });
        eventBus.emit("sound", { soundName: "build_done" });

        this.removeZone(zone.id);
        continue;
      }

      // Update Screen-Space DOM badge position & count
      if (zone.domBadge && camera) {
        tempVec.set(zone.centerX, zone.markerY + 0.8, zone.centerZ);
        tempVec.project(camera);

        if (tempVec.z < 1.0) {
          const screenX = (tempVec.x * 0.5 + 0.5) * window.innerWidth;
          const screenY = (-(tempVec.y * 0.5) + 0.5) * window.innerHeight;

          zone.domBadge.style.display = "flex";
          zone.domBadge.style.left = `${screenX}px`;
          zone.domBadge.style.top = `${screenY}px`;
          zone.domLabel.textContent = `${remainingTrees.length} 🪵`;
        } else {
          zone.domBadge.style.display = "none";
        }
      }

      // Ensure assigned workers are continually clearing trees in the zone
      for (const uid of zone.assignedWorkerIds) {
        const worker = units.find((u) => u.id === uid && u.isAlive);
        if (!worker) {
          zone.assignedWorkerIds.delete(uid);
          continue;
        }

        // If worker is idle, dispatch to next tree in zone
        if (worker.state === "idle") {
          const nextTree = this.findClosestTreeInZone(zone, worker.position.x, worker.position.z);
          if (nextTree) {
            this.gatheringSys.orderGather(worker, nextTree);
          }
        }
      }

      this.updateBadgeWorkerCount(zone);
      this.updateZoneVisibility(zone);
    }
  }

  public removeZone(zoneId: string): void {
    const zone = this.zones.get(zoneId);
    if (zone) {
      this.scene.remove(zone.badgeSprite);
      this.scene.remove(zone.axeMesh);
      this.scene.remove(zone.beamMesh);
      this.scene.remove(zone.centerRing);
      this.scene.remove(zone.hitBox);
      this.scene.remove(zone.boundaryRing);

      if (zone.domBadge) {
        zone.domBadge.remove();
      }

      this.zones.delete(zoneId);
    }
  }

  public getZoneAt(x: number, z: number): LumberZone | null {
    for (const zone of this.zones.values()) {
      const d = Math.hypot(x - zone.centerX, z - zone.centerZ);
      if (d <= zone.radius) {
        return zone;
      }
    }
    return null;
  }
}
