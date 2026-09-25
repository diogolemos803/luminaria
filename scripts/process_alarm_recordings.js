// Transforma as gravações reais (já convertidas pra WAV por transcode_recordings.ps1)
// nos sons de despertador do app: mono, 44,1 kHz, 16-bit, 20s, entrada/saída suaves e
// volume normalizado. Sem dependências — só Node puro (sem Python nesta máquina, e o
// usuário pediu pra não instalar pacotes).
//
// Por que 20s: a notificação de reserva (usada quando não há permissão de Alarmes do
// AlarmKit) só aceita som de até 30s — acima disso o iOS toca o som padrão —, e cada
// segundo pesa ~88 KB no app (20 sons × 20s ≈ 35 MB). O AlarmKit repete o som enquanto o
// alarme toca; com a entrada/saída suaves, a repetição vira uma "respiração" a cada 20s.
//
// Uso:
//   node scripts/process_alarm_recordings.js analyze <pasta com os WAV convertidos>
//   node scripts/process_alarm_recordings.js build   <pasta com os WAV convertidos> <pasta de saída>
// O trecho usado de cada gravação fica fixo em SOUNDS abaixo (escolhido pela análise),
// pra reprocessar dá o mesmo resultado.

const fs = require('fs');
const path = require('path');

const TARGET_RATE = 44100;
const CLIP_SECONDS = 20;
const FADE_IN = 1.5;
const FADE_OUT = 2.5;

// arquivo convertido → arquivo final no app e início do trecho (segundos). `start: null`
// = escolhe sozinho o trecho mais "cheio" e sem picos (ver pickWindow).
const NATURE = -17;
const SOFT = -21; // sinos/música: picos de ataque altos — alvo menor evita comprimir o toque
const SOUNDS = [
  { source: "passaros_acordando.wav", output: "alarm_passaros_acordando.wav", start: null, targetRmsDb: NATURE },
  { source: "rouxinol.wav", output: "alarm_rouxinol.wav", start: null, targetRmsDb: NATURE },
  { source: "melros_manha.wav", output: "alarm_melros.wav", start: null, targetRmsDb: NATURE },
  { source: "brisa_passaros.wav", output: "alarm_brisa_passaros.wav", start: null, targetRmsDb: NATURE },
  { source: "ondas_praia.wav", output: "alarm_ondas_praia.wav", start: null, targetRmsDb: -18 },
  { source: "ondas_mar.wav", output: "alarm_ondas_mar.wav", start: null, targetRmsDb: -18 },
  { source: "praia_pedrinhas.wav", output: "alarm_praia_pedrinhas.wav", start: null, targetRmsDb: -18 },
  { source: "riacho.wav", output: "alarm_riacho.wav", start: 0, targetRmsDb: -18 },
  { source: "fio_dagua.wav", output: "alarm_fio_dagua.wav", start: null, targetRmsDb: -18 },
  { source: "chuva_leve.wav", output: "alarm_chuva_leve.wav", start: null, targetRmsDb: -18 },
  { source: "noite_campo.wav", output: "alarm_noite_campo.wav", start: null, targetRmsDb: NATURE },
  { source: "sinos_vento.wav", output: "alarm_sinos_koshi.wav", start: 0, targetRmsDb: SOFT },
  { source: "sinos_vento_2.wav", output: "alarm_sinos_vento.wav", start: null, targetRmsDb: SOFT },
  { source: "sininhos.wav", output: "alarm_sininhos.wav", start: null, targetRmsDb: SOFT },
  { source: "sinos_tubulares.wav", output: "alarm_sinos_tubulares.wav", start: 0, targetRmsDb: SOFT },
  { source: "ceramica.wav", output: "alarm_ceramica.wav", start: 0, targetRmsDb: SOFT },
  { source: "tigela_tibetana.wav", output: "alarm_tigela.wav", start: 0, targetRmsDb: SOFT },
  { source: "caixinha_musica.wav", output: "alarm_caixinha.wav", start: 0, targetRmsDb: SOFT },
  { source: "caixinha_brahms.wav", output: "alarm_cancao_ninar.wav", start: 0, targetRmsDb: SOFT },
];
// Descartados na análise: passaros_jardim e riacho_perto — quase só silêncio (RMS perto
// de -51/-54 dB); ficar audível exigiria ~35 dB de ganho, subindo o chiado junto. E
// pintarroxo ("Robin's song ZS V78-0033.wav"): apesar do nome, é uma MÚSICA gravada em
// cilindro de fonógrafo (Biblioteca Nacional da Suécia), não canto de pássaro.

