import { mkdirSync, writeFileSync } from "node:fs";

const SAMPLE_RATE = 44100;
const BPM = 110;
const BEAT = 60 / BPM;
const BARS = 8;
const PASS_DURATION = BARS * 4 * BEAT;
const TAU = Math.PI * 2;

function fract(value) {
  return value - Math.floor(value);
}

function midi(note) {
  return 440 * 2 ** ((note - 69) / 12);
}

function noise(index, salt = 0) {
  return fract(Math.sin((index + salt * 173) * 12.9898) * 43758.5453) * 2 - 1;
}

function highNoise(index, salt = 0) {
  return noise(index, salt) - noise(index - 1, salt);
}

function saw(phase) {
  return 2 * fract(phase / TAU) - 1;
}

function triangle(phase) {
  return 1 - 4 * Math.abs(fract(phase / TAU) - 0.5);
}

function pan(sample, position) {
  const angle = (position + 1) * Math.PI * 0.25;
  return [sample * Math.cos(angle), sample * Math.sin(angle)];
}

function add(target, source) {
  target[0] += source[0];
  target[1] += source[1];
}

function kick(age) {
  if (age < 0 || age >= 0.46) {
    return 0;
  }
  const phase = TAU * (46 * age + 4.2 * (1 - Math.exp(-24 * age)));
  return (
    Math.sin(phase) * Math.exp(-age * 8.5) * 0.75 +
    Math.sin(TAU * 105 * age) * Math.exp(-age * 27) * 0.18 +
    highNoise(Math.floor(age * SAMPLE_RATE), 2) * Math.exp(-age * 115) * 0.11
  );
}

function snare(age, index) {
  if (age < 0 || age >= 0.34) {
    return 0;
  }
  const body =
    Math.sin(TAU * 158 * age) * Math.exp(-age * 18) * 0.19 +
    Math.sin(TAU * 221 * age) * Math.exp(-age * 24) * 0.1;
  return body + highNoise(index, 7) * Math.exp(-age * 14) * 0.24;
}

function hat(age, index, open = false) {
  const length = open ? 0.3 : 0.085;
  if (age < 0 || age >= length) {
    return 0;
  }
  return (
    highNoise(index, open ? 13 : 11) *
    Math.exp(-age * (open ? 15 : 55)) *
    (open ? 0.12 : 0.085)
  );
}

function machineHit(age, pitch, index) {
  if (age < 0 || age >= 0.28) {
    return 0;
  }
  const ring =
    Math.sin(TAU * pitch * age) * 0.55 +
    Math.sin(TAU * pitch * 1.37 * age) * 0.3 +
    Math.sin(TAU * pitch * 2.11 * age) * 0.15;
  return ring * Math.exp(-age * 17) * 0.14 + highNoise(index, 19) * Math.exp(-age * 38) * 0.025;
}

const PASS_A = ["em", "f", "c", "d", "em", "f", "c", "d"];
const PASS_B = ["em", "c", "f", "d", "em", "c", "d", "f"];
const CHORDS = {
  em: [52, 55, 59, 64],
  f: [53, 57, 60, 65],
  c: [48, 52, 55, 60],
  d: [50, 53, 57, 62],
};
const ROOTS = { em: 40, f: 41, c: 36, d: 38 };
const RISING_A = [64, 67, 69, 71];
const RISING_B = [76, 79, 81, 83];

