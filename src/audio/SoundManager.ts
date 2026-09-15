import { eventBus } from "../game/EventBus";

export class SoundManager {
  private ctx: AudioContext | null = null;
  private isMuted: boolean = false;
  private masterGain: GainNode | null = null;

  constructor() {
    eventBus.on("sound", (data: { soundName: string }) => {
      this.playSound(data.soundName);
    });
  }

  private initContext() {
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
      if (AudioCtx) {
        this.ctx = new AudioCtx();
        this.masterGain = this.ctx.createGain();
        this.masterGain.gain.value = this.isMuted ? 0 : 0.4;
        this.masterGain.connect(this.ctx.destination);
      }
    }
    if (this.ctx && this.ctx.state === "suspended") {
      this.ctx.resume();
    }
  }

  public toggleMute(): boolean {
    this.isMuted = !this.isMuted;
    if (this.masterGain) {
      this.masterGain.gain.value = this.isMuted ? 0 : 0.4;
    }
    return this.isMuted;
  }

  public playSound(name: string): void {
    if (this.isMuted) return;
    this.initContext();
    if (!this.ctx || !this.masterGain) return;

    const t = this.ctx.currentTime;

    switch (name) {
      case "click": {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sine";
        osc.frequency.setValueAtTime(800, t);
        osc.frequency.exponentialRampToValueAtTime(400, t + 0.05);
        gain.gain.setValueAtTime(0.3, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.05);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(t);
        osc.stop(t + 0.05);
        break;
      }

      case "select_unit": {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "triangle";
        osc.frequency.setValueAtTime(320, t);
        osc.frequency.exponentialRampToValueAtTime(480, t + 0.08);
        gain.gain.setValueAtTime(0.25, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.08);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(t);
        osc.stop(t + 0.08);
        break;
      }

      case "order_move": {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sine";
        osc.frequency.setValueAtTime(520, t);
        osc.frequency.exponentialRampToValueAtTime(380, t + 0.09);
        gain.gain.setValueAtTime(0.2, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.09);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(t);
        osc.stop(t + 0.09);
        break;
      }

      case "chop": {
        // Wooden thud
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "square";
        osc.frequency.setValueAtTime(140, t);
        osc.frequency.exponentialRampToValueAtTime(40, t + 0.07);
        gain.gain.setValueAtTime(0.35, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.07);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(t);
        osc.stop(t + 0.07);
        break;
      }

      case "mine": {
        // Metallic pickaxe ping on stone
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "triangle";
        osc.frequency.setValueAtTime(1200, t);
        osc.frequency.exponentialRampToValueAtTime(600, t + 0.09);
        gain.gain.setValueAtTime(0.25, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.09);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(t);
        osc.stop(t + 0.09);
        break;
      }

      case "build": {
        // Hammer knock
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sawtooth";
        osc.frequency.setValueAtTime(260, t);
        osc.frequency.exponentialRampToValueAtTime(90, t + 0.08);
        gain.gain.setValueAtTime(0.25, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.08);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(t);
        osc.stop(t + 0.08);
        break;
      }

      case "build_done": {
        // Fanfare chord
        [440, 554.37, 659.25].forEach((f, i) => {
          const osc = this.ctx!.createOscillator();
          const gain = this.ctx!.createGain();
          osc.type = "triangle";
          osc.frequency.value = f;
          gain.gain.setValueAtTime(0.15, t + i * 0.05);
          gain.gain.exponentialRampToValueAtTime(0.001, t + 0.4 + i * 0.05);
          osc.connect(gain);
          gain.connect(this.masterGain!);
          osc.start(t + i * 0.05);
          osc.stop(t + 0.4 + i * 0.05);
        });
        break;
      }

      case "attack_hit": {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sawtooth";
        osc.frequency.setValueAtTime(200, t);
        osc.frequency.exponentialRampToValueAtTime(60, t + 0.12);
        gain.gain.setValueAtTime(0.35, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.12);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(t);
        osc.stop(t + 0.12);
        break;
      }

      case "arrow_shot": {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sine";
        osc.frequency.setValueAtTime(900, t);
        osc.frequency.exponentialRampToValueAtTime(200, t + 0.1);
        gain.gain.setValueAtTime(0.2, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.1);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(t);
        osc.stop(t + 0.1);
        break;
      }

      case "death": {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sawtooth";
        osc.frequency.setValueAtTime(160, t);
        osc.frequency.exponentialRampToValueAtTime(40, t + 0.3);
        gain.gain.setValueAtTime(0.3, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.3);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(t);
        osc.stop(t + 0.3);
        break;
      }

      case "chest": {
        // Chime arpeggio
        [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => {
          const osc = this.ctx!.createOscillator();
          const gain = this.ctx!.createGain();
          osc.type = "sine";
          osc.frequency.value = f;
          gain.gain.setValueAtTime(0.18, t + i * 0.08);
          gain.gain.exponentialRampToValueAtTime(0.001, t + 0.35 + i * 0.08);
          osc.connect(gain);
          gain.connect(this.masterGain!);
          osc.start(t + i * 0.08);
          osc.stop(t + 0.35 + i * 0.08);
        });
        break;
      }

      case "horn_warn": {
        // Brass warning horn
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sawtooth";
        osc.frequency.setValueAtTime(180, t);
        osc.frequency.setValueAtTime(220, t + 0.25);
        gain.gain.setValueAtTime(0.3, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.7);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(t);
        osc.stop(t + 0.7);
        break;
      }

      case "horn_raid": {
        // Ominous battle horn
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sawtooth";
        osc.frequency.setValueAtTime(130, t);
        osc.frequency.exponentialRampToValueAtTime(95, t + 0.9);
        gain.gain.setValueAtTime(0.4, t);
        gain.gain.exponentialRampToValueAtTime(0.01, t + 0.9);
        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(t);
        osc.stop(t + 0.9);
        break;
      }

      case "dawn": {
        // Uplifting sunrise birdsong chords
        [330, 440, 660, 880].forEach((f, i) => {
          const osc = this.ctx!.createOscillator();
          const gain = this.ctx!.createGain();
          osc.type = "sine";
          osc.frequency.value = f;
          gain.gain.setValueAtTime(0.12, t + i * 0.1);
          gain.gain.exponentialRampToValueAtTime(0.001, t + 0.5 + i * 0.1);
          osc.connect(gain);
          gain.connect(this.masterGain!);
          osc.start(t + i * 0.1);
          osc.stop(t + 0.5 + i * 0.1);
        });
        break;
      }
    }
  }
}