function readWav(file) {
  const buf = fs.readFileSync(file);
  if (buf.toString('ascii', 0, 4) !== 'RIFF' || buf.toString('ascii', 8, 12) !== 'WAVE') {
    throw new Error(`${file}: não é WAV`);
  }
  let offset = 12;
  let format = null;
  let data = null;
  while (offset + 8 <= buf.length) {
    const id = buf.toString('ascii', offset, offset + 4);
    const size = buf.readUInt32LE(offset + 4);
    const body = offset + 8;
    if (id === 'fmt ') {
      let audioFormat = buf.readUInt16LE(body);
      const channels = buf.readUInt16LE(body + 2);
      const sampleRate = buf.readUInt32LE(body + 4);
      const bits = buf.readUInt16LE(body + 14);
      if (audioFormat === 0xfffe) audioFormat = buf.readUInt16LE(body + 24); // WAVE_FORMAT_EXTENSIBLE
      format = { audioFormat, channels, sampleRate, bits };
    } else if (id === 'data') {
      data = buf.subarray(body, Math.min(body + size, buf.length));
    }
    offset = body + size + (size % 2);
  }
  if (!format || !data) throw new Error(`${file}: WAV sem fmt/data`);

  const { audioFormat, channels, sampleRate, bits } = format;
  const bytes = bits / 8;
  const frames = Math.floor(data.length / (bytes * channels));
  const mono = new Float32Array(frames);
  for (let i = 0; i < frames; i++) {
    let sum = 0;
    for (let c = 0; c < channels; c++) {
      const p = (i * channels + c) * bytes;
      let v;
      if (audioFormat === 3 && bits === 32) v = data.readFloatLE(p);
      else if (bits === 16) v = data.readInt16LE(p) / 32768;
      else if (bits === 24) v = data.readIntLE(p, 3) / 8388608;
      else if (bits === 32) v = data.readInt32LE(p) / 2147483648;
      else throw new Error(`${file}: formato não suportado (${audioFormat}/${bits} bits)`);
      sum += v;
    }
    mono[i] = sum / channels;
  }
  return { samples: mono, rate: sampleRate };
}

/// Reamostragem com passa-baixa simples antes (evita aliasing ao reduzir 48k → 44,1k).
function resample(samples, fromRate) {
  if (fromRate === TARGET_RATE) return samples;
  let src = samples;
  if (fromRate > TARGET_RATE) {
    const cutoff = TARGET_RATE * 0.45;
    const rc = 1 / (2 * Math.PI * cutoff);
    const alpha = (1 / fromRate) / (rc + 1 / fromRate);
    src = new Float32Array(samples.length);
    let y = 0;
    for (let pass = 0; pass < 2; pass++) {
      const input = pass === 0 ? samples : src;
      const out = new Float32Array(samples.length);
      y = input[0];
      for (let i = 0; i < input.length; i++) { y += alpha * (input[i] - y); out[i] = y; }
      src = out;
    }
  }
  const ratio = fromRate / TARGET_RATE;
  const length = Math.floor(src.length / ratio);
  const out = new Float32Array(length);
  for (let i = 0; i < length; i++) {
    const pos = i * ratio;
    const i0 = Math.floor(pos);
    const frac = pos - i0;
    const a = src[i0];
    const b = i0 + 1 < src.length ? src[i0 + 1] : a;
    out[i] = a + (b - a) * frac;
  }
  return out;
}

function removeDC(samples) {
  let mean = 0;
  for (const v of samples) mean += v;
  mean /= samples.length || 1;
  const out = new Float32Array(samples.length);
  for (let i = 0; i < samples.length; i++) out[i] = samples[i] - mean;
  return out;
}

const db = (v) => (v > 0 ? 20 * Math.log10(v) : -120);

/// RMS e pico por janelas de `step` segundos.
function envelope(samples, step = 1) {
  const n = Math.floor(TARGET_RATE * step);
  const rms = [];
  const peak = [];
  for (let i = 0; i + n <= samples.length; i += n) {
    let s = 0;
    let p = 0;
    for (let j = i; j < i + n; j++) { s += samples[j] * samples[j]; p = Math.max(p, Math.abs(samples[j])); }
    rms.push(Math.sqrt(s / n));
    peak.push(p);
  }
  return { rms, peak };
}

/// Trecho de CLIP_SECONDS com energia alta e estável: maximiza a média do RMS (em dB)
/// penalizando a variação e os picos isolados (trovão, batida, microfone).
function pickWindow(env) {
  const w = CLIP_SECONDS;
  if (env.rms.length <= w) return 0;
  let best = 0;
  let bestScore = -Infinity;
  for (let s = 0; s + w <= env.rms.length; s++) {
    const r = env.rms.slice(s, s + w).map(db);
    const mean = r.reduce((a, b) => a + b, 0) / w;
    const sd = Math.sqrt(r.reduce((a, b) => a + (b - mean) ** 2, 0) / w);
    const crest = Math.max(...env.peak.slice(s, s + w).map(db)) - mean;
    const score = mean - 1.5 * sd - 0.5 * Math.max(0, crest - 18);
    if (score > bestScore) { bestScore = score; best = s; }
  }
  return best;
}

