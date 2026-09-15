import { Vec3 } from "../game/GameCommand";

export abstract class Entity {
  public id: string;
  public position: Vec3;
  public rotation: number = 0;
  public health: number;
  public maxHealth: number;
  public faction: "player" | "enemy" | "neutral";

  constructor(id: string, x: number, y: number, z: number, health: number, faction: "player" | "enemy" | "neutral") {
    this.id = id;
    this.position = { x, y, z };
    this.health = health;
    this.maxHealth = health;
    this.faction = faction;
  }

  public get isAlive(): boolean {
    return this.health > 0;
  }

  public takeDamage(amount: number): boolean {
    this.health = Math.max(0, this.health - amount);
    return this.health <= 0;
  }

  public heal(amount: number): void {
    this.health = Math.min(this.maxHealth, this.health + amount);
  }
}
