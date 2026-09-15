import { Tile, BiomeType } from "./Tile";

// Seeded pseudo-random number generator (Mulberry32)
export class PRNG {
  private s: number;

  constructor(seed: number = 42) {
    this.s = Math.floor(seed);
  }

  public next(): number {
    let t = (this.s += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
}

// 2D Perlin-style noise generator
export class Simple2DNoise {
  private perm: number[] = [];

  constructor(seed: number = 1337) {
    const prng = new PRNG(seed);
    const p: number[] = [];
    for (let i = 0; i < 256; i++) p[i] = i;
    for (let i = 255; i > 0; i--) {
      const j = Math.floor(prng.next() * (i + 1));
      const temp = p[i];
      p[i] = p[j];
      p[j] = temp;
    }
    this.perm = p.concat(p);
  }

  private fade(t: number): number {
    return t * t * t * (t * (t * 6 - 15) + 10);
  }

  private lerp(a: number, b: number, t: number): number {
    return a + t * (b - a);
  }

  private grad(hash: number, x: number, y: number): number {
    const h = hash & 3;
    const u = h < 2 ? x : y;
    const v = h < 2 ? y : x;
    return ((h & 1) === 0 ? u : -u) + ((h & 2) === 0 ? v : -v);
  }

  public get(x: number, y: number): number {
    const X = Math.floor(x) & 255;
    const Y = Math.floor(y) & 255;

    const xf = x - Math.floor(x);
    const yf = y - Math.floor(y);

    const u = this.fade(xf);
    const v = this.fade(yf);

    const a = this.perm[X] + Y;
    const b = this.perm[X + 1] + Y;

    return this.lerp(
      this.lerp(this.grad(this.perm[a], xf, yf), this.grad(this.perm[b], xf - 1, yf), u),
      this.lerp(this.grad(this.perm[a + 1], xf, yf - 1), this.grad(this.perm[b + 1], xf - 1, yf - 1), u),
      v
    );
  }

  public getOctaves(x: number, y: number, octaves: number = 3, persistence: number = 0.5): number {
    let total = 0;
    let frequency = 1;
    let amplitude = 1;
    let maxValue = 0;
    for (let i = 0; i < octaves; i++) {
      total += this.get(x * frequency, y * frequency) * amplitude;
      maxValue += amplitude;
      amplitude *= persistence;
      frequency *= 2;
    }
    return (total / maxValue + 1) * 0.5; // Normalized to 0..1
  }
}

export class TerrainGenerator {
  private heightNoise: Simple2DNoise;
  private moistureNoise: Simple2DNoise;
  public size: number;

  constructor(size: number = 64, seed: number = 42) {
    this.size = size;
    this.heightNoise = new Simple2DNoise(seed);
    this.moistureNoise = new Simple2DNoise(seed + 9999);
  }

  public generate(): Tile[][] {
    const tiles: Tile[][] = [];
    const center = this.size / 2;
    const maxRadius = this.size * 0.46;

    for (let x = 0; x < this.size; x++) {
      tiles[x] = [];
      for (let z = 0; z < this.size; z++) {
        // Distance from center for island masking
        const dx = (x - center) / maxRadius;
        const dz = (z - center) / maxRadius;
        const distFromCenter = Math.sqrt(dx * dx + dz * dz);

        // Noise values
        const scale = 0.045;
        const rawElevation = this.heightNoise.getOctaves(x * scale, z * scale, 3);
        const moisture = this.moistureNoise.getOctaves(x * scale * 1.5, z * scale * 1.5, 2);

        // Island falloff near borders
        let elevation = rawElevation - Math.pow(distFromCenter, 2.2) * 0.7;

        // Force center area to be flat safe clearing (radius ~ 7 tiles)
        const distFromCenterSq = (x - center) * (x - center) + (z - center) * (z - center);
        if (distFromCenterSq < 49) {
          elevation = 0.45; // Level ground in camp
        }

        // Quantize height into discrete voxel steps
        let heightStep = 1;
        let biome: BiomeType = "plains";
        let walkable = true;

        if (elevation < 0.18) {
          // Water
          heightStep = 0;
          biome = "water";
          walkable = false;
        } else if (elevation < 0.28) {
          // Sand beach
          heightStep = 0.5;
          biome = "sand";
          walkable = true;
        } else if (elevation < 0.55) {
          // Plains or Forest depending on moisture
          heightStep = 1.0;
          if (moisture > 0.48 && distFromCenterSq > 40) {
            biome = "forest";
          } else {
            biome = "plains";
          }
          walkable = true;
        } else if (elevation < 0.75) {
          // Hills / Plateau
          heightStep = 1.8;
          biome = moisture > 0.5 ? "forest" : "rock";
          walkable = true;
        } else {
          // High mountain peaks
          heightStep = 2.6;
          biome = "rock";
          walkable = true;
        }

        tiles[x][z] = new Tile(x, z, heightStep, biome, walkable);
      }
    }

    return tiles;
  }
}
