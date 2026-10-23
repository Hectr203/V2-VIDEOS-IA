import time, os, sys
from services import render_service

scene = {
    "id": 1,
    "title": "Benchmark",
    "narrative_text": "Prueba de velocidad",
    "audio_duration": 5.0,
    "svg_markup": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1920"><rect width="1080" height="1920" fill="#1e293b"/><circle cx="540" cy="960" r="200" fill="#38bdf8"/></svg>',
    "words": []
}

t0 = time.time()
res = render_service.render_project(
    {"output_format": "vertical"},
    [scene],
    "speed_check.mp4",
    fps=30
)
t1 = time.time()
print(f"Render time for 5s (150 frames): {t1 - t0:.2f}s")
if os.path.exists(res["video_path"]):
    os.remove(res["video_path"])
