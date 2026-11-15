// Ein Video: Szenen nacheinander auf Markengrund, Untertitel darüber.
import React from 'react';
import { AbsoluteFill, Sequence } from 'remotion';
import { Aufhaenger, AppSzene, Schlusskarte, Teaser, Untertitel } from './bausteine.jsx';
import { Schrift } from './schrift.jsx';

const BAUSTEIN = { aufhaenger: Aufhaenger, app: AppSzene, teaser: Teaser, schluss: Schlusskarte };

export const Video = ({ plan, marke, texte, ausschnitte, bilder }) => {
  if (!marke) return null;
  const grund = `linear-gradient(160deg, ${marke.grund[0]} 0%, ${marke.grund[1]} 100%)`;
  return (
    <Schrift familie={marke.schrift}>
      <AbsoluteFill style={{ background: grund, color: '#fff', fontFamily: `'${marke.schrift}', sans-serif` }}>
        {plan.szenen.map((szene, i) => {
          const Baustein = BAUSTEIN[szene.art];
          return (
            <Sequence key={i} from={szene.von} durationInFrames={szene.frames}>
              <Baustein szene={szene} erste={i === 0} marke={marke} texte={texte} ausschnitte={ausschnitte} bilder={bilder} />
            </Sequence>
          );
        })}
        {plan.szenen.flatMap((szene) =>
          szene.saetze.flatMap((satz) =>
            satz.untertitel.map((teil) => (
              <Sequence key={`${satz.nr}-${teil.von}`} from={teil.von} durationInFrames={teil.frames}>
                <Untertitel zeilen={teil.zeilen} />
              </Sequence>
            )),
          ),
        )}
      </AbsoluteFill>
    </Schrift>
  );
};
