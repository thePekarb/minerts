import * as THREE from "three";
import { World } from "../world/World";
import { Materials } from "./Materials";
import { BiomeType } from "../world/Tile";
import { VoxelMeshes } from "./VoxelMeshes";

export class TerrainRenderer {
  public terrainGroup: THREE.Group = new THREE.Group();
  public waterMesh: THREE.Mesh | null = null;
  public propMeshes: Map<string, THREE.Group> = new Map();
  public poiMeshes: Map<string, THREE.Group> = new Map();

  constructor(world: World, scene: THREE.Scene) {
    this.buildTerrain(world);
    this.buildPropsAndPOIs(world);
    scene.add(this.terrainGroup);
  }

  private buildTerrain(world: World): void {
    const size = world.size;

    // Separate face buffers for each biome to share materials and minimize draw calls
    const biomeBuffers: Record<
      BiomeType,
      { positions: number[]; normals: number[]; uvs: number[]; indices: number[] }
    > = {
      plains: { positions: [], normals: [], uvs: [], indices: [] },
      forest: { positions: [], normals: [], uvs: [], indices: [] },
      rock: { positions: [], normals: [], uvs: [], indices: [] },
      sand: { positions: [], normals: [], uvs: [], indices: [] },
      water: { positions: [], normals: [], uvs: [], indices: [] }
    };

    const addQuad = (
      buf: { positions: number[]; normals: number[]; uvs: number[]; indices: number[] },
      v0: [number, number, number],
      v1: [number, number, number],
      v2: [number, number, number],
      v3: [number, number, number],
      nx: number,
      ny: number,
      nz: number
    ) => {
      const baseIdx = buf.positions.length / 3;
      buf.positions.push(...v0, ...v1, ...v2, ...v3);
      buf.normals.push(nx, ny, nz, nx, ny, nz, nx, ny, nz, nx, ny, nz);
      buf.uvs.push(0, 0, 1, 0, 1, 1, 0, 1);
      buf.indices.push(baseIdx, baseIdx + 1, baseIdx + 2, baseIdx, baseIdx + 2, baseIdx + 3);
    };

    for (let x = 0; x < size; x++) {
      for (let z = 0; z < size; z++) {
        const tile = world.tiles[x][z];
        const h = tile.height;
        const buf = biomeBuffers[tile.biome];

        // 1. Top face
        addQuad(
          buf,
          [x, h, z + 1],
          [x + 1, h, z + 1],
          [x + 1, h, z],
          [x, h, z],
          0,
          1,
          0
        );

        // 2. North side (+z)
        const northH = z + 1 < size ? world.tiles[x][z + 1].height : 0;
        if (h > northH) {
          addQuad(
            buf,
            [x, northH, z + 1],
            [x + 1, northH, z + 1],
            [x + 1, h, z + 1],
            [x, h, z + 1],
            0,
            0,
            1
          );
        }

        // 3. South side (-z)
        const southH = z - 1 >= 0 ? world.tiles[x][z - 1].height : 0;
        if (h > southH) {
          addQuad(
            buf,
            [x + 1, southH, z],
            [x, southH, z],
            [x, h, z],
            [x + 1, h, z],
            0,
            0,
            -1
          );
        }

        // 4. East side (+x)
        const eastH = x + 1 < size ? world.tiles[x + 1][z].height : 0;
        if (h > eastH) {
          addQuad(
            buf,
            [x + 1, eastH, z + 1],
            [x + 1, eastH, z],
            [x + 1, h, z],
            [x + 1, h, z + 1],
            1,
            0,
            0
          );
        }

        // 5. West side (-x)
        const westH = x - 1 >= 0 ? world.tiles[x - 1][z].height : 0;
        if (h > westH) {
          addQuad(
            buf,
            [x, westH, z],
            [x, westH, z + 1],
            [x, h, z + 1],
            [x, h, z],
            -1,
            0,
            0
          );
        }
      }
    }

    // Create meshes for each biome
    const biomes: BiomeType[] = ["plains", "forest", "rock", "sand", "water"];
    for (const b of biomes) {
      const data = biomeBuffers[b];
      if (data.positions.length === 0) continue;

      const geo = new THREE.BufferGeometry();
      geo.setAttribute("position", new THREE.Float32BufferAttribute(data.positions, 3));
      geo.setAttribute("normal", new THREE.Float32BufferAttribute(data.normals, 3));
      geo.setAttribute("uv", new THREE.Float32BufferAttribute(data.uvs, 2));
      geo.setIndex(data.indices);

      let mat = Materials.grass;
      if (b === "forest") mat = Materials.grass;
      else if (b === "rock") mat = Materials.stone;
      else if (b === "sand") mat = Materials.sand;
      else if (b === "water") mat = Materials.water;

      const mesh = new THREE.Mesh(geo, mat);
      mesh.receiveShadow = true;
      mesh.castShadow = true;
      this.terrainGroup.add(mesh);
    }
  }

  private buildPropsAndPOIs(world: World): void {
    // 1. Resources (Trees, Rocks, Berry bushes, Ore)
    for (const res of world.resources.values()) {
      let propMesh: THREE.Group;
      if (res.type === "wood") {
        propMesh = VoxelMeshes.createTreeMesh();
      } else if (res.type === "stone") {
        propMesh = VoxelMeshes.createRockMesh(false);
      } else if (res.type === "ore") {
        propMesh = VoxelMeshes.createRockMesh(true);
      } else {
        propMesh = VoxelMeshes.createBushMesh();
      }

      propMesh.position.set(res.x + 0.5, res.height, res.z + 0.5);
      propMesh.userData = { resourceId: res.id };
      propMesh.traverse((child) => {
        child.userData = { resourceId: res.id };
      });
      this.terrainGroup.add(propMesh);
      this.propMeshes.set(res.id, propMesh);
    }

    // 2. POIs (Cave, Abandoned Camp, Chests)
    for (const poi of world.pois.values()) {
      let poiMesh: THREE.Group;
      if (poi.type === "cave") {
        poiMesh = VoxelMeshes.createCaveMesh();
        poiMesh.position.set(poi.x + 0.5, poi.height, poi.z + 0.5);
      } else if (poi.type === "abandoned_camp") {
        poiMesh = VoxelMeshes.createBuildingMesh("hut");
        poiMesh.scale.set(0.7, 0.7, 0.7);
        poiMesh.position.set(poi.x + 0.5, poi.height, poi.z + 0.5);
      } else {
        poiMesh = VoxelMeshes.createChestMesh();
        poiMesh.position.set(poi.x + 0.5, poi.height, poi.z + 0.5);
      }

      poiMesh.userData = { poiId: poi.id };
      poiMesh.traverse((child) => {
        child.userData = { poiId: poi.id };
      });
      this.terrainGroup.add(poiMesh);
      this.poiMeshes.set(poi.id, poiMesh);
    }
  }

  public removeResourceMesh(resId: string): void {
    const mesh = this.propMeshes.get(resId);
    if (mesh) {
      this.terrainGroup.remove(mesh);
      this.propMeshes.delete(resId);
    }
  }

  public openChestMesh(chestId: string): void {
    const mesh = this.poiMeshes.get(chestId);
    if (mesh) {
      // Tilt lid open
      const lid = mesh.children[1];
      if (lid) lid.rotation.x = -Math.PI / 2.5;
    }
  }
}
