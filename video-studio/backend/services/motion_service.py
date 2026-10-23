import os
from pathlib import Path
from typing import Dict, Any, List

BASE_DIR = Path(__file__).resolve().parent.parent.parent
ASSETS_DIR = BASE_DIR / "assets"
STICKERS_DIR = ASSETS_DIR / "stickers"
MOTION_DIR = ASSETS_DIR / "motion"

class MotionService:
    @staticmethod
    def get_library() -> Dict[str, Any]:
        """
        Escanea y agrupa los recursos SVG y animaciones Manim por categorías temáticas.
        """
        categories = {}
        
        # Categorías predefinidas
        known_dirs = [
            "tecnologia", "belleza", "comida", "animales",
            "finanzas", "salud_fitness", "educacion", "cineticos"
        ]
        
        for cat in known_dirs:
            cat_path = STICKERS_DIR / cat
            if not cat_path.exists():
                continue
                
            items = []
            for file in sorted(os.listdir(cat_path)):
                if not file.endswith(".svg"):
                    continue
                stem = Path(file).stem
                has_motion = (MOTION_DIR / cat / f"{stem}.webm").exists() or (MOTION_DIR / cat / f"{stem}.mov").exists()
                
                items.append({
                    "id": f"{cat}/{stem}",
                    "name": stem.replace("_", " ").title(),
                    "category": cat,
                    "svg_url": f"/assets/stickers/{cat}/{file}",
                    "motion_url": f"/assets/motion/{cat}/{stem}.webm" if has_motion else None,
                    "has_motion": has_motion
                })
            categories[cat] = items
            
        # Stickers sueltos en la raíz de stickers
        root_items = []
        for file in sorted(os.listdir(STICKERS_DIR)):
            fpath = STICKERS_DIR / file
            if fpath.is_file() and file.endswith(".svg"):
                stem = Path(file).stem
                has_motion = (MOTION_DIR / f"{stem}.webm").exists()
                root_items.append({
                    "id": stem,
                    "name": stem.replace("_", " ").title(),
                    "category": "general",
                    "svg_url": f"/assets/stickers/{file}",
                    "motion_url": f"/assets/motion/{stem}.webm" if has_motion else None,
                    "has_motion": has_motion
                })
        if root_items:
            categories["general"] = root_items

        return {
            "categories": categories,
            "total_categories": len(categories),
            "summary": {cat: len(items) for cat, items in categories.items()}
        }
