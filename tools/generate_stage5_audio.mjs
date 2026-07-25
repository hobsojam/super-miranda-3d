import { mkdirSync, writeFileSync } from "node:fs";

const SAMPLE_RATE = 44100;
const BPM = 142;
const BEAT = 60 / BPM;
const PASS_DURATION = BEAT * 32;
const TAU = Math.PI * 2;

function fract(value) {
  return value - Math.floor(value);
}

function noise(index, seed) {
  const value = Math.sin((index + seed * 7919) * 12.9898) * 43758.5453;
  return fract(value) * 2 - 1;
}

function highNoise(index, seed) {
  return noise(index, seed) - noise(Math.max(0, index - 1), seed) * 0.92;
}

function saw(phase) {
  return 2 * fract(phase / TAU) - 1;
}

function triangle(phase) {
  return 2 * Math.abs(2 * fract(phase / TAU) - 1) - 1;
}

function pan(sample, position) {
  const angle = (position + 1) * Math.PI * 0.25;
  return [sample * Math.cos(angle), sample * Math.sin(angle)];
}

function add(target, source) {
  target[0] += source[0];
  target[1] += source[1];
}

function noteFrequency(root, semitones) {
  return root * 2 ** (semitones / 12);
}

function kick(age) {
  if (age < 0 || age >= 0.38) {
    return 0;
  }
  const pitchDrop = 4.8 * (1 - Math.exp(-age * 32));
  const phase = TAU * (48 * age + pitchDrop);
  const body = Math.sin(phase) * Math.exp(-age * 10) * 0.78;
  const knock = Math.sin(TAU * 124 * age) * Math.exp(-age * 34) * 0.2;
  const click = highNoise(Math.floor(age * SAMPLE_RATE), 3) * Math.exp(-age * 120) * 0.13;
  return body + knock + click;
}

function clap(age, index) {
  if (age < 0 || age >= 0.24) {
    return 0;
  }
  const burst =
    highNoise(index, 11) * Math.exp(-age * 18) +
    highNoise(index + 97, 13) * Math.exp(-Math.max(0, age - 0.025) * 25) * 0.5;
  const tone = Math.sin(TAU * 196 * age) * Math.exp(-age * 24) * 0.2;
  return burst * 0.22 + tone;
}

function hat(age, index, open = false) {
  const length = open ? 0.25 : 0.065;
  if (age < 0 || age >= length) {
    return 0;
  }
  return (
    highNoise(index, open ? 23 : 19) *
    Math.exp(-age * (open ? 17 : 70)) *
    (open ? 0.17 : 0.12)
  );
}

function acidVoice(time, frequency, envelope, movement) {
  const phase = TAU * frequency * time;
  const harmonics =
    saw(phase) * 0.12 +
    saw(phase * 2.003) * 0.055 +
    triangle(phase * 0.501) * 0.04;
  const filterMotion = 0.55 + 0.45 * Math.sin(TAU * movement);
  return Math.tanh(harmonics * (2.2 + filterMotion * 2.8)) * envelope * 0.32;
}

function baseSample(time, variant) {
  const beat = time / BEAT;
  const bar = Math.floor(beat / 4);
  const sixteenth = Math.floor(beat * 4);
  const stepAge = fract(beat * 4) * BEAT * 0.25;
  const output = [0, 0];
  const bassPattern =
    variant === "a"
      ? [0, 0, 12, 0, 3, 0, 7, 10]
      : [0, 0, 7, 0, 10, 12, 3, 0];
  const semitone = bassPattern[sixteenth % bassPattern.length];
  const bassFrequency = noteFrequency(41.2, semitone);
  const bassEnvelope = Math.exp(-stepAge * 18);
  const bass =
    (Math.sin(TAU * bassFrequency * time) * 0.24 +
      triangle(TAU * bassFrequency * time) * 0.11) *
    bassEnvelope;
  output[0] += bass;
  output[1] += bass;

  const chordRoots = variant === "a" ? [0, 3, 7, 10] : [0, 7, 10, 3];
  const chordRoot = chordRoots[bar % chordRoots.length];
  for (const [index, interval] of [0, 7, 12].entries()) {
    const frequency = noteFrequency(82.41, chordRoot + interval);
    const phase = TAU * frequency * time;
    const pad = (Math.sin(phase) + triangle(phase * 0.5) * 0.35) * 0.028;
    add(output, pan(pad, -0.5 + index * 0.5));
  }

  const eighth = Math.floor(beat * 2);
  const leadAge = fract(beat * 2) * BEAT * 0.5;
  if (bar >= 2 && eighth % 2 === 0) {
    const leadPattern = variant === "a" ? [12, 15, 19, 22] : [19, 15, 22, 24];
    const frequency = noteFrequency(82.41, leadPattern[Math.floor(eighth / 2) % 4]);
    const envelope = Math.exp(-leadAge * 10);
    add(
      output,
      pan(
        acidVoice(time, frequency, envelope, time / PASS_DURATION + bar * 0.07),
        variant === "a" ? 0.28 : -0.28,
      ),
    );
  }
  return output;
}

