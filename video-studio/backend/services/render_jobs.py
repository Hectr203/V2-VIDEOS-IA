"""SQLite-backed durable job registry for the single-machine renderer."""
import os
from typing import Any, Dict, Optional, Tuple

from services.database import SQLiteDatabase


class RenderJobStore:
    def __init__(self, directory: str, db: Optional[SQLiteDatabase] = None):
        os.makedirs(directory, exist_ok=True)
        # In production the project store and render jobs share one SQLite DB.
        # The isolated default is useful for tests and standalone callers.
        self.db = db or SQLiteDatabase(
            os.path.join(directory, "render_jobs.sqlite3"),
            legacy_projects_dir=os.path.join(directory, "legacy_projects"),
        )

    def create_or_get(self, project_id: str) -> Tuple[Dict[str, Any], bool]:
        return self.db.create_or_get_job(project_id)

    def get(self, job_id: str) -> Optional[Dict[str, Any]]:
        return self.db.get_job(job_id)

    def update(self, job_id: str, **changes: Any) -> Dict[str, Any]:
        job = self.db.update_job(job_id, changes)
        if not job:
            raise FileNotFoundError("Trabajo de render no encontrado")
        return job

    def request_cancel(self, job_id: str) -> Optional[Dict[str, Any]]:
        job = self.get(job_id)
        if not job:
            return None
        if job["status"] in {"queued", "failed", "interrupted"}:
            return self.update(job_id, status="cancelled", message="Cancelado")
        if job["status"] in {"preparing", "rendering"}:
            return self.update(job_id, cancel_requested=True, message="Cancelando render…")
        return job
