import { Game } from "./game/Game";

window.addEventListener("DOMContentLoaded", () => {
  const game = new Game();
  (window as any).frontierGame = game;
});