function sparseDrumsSample(time, index) {
  const beat = time / BEAT;
  const output = [0, 0];
  const kickAge = fract(beat) * BEAT;
  const kickTone = kick(kickAge) * 0.62;
  output[0] += kickTone;
  output[1] += kickTone;

  const wholeBeat = Math.floor(beat);
  if (wholeBeat % 4 === 1 || wholeBeat % 4 === 3) {
    add(output, pan(clap(kickAge, index) * 0.72, -0.04));
  }
  const eighthAge = fract(beat * 2) * BEAT * 0.5;
  if (Math.floor(beat * 2) % 2 === 1) {
    add(output, pan(hat(eighthAge, index, true) * 0.9, 0.35));
  }
  return output;
}

function highDrumsSample(time, index, variant) {
  const beat = time / BEAT;
  const bar = Math.floor(beat / 4);
  const output = sparseDrumsSample(time, index);
  const sixteenth = Math.floor(beat * 4);
  const sixteenthAge = fract(beat * 4) * BEAT * 0.25;
  add(
    output,
    pan(
      hat(sixteenthAge, index, sixteenth % 4 === 2) * (sixteenth % 4 === 2 ? 0.85 : 0.68),
      sixteenth % 2 === 0 ? -0.42 : 0.42,
    ),
  );

  const beatInBar = beat - bar * 4;
  const syncopation = variant === "a" ? [1.5, 2.75] : [0.75, 2.5, 3.25];
  for (let hit = 0; hit < syncopation.length; hit += 1) {
    const age = (beatInBar - syncopation[hit]) * BEAT;
    if (age >= 0 && age < 0.18) {
      const pitch = 150 + hit * 57;
      const tom =
        Math.sin(TAU * pitch * age) * Math.exp(-age * 22) * 0.22 +
        highNoise(index, 29 + hit) * Math.exp(-age * 65) * 0.05;
      add(output, pan(tom, hit % 2 === 0 ? -0.58 : 0.58));
    }
  }
  return output;
}

function render(sampleFunction, duration = PASS_DURATION) {
  const frameCount = Math.floor(duration * SAMPLE_RATE);
  const output = new Float32Array(frameCount * 2);
  for (let frame = 0; frame < frameCount; frame += 1) {
    const sample = sampleFunction(frame / SAMPLE_RATE, frame);
    output[frame * 2] = sample[0];
    output[frame * 2 + 1] = sample[1];
  }
  return output;
}

function master(samples, peakTarget, drive = 2.1, gainDb = 0) {
  let peak = 0;
  for (let index = 0; index < samples.length; index += 1) {
    samples[index] = Math.tanh(samples[index] * drive) / Math.tanh(drive);
    peak = Math.max(peak, Math.abs(samples[index]));
  }
  const gain = (peakTarget / Math.max(peak, 0.0001)) * 10 ** (gainDb / 20);
  for (let index = 0; index < samples.length; index += 1) {
    samples[index] *= gain;
  }
  return samples;
}

function mix(...tracks) {
  const output = new Float32Array(tracks[0][0].length);
  for (const [samples, gain] of tracks) {
    for (let index = 0; index < output.length; index += 1) {
      output[index] += samples[index] * gain;
    }
  }
  return output;
}

function concatenate(...tracks) {
  const output = new Float32Array(tracks.reduce((sum, track) => sum + track.length, 0));
  let offset = 0;
  for (const track of tracks) {
    output.set(track, offset);
    offset += track.length;
  }
  return output;
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

function stormFrontImpact(time, index) {
  const duration = 0.72;
  const progress = Math.min(1, time / duration);
  const envelope = Math.sin(Math.PI * progress) * Math.exp(-time * 2.5);
  const sweep = 720 - progress * 590;
  const phase = TAU * (720 * time - (590 / (2 * duration)) * time * time);
  const tone =
    Math.sin(phase) * 0.31 +
    Math.sin(TAU * sweep * 0.49 * time) * 0.18 +
    Math.sin(TAU * 58 * time) * Math.exp(-time * 4) * 0.34;
  const air = highNoise(index, 41) * Math.exp(-time * 7) * 0.16;
  const sample = (tone + air) * envelope;
  return [sample, sample];
}

mkdirSync("audio/music", { recursive: true });
mkdirSync("audio/sfx", { recursive: true });

const baseA = master(render((time) => baseSample(time, "a")), 0.72);
const baseB = master(render((time) => baseSample(time, "b")), 0.72);
const highA = master(render((time, index) => highDrumsSample(time, index, "a")), 0.82, 2.1, -2.6);
const highB = master(render((time, index) => highDrumsSample(time, index, "b")), 0.82, 2.1, -2.6);
const sparse = master(render(sparseDrumsSample), 0.78, 2.1, -3.5);

writeStereoWav("audio/music/stage5_base_a.wav", baseA);
writeStereoWav("audio/music/stage5_base_b.wav", baseB);
writeStereoWav("audio/music/stage5_drums_psytrance_a.wav", highA);
writeStereoWav("audio/music/stage5_drums_psytrance_b.wav", highB);
writeStereoWav("audio/music/stage5_drums_sparse.wav", sparse);

const runtimeBaseGain = 10 ** (-9 / 20);
writeStereoWav(
  "audio/music/stage5_preview_ab_stitched.wav",
  concatenate(
    mix([baseA, runtimeBaseGain], [highA, 1]),
    mix([baseB, runtimeBaseGain], [highB, 1]),
  ),
);
writeStereoWav(
  "audio/sfx/storm_front_impact.wav",
  master(render(stormFrontImpact, 0.72), 0.82, 1.8, -1.5),
);
