import * as THREE from "three";

export class TextureFactory {
  private static cache: Map<string, THREE.CanvasTexture> = new Map();

  private static createPixelCanvas(
    size: number,
    drawer: (ctx: CanvasRenderingContext2D, size: number) => void
  ): THREE.CanvasTexture {
    const canvas = document.createElement("canvas");
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext("2d")!;
    drawer(ctx, size);

    const texture = new THREE.CanvasTexture(canvas);
    texture.magFilter = THREE.NearestFilter;
    texture.minFilter = THREE.NearestFilter;
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.RepeatWrapping;
    return texture;
  }

  static getGrassTexture(): THREE.CanvasTexture {
    if (this.cache.has("grass")) return this.cache.get("grass")!;

    const tex = this.createPixelCanvas(32, (ctx, s) => {
      // Base green
      ctx.fillStyle = "#559e38";
      ctx.fillRect(0, 0, s, s);

      // Pixel shades
      const greens = ["#47852e", "#62b041", "#3c7025", "#6bc248"];
      for (let x = 0; x < s; x += 2) {
        for (let y = 0; y < s; y += 2) {
          if (Math.random() > 0.4) {
            ctx.fillStyle = greens[Math.floor(Math.random() * greens.length)];
            ctx.fillRect(x, y, 2, 2);
          }
        }
      }

      // Small flower/blade specks
      for (let i = 0; i < 8; i++) {
        const rx = Math.floor(Math.random() * (s - 2));
        const ry = Math.floor(Math.random() * (s - 2));
        ctx.fillStyle = Math.random() > 0.6 ? "#86efac" : "#fef08a";
        ctx.fillRect(rx, ry, 1, 2);
      }
    });

    this.cache.set("grass", tex);
    return tex;
  }

  static getDirtTexture(): THREE.CanvasTexture {
    if (this.cache.has("dirt")) return this.cache.get("dirt")!;

    const tex = this.createPixelCanvas(32, (ctx, s) => {
      ctx.fillStyle = "#784a2d";
      ctx.fillRect(0, 0, s, s);

      const browns = ["#633d24", "#8c5634", "#54331e", "#945c38"];
      for (let x = 0; x < s; x += 2) {
        for (let y = 0; y < s; y += 2) {
          if (Math.random() > 0.35) {
            ctx.fillStyle = browns[Math.floor(Math.random() * browns.length)];
            ctx.fillRect(x, y, 2, 2);
          }
        }
      }

      // Small stone pebbles in dirt
      for (let i = 0; i < 6; i++) {
        ctx.fillStyle = "#a8a29e";
        ctx.fillRect(Math.floor(Math.random() * s), Math.floor(Math.random() * s), 2, 2);
      }
    });

    this.cache.set("dirt", tex);
    return tex;
  }

  static getStoneTexture(): THREE.CanvasTexture {
    if (this.cache.has("stone")) return this.cache.get("stone")!;

    const tex = this.createPixelCanvas(32, (ctx, s) => {
      ctx.fillStyle = "#71717a";
      ctx.fillRect(0, 0, s, s);

      const grays = ["#52525b", "#82828b", "#3f3f46", "#a1a1aa"];
      // Cobblestone brick pattern
      for (let y = 0; y < s; y += 8) {
        const offsetX = (y % 16 === 0) ? 0 : 4;
        for (let x = 0; x < s; x += 8) {
          ctx.fillStyle = grays[Math.floor(Math.random() * grays.length)];
          ctx.fillRect((x + offsetX) % s, y, 7, 7);
          ctx.fillStyle = "#27272a";
          ctx.fillRect((x + offsetX + 7) % s, y, 1, 8);
          ctx.fillRect((x + offsetX) % s, y + 7, 8, 1);
        }
      }
    });

    this.cache.set("stone", tex);
    return tex;
  }

  static getWoodTexture(): THREE.CanvasTexture {
    if (this.cache.has("wood")) return this.cache.get("wood")!;

    const tex = this.createPixelCanvas(32, (ctx, s) => {
      ctx.fillStyle = "#925e36";
      ctx.fillRect(0, 0, s, s);

      // Plank horizontal lines
      for (let y = 0; y < s; y += 8) {
        ctx.fillStyle = "#633c1d";
        ctx.fillRect(0, y + 7, s, 1);

        // Wood grain variations
        for (let x = 0; x < s; x += 3) {
          if (Math.random() > 0.5) {
            ctx.fillStyle = Math.random() > 0.5 ? "#a66c3f" : "#7d4f2b";
            ctx.fillRect(x, y + Math.floor(Math.random() * 6), 2, 1);
          }
        }

        // Iron nail / peg
        ctx.fillStyle = "#334155";
        ctx.fillRect(2, y + 3, 2, 2);
        ctx.fillRect(s - 4, y + 3, 2, 2);
      }
    });

    this.cache.set("wood", tex);
    return tex;
  }

  static getSandTexture(): THREE.CanvasTexture {
    if (this.cache.has("sand")) return this.cache.get("sand")!;

    const tex = this.createPixelCanvas(32, (ctx, s) => {
      ctx.fillStyle = "#d4b26f";
      ctx.fillRect(0, 0, s, s);

      const sands = ["#c7a35e", "#dfc07f", "#be9853", "#ebd094"];
      for (let x = 0; x < s; x += 2) {
        for (let y = 0; y < s; y += 2) {
          if (Math.random() > 0.4) {
            ctx.fillStyle = sands[Math.floor(Math.random() * sands.length)];
            ctx.fillRect(x, y, 2, 2);
          }
        }
      }
    });

    this.cache.set("sand", tex);
    return tex;
  }

  static getWaterTexture(): THREE.CanvasTexture {
    if (this.cache.has("water")) return this.cache.get("water")!;

    const tex = this.createPixelCanvas(32, (ctx, s) => {
      ctx.fillStyle = "#2563eb";
      ctx.fillRect(0, 0, s, s);

      const blues = ["#1d4ed8", "#3b82f6", "#60a5fa", "#1e40af"];
      for (let y = 0; y < s; y += 4) {
        for (let x = 0; x < s; x += 4) {
          ctx.fillStyle = blues[Math.floor(Math.random() * blues.length)];
          ctx.fillRect(x, y, 3, 2);
        }
      }
    });

    this.cache.set("water", tex);
    return tex;
  }

  static getOreTexture(): THREE.CanvasTexture {
    if (this.cache.has("ore")) return this.cache.get("ore")!;

    const tex = this.createPixelCanvas(32, (ctx, s) => {
      ctx.fillStyle = "#52525b";
      ctx.fillRect(0, 0, s, s);

      // Iron / ore veins
      const metalColors = ["#e2e8f0", "#94a3b8", "#f59e0b", "#d97706"];
      for (let i = 0; i < 12; i++) {
        const rx = Math.floor(Math.random() * (s - 3));
        const ry = Math.floor(Math.random() * (s - 3));
        ctx.fillStyle = metalColors[Math.floor(Math.random() * metalColors.length)];
        ctx.fillRect(rx, ry, 3, 3);
      }
    });

    this.cache.set("ore", tex);
    return tex;
  }
}
