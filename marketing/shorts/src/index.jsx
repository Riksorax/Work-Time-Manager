// Einstieg der Videokomposition (Remotion). Maße, Bildrate und Länge kommen aus den
// Eingabedaten, die `render.mjs` aus Videobeschreibung und Ton berechnet.
import React from 'react';
import { Composition, registerRoot } from 'remotion';
import { Platzhalter } from './Platzhalter.jsx';
import { Video } from './Video.jsx';

const ausEingabe = ({ props }) => ({
  width: props.breite,
  height: props.hoehe,
  fps: props.plan.fps,
  durationInFrames: props.plan.frames,
});

const leer = { breite: 1080, hoehe: 1920, plan: { fps: 30, frames: 1, szenen: [] }, marke: null, texte: {}, bilder: {} };

registerRoot(() => (
  <>
    <Composition id="video" component={Video} defaultProps={leer} calculateMetadata={ausEingabe} width={1080} height={1920} fps={30} durationInFrames={1} />
    <Composition id="platzhalter" component={Platzhalter} defaultProps={leer} width={1080} height={1920} fps={30} durationInFrames={1} />
  </>
));