function baseSample(time, variant) {
  const beat = time / BEAT;
  const bar = Math.min(BARS - 1, Math.floor(beat / 4));
  const beatInBar = beat - bar * 4;
  const progression = variant === "a" ? PASS_A : PASS_B;
  const chordName = progression[bar];
  const chord = CHORDS[chordName];
  const rootFrequency = midi(ROOTS[chordName]);
  const output = [0, 0];

  const quarterAge = fract(beat) * BEAT;
  const kickDuck = 0.28 + 0.72 * Math.min(1, quarterAge / (BEAT * 0.26));
  const eighthAge = fract(beat * 2) * BEAT * 0.5;
  const bassEnvelope = Math.exp(-eighthAge * 5.2) * Math.min(1, eighthAge / 0.008);
  const wobble = 0.55 + 0.45 * Math.sin(TAU * beat * (variant === "a" ? 0.5 : 0.75));
  const bassPhase = TAU * rootFrequency * time;
  const bass =
    (Math.sin(bassPhase) * 0.23 +
      triangle(bassPhase) * 0.2 +
      saw(bassPhase * 2) * 0.12 +
      Math.sin(bassPhase * 3) * 0.075) *
    bassEnvelope *
    (0.72 + wobble * 0.28) *
    kickDuck;
  output[0] += bass;
  output[1] += bass;

  const chordPulse = fract(beat) < 0.62 ? 1 : 0;
  for (let voice = 0; voice < chord.length; voice += 1) {
    const frequency = midi(chord[voice]);
    const drift = 0.997 + voice * 0.002;
    const phase = TAU * frequency * drift * time;
    const pad =
      (Math.sin(phase) * 0.055 + triangle(phase * 0.5) * 0.028) *
      (0.58 + chordPulse * 0.42) *
      kickDuck;
    add(output, pan(pad, -0.66 + voice * 0.44));
  }

  const offbeatAge = fract(beat * 2) * BEAT * 0.5;
  const offbeatIndex = Math.floor(beat * 2);
  if (offbeatIndex % 2 === 1) {
    const stabEnvelope = Math.exp(-offbeatAge * 8) * Math.min(1, offbeatAge / 0.006);
    const note = chord[(bar + offbeatIndex) % chord.length] + 12;
    const phase = TAU * midi(note) * time;
    const stab = (saw(phase) * 0.075 + Math.sin(phase) * 0.055) * stabEnvelope;
    add(output, pan(stab, offbeatIndex % 4 === 1 ? -0.38 : 0.38));
  }

  const phraseBeat = beat % 16;
  if (phraseBeat >= 14) {
    const step = Math.min(3, Math.floor((phraseBeat - 14) * 2));
    const age = fract((phraseBeat - 14) * 2) * BEAT * 0.5;
    const motif = variant === "a" ? RISING_A : RISING_B;
    const frequency = midi(motif[step]);
    const envelope = Math.exp(-age * 6.5) * Math.min(1, age / 0.006);
    const phase = TAU * frequency * time;
    add(
      output,
      pan(
        (Math.sin(phase) * 0.13 + triangle(phase * 2) * 0.035) * envelope,
        variant === "a" ? 0.2 : -0.2,
      ),
    );
  }

  const machinery = Math.sin(TAU * 47 * time + Math.sin(TAU * 0.17 * time)) * 0.018;
  output[0] += machinery;
  output[1] += machinery;
  return output;
}

function sparseDrumsSample(time, index) {
  const beat = time / BEAT;
  const beatInBar = beat % 4;
  const output = [0, 0];

  for (const position of [0, 3.25]) {
    const age = (beatInBar - position) * BEAT;
    if (age >= 0 && age < 0.46) {
      const tone = kick(age) * 0.62;
      output[0] += tone;
      output[1] += tone;
    }
  }

  const snareAge = (beatInBar - 2) * BEAT;
  if (snareAge >= 0 && snareAge < 0.34) {
    add(output, pan(snare(snareAge, index) * 0.82, -0.05));
  }

  const eighthAge = fract(beat * 2) * BEAT * 0.5;
  if (Math.floor(beat * 2) % 2 === 1) {
    add(output, pan(hat(eighthAge, index, true) * 0.88, 0.34));
  }

  const tickAge = fract(beat * 4) * BEAT * 0.25;
  if (Math.floor(beat * 4) % 4 === 2) {
    add(output, pan(machineHit(tickAge, 380, index) * 0.42, -0.5));
  }
  return output;
}

function highDrumsSample(time, index, variant) {
  const beat = time / BEAT;
  const beatInBar = beat % 4;
  const bar = Math.floor(beat / 4);
  const output = [0, 0];
  const kicks = variant === "a" ? [0, 1.5, 3.25] : [0, 0.75, 2.75, 3.5];

  for (const position of kicks) {
    const age = (beatInBar - position) * BEAT;
    if (age >= 0 && age < 0.46) {
      const tone = kick(age) * 0.58;
      output[0] += tone;
      output[1] += tone;
    }
  }

  const snareAge = (beatInBar - 2) * BEAT;
  if (snareAge >= 0 && snareAge < 0.34) {
    add(output, pan(snare(snareAge, index), variant === "a" ? -0.1 : 0.1));
  }

  const sixteenthAge = fract(beat * 4) * BEAT * 0.25;
  const sixteenth = Math.floor(beat * 4);
  const open = sixteenth % 4 === 2;
  add(output, pan(hat(sixteenthAge, index, open) * (open ? 0.88 : 0.68), open ? 0.4 : -0.35));

  const hitPositions = variant === "a" ? [0.75, 1.75, 3.5] : [0.5, 1.25, 3.0];
  for (let hit = 0; hit < hitPositions.length; hit += 1) {
    const age = (beatInBar - hitPositions[hit]) * BEAT;
    if (age >= 0 && age < 0.28) {
      const pitch = variant === "a" ? 330 + hit * 95 : 520 - hit * 75;
      add(output, pan(machineHit(age, pitch, index) * 0.95, -0.58 + hit * 0.58));
    }
  }

  if (bar % 4 === 3 && beatInBar >= 3) {
    const step = Math.floor((beatInBar - 3) * 4);
    const age = fract((beatInBar - 3) * 4) * BEAT * 0.25;
    add(output, pan(machineHit(age, 210 + step * 70, index), -0.6 + step * 0.4));
  }
  return output;
}

function render(sampleAt, duration = PASS_DURATION) {
  const frames = Math.round(duration * SAMPLE_RATE);
  const samples = new Float32Array(frames * 2);
  for (let frame = 0; frame < frames; frame += 1) {
    const [left, right] = sampleAt(frame / SAMPLE_RATE, frame);
    samples[frame * 2] = left;
    samples[frame * 2 + 1] = right;
  }
  return samples;
}

