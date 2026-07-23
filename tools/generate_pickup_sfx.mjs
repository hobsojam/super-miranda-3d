import { mkdirSync, writeFileSync } from "node:fs";

const SAMPLE_RATE = 44100;
const TAU = Math.PI * 2;

function envelope(time, start, attack, release) {
  const age = time - start;
  if (age < 0 || age >= attack + release) {
    return 0;
  }
  if (age < attack) {
    return age / attack;
  }
  return 1 - (age - attack) / release;
}

function softClip(value) {
  return Math.tanh(value * 1.35) / Math.tanh(1.35);
}

function writeMonoWav(path, duration, sampleAt) {
  const sampleCount = Math.ceil(duration * SAMPLE_RATE);
  const dataSize = sampleCount * 2;
  const wav = Buffer.alloc(44 + dataSize);
  wav.write("RIFF", 0);
  wav.writeUInt32LE(36 + dataSize, 4);
  wav.write("WAVEfmt ", 8);
  wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(SAMPLE_RATE, 24);
  wav.writeUInt32LE(SAMPLE_RATE * 2, 28);
  wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34);
  wav.write("data", 36);
  wav.writeUInt32LE(dataSize, 40);

  for (let i = 0; i < sampleCount; i += 1) {
    const sample = softClip(sampleAt(i / SAMPLE_RATE, i));
    wav.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sample)) * 32767), 44 + i * 2);
  }
  writeFileSync(path, wav);
}

function lifeSample(time, index) {
  const notes = [
    [0.0, 523.25],
    [0.105, 659.25],
    [0.21, 783.99],
    [0.34, 1046.5],
  ];
  let sample = 0;
  for (const [start, frequency] of notes) {
    const env = envelope(time, start, 0.008, start === 0.34 ? 0.43 : 0.22);
    const age = Math.max(0, time - start);
    sample +=
      env *
      (Math.sin(TAU * frequency * age) * 0.34 +
        Math.sin(TAU * frequency * 2.01 * age) * 0.12 +
        Math.sin(TAU * frequency * 3.98 * age) * 0.035);
  }

  const shimmer = envelope(time, 0.34, 0.012, 0.5);
  const deterministicNoise = Math.sin(index * 12.9898) * Math.sin(index * 78.233);
  sample += shimmer * deterministicNoise * 0.025;
  return sample;
}

function purgeSample(time, index) {
  let sample = 0;
  if (time < 0.19) {
    const progress = time / 0.19;
    const frequency = 360 + 1500 * progress * progress;
    const phase = TAU * (360 * time + (1500 / (3 * 0.19 * 0.19)) * time ** 3);
    sample += Math.sin(phase) * Math.sin(Math.PI * progress) * 0.32;
    sample += Math.sin(TAU * frequency * 1.51 * time) * Math.sin(Math.PI * progress) * 0.08;
  }

  const pulseAge = time - 0.185;
  if (pulseAge >= 0) {
    const pulseEnv = Math.exp(-pulseAge * 6.2);
    const lowPhase = TAU * (128 * pulseAge - 42 * pulseAge * pulseAge);
    sample += Math.sin(lowPhase) * pulseEnv * 0.52;
    sample += Math.sin(TAU * 760 * pulseAge) * Math.exp(-pulseAge * 9.5) * 0.17;
    sample += Math.sin(TAU * 1140 * pulseAge) * Math.exp(-pulseAge * 12) * 0.11;
    const deterministicNoise = Math.sin(index * 91.73) * Math.sin(index * 17.17);
    sample += deterministicNoise * Math.exp(-pulseAge * 18) * 0.12;
  }
  return sample;
}

mkdirSync("audio/sfx", { recursive: true });
writeMonoWav("audio/sfx/pickup_life.wav", 0.86, lifeSample);
writeMonoWav("audio/sfx/pickup_purge.wav", 0.76, purgeSample);
