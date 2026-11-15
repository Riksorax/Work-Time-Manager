// Platzhalterbild für das Probevideo (`npm run platzhalter`). Bewusst kein Nachbau der App:
// graue Flächen mit Beschriftung, damit Zoom, Ausschnitt und Tipp-Markierung prüfbar sind.
import React from 'react';
import { AbsoluteFill } from 'remotion';
import { Schrift } from './schrift.jsx';

const Feld = ({ oben, hoehe, farbe = '#dfe3e8', children }) => (
  <div
    style={{ position: 'absolute', left: 108, width: 864, top: oben, height: hoehe, borderRadius: 36, background: farbe, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 52, fontWeight: 700, color: '#37474f' }}
  >
    {children}
  </div>
);

export const Platzhalter = ({ marke }) => {
  if (!marke) return null;
  return (
    <Schrift familie={marke.schrift}>
      <AbsoluteFill style={{ background: '#f4f6f8', fontFamily: `'${marke.schrift}', sans-serif` }}>
        <div style={{ height: 190, background: '#90a4ae', color: '#fff', fontSize: 56, fontWeight: 700, display: 'flex', alignItems: 'flex-end', padding: '0 0 44px 108px' }}>
          Platzhalter · kein App-Bild
        </div>
        <Feld oben={270} hoehe={420}>Fläche A</Feld>
        <Feld oben={750} hoehe={300} farbe="#cfd8dc">Ausschnitt „mitte“</Feld>
        <Feld oben={1110} hoehe={150} farbe="#78909c"><span style={{ color: '#fff' }}>Ausschnitt „knopf“</span></Feld>
        <Feld oben={1320} hoehe={380}>Fläche B</Feld>
        <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 160, background: '#cfd8dc' }} />
      </AbsoluteFill>
    </Schrift>
  );
};
