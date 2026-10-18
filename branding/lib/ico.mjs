// ICO-Container mit eingebetteten PNGs (ab Windows Vista, von allen Browsern gelesen).

/**
 * @param {{size:number,data:Buffer}[]} images quadratische PNGs (size <= 255)
 */
export function packIco(images) {
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0); // reserviert
  header.writeUInt16LE(1, 2); // Typ 1 = Icon
  header.writeUInt16LE(images.length, 4);
  const dir = Buffer.alloc(16 * images.length);
  let offset = header.length + dir.length;
  images.forEach((img, i) => {
    if (img.size > 255) throw new Error('ICO-Eintrag größer als 255 px');
    const o = i * 16;
    dir[o] = img.size; // Breite
    dir[o + 1] = img.size; // Höhe
    dir[o + 2] = 0; // Farbpalette
    dir[o + 3] = 0;
    dir.writeUInt16LE(1, o + 4); // Planes
    dir.writeUInt16LE(32, o + 6); // Bit pro Pixel
    dir.writeUInt32LE(img.data.length, o + 8);
    dir.writeUInt32LE(offset, o + 12);
    offset += img.data.length;
  });
  return Buffer.concat([header, dir, ...images.map((i) => i.data)]);
}

/** @returns {{width:number,height:number,data:Buffer}[]} */
export function parseIco(buf) {
  if (buf.length < 6 || buf.readUInt16LE(0) !== 0 || buf.readUInt16LE(2) !== 1) {
    throw new Error('Keine ICO-Datei');
  }
  const count = buf.readUInt16LE(4);
  const entries = [];
  for (let i = 0; i < count; i++) {
    const o = 6 + i * 16;
    const size = buf.readUInt32LE(o + 8);
    const offset = buf.readUInt32LE(o + 12);
    entries.push({
      width: buf[o] || 256,
      height: buf[o + 1] || 256,
      data: buf.subarray(offset, offset + size),
    });
  }
  return entries;
}
