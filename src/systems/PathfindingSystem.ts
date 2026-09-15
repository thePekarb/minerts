import { World } from "../world/World";
import { Vec3 } from "../game/GameCommand";

interface Node {
  x: number;
  z: number;
  g: number;
  h: number;
  f: number;
  parent: Node | null;
}

export class PathfindingSystem {
  private world: World;

  constructor(world: World) {
    this.world = world;
  }

  public findPath(
    startX: number,
    startZ: number,
    targetX: number,
    targetZ: number,
    faction: "player" | "enemy" = "player",
    maxDistance: number = 80
  ): Vec3[] {
    const sx = Math.floor(startX);
    const sz = Math.floor(startZ);
    let tx = Math.floor(targetX);
    let tz = Math.floor(targetZ);

    // If target is out of bounds, clamp
    tx = Math.max(0, Math.min(this.world.size - 1, tx));
    tz = Math.max(0, Math.min(this.world.size - 1, tz));

    // If start equals target, return current
    if (sx === tx && sz === tz) {
      return [{ x: targetX, y: this.world.getHeight(targetX, targetZ), z: targetZ }];
    }

    // If start tile itself is an obstacle, find nearest walkable neighbor to start from
    let effSx = sx;
    let effSz = sz;
    if (!this.world.isWalkable(sx, sz, faction)) {
      const nearStart = this.findNearestWalkableNeighbor(sx, sz, targetX, targetZ, faction);
      if (nearStart) {
        effSx = nearStart.x;
        effSz = nearStart.z;
      }
    }

    const isTargetObstacle = !this.world.isWalkable(tx, tz, faction);

    // If start is already adjacent to obstacle target, return current position
    if (isTargetObstacle && Math.abs(effSx - tx) <= 1 && Math.abs(effSz - tz) <= 1) {
      return [{ x: startX, y: this.world.getHeight(startX, startZ), z: startZ }];
    }

    const openList: Node[] = [];
    const closedSet = new Set<number>();
    const nodeMap = new Map<number, Node>();

    const getKey = (x: number, z: number) => x * 1000 + z;

    const startNode: Node = {
      x: effSx,
      z: effSz,
      g: 0,
      h: this.heuristic(effSx, effSz, tx, tz),
      f: 0,
      parent: null
    };
    startNode.f = startNode.h;

    openList.push(startNode);
    nodeMap.set(getKey(effSx, effSz), startNode);

    let bestNode: Node = startNode;
    let minH: number = startNode.h;

    const directions = [
      { dx: 1, dz: 0, cost: 1.0 },
      { dx: -1, dz: 0, cost: 1.0 },
      { dx: 0, dz: 1, cost: 1.0 },
      { dx: 0, dz: -1, cost: 1.0 },
      { dx: 1, dz: 1, cost: 1.414 },
      { dx: -1, dz: 1, cost: 1.414 },
      { dx: 1, dz: -1, cost: 1.414 },
      { dx: -1, dz: -1, cost: 1.414 }
    ];

    let steps = 0;
    const maxSteps = 1200; // Cap steps to maintain 60 FPS

    while (openList.length > 0 && steps < maxSteps) {
      steps++;

      // Find node with lowest f
      let lowestIndex = 0;
      for (let i = 1; i < openList.length; i++) {
        if (openList[i].f < openList[lowestIndex].f) {
          lowestIndex = i;
        }
      }

      const current = openList[lowestIndex];

      // Track closest node reached towards target
      if (current.h < minH) {
        minH = current.h;
        bestNode = current;
      }

      // Reached destination: either exact tile or adjacent to obstacle
      if (isTargetObstacle) {
        if (Math.abs(current.x - tx) <= 1 && Math.abs(current.z - tz) <= 1) {
          return this.reconstructPath(current);
        }
      } else {
        if (current.x === tx && current.z === tz) {
          return this.reconstructPath(current);
        }
      }

      // Move current from open to closed
      openList.splice(lowestIndex, 1);
      closedSet.add(getKey(current.x, current.z));

      // Check neighbors
      for (const dir of directions) {
        const nx = current.x + dir.dx;
        const nz = current.z + dir.dz;
        const nKey = getKey(nx, nz);

        if (closedSet.has(nKey)) continue;

        if (!this.world.isWalkable(nx, nz, faction)) {
          continue;
        }

        // Corner cutting check: only block if BOTH cardinal neighbors are blocked
        if (dir.dx !== 0 && dir.dz !== 0) {
          if (!this.world.isWalkable(current.x + dir.dx, current.z, faction) &&
              !this.world.isWalkable(current.x, current.z + dir.dz, faction)) {
            continue;
          }
        }

        const tentativeG = current.g + dir.cost;
        let neighbor = nodeMap.get(nKey);

        if (!neighbor) {
          neighbor = {
            x: nx,
            z: nz,
            g: tentativeG,
            h: this.heuristic(nx, nz, tx, tz),
            f: tentativeG + this.heuristic(nx, nz, tx, tz),
            parent: current
          };
          nodeMap.set(nKey, neighbor);
          openList.push(neighbor);
        } else if (tentativeG < neighbor.g) {
          neighbor.g = tentativeG;
          neighbor.f = tentativeG + neighbor.h;
          neighbor.parent = current;
        }
      }
    }

    // Fallback: Return best partial path if destination not fully reached
    if (bestNode !== startNode) {
      return this.reconstructPath(bestNode);
    }

    if (openList.length > 0) {
      openList.sort((a, b) => a.h - b.h);
      return this.reconstructPath(openList[0]);
    }

    return [];
  }