function master(samples, peakTarget, drive = 2.15, gainDb = 0) {
  let peak = 0;
  for (const sample of samples) {
    peak = Math.max(peak, Math.abs(sample));
  }
  const scale = peak > 0 ? peakTarget / peak : 1;
  const outputGain = 10 ** (gainDb / 20);
  for (let index = 0; index < samples.length; index += 1) {
    samples[index] =
      (Math.tanh(samples[index] * scale * drive) / Math.tanh(drive)) * outputGain;
  }
  return fadeEdges(samples);
}

function fadeEdges(samples, milliseconds = 4) {
  const fadeFrames = Math.round((milliseconds / 1000) * SAMPLE_RATE);
  const totalFrames = samples.length / 2;
  for (let frame = 0; frame < fadeFrames; frame += 1) {
    const fadeIn = frame / fadeFrames;
    const fadeOut = (fadeFrames - frame - 1) / fadeFrames;
    const endFrame = totalFrames - fadeFrames + frame;
    samples[frame * 2] *= fadeIn;
    samples[frame * 2 + 1] *= fadeIn;
    samples[endFrame * 2] *= fadeOut;
    samples[endFrame * 2 + 1] *= fadeOut;
  }
  return samples;
}

function mix(...tracks) {
  const result = new Float32Array(tracks[0][0].length);
  for (const [samples, gain] of tracks) {
    for (let index = 0; index < result.length; index += 1) {
      result[index] += samples[index] * gain;
    }
  }
  return result;
}

function concatenate(...tracks) {
  const result = new Float32Array(tracks.reduce((sum, track) => sum + track.length, 0));
  let offset = 0;
  for (const track of tracks) {
    result.set(track, offset);
    offset += track.length;
  }
  return result;
}

function writeStereoWav(path, samples) {
  const dataSize = samples.length * 2;
  const wav = Buffer.alloc(44 + dataSize);
  wav.write("RIFF", 0);
  wav.writeUInt32LE(36 + dataSize, 4);
  wav.write("WAVEfmt ", 8);
  wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(2, 22);
  wav.writeUInt32LE(SAMPLE_RATE, 24);
  wav.writeUInt32LE(SAMPLE_RATE * 4, 28);
  wav.writeUInt16LE(4, 32);
  wav.writeUInt16LE(16, 34);
  wav.write("data", 36);
  wav.writeUInt32LE(dataSize, 40);
  for (let index = 0; index < samples.length; index += 1) {
    wav.writeInt16LE(
      Math.round(Math.max(-1, Math.min(1, samples[index])) * 32767),
      44 + index * 2,
    );
  }
  writeFileSync(path, wav);
}

function reactorZapSample(time, index) {
  const duration = 0.58;
  const progress = Math.min(1, time / duration);
  const envelope = Math.sin(Math.PI * progress) * Math.exp(-time * 2.2);
  const sweepFrequency = 1400 - 1120 * progress;
  const phase = TAU * (1400 * time - (1120 / (2 * duration)) * time * time);
  const electrical = highNoise(index, 31) * Math.exp(-time * 8) * 0.18;
  const tone =
    Math.sin(phase) * 0.32 +
    Math.sin(TAU * sweepFrequency * 0.51 * time) * 0.16 +
    Math.sin(TAU * 92 * time) * Math.exp(-time * 5) * 0.28;
  const sample = (tone + electrical) * envelope;
  return [sample, sample];
}

mkdirSync("audio/music", { recursive: true });
mkdirSync("audio/sfx", { recursive: true });

const baseA = master(render((time) => baseSample(time, "a")), 0.72);
const baseB = master(render((time) => baseSample(time, "b")), 0.72);
const highA = master(render((time, index) => highDrumsSample(time, index, "a")), 0.82, 2.15, -3.5);
const highB = master(render((time, index) => highDrumsSample(time, index, "b")), 0.82, 2.15, -3.5);
const sparse = master(render(sparseDrumsSample), 0.76, 2.15, -4.0);

writeStereoWav("audio/music/stage4_base_a.wav", baseA);
writeStereoWav("audio/music/stage4_base_b.wav", baseB);
writeStereoWav("audio/music/stage4_drums_cyberdub_a.wav", highA);
writeStereoWav("audio/music/stage4_drums_cyberdub_b.wav", highB);
writeStereoWav("audio/music/stage4_drums_sparse.wav", sparse);

const runtimeBaseGain = 10 ** (-9 / 20);
writeStereoWav(
  "audio/music/stage4_preview_ab_stitched.wav",
  concatenate(
    mix([baseA, runtimeBaseGain], [highA, 1]),
    mix([baseB, runtimeBaseGain], [highB, 1]),
  ),
);

writeStereoWav(
  "audio/sfx/reactor_discharge.wav",
  master(render(reactorZapSample, 0.58), 0.82, 1.7, -1),
);
