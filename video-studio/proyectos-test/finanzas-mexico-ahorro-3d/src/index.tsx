import { registerRoot, Composition } from 'remotion';
import { FinanzasMexico3D } from './Film';

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="finanzas-mexico-ahorro-3d"
        component={FinanzasMexico3D}
        durationInFrames={750}
        fps={30}
        width={1080}
        height={1920}
      />
    </>
  );
};

registerRoot(RemotionRoot);
