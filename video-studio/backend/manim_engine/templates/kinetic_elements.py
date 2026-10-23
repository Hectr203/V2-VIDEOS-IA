from manim import *

class CurvedArrowScene(Scene):
    def construct(self):
        arrow = CurvedArrow(
            start_point=2.5 * LEFT + 1.5 * DOWN,
            end_point=1.5 * RIGHT + 2.0 * UP,
            angle=-TAU / 4,
            color=YELLOW,
            stroke_width=10,
            tip_length=0.45
        )
        self.play(Create(arrow, run_time=0.9, rate_func=smooth))
        self.play(arrow.animate.scale(1.1), run_time=0.15)
        self.play(arrow.animate.scale(1/1.1), run_time=0.15)
        self.wait(0.8)

class HighlightCircleScene(Scene):
    def construct(self):
        circle = Ellipse(width=5.5, height=3.5, color=RED, stroke_width=9)
        circle.rotate(-0.08)
        self.play(Create(circle, run_time=0.8, rate_func=rush_into))
        self.play(Wiggle(circle, rotation_angle=0.04, run_time=0.4))
        self.wait(0.8)

class CheckMarkScene(Scene):
    def construct(self):
        circle = Circle(radius=2.2, color=GREEN, fill_opacity=0.25, stroke_width=8)
        # Check mark lines
        p1 = 0.8 * LEFT + 0.1 * DOWN
        p2 = 0.2 * LEFT + 0.7 * DOWN
        p3 = 1.0 * RIGHT + 0.8 * UP
        check = VMobject(color=GREEN, stroke_width=12)
        check.set_points_as_corners([p1, p2, p3])
        
        group = VGroup(circle, check)
        self.play(DrawBorderThenFill(circle, run_time=0.5))
        self.play(Create(check, run_time=0.4, rate_func=rush_into))
        self.play(group.animate.scale(1.12), run_time=0.15)
        self.play(group.animate.scale(1/1.12), run_time=0.15)
        self.wait(0.8)

class CrossMarkScene(Scene):
    def construct(self):
        circle = Circle(radius=2.2, color=RED, fill_opacity=0.25, stroke_width=8)
        l1 = Line(1.0 * UP + 1.0 * LEFT, 1.0 * DOWN + 1.0 * RIGHT, color=RED, stroke_width=12)
        l2 = Line(1.0 * UP + 1.0 * RIGHT, 1.0 * DOWN + 1.0 * LEFT, color=RED, stroke_width=12)
        cross = VGroup(l1, l2)
        group = VGroup(circle, cross)
        
        self.play(DrawBorderThenFill(circle, run_time=0.5))
        self.play(Create(cross, run_time=0.4, rate_func=rush_into))
        self.play(Wiggle(group, run_time=0.4))
        self.wait(0.8)

class VSBadgeScene(Scene):
    def construct(self):
        hexagon = RegularPolygon(n=6, radius=2.5, color=PURPLE, stroke_width=9)
        hexagon.rotate(PI / 6)
        text = Text("VS", font_size=96, weight=BOLD, color=YELLOW)
        group = VGroup(hexagon, text)
        
        self.play(SpinInFromNothing(group, run_time=0.8))
        self.play(Wiggle(group, rotation_angle=0.08, run_time=0.4))
        self.wait(0.8)

class ProgressBarScene(Scene):
    def construct(self):
        bg_bar = RoundedRectangle(corner_radius=0.3, width=7.0, height=0.8, color=GRAY, fill_opacity=0.4, stroke_width=4)
        fill_bar = RoundedRectangle(corner_radius=0.3, width=6.8, height=0.6, color=GREEN, fill_color=GREEN, fill_opacity=1.0, stroke_width=0)
        fill_bar.align_to(bg_bar, LEFT).shift(0.1 * RIGHT)
        
        pct_text = DecimalNumber(0, unit="%", num_decimal_places=0, font_size=52, color=WHITE)
        pct_text.next_to(bg_bar, UP, buff=0.4)
        
        self.add(bg_bar)
        self.play(
            GrowFromEdge(fill_bar, LEFT, run_time=1.5, rate_func=smooth),
            ChangeDecimalToValue(pct_text, 100, run_time=1.5, rate_func=smooth)
        )
        self.play(pct_text.animate.set_color(YELLOW), run_time=0.2)
        self.wait(0.6)
