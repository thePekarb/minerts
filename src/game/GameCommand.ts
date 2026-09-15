import { UnitType } from "../data/unitConfigs";
import { BuildingType } from "../data/buildingConfigs";

export interface Vec2 {
  x: number;
  z: number;
}

export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

export interface GridPosition {
  x: number;
  z: number;
}

export type GameCommand =
  | { type: "move_units"; unitIds: string[]; target: Vec3 }
  | { type: "attack_target"; unitIds: string[]; targetId: string }
  | { type: "build"; buildingType: BuildingType; position: GridPosition }
  | { type: "gather"; unitIds: string[]; resourceId: string }
  | { type: "interact"; unitIds: string[]; targetId: string }
  | { type: "repair"; unitIds: string[]; buildingId: string }
  | { type: "train_unit"; unitType: UnitType; buildingId: string }
  | { type: "stop"; unitIds: string[] }
  | { type: "hold"; unitIds: string[] }
  | { type: "retreat"; unitIds: string[] };
