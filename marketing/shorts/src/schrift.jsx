// Lädt die Schrift aus dem Repo (Dateien stellt render.mjs unter fonts/ bereit) und hält das
// Rendern an, bis sie da ist. Systemschriften kommen so nicht ins Bild.
import React, { useEffect, useState } from 'react';
import { continueRender, delayRender, staticFile } from 'remotion';

export const Schrift = ({ familie, children }) => {
  const [warten] = useState(() => delayRender('Schrift laden'));
  const [bereit, setBereit] = useState(false);
  useEffect(() => {
    const schnitte = [400, 700].map((gewicht) =>
      new FontFace(familie, `url(${staticFile(`fonts/${gewicht}.ttf`)})`, { weight: String(gewicht) }).load(),
    );
    Promise.all(schnitte).then((geladen) => {
      geladen.forEach((schnitt) => document.fonts.add(schnitt));
      setBereit(true);
      continueRender(warten);
    });
  }, [familie, warten]);
  return bereit ? children : null;
};
