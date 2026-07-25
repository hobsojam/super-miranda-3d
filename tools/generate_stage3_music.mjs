import { mkdirSync, writeFileSync } from "node:fs";

const SAMPLE_RATE = 44100;
const BPM = 136;
const BEAT = 60 / BPM;
const BARS = 8;
const PASS_BEATS = BARS * 4;
const PASS_DURATION = PASS_BEATS * BEAT;
const TAU = Math.PI * 2;

function midi(note) {
  return 440 * 2 ** ((note - 69) / 12);
}

function fract(value) {
  return value - Math.floor(value);
}

function noise(index, salt = 0) {
  return fract(Math.sin((index + salt * 131) * 12.9898) * 43758.5453) * 2 - 1;
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
  if (age < 0 || age >= 0.42) {
    return 0;
  }
  const phase = TAU * (49 * age + 3.5 * (1 - Math.exp(-28 * age)));
  const body = Math.sin(phase) * Math.exp(-age * 9);
  const knock = Math.sin(TAU * 118 * age) * Math.exp(-age * 28);
  const click = highNoise(Math.floor(age * SAMPLE_RATE), 3) * Math.exp(-age * 110);
  return body * 0.82 + knock * 0.2 + click * 0.12;
}

function hat(age, index, open = false) {
  const length = open ? 0.24 : 0.075;
  if (age < 0 || age >= length) {
    return 0;
  }
  const decay = open ? 18 : 62;
  return highNoise(index, open ? 7 : 5) * Math.exp(-age * decay) * (open ? 0.18 : 0.15);
}

function snare(age, index) {
  if (age < 0 || age >= 0.24) {
    return 0;
  }
  const noiseBody = highNoise(index, 11) * Math.exp(-age * 17) * 0.24;
  const metal =
    (Math.sin(TAU * 183 * age) + Math.sin(TAU * 247 * age) * 0.55) *
    Math.exp(-age * 21) *
    0.13;
  return noiseBody + metal;
}

function metallicHit(age, pitch, index) {
  if (age < 0 || age >= 0.18) {
    return 0;
  }
  const ring =
    Math.sin(TAU * pitch * age) * 0.6 +
    Math.sin(TAU * pitch * 1.414 * age) * 0.25 +
    Math.sin(TAU * pitch * 2.13 * age) * 0.15;
  return ring * Math.exp(-age * 24) * 0.15 + highNoise(index, 17) * Math.exp(-age * 45) * 0.025;
}

const CHORDS = {
  dm: [62, 65, 69, 72],
  bb: [58, 62, 65, 69],
  c: [60, 64, 67, 70],
  a: [57, 61, 64, 67],
};

const ROOTS = {
  dm: 38,
  bb: 34,
  c: 36,
  a: 33,
};

const PASS_A_CHORDS = ["dm", "dm", "bb", "a", "dm", "c", "bb", "a"];
const PASS_B_CHORDS = ["dm", "c", "bb", "a", "dm", "bb", "c", "a"];
const ARP_A = [0, 1, 2, 1, 3, 2, 1, 2, 0, 2, 3, 2, 1, 2, 3, 1];
const ARP_B = [0, 2, 1, 3, 2, 1, 3, 2, 0, 1, 2, 3, 1, 3, 2, 1];
const DESCENT_A = [74, 72, 70, 69];
const DESCENT_B = [86, 84, 82, 81];

