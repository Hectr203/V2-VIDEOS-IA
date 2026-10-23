import sys
import os
from manim import *

class GenericSVGDrawScene(Scene):
    """
    Escena genérica para animar cualquier SVG con efecto de trazado a mano y pulso de impacto.
    Recibe la ruta del SVG mediante variable de entorno MANIM_SVG_PATH.
    """
    def construct(self):
        svg_path = os.environ.get("MANIM_SVG_PATH", "assets/stickers/tecnologia/laptop.svg")
        scale = float(os.environ.get("MANIM_SCALE", "3.2"))
        run_time = float(os.environ.get("MANIM_RUN_TIME", "1.2"))

        # Cargar SVG
        svg = SVGMobject(svg_path)
        svg.scale(scale)
        svg.move_to(ORIGIN)

        # 1. Efecto de dibujado / trazado de bordes
        self.play(DrawBorderThenFill(svg, run_time=run_time, stroke_color=WHITE))
        
        # 2. Pulso elástico al terminar
        self.play(svg.animate.scale(1.08), run_time=0.2, rate_func=rush_into)
        self.play(svg.animate.scale(1 / 1.08), run_time=0.2, rate_func=rush_from)
        
        # 3. Pequeña pausa final para retención visual
        self.wait(0.6)
