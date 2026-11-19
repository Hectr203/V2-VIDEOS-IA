import { registerRoot, Composition } from 'remotion';
import { FinanzasMexico2D } from './Film';

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="finanzas-mexico-ahorro-2d"
        component={FinanzasMexico2D}
        durationInFrames={750}
        fps={30}
        width={1080}
        height={1920}
      />
    </>
  );
};

registerRoot(RemotionRoot);