function baseSample(time, variant) {
  const beat = time / BEAT;
  const bar = Math.min(BARS - 1, Math.floor(beat / 4));
  const beatInBar = beat - bar * 4;
  const sixteenth = Math.floor(beatInBar * 4);
  const stepAge = fract(beat * 4) * BEAT * 0.25;
  const progression = variant === "a" ? PASS_A_CHORDS : PASS_B_CHORDS;
  const arpPattern = variant === "a" ? ARP_A : ARP_B;
  const chordName = progression[bar];
  const chord = CHORDS[chordName];
  const root = ROOTS[chordName];
  const output = [0, 0];

  const pulseEnvelope = Math.exp(-stepAge * 15) * Math.min(1, stepAge / 0.004);
  const arpNote = chord[arpPattern[sixteenth] % chord.length];
  const arpFrequency = midi(arpNote);
  const arpPhase = TAU * arpFrequency * time;
  const arpTone =
    (saw(arpPhase) * 0.12 +
      saw(arpPhase * 1.003) * 0.075 +
      Math.sin(arpPhase) * 0.1 +
      triangle(arpPhase * 0.5) * 0.045) *
    pulseEnvelope;
  add(output, pan(arpTone, sixteenth % 2 === 0 ? -0.36 : 0.36));

  const eighthAge = fract(beat * 2) * BEAT * 0.5;
  const bassEnvelope = Math.exp(-eighthAge * 8) * Math.min(1, eighthAge / 0.006);
  const quarterAge = fract(beat) * BEAT;
  const bassDuck = 0.25 + 0.75 * Math.min(1, quarterAge / (BEAT * 0.2));
  const bassFrequency = midi(root);
  const bassPhase = TAU * bassFrequency * time;
  const bass =
    (triangle(bassPhase) * 0.26 +
      Math.sin(bassPhase) * 0.23 +
      triangle(bassPhase * 2) * 0.14 +
      saw(bassPhase * 2) * 0.1 +
      Math.sin(bassPhase * 2) * 0.1 +
      Math.sin(bassPhase * 3) * 0.08) *
    bassEnvelope *
    bassDuck;
  output[0] += bass;
  output[1] += bass;

  const sidechain = 0.45 + 0.55 * Math.min(1, quarterAge / (BEAT * 0.42));
  const padNotes = [chord[0] - 12, chord[1], chord[2]];
  for (let voice = 0; voice < padNotes.length; voice += 1) {
    const frequency = midi(padNotes[voice]);
    const drift = variant === "a" ? 0.997 + voice * 0.003 : 1.004 - voice * 0.002;
    const pad =
      (Math.sin(TAU * frequency * drift * time) * 0.07 +
        triangle(TAU * frequency * 0.5 * time) * 0.036) *
      sidechain;
    add(output, pan(pad, (voice - 1) * 0.48));
  }

  const phraseBeat = beat % 16;
  if (phraseBeat >= 14) {
    const motifStep = Math.min(3, Math.floor((phraseBeat - 14) * 2));
    const motifAge = fract((phraseBeat - 14) * 2) * BEAT * 0.5;
    const motif = variant === "a" ? DESCENT_A : DESCENT_B;
    const frequency = midi(motif[motifStep]);
    const leadEnvelope = Math.exp(-motifAge * 7.5) * Math.min(1, motifAge / 0.006);
    const phase = TAU * frequency * time;
    const lead =
      (Math.sin(phase) * 0.13 + triangle(phase * 2.002) * 0.045) * leadEnvelope;
    add(output, pan(lead, variant === "a" ? 0.22 : -0.22));
  }

  const movement = Math.sin(TAU * time / (PASS_DURATION * 0.5));
  output[0] += movement * 0.012;
  output[1] -= movement * 0.012;
  return output;
}

function sparseDrumsSample(time, index) {
  const beat = time / BEAT;
  const output = [0, 0];
  const kickAge = fract(beat) * BEAT;
  const kickTone = kick(kickAge) * 0.58;
  output[0] += kickTone;
  output[1] += kickTone;

  const eighth = Math.floor(beat * 2);
  const eighthAge = fract(beat * 2) * BEAT * 0.5;
  if (eighth % 2 === 1) {
    add(output, pan(hat(eighthAge, index, true) * 0.9, 0.25));
  }

  const wholeBeat = Math.floor(beat);
  const beatAge = fract(beat) * BEAT;
  if (wholeBeat % 4 === 1 || wholeBeat % 4 === 3) {
    add(output, pan(snare(beatAge, index) * 0.72, -0.06));
  }

  const barBeat = beat % 4;
  if (barBeat < 0.22) {
    const pulse = metallicHit(barBeat * BEAT, 315, index) * 0.5;
    add(output, pan(pulse, -0.42));
  }
  return output;
}

