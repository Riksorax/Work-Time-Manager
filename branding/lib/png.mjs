// Minimaler PNG-Kodierer/-Dekodierer (8 Bit, RGB oder RGBA, nicht interlaced).
// Eigene Implementierung, damit die Ausgabe deterministisch ist, Alpha gezielt
// entfernt werden kann (Feature Graphic) und der Drift-Check Pixel vergleichen kann.
import zlib from 'node:zlib';

const SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

export function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const out = Buffer.alloc(12 + data.length);
  out.writeUInt32BE(data.length, 0);
  out.write(type, 4, 'ascii');
  data.copy(out, 8);
  out.writeUInt32BE(crc32(out.subarray(4, 8 + data.length)), 8 + data.length);
  return out;
}

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

function filterRow(type, row, prev, bpp) {
  const out = Buffer.alloc(row.length);
  for (let i = 0; i < row.length; i++) {
    const a = i >= bpp ? row[i - bpp] : 0;
    const b = prev ? prev[i] : 0;
    const c = prev && i >= bpp ? prev[i - bpp] : 0;
    let predicted = 0;
    if (type === 1) predicted = a;
    else if (type === 2) predicted = b;
    else if (type === 3) predicted = (a + b) >> 1;
    else if (type === 4) predicted = paeth(a, b, c);
    out[i] = (row[i] - predicted) & 0xff;
  }
  return out;
}

/**
 * @param {{width:number,height:number,pixels:Uint8Array|Buffer}} image RGBA-Pixel (4 Byte je Pixel)
 * @param {{colorType?:2|6}} options 6 = RGBA (Standard), 2 = RGB (Alpha wird verworfen)
 */
export function encodePng({ width, height, pixels }, { colorType = 6 } = {}) {
  const channels = colorType === 6 ? 4 : 3;
  const stride = width * channels;
  const raw = Buffer.alloc((stride + 1) * height);
  let prev = null;
  for (let y = 0; y < height; y++) {
    const row = Buffer.alloc(stride);
    for (let x = 0; x < width; x++) {
      const s = (y * width + x) * 4;
      const d = x * channels;
      row[d] = pixels[s];
      row[d + 1] = pixels[s + 1];
      row[d + 2] = pixels[s + 2];
      if (channels === 4) row[d + 3] = pixels[s + 3];
    }
    // Filter mit der kleinsten Betragssumme je Zeile (übliche Heuristik)
    let best = null;
    let bestType = 0;
    let bestScore = Infinity;
    for (let type = 0; type < 5; type++) {
      const f = type === 0 ? row : filterRow(type, row, prev, channels);
      let score = 0;
      for (let i = 0; i < f.length; i++) score += f[i] < 128 ? f[i] : 256 - f[i];
      if (score < bestScore) {
        bestScore = score;
        best = f;
        bestType = type;
      }
    }
    raw[y * (stride + 1)] = bestType;
    best.copy(raw, y * (stride + 1) + 1);
    prev = row;
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // Bittiefe
  ihdr[9] = colorType;
  return Buffer.concat([
    SIGNATURE,
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/** Liest Breite/Höhe/Farbtyp aus dem IHDR, ohne zu dekodieren. */
export function readPngHeader(buf) {
  if (buf.length < 33 || !buf.subarray(0, 8).equals(SIGNATURE)) throw new Error('Keine PNG-Datei');
  return {
    width: buf.readUInt32BE(16),
    height: buf.readUInt32BE(20),
    bitDepth: buf[24],
    colorType: buf[25],
    interlace: buf[28],
  };
}

/** Dekodiert 8-Bit-RGB/RGBA (nicht interlaced) zu RGBA-Pixeln. */
export function decodePng(buf) {
  const { width, height, bitDepth, colorType, interlace } = readPngHeader(buf);
  if (bitDepth !== 8 || interlace !== 0 || (colorType !== 2 && colorType !== 6)) {
    throw new Error(`Nicht unterstütztes PNG-Format (Tiefe ${bitDepth}, Typ ${colorType}, interlace ${interlace})`);
  }
  const idat = [];
  for (let pos = 8; pos < buf.length; ) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString('ascii', pos + 4, pos + 8);
    if (type === 'IDAT') idat.push(buf.subarray(pos + 8, pos + 8 + len));
    if (type === 'IEND') break;
    pos += 12 + len;
  }
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const channels = colorType === 6 ? 4 : 3;
  const stride = width * channels;
  const pixels = Buffer.alloc(width * height * 4, 255);
  let prev = Buffer.alloc(stride);
  for (let y = 0; y < height; y++) {
    const type = raw[y * (stride + 1)];
    const line = Buffer.from(raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)));
    for (let i = 0; i < stride; i++) {
      const a = i >= channels ? line[i - channels] : 0;
      const b = prev[i];
      const c = i >= channels ? prev[i - channels] : 0;
      let predicted = 0;
      if (type === 1) predicted = a;
      else if (type === 2) predicted = b;
      else if (type === 3) predicted = (a + b) >> 1;
      else if (type === 4) predicted = paeth(a, b, c);
      else if (type !== 0) throw new Error(`Unbekannter PNG-Filter ${type}`);
      line[i] = (line[i] + predicted) & 0xff;
    }
    for (let x = 0; x < width; x++) {
      const d = (y * width + x) * 4;
      const s = x * channels;
      pixels[d] = line[s];
      pixels[d + 1] = line[s + 1];
      pixels[d + 2] = line[s + 2];
      if (channels === 4) pixels[d + 3] = line[s + 3];
    }
    prev = line;
  }
  return { width, height, colorType, pixels };
}
