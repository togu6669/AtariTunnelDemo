import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.resolve(__dirname, "..");
const outPath = path.join(root, "music.rmt");
const backupPath = path.join(root, "music.before-psytechno.rmt");

if (fs.existsSync(outPath) && !fs.existsSync(backupPath)) {
  fs.copyFileSync(outPath, backupPath);
}

const BASE = 0x4000;
const HEADER_SIZE = 16;
const INSTRPAR = 12;

function word(value) {
  return [value & 0xff, (value >> 8) & 0xff];
}

function noteEvent(note, instrument, volume = 15) {
  return [
    (note & 0x3f) | ((volume & 0x03) << 6),
    ((instrument & 0x3f) << 2) | ((volume >> 2) & 0x03),
  ];
}

function rest(length = 1) {
  return [0x3e, length & 0xff];
}

function instrument(rows) {
  const lastRowOffset = INSTRPAR + 1 + (rows.length - 1) * 3;
  const bytes = [
    INSTRPAR,
    INSTRPAR,
    lastRowOffset,
    lastRowOffset,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
  ];

  for (const [volume, distortionAndCommand, commandValue] of rows) {
    bytes.push(volume & 0xff, distortionAndCommand & 0xff, commandValue & 0xff);
  }

  return bytes;
}

const instruments = [
  // Kick: short command-1 frequency sweep with pure/bass distortion.
  instrument([
    [0x0f, 0x1a, 0x78],
    [0x0d, 0x1a, 0x98],
    [0x08, 0x1a, 0xb8],
    [0x04, 0x1a, 0xd8],
    [0x00, 0x0a, 0x00],
  ]),

  // Offbeat psy bass: clipped, short, mostly dry.
  instrument([
    [0x0f, 0x0a, 0x00],
    [0x0b, 0x0a, 0x00],
    [0x06, 0x0a, 0x00],
    [0x00, 0x0a, 0x00],
  ]),

  // Closed hat: very short noise tick.
  instrument([
    [0x0a, 0x08, 0x00],
    [0x04, 0x08, 0x00],
    [0x00, 0x08, 0x00],
  ]),

  // Open hat: longer noise tail.
  instrument([
    [0x0c, 0x08, 0x00],
    [0x09, 0x08, 0x00],
    [0x06, 0x08, 0x00],
    [0x03, 0x08, 0x00],
    [0x01, 0x08, 0x00],
    [0x00, 0x08, 0x00],
  ]),

  // Snare/clap: two-color noise snap.
  instrument([
    [0x0f, 0x08, 0x00],
    [0x07, 0x08, 0x00],
    [0x0a, 0x04, 0x00],
    [0x04, 0x04, 0x00],
    [0x00, 0x04, 0x00],
  ]),

  // Metallic rhythm blip.
  instrument([
    [0x09, 0x02, 0x00],
    [0x07, 0x02, 0x00],
    [0x03, 0x04, 0x00],
    [0x00, 0x04, 0x00],
  ]),
];

const rows = 64;
const kickRows = new Set();
const bassRows = new Set();
const hatRows = new Set();
const openHatRows = new Set();
const snareRows = new Set();
const blipRows = new Set();

for (let i = 0; i < rows; i += 4) kickRows.add(i);
for (const i of [14, 30, 46, 55, 62]) kickRows.add(i);
for (let i = 2; i < rows; i += 4) bassRows.add(i);
for (let i = 1; i < rows; i += 2) hatRows.add(i);
for (const i of [7, 15, 31, 47, 63]) openHatRows.add(i);
for (const i of [12, 28, 44, 60]) snareRows.add(i);
for (const i of [3, 10, 19, 27, 35, 42, 51, 59]) blipRows.add(i);

const bassNotes = [12, 12, 15, 12, 10, 12, 17, 12, 12, 15, 19, 15, 10, 12, 15, 10];
const blipNotes = [36, 43, 48, 55, 41, 48, 53, 60];

function makeTrack(selector) {
  const data = [];
  for (let row = 0; row < rows; row++) {
    data.push(...selector(row));
  }
  return data;
}

const tracks = [
  makeTrack((row) => kickRows.has(row) ? noteEvent(9, 0, 15) : rest(1)),
  makeTrack((row) => bassRows.has(row) ? noteEvent(bassNotes[(row >> 2) & 0x0f], 1, 13) : rest(1)),
  makeTrack((row) => {
    if (openHatRows.has(row)) return noteEvent(48, 3, 10);
    if (hatRows.has(row)) return noteEvent(52, 2, 8);
    return rest(1);
  }),
  makeTrack((row) => {
    if (snareRows.has(row)) return noteEvent(34, 4, 12);
    if (blipRows.has(row)) return noteEvent(blipNotes[row & 0x07], 5, 9);
    return rest(1);
  }),
];

let cursor = BASE + HEADER_SIZE;
const pinst = cursor;
cursor += instruments.length * 2;

const pltrc = cursor;
cursor += tracks.length;

const phtrc = cursor;
cursor += tracks.length;

const instrumentAddresses = [];
for (const inst of instruments) {
  instrumentAddresses.push(cursor);
  cursor += inst.length;
}

const trackAddresses = [];
for (const track of tracks) {
  trackAddresses.push(cursor);
  cursor += track.length;
}

const ptlst = cursor;
const trackList = [0x00, 0x01, 0x02, 0x03, 0xfe, 0x00, ptlst & 0xff, ptlst >> 8];
cursor += trackList.length;

const moduleLength = cursor - BASE;
const module = [];

module.push(0x52, 0x4d, 0x54, 0x34); // RMT4
module.push(rows, 0x05, 0x01, 0x01);
module.push(...word(pinst), ...word(pltrc), ...word(phtrc), ...word(ptlst));

for (const address of instrumentAddresses) module.push(...word(address));
for (const address of trackAddresses) module.push(address & 0xff);
for (const address of trackAddresses) module.push(address >> 8);
for (const inst of instruments) module.push(...inst);
for (const track of tracks) module.push(...track);
module.push(...trackList);

if (module.length !== moduleLength) {
  throw new Error(`Internal length mismatch: ${module.length} !== ${moduleLength}`);
}

const file = [];
file.push(0xff, 0xff, ...word(BASE), ...word(BASE + module.length - 1), ...module);
fs.writeFileSync(outPath, Buffer.from(file));

console.log(`Generated ${path.basename(outPath)} (${file.length} bytes)`);
console.log(`Module range $${BASE.toString(16)}-$${(BASE + module.length - 1).toString(16)}`);
console.log(`Backup: ${path.basename(backupPath)}`);
