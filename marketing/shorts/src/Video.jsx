// Ein Video: Szenen nacheinander auf Markengrund, harte Schnitte.
import React from 'react';
import { AbsoluteFill, Sequence } from 'remotion';
import { Aufhaenger, AppSzene, Schlusskarte, Teaser } from './bausteine.jsx';
import { Schrift } from './schrift.jsx';

const BAUSTEIN = { aufhaenger: Aufhaenger, app: AppSzene, teaser: Teaser, schluss: Schlusskarte };

export const Video = ({ plan, marke, texte, bilder }) => {
  if (!marke) return null;
  const grund = `linear-gradient(160deg, ${marke.grund[0]} 0%, ${marke.grund[1]} 100%)`;
  return (
    <Schrift familie={marke.schrift}>
      <AbsoluteFill style={{ background: grund, color: '#fff', fontFamily: `'${marke.schrift}', sans-serif` }}>
        {plan.szenen.map((szene, i) => {
          const Baustein = BAUSTEIN[szene.art];
          return (
            <Sequence key={i} from={szene.von} durationInFrames={szene.frames}>
              <Baustein szene={szene} vorher={plan.szenen[i - 1]} erste={i === 0} marke={marke} texte={texte} bilder={bilder} />
            </Sequence>
          );
        })}
      </AbsoluteFill>
    </Schrift>
  );
};