function load(file) {
  const { samples, rate } = readWav(file);
  return removeDC(resample(samples, rate));
}

function analyze(dir) {
  for (const name of fs.readdirSync(dir).filter((f) => f.endsWith('.wav')).sort()) {
    const s = load(path.join(dir, name));
    const env = envelope(s, 1);
    const dur = s.length / TARGET_RATE;
    const start = pickWindow(env);
    const bar = env.rms.map((v) => ' .:-=+*#%@'[Math.max(0, Math.min(9, Math.round((db(v) + 60) / 6)))]).join('');
    console.log(`${name.padEnd(24)} ${dur.toFixed(0).padStart(4)}s  pico ${db(Math.max(...env.peak)).toFixed(1)}dB  rms ${db(Math.sqrt(env.rms.reduce((a, v) => a + v * v, 0) / env.rms.length)).toFixed(1)}dB  trecho→${start}s`);
    console.log(`   ${bar.slice(0, 200)}`);
  }
}

/// Normalização por volume percebido (RMS alvo) com teto suave: alarmes calmos, mas
/// audíveis — gravação de pássaro tem picos altos e RMS baixo, normalizar só pelo pico
/// deixaria o som baixo demais pra acordar alguém.
function normalize(samples, targetRmsDb = -17, ceiling = 0.89) {
  let s = 0;
  for (const v of samples) s += v * v;
  const rms = Math.sqrt(s / samples.length);
  const gain = Math.min(10 ** (targetRmsDb / 20) / (rms || 1e-9), 40);
  const out = new Float32Array(samples.length);
  const knee = ceiling * 0.8;
  for (let i = 0; i < samples.length; i++) {
    let v = samples[i] * gain;
    const a = Math.abs(v);
    if (a > knee) {
      // compressão suave acima do joelho, nunca passando do teto
      const over = (a - knee) / (ceiling - knee);
      v = Math.sign(v) * (knee + (ceiling - knee) * Math.tanh(over));
    }
    out[i] = v;
  }
  return out;
}

function fade(samples) {
  const out = Float32Array.from(samples);
  const fi = Math.floor(FADE_IN * TARGET_RATE);
  const fo = Math.floor(FADE_OUT * TARGET_RATE);
  for (let i = 0; i < fi && i < out.length; i++) out[i] *= Math.sin((i / fi) * Math.PI / 2) ** 2;
  for (let i = 0; i < fo && i < out.length; i++) out[out.length - 1 - i] *= Math.sin((i / fo) * Math.PI / 2) ** 2;
  return out;
}

/// Gravação mais curta que o trecho (ex.: tigela tibetana, 13s): repete com crossfade
/// até completar, em vez de deixar silêncio no fim.
function loopToLength(samples, length) {
  if (samples.length >= length) return samples.subarray(0, length);
  const xf = Math.min(Math.floor(1.0 * TARGET_RATE), Math.floor(samples.length / 3));
  const out = new Float32Array(length);
  let pos = 0;
  while (pos < length) {
    for (let i = 0; i < samples.length && pos + i < length; i++) {
      const inFade = pos > 0 && i < xf ? i / xf : 1;
      out[pos + i] = out[pos + i] * (1 - inFade) + samples[i] * inFade;
    }
    pos += samples.length - xf;
  }
  return out;
}

function writeWav(file, samples) {
  const data = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i++) {
    data.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767))), i * 2);
  }
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8, 'ascii');
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(TARGET_RATE, 24);
  header.writeUInt32LE(TARGET_RATE * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(data.length, 40);
  fs.writeFileSync(file, Buffer.concat([header, data]));
}

function build(dir, outDir) {
  fs.mkdirSync(outDir, { recursive: true });
  const length = CLIP_SECONDS * TARGET_RATE;
  for (const sound of SOUNDS) {
    const s = load(path.join(dir, sound.source));
    const start = sound.start ?? pickWindow(envelope(s, 1));
    const clip = loopToLength(s.subarray(Math.floor(start * TARGET_RATE)), length);
    const final = fade(normalize(clip, sound.targetRmsDb));
    writeWav(path.join(outDir, sound.output), final);
    const env = envelope(final, 1);
    console.log(`${sound.output.padEnd(30)} trecho ${start}s  pico ${db(Math.max(...env.peak)).toFixed(1)}dB  rms ${db(Math.sqrt(env.rms.reduce((a, v) => a + v * v, 0) / env.rms.length)).toFixed(1)}dB`);
  }
}

const [mode, dir, outDir] = process.argv.slice(2);
if (mode === 'analyze' && dir) analyze(dir);
else if (mode === 'build' && dir && outDir) build(dir, outDir);
else {
  console.error('uso: analyze <dir> | build <dir> <saida>');
  process.exit(1);
}