function highDrumsSample(time, index, variant) {
  const beat = time / BEAT;
  const bar = Math.floor(beat / 4);
  const beatInBar = beat - bar * 4;
  const output = [0, 0];

  const kickAge = fract(beat) * BEAT;
  const kickTone = kick(kickAge) * 0.58;
  output[0] += kickTone;
  output[1] += kickTone;

  const eighth = Math.floor(beat * 2);
  const eighthAge = fract(beat * 2) * BEAT * 0.5;
  const openHat = eighth % 2 === 1;
  add(
    output,
    pan(
      hat(eighthAge, index, openHat) * (openHat ? 0.92 : 0.72),
      openHat ? 0.32 : -0.28,
    ),
  );

  const sixteenth = Math.floor(beat * 4);
  const sixteenthAge = fract(beat * 4) * BEAT * 0.25;
  const extraHat =
    variant === "a"
      ? sixteenth % 4 === 3
      : sixteenth % 8 === 3 || sixteenth % 8 === 6;
  if (extraHat) {
    add(output, pan(hat(sixteenthAge, index, false) * 0.58, -0.5));
  }

  const wholeBeat = Math.floor(beat);
  const beatAge = fract(beat) * BEAT;
  if (wholeBeat % 4 === 1 || wholeBeat % 4 === 3) {
    const snareTone = snare(beatAge, index);
    add(output, pan(snareTone, variant === "a" ? -0.08 : 0.08));
  }

  const syncopation =
    variant === "a"
      ? [1.5, 2.75]
      : [0.75, 2.5, 3.25];
  for (let hit = 0; hit < syncopation.length; hit += 1) {
    const hitAge = (beatInBar - syncopation[hit]) * BEAT;
    if (hitAge >= 0 && hitAge < 0.18) {
      const pitch = variant === "a" ? 430 + hit * 115 : 520 - hit * 70;
      add(
        output,
        pan(
          metallicHit(hitAge, pitch, index) * 1.08,
          hit % 2 === 0 ? -0.58 : 0.58,
        ),
      );
    }
  }

  if (bar % 4 === 3 && beatInBar >= 3) {
    const fillStep = Math.floor((beatInBar - 3) * 4);
    const fillAge = fract((beatInBar - 3) * 4) * BEAT * 0.25;
    const pitch = variant === "a" ? 170 + fillStep * 42 : 330 - fillStep * 45;
    add(output, pan(metallicHit(fillAge, pitch, index), -0.6 + fillStep * 0.4));
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

function normalize(samples, peakTarget) {
  let peak = 0;
  for (const sample of samples) {
    peak = Math.max(peak, Math.abs(sample));
  }
  const scale = peak > 0 ? peakTarget / peak : 1;
  const drive = 2.4;
  for (let index = 0; index < samples.length; index += 1) {
    samples[index] = Math.tanh(samples[index] * scale * drive) / Math.tanh(drive);
  }
  return samples;
}

function applyGain(samples, decibels) {
  const gain = 10 ** (decibels / 20);
  for (let index = 0; index < samples.length; index += 1) {
    samples[index] *= gain;
  }
  return samples;
}

function boostLowEnd(samples, cutoff, gain) {
  const alpha = 1 - Math.exp((-TAU * cutoff) / SAMPLE_RATE);
  let lowLeft = 0;
  let lowRight = 0;
  for (let frame = 0; frame < samples.length / 2; frame += 1) {
    const index = frame * 2;
    lowLeft += alpha * (samples[index] - lowLeft);
    lowRight += alpha * (samples[index + 1] - lowRight);
    samples[index] += lowLeft * gain;
    samples[index + 1] += lowRight * gain;
  }
  return samples;
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
  const length = tracks[0][0].length;
  const result = new Float32Array(length);
  for (const [samples, gain] of tracks) {
    for (let index = 0; index < length; index += 1) {
      result[index] += samples[index] * gain;
    }
  }
  return result;
}

function concatenate(...tracks) {
  const totalLength = tracks.reduce((sum, track) => sum + track.length, 0);
  const result = new Float32Array(totalLength);
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
    const sample = Math.max(-1, Math.min(1, samples[index]));
    wav.writeInt16LE(Math.round(sample * 32767), 44 + index * 2);
  }
  writeFileSync(path, wav);
}

mkdirSync("audio/music", { recursive: true });

const baseA = fadeEdges(
  normalize(boostLowEnd(render((time) => baseSample(time, "a")), 180, 0.75), 0.72),
);
const baseB = fadeEdges(
  normalize(boostLowEnd(render((time) => baseSample(time, "b")), 180, 0.75), 0.72),
);
const drumsHighA = fadeEdges(
  applyGain(
    normalize(render((time, index) => highDrumsSample(time, index, "a")), 0.84),
    -2.6,
  ),
);
const drumsHighB = fadeEdges(
  applyGain(
    normalize(render((time, index) => highDrumsSample(time, index, "b")), 0.84),
    -2.6,
  ),
);
const drumsSparse = fadeEdges(
  applyGain(normalize(render(sparseDrumsSample), 0.78), -4.0),
);

writeStereoWav("audio/music/stage3_base_a.wav", baseA);
writeStereoWav("audio/music/stage3_base_b.wav", baseB);
writeStereoWav("audio/music/stage3_drums_industrial_a.wav", drumsHighA);
writeStereoWav("audio/music/stage3_drums_industrial_b.wav", drumsHighB);
writeStereoWav("audio/music/stage3_drums_sparse.wav", drumsSparse);

const runtimeBaseGain = 10 ** (-9 / 20);
const previewA = mix([baseA, runtimeBaseGain], [drumsHighA, 1]);
const previewB = mix([baseB, runtimeBaseGain], [drumsHighB, 1]);
writeStereoWav(
  "audio/music/stage3_preview_ab_stitched.wav",
  concatenate(previewA, previewB),
);
