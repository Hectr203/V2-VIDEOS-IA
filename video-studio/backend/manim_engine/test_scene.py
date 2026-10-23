from manim import *

class TestLaptopScene(Scene):
    def construct(self):
        svg = SVGMobject("assets/stickers/tecnologia/laptop.svg")
        svg.scale(3.0)
        svg.move_to(ORIGIN)
        self.play(DrawBorderThenFill(svg, run_time=1.2))
        self.play(svg.animate.scale(1.1), run_time=0.2)
        self.play(svg.animate.scale(1/1.1), run_time=0.2)
        self.wait(0.5)
