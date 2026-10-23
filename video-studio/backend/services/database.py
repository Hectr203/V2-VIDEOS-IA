"""SQLite persistence for projects, scenes, and local render jobs."""
import json
import os
import re
import sqlite3
import time
from typing import Any, Dict, List, Optional


PROJECTS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../projects"))
DEFAULT_DB_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../video_studio.sqlite3"))


class SQLiteDatabase:
    def __init__(self, path: str = DEFAULT_DB_PATH, legacy_projects_dir: str = PROJECTS_DIR):
        self.path = os.path.abspath(path)
        self.legacy_projects_dir = os.path.abspath(legacy_projects_dir)
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        os.makedirs(self.legacy_projects_dir, exist_ok=True)
        self._initialize()
        for protected_path in (self.path, f"{self.path}-wal", f"{self.path}-shm"):
            try:
                os.chmod(protected_path, 0o600)
            except OSError:
                pass

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.path, timeout=30, isolation_level="IMMEDIATE")
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys=ON")
        conn.execute("PRAGMA busy_timeout=30000")
        return conn

    def _initialize(self) -> None:
        with self._connect() as conn:
            conn.execute("PRAGMA journal_mode=WAL")
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS schema_migrations (
                    name TEXT PRIMARY KEY,
                    applied_at REAL NOT NULL
                );
                CREATE TABLE IF NOT EXISTS projects (
                    id TEXT PRIMARY KEY,
                    metadata_json TEXT NOT NULL,
                    updated_at REAL NOT NULL
                );
                CREATE TABLE IF NOT EXISTS scenes (
                    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                    scene_id INTEGER NOT NULL,
                    position INTEGER NOT NULL,
                    scene_json TEXT NOT NULL,
                    PRIMARY KEY (project_id, scene_id)
                );
                CREATE INDEX IF NOT EXISTS scenes_project_order ON scenes(project_id, position);
                CREATE TABLE IF NOT EXISTS source_media (
                    id TEXT PRIMARY KEY,
                    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                    filename TEXT NOT NULL,
                    media_type TEXT NOT NULL,
                    size_bytes INTEGER NOT NULL,
                    duration_seconds REAL,
                    created_at REAL NOT NULL,
                    media_json TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS source_media_project_order ON source_media(project_id, created_at);
                CREATE TABLE IF NOT EXISTS render_jobs (
                    id TEXT PRIMARY KEY,
                    project_id TEXT NOT NULL,
                    status TEXT NOT NULL,
                    updated_at REAL NOT NULL,
                    job_json TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS render_jobs_project_status ON render_jobs(project_id, status);
            """)
        self._migrate_legacy_projects()
        self._migrate_legacy_jobs()
        self.recover_inflight_jobs()

    @staticmethod
    def _valid_project_id(project_id: str) -> bool:
        return bool(re.fullmatch(r"proj_[A-Za-z0-9_-]+", project_id))

    def _migrate_legacy_projects(self) -> None:
        migration = "legacy_json_projects_v1"
        with self._connect() as conn:
            if conn.execute("SELECT 1 FROM schema_migrations WHERE name=?", (migration,)).fetchone():
                return
            if os.path.isdir(self.legacy_projects_dir):
                for project_id in os.listdir(self.legacy_projects_dir):
                    if not self._valid_project_id(project_id):
                        continue
                    project_dir = os.path.join(self.legacy_projects_dir, project_id)
                    metadata_path = os.path.join(project_dir, "project.json")
                    scenes_path = os.path.join(project_dir, "scenes.json")
                    if not os.path.isfile(metadata_path):
                        continue
                    conn.execute("SAVEPOINT migrate_project")
                    try:
                        with open(metadata_path, encoding="utf-8") as stream:
                            metadata = json.load(stream)
                        with open(scenes_path, encoding="utf-8") as stream:
                            scenes = json.load(stream)
                        if not isinstance(metadata, dict) or not isinstance(scenes, list):
                            conn.execute("ROLLBACK TO migrate_project")
                            conn.execute("RELEASE migrate_project")
                            continue
                        self._upsert_project(conn, project_id, metadata, scenes)
                        conn.execute("RELEASE migrate_project")
                    except (OSError, ValueError, TypeError, sqlite3.Error) as error:
                        conn.execute("ROLLBACK TO migrate_project")
                        conn.execute("RELEASE migrate_project")
                        # Keep the original files in place; malformed legacy data
                        # is not deleted or overwritten during migration.
                        print(f"[SQLite] Proyecto legado {project_id} no migrado: {error}")
            conn.execute("INSERT INTO schema_migrations(name, applied_at) VALUES (?, ?)", (migration, time.time()))

    def _migrate_legacy_jobs(self) -> None:
        migration = "legacy_json_render_jobs_v1"
        legacy_dir = os.path.join(self.legacy_projects_dir, "render_jobs")
        with self._connect() as conn:
            if conn.execute("SELECT 1 FROM schema_migrations WHERE name=?", (migration,)).fetchone():
                return
            if os.path.isdir(legacy_dir):
                for filename in os.listdir(legacy_dir):
                    if not filename.endswith(".json"):
                        continue
                    conn.execute("SAVEPOINT migrate_job")
                    try:
                        with open(os.path.join(legacy_dir, filename), encoding="utf-8") as stream:
                            job = json.load(stream)
                        if not isinstance(job, dict) or not str(job.get("id", "")).startswith("render_"):
                            conn.execute("ROLLBACK TO migrate_job")
                            conn.execute("RELEASE migrate_job")
                            continue
                        if job.get("status") in {"preparing", "rendering"}:
                            job.update(status="interrupted", message="Migrado; el render debe relanzarse", updated_at=time.time())
                        self._upsert_job(conn, job)
                        conn.execute("RELEASE migrate_job")
                    except (OSError, ValueError, TypeError, sqlite3.Error) as error:
                        conn.execute("ROLLBACK TO migrate_job")
                        conn.execute("RELEASE migrate_job")
                        print(f"[SQLite] Trabajo legado {filename} no migrado: {error}")
            conn.execute("INSERT INTO schema_migrations(name, applied_at) VALUES (?, ?)", (migration, time.time()))

    @staticmethod
    def _upsert_project(conn: sqlite3.Connection, project_id: str, metadata: Dict[str, Any], scenes: List[Dict[str, Any]]) -> None:
        now = time.time()
        conn.execute(
            "INSERT INTO projects(id, metadata_json, updated_at) VALUES (?, ?, ?) "
            "ON CONFLICT(id) DO UPDATE SET metadata_json=excluded.metadata_json, updated_at=excluded.updated_at",
            (project_id, json.dumps(metadata, ensure_ascii=False), now),
        )
        conn.execute("DELETE FROM scenes WHERE project_id=?", (project_id,))
        for position, scene in enumerate(scenes):
            scene_id = scene.get("id", position + 1)
            if not isinstance(scene_id, int) or isinstance(scene_id, bool):
                raise ValueError(f"ID de escena inválido: {scene_id!r}")
            conn.execute(
                "INSERT INTO scenes(project_id, scene_id, position, scene_json) VALUES (?, ?, ?, ?)",
                (project_id, scene_id, position, json.dumps(scene, ensure_ascii=False)),
            )

    def save_project(self, project_id: str, metadata: Dict[str, Any], scenes: List[Dict[str, Any]]) -> None:
        if not self._valid_project_id(project_id):
            raise ValueError("ID de proyecto inválido")
        with self._connect() as conn:
            self._upsert_project(conn, project_id, metadata, scenes)

    def get_project(self, project_id: str) -> Optional[Dict[str, Any]]:
        if not self._valid_project_id(project_id):
            raise ValueError("ID de proyecto inválido")
        with self._connect() as conn:
            project = conn.execute("SELECT metadata_json FROM projects WHERE id=?", (project_id,)).fetchone()
            if not project:
                return None
            scenes = conn.execute(
                "SELECT scene_json FROM scenes WHERE project_id=? ORDER BY position, scene_id", (project_id,)
            ).fetchall()
            return {"project": json.loads(project["metadata_json"]), "scenes": [json.loads(row["scene_json"]) for row in scenes]}

    def list_projects(self) -> List[Dict[str, Any]]:
        with self._connect() as conn:
            rows = conn.execute("SELECT metadata_json FROM projects ORDER BY updated_at DESC, id DESC").fetchall()
            return [json.loads(row["metadata_json"]) for row in rows]

    def save_source_media(self, media: Dict[str, Any]) -> None:
        with self._connect() as conn:
            conn.execute(
                "INSERT INTO source_media(id, project_id, filename, media_type, size_bytes, duration_seconds, created_at, media_json) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET "
                "filename=excluded.filename, media_type=excluded.media_type, size_bytes=excluded.size_bytes, "
                "duration_seconds=excluded.duration_seconds, media_json=excluded.media_json",
                (media["id"], media["project_id"], media["filename"], media["media_type"],
                 media["size_bytes"], media.get("duration_seconds"), media["created_at"],
                 json.dumps(media, ensure_ascii=False)),
            )

    def list_source_media(self, project_id: str) -> List[Dict[str, Any]]:
        with self._connect() as conn:
            rows = conn.execute(
                "SELECT media_json FROM source_media WHERE project_id=? ORDER BY created_at, id", (project_id,)
            ).fetchall()
            return [json.loads(row["media_json"]) for row in rows]

    def get_source_media(self, project_id: str, media_id: str) -> Optional[Dict[str, Any]]:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT media_json FROM source_media WHERE project_id=? AND id=?", (project_id, media_id)
            ).fetchone()
            return json.loads(row["media_json"]) if row else None

    def save_job(self, job: Dict[str, Any]) -> None:
        job_id = job.get("id", "")
        if not job_id.startswith("render_") or not all(c.isalnum() or c in "_-" for c in job_id):
            raise ValueError("ID de trabajo inválido")
        with self._connect() as conn:
            self._upsert_job(conn, job)

    @staticmethod
    def _upsert_job(conn: sqlite3.Connection, job: Dict[str, Any]) -> None:
        job_id = job["id"]
        updated_at = float(job.get("updated_at", time.time()))
        conn.execute(
            "INSERT INTO render_jobs(id, project_id, status, updated_at, job_json) VALUES (?, ?, ?, ?, ?) "
            "ON CONFLICT(id) DO UPDATE SET project_id=excluded.project_id, status=excluded.status, "
            "updated_at=excluded.updated_at, job_json=excluded.job_json",
            (job_id, job.get("project_id", ""), job.get("status", "queued"), updated_at,
             json.dumps(job, ensure_ascii=False)),
        )

    def get_job(self, job_id: str) -> Optional[Dict[str, Any]]:
        if not job_id.startswith("render_") or not all(c.isalnum() or c in "_-" for c in job_id):
            raise ValueError("ID de trabajo inválido")
        with self._connect() as conn:
            row = conn.execute("SELECT job_json FROM render_jobs WHERE id=?", (job_id,)).fetchone()
            return json.loads(row["job_json"]) if row else None

    def create_or_get_job(self, project_id: str) -> tuple[Dict[str, Any], bool]:
        if not self._valid_project_id(project_id):
            raise ValueError("ID de proyecto inválido")
        with self._connect() as conn:
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute(
                "SELECT job_json FROM render_jobs WHERE project_id=? AND status IN ('queued','preparing','rendering') "
                "ORDER BY updated_at DESC LIMIT 1", (project_id,),
            ).fetchone()
            if row:
                return json.loads(row["job_json"]), False
            retry = conn.execute(
                "SELECT job_json FROM render_jobs WHERE project_id=? AND status IN ('interrupted','failed','cancelled') "
                "ORDER BY updated_at DESC LIMIT 1", (project_id,),
            ).fetchone()
            if retry:
                job = json.loads(retry["job_json"])
                job.update(status="queued", progress=0, message="Reanudando desde checkpoints disponibles",
                           cancel_requested=False, resumed=True, updated_at=time.time())
                self._upsert_job(conn, job)
                return job, True
            now = time.time()
            job = {"id": f"render_{os.urandom(16).hex()}", "project_id": project_id,
                   "status": "queued", "progress": 0, "message": "En cola",
                   "cancel_requested": False, "resumed": False, "created_at": now, "updated_at": now}
            self._upsert_job(conn, job)
            return job, True

    def update_job(self, job_id: str, changes: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        with self._connect() as conn:
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute("SELECT job_json FROM render_jobs WHERE id=?", (job_id,)).fetchone()
            if not row:
                return None
            job = json.loads(row["job_json"])
            job.update(changes, updated_at=time.time())
            self._upsert_job(conn, job)
            return job

    def recover_inflight_jobs(self) -> None:
        with self._connect() as conn:
            rows = conn.execute(
                "SELECT job_json FROM render_jobs WHERE status IN ('queued','preparing','rendering')"
            ).fetchall()
            for row in rows:
                job = json.loads(row["job_json"])
                job.update(status="interrupted", message="API reiniciada; vuelve a lanzar el render", updated_at=time.time())
                self._upsert_job(conn, job)

    def list_jobs(self, project_id: Optional[str] = None) -> List[Dict[str, Any]]:
        with self._connect() as conn:
            if project_id:
                rows = conn.execute("SELECT job_json FROM render_jobs WHERE project_id=? ORDER BY updated_at DESC", (project_id,)).fetchall()
            else:
                rows = conn.execute("SELECT job_json FROM render_jobs ORDER BY updated_at DESC").fetchall()
            return [json.loads(row["job_json"]) for row in rows]


database = SQLiteDatabase(os.getenv("VIDEO_STUDIO_DB_PATH", DEFAULT_DB_PATH))
