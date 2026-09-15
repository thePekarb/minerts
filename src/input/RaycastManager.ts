import * as THREE from "three";
import { World } from "../world/World";
import { Unit } from "../entities/Unit";
import { Building } from "../entities/Building";
import { ResourceData } from "../world/ResourceSpawner";
import { POIData } from "../world/POIGenerator";

export interface RaycastHitResult {
  point: THREE.Vector3;
  gridX: number;
  gridZ: number;
  unit: Unit | null;
  building: Building | null;
  resource: ResourceData | null;
  poi: POIData | null;
  lumberZoneId?: string | null;
}

export class RaycastManager {
  private raycaster: THREE.Raycaster;
  private mouse: THREE.Vector2;
  private groundPlane: THREE.Plane;

  constructor() {
    this.raycaster = new THREE.Raycaster();
    this.mouse = new THREE.Vector2();
    this.groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  }

  public getGroundHit(
    screenX: number,
    screenY: number,
    camera: THREE.Camera,
    canvasWidth: number,
    canvasHeight: number,
    world: World,
    allUnits: Unit[],
    buildings: Building[],
    sceneObjects?: THREE.Object3D[]
  ): RaycastHitResult {
    this.mouse.x = (screenX / canvasWidth) * 2 - 1;
    this.mouse.y = -(screenY / canvasHeight) * 2 + 1;
    this.raycaster.setFromCamera(this.mouse, camera);

    let hitPoint = new THREE.Vector3();
    let hitUnit: Unit | null = null;
    let hitBuilding: Building | null = null;
    let hitResource: ResourceData | null = null;
    let hitPOI: POIData | null = null;
    let hitLumberZoneId: string | null = null;

    // 1. Raycast against 3D scene objects (terrain, props, buildings, units)
    if (sceneObjects && sceneObjects.length > 0) {
      const intersects = this.raycaster.intersectObjects(sceneObjects, true);
      if (intersects.length > 0) {
        hitPoint = intersects[0].point.clone();

        // Inspect intersected object hierarchy for tagged userData
        for (const inter of intersects) {
          let curr: THREE.Object3D | null = inter.object;
          while (curr) {
            if (curr.userData) {
              if (curr.userData.unitId && !hitUnit) {
                hitUnit = allUnits.find((u) => u.id === curr!.userData.unitId && u.isAlive && u.meshHierarchy.root.visible && u.state !== "mining_inside") || null;
              }
              if (curr.userData.buildingId && !hitBuilding) {
                hitBuilding = buildings.find((b) => b.id === curr!.userData.buildingId && b.isAlive) || null;
              }
              if (curr.userData.resourceId && !hitResource) {
                const res = world.resources.get(curr.userData.resourceId);
                if (res && res.amount > 0) hitResource = res;
              }
              if (curr.userData.poiId && !hitPOI) {
                hitPOI = world.pois.get(curr.userData.poiId) || null;
              }
              if (curr.userData.lumberZoneId && !hitLumberZoneId) {
                hitLumberZoneId = curr.userData.lumberZoneId;
              }
            }
            curr = curr.parent;
          }
          if (hitUnit || hitBuilding || hitResource || hitPOI || hitLumberZoneId) break;
        }
      } else {
        this.raycaster.ray.intersectPlane(this.groundPlane, hitPoint);
      }
    } else {
      this.raycaster.ray.intersectPlane(this.groundPlane, hitPoint);
    }

    const gx = Math.floor(hitPoint.x);
    const gz = Math.floor(hitPoint.z);

    // 2. Fallback Entity detection using coordinates
    if (!hitUnit) {
      let minUnitDist = 1.0;
      for (const u of allUnits) {
        if (!u.isAlive || !u.meshHierarchy.root.visible || u.state === "mining_inside") continue;
        const d = Math.hypot(hitPoint.x - u.position.x, hitPoint.z - u.position.z);
        if (d < minUnitDist) {
          minUnitDist = d;
          hitUnit = u;
        }
      }
    }

    if (!hitBuilding) {
      for (const b of buildings) {
        if (!b.isAlive) continue;
        if (
          gx >= b.gridX &&
          gx < b.gridX + b.config.size.x &&
          gz >= b.gridZ &&
          gz < b.gridZ + b.config.size.z
        ) {
          hitBuilding = b;
          break;
        }
      }
    }

    if (!hitResource) {
      // Check clicked tile directly
      const tile = world.getTile(gx, gz);
      if (tile && tile.resourceId) {
        const res = world.resources.get(tile.resourceId);
        if (res && res.amount > 0) hitResource = res;
      }

      // Check within radius to tile center (r.x + 0.5, r.z + 0.5)
      if (!hitResource) {
        let minDist = 1.4;
        for (const r of world.resources.values()) {
          if (r.amount > 0) {
            const d = Math.hypot(hitPoint.x - (r.x + 0.5), hitPoint.z - (r.z + 0.5));
            if (d < minDist) {
              minDist = d;
              hitResource = r;
            }
          }
        }
      }
    }

    if (!hitPOI) {
      for (const p of world.pois.values()) {
        if (Math.hypot(hitPoint.x - (p.x + 0.5), hitPoint.z - (p.z + 0.5)) < 1.4) {
          hitPOI = p;
          break;
        }
      }
    }

    return {
      point: hitPoint,
      gridX: gx,
      gridZ: gz,
      unit: hitUnit,
      building: hitBuilding,
      resource: hitResource,
      poi: hitPOI,
      lumberZoneId: hitLumberZoneId
    };
  }
}