  private heuristic(x1: number, z1: number, x2: number, z2: number): number {
    const dx = Math.abs(x1 - x2);
    const dz = Math.abs(z1 - z2);
    return 1.0 * (dx + dz) + (1.414 - 2.0) * Math.min(dx, dz);
  }

  private reconstructPath(endNode: Node): Vec3[] {
    const path: Vec3[] = [];
    let curr: Node | null = endNode;
    while (curr) {
      path.unshift({
        x: curr.x + 0.5,
        y: this.world.getHeight(curr.x, curr.z),
        z: curr.z + 0.5
      });
      curr = curr.parent;
    }

    // Path smoothing / waypoint reduction if needed
    return path;
  }

  private findNearestWalkableNeighbor(
    x: number,
    z: number,
    fromX: number,
    fromZ: number,
    faction: "player" | "enemy" = "player"
  ): { x: number; z: number } | null {
    let closest: { x: number; z: number } | null = null;
    let minDist = Infinity;

    // Search concentric rings from radius 1 to 4
    for (let r = 1; r <= 4; r++) {
      for (let dx = -r; dx <= r; dx++) {
        for (let dz = -r; dz <= r; dz++) {
          if (Math.abs(dx) !== r && Math.abs(dz) !== r) continue;
          const nx = x + dx;
          const nz = z + dz;
          if (this.world.isWalkable(nx, nz, faction)) {
            const d = Math.hypot(nx - fromX, nz - fromZ);
            if (d < minDist) {
              minDist = d;
              closest = { x: nx, z: nz };
            }
          }
        }
      }
      if (closest) return closest;
    }

    return closest;
  }

  // Group movement formation offsets (grid formation)
  public static getFormationOffsets(count: number, spacing: number = 1.2): { x: number; z: number }[] {
    const offsets: { x: number; z: number }[] = [];
    if (count <= 1) return [{ x: 0, z: 0 }];

    const cols = Math.ceil(Math.sqrt(count));
    const rows = Math.ceil(count / cols);

    for (let i = 0; i < count; i++) {
      const col = i % cols;
      const row = Math.floor(i / cols);
      const offsetX = (col - (cols - 1) / 2) * spacing;
      const offsetZ = (row - (rows - 1) / 2) * spacing;
      offsets.push({ x: offsetX, z: offsetZ });
    }

    return offsets;
  }
}
