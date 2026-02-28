import os
import shutil
import signal
import subprocess
import time
from datetime import datetime
from pathlib import Path
from threading import Lock
from typing import Any, Dict, Optional

from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session

from database import Base, SessionLocal, engine, get_db
from models import Configuration, Connection, Log, User

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Paqet UI Panel")

DATA_DIR = Path.home() / ".paqet-ui"
CONFIG_DIR = DATA_DIR / "configs"
LOG_DIR = DATA_DIR / "logs"
LOG_FILE = LOG_DIR / "paqet-runtime.log"
PAQET_BINARY = os.getenv("PAQET_BINARY", os.getenv("PAQET_BIN", "paqet"))

DATA_DIR.mkdir(parents=True, exist_ok=True)
CONFIG_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)


def utc_now() -> datetime:
    return datetime.utcnow()


def append_db_log(db: Session, level: str, message: str, source: str = "runtime") -> None:
    db.add(Log(level=level, message=message, source=source, created_at=utc_now()))
    db.commit()


class RuntimeManager:
    def __init__(self, binary_name: str, log_file: Path):
        self.lock = Lock()
        self.binary_name = binary_name
        self.log_file_path = log_file
        self.proc: Optional[Any] = None
        self.proc_log_handle = None
        self.active_config_id: Optional[int] = None
        self.started_at: Optional[float] = None
        self.config_path: Optional[Path] = None
        self.last_error: Optional[str] = None

    def _resolve_binary(self) -> Optional[str]:
        candidate = Path(os.path.expanduser(self.binary_name))
        if candidate.exists() and candidate.is_file():
            return str(candidate)
        return shutil.which(self.binary_name)

    def is_running(self) -> bool:
        return self.proc is not None and self.proc.poll() is None

    def _open_log(self) -> None:
        if self.proc_log_handle is None:
            self.proc_log_handle = open(self.log_file_path, "a", encoding="utf-8")

    def _close_log(self) -> None:
        if self.proc_log_handle is not None:
            try:
                self.proc_log_handle.flush()
                self.proc_log_handle.close()
            finally:
                self.proc_log_handle = None

    def start(self, config_id: int, config_yaml: str) -> Dict[str, Any]:
        with self.lock:
            if self.is_running():
                return {
                    "ok": False,
                    "error": "Paqet is already running. Stop it before starting another config.",
                }

            binary_path = self._resolve_binary()
            if not binary_path:
                return {
                    "ok": False,
                    "error": (
                        "Paqet binary not found. Set PAQET_BINARY env var or install 'paqet' in PATH."
                    ),
                }

            config_file = CONFIG_DIR / ("config-%d.yaml" % config_id)
            config_file.write_text(config_yaml or "", encoding="utf-8")

            self._open_log()
            self.proc_log_handle.write("\n=== %s START config_id=%d ===\n" % (utc_now().isoformat(), config_id))
            self.proc_log_handle.flush()

            cmd = [binary_path, "run", "-c", str(config_file)]
            try:
                popen_kwargs: Dict[str, Any] = {
                    "stdout": self.proc_log_handle,
                    "stderr": subprocess.STDOUT,
                    "cwd": str(DATA_DIR),
                }
                if os.name != "nt":
                    popen_kwargs["start_new_session"] = True

                self.proc = subprocess.Popen(cmd, **popen_kwargs)
                self.started_at = time.time()
                self.active_config_id = config_id
                self.config_path = config_file
                self.last_error = None
            except Exception as exc:
                self.last_error = "Failed to start Paqet: %s" % exc
                self.proc = None
                self.started_at = None
                return {"ok": False, "error": self.last_error}

            # Detect quick-fail startup
            time.sleep(0.4)
            if self.proc.poll() is not None:
                exit_code = self.proc.returncode
                self.last_error = "Paqet exited immediately with code %s. Check %s" % (
                    exit_code,
                    self.log_file_path,
                )
                self.proc = None
                self.started_at = None
                self._close_log()
                return {"ok": False, "error": self.last_error}

            return {
                "ok": True,
                "pid": self.proc.pid,
                "config_id": config_id,
                "config_path": str(config_file),
            }

    def stop(self) -> Dict[str, Any]:
        with self.lock:
            if not self.proc:
                self.last_error = None
                return {"ok": True, "message": "Paqet is already stopped."}

            if self.proc.poll() is not None:
                self.proc = None
                self.started_at = None
                self._close_log()
                return {"ok": True, "message": "Paqet was already stopped."}

            try:
                if os.name != "nt":
                    os.killpg(os.getpgid(self.proc.pid), signal.SIGTERM)
                else:
                    self.proc.terminate()
                self.proc.wait(timeout=8)
            except Exception:
                try:
                    if os.name != "nt":
                        os.killpg(os.getpgid(self.proc.pid), signal.SIGKILL)
                    else:
                        self.proc.kill()
                except Exception:
                    pass

            self.proc = None
            self.started_at = None
            self._close_log()
            return {"ok": True, "message": "Paqet stopped."}

    def status(self) -> Dict[str, Any]:
        running = self.is_running()
        pid = self.proc.pid if running and self.proc else None
        uptime_seconds = int(time.time() - self.started_at) if running and self.started_at else 0
        started_at = datetime.utcfromtimestamp(self.started_at).isoformat() if running and self.started_at else None
        return {
            "running": running,
            "pid": pid,
            "uptime_seconds": uptime_seconds,
            "started_at": started_at,
            "active_config_id": self.active_config_id,
            "binary": self.binary_name,
            "resolved_binary": self._resolve_binary(),
            "config_path": str(self.config_path) if self.config_path else None,
            "log_file": str(self.log_file_path),
            "last_error": self.last_error,
        }


runtime = RuntimeManager(PAQET_BINARY, LOG_FILE)


class RuntimeStartRequest(BaseModel):
    config_id: Optional[int] = None


# Add CORS middleware to allow API calls from frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve static files
app.mount("/panel/static", StaticFiles(directory="web/html"), name="static")


# Initialize default user
def init_default_user() -> None:
    db = SessionLocal()
    try:
        existing_user = db.query(User).filter(User.username == "admin").first()
        if not existing_user:
            # Keep hashing simple for now to avoid migration breakage with old DB rows.
            user = User(username="admin", password=hash_password("admin"))
            db.add(user)
            db.commit()
            print("Default user 'admin' created")
    finally:
        db.close()


def hash_password(password: str) -> str:
    import hashlib

    return hashlib.sha256(password.encode()).hexdigest()


def verify_password(plain: str, hashed: str) -> bool:
    return hash_password(plain) == hashed


@app.on_event("startup")
async def startup() -> None:
    init_default_user()
    print("Database initialized")


# Routes
@app.get("/panel")
@app.get("/panel/")
@app.get("/panel/dashboard")
async def serve_dashboard() -> FileResponse:
    return FileResponse("web/html/dashboard.html")


@app.get("/panel/login")
async def serve_login() -> FileResponse:
    return FileResponse("web/html/login.html")


@app.get("/panel/logout")
async def logout() -> RedirectResponse:
    return RedirectResponse(url="/panel/login", status_code=302)


@app.get("/panel/configurations")
async def serve_configurations() -> FileResponse:
    return FileResponse("web/html/configurations.html")


@app.get("/panel/connections")
async def serve_connections() -> FileResponse:
    return FileResponse("web/html/connections.html")


@app.get("/panel/settings")
async def serve_settings() -> FileResponse:
    return FileResponse("web/html/settings.html")


# API Routes
@app.post("/panel/api/auth/login")
async def login(request: Request, db: Session = Depends(get_db)) -> Dict[str, Any]:
    data = await request.json()
    username = data.get("username")
    password = data.get("password")

    user = db.query(User).filter(User.username == username).first()
    if not user or not verify_password(password, user.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return {"status": "success", "user_id": user.id, "username": user.username}


@app.get("/panel/api/configurations")
async def get_configurations(db: Session = Depends(get_db)) -> Any:
    configs = db.query(Configuration).all()
    return [
        {
            "id": c.id,
            "name": c.name,
            "role": c.role,
            "config_yaml": c.config_yaml,
            "active": c.active,
            "created_at": c.created_at.isoformat() if c.created_at else None,
            "updated_at": c.updated_at.isoformat() if c.updated_at else None,
        }
        for c in configs
    ]


@app.get("/panel/api/configurations/{config_id}")
async def get_configuration(config_id: int, db: Session = Depends(get_db)) -> Dict[str, Any]:
    config = db.query(Configuration).filter(Configuration.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Configuration not found")

    return {
        "id": config.id,
        "name": config.name,
        "role": config.role,
        "config_yaml": config.config_yaml,
        "active": config.active,
    }


@app.post("/panel/api/configurations")
async def create_configuration(request: Request, db: Session = Depends(get_db)) -> Dict[str, Any]:
    data = await request.json()

    config = Configuration(
        name=data.get("name"),
        role=data.get("role"),
        config_yaml=data.get("config_yaml"),
        active=False,
    )
    db.add(config)
    db.commit()
    db.refresh(config)

    append_db_log(db, "info", "Created configuration '%s' (id=%d)." % (config.name, config.id), "config")
    return {"id": config.id, "status": "created"}


@app.put("/panel/api/configurations/{config_id}")
async def update_configuration(config_id: int, request: Request, db: Session = Depends(get_db)) -> Dict[str, str]:
    config = db.query(Configuration).filter(Configuration.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Configuration not found")

    data = await request.json()
    config.name = data.get("name", config.name)
    config.role = data.get("role", config.role)
    config.config_yaml = data.get("config_yaml", config.config_yaml)
    config.updated_at = utc_now()

    db.commit()
    append_db_log(db, "info", "Updated configuration '%s' (id=%d)." % (config.name, config.id), "config")
    return {"status": "updated"}


@app.delete("/panel/api/configurations/{config_id}")
async def delete_configuration(config_id: int, db: Session = Depends(get_db)) -> Dict[str, str]:
    config = db.query(Configuration).filter(Configuration.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Configuration not found")

    if runtime.is_running() and runtime.active_config_id == config.id:
        stop_result = runtime.stop()
        if not stop_result["ok"]:
            raise HTTPException(status_code=400, detail=stop_result["error"])

    name = config.name
    db.delete(config)
    db.commit()
    append_db_log(db, "info", "Deleted configuration '%s' (id=%d)." % (name, config_id), "config")
    return {"status": "deleted"}


@app.get("/panel/api/connections")
async def get_connections(db: Session = Depends(get_db)) -> Any:
    connections = db.query(Connection).all()
    return [
        {
            "id": c.id,
            "config_id": c.config_id,
            "status": c.status,
            "bytes_in": c.bytes_in,
            "bytes_out": c.bytes_out,
            "last_activity_at": c.last_activity_at.isoformat() if c.last_activity_at else None,
            "configuration": {
                "id": c.configuration.id,
                "name": c.configuration.name,
            }
            if c.configuration
            else None,
        }
        for c in connections
    ]


@app.patch("/panel/api/configurations/{config_id}/activate")
async def activate_configuration(config_id: int, db: Session = Depends(get_db)) -> Dict[str, str]:
    config = db.query(Configuration).filter(Configuration.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Configuration not found")

    db.query(Configuration).update({Configuration.active: False})
    config.active = True
    db.commit()

    runtime.active_config_id = config_id
    append_db_log(db, "info", "Activated configuration '%s' (id=%d)." % (config.name, config.id), "config")
    return {"status": "activated"}


@app.get("/panel/api/status")
async def get_status(db: Session = Depends(get_db)) -> Dict[str, Any]:
    active_config = db.query(Configuration).filter(Configuration.active.is_(True)).first()

    total_connections = db.query(func.count(Connection.id)).scalar() or 0
    active_connections = (
        db.query(func.count(Connection.id)).filter(Connection.status == "running").scalar() or 0
    )
    total_bytes_in = db.query(func.coalesce(func.sum(Connection.bytes_in), 0)).scalar() or 0

    runtime_status = runtime.status()
    return {
        "runtime": runtime_status,
        "active_config": {
            "id": active_config.id,
            "name": active_config.name,
            "role": active_config.role,
        }
        if active_config
        else None,
        "stats": {
            "total_connections": int(total_connections),
            "active_connections": int(active_connections),
            "total_bytes_in": int(total_bytes_in),
        },
        "panel": {"version": "1.1.0"},
    }


@app.post("/panel/api/runtime/start")
async def start_runtime(payload: RuntimeStartRequest, db: Session = Depends(get_db)) -> Dict[str, Any]:
    config: Optional[Configuration] = None
    if payload.config_id is not None:
        config = db.query(Configuration).filter(Configuration.id == payload.config_id).first()
        if not config:
            raise HTTPException(status_code=404, detail="Configuration not found")
    else:
        config = db.query(Configuration).filter(Configuration.active.is_(True)).first()
        if not config:
            raise HTTPException(
                status_code=400,
                detail="No active configuration. Activate one first or send config_id.",
            )

    db.query(Configuration).update({Configuration.active: False})
    config.active = True
    db.commit()

    result = runtime.start(config.id, config.config_yaml or "")
    if not result["ok"]:
        append_db_log(db, "error", result["error"], "runtime")
        raise HTTPException(status_code=400, detail=result["error"])

    conn = db.query(Connection).filter(Connection.config_id == config.id).first()
    if not conn:
        conn = Connection(
            config_id=config.id,
            status="running",
            bytes_in=0,
            bytes_out=0,
            last_activity_at=utc_now(),
            created_at=utc_now(),
            updated_at=utc_now(),
        )
        db.add(conn)
    else:
        conn.status = "running"
        conn.last_activity_at = utc_now()
        conn.updated_at = utc_now()
    db.commit()

    append_db_log(db, "info", "Started Paqet with configuration '%s' (id=%d)." % (config.name, config.id))
    return {"status": "started", "runtime": runtime.status(), "config_id": config.id}


@app.post("/panel/api/runtime/stop")
async def stop_runtime(db: Session = Depends(get_db)) -> Dict[str, Any]:
    result = runtime.stop()
    if not result["ok"]:
        append_db_log(db, "error", result["error"], "runtime")
        raise HTTPException(status_code=400, detail=result["error"])

    active_id = runtime.active_config_id
    if active_id is not None:
        conn = db.query(Connection).filter(Connection.config_id == active_id).first()
        if conn:
            conn.status = "stopped"
            conn.last_activity_at = utc_now()
            conn.updated_at = utc_now()
            db.commit()

    append_db_log(db, "info", "Stopped Paqet process.", "runtime")
    return {"status": "stopped", "runtime": runtime.status()}


@app.post("/panel/api/runtime/restart")
async def restart_runtime(payload: RuntimeStartRequest, db: Session = Depends(get_db)) -> Dict[str, Any]:
    stop_result = runtime.stop()
    if not stop_result["ok"]:
        append_db_log(db, "error", stop_result["error"], "runtime")
        raise HTTPException(status_code=400, detail=stop_result["error"])

    config: Optional[Configuration] = None
    if payload.config_id is not None:
        config = db.query(Configuration).filter(Configuration.id == payload.config_id).first()
        if not config:
            raise HTTPException(status_code=404, detail="Configuration not found")
    elif runtime.active_config_id is not None:
        config = db.query(Configuration).filter(Configuration.id == runtime.active_config_id).first()
    if not config:
        config = db.query(Configuration).filter(Configuration.active.is_(True)).first()

    if not config:
        raise HTTPException(
            status_code=400,
            detail="No configuration found to restart with. Activate one first.",
        )

    db.query(Configuration).update({Configuration.active: False})
    config.active = True
    db.commit()

    start_result = runtime.start(config.id, config.config_yaml or "")
    if not start_result["ok"]:
        append_db_log(db, "error", start_result["error"], "runtime")
        raise HTTPException(status_code=400, detail=start_result["error"])

    conn = db.query(Connection).filter(Connection.config_id == config.id).first()
    if not conn:
        conn = Connection(
            config_id=config.id,
            status="running",
            bytes_in=0,
            bytes_out=0,
            last_activity_at=utc_now(),
            created_at=utc_now(),
            updated_at=utc_now(),
        )
        db.add(conn)
    else:
        conn.status = "running"
        conn.last_activity_at = utc_now()
        conn.updated_at = utc_now()
    db.commit()

    append_db_log(db, "info", "Restarted Paqet process with configuration '%s' (id=%d)." % (config.name, config.id))
    return {"status": "restarted", "runtime": runtime.status(), "config_id": config.id}


@app.get("/panel/api/runtime/logs")
async def runtime_logs(lines: int = 200) -> Dict[str, Any]:
    if not LOG_FILE.exists():
        return {"lines": []}

    safe_lines = max(1, min(lines, 1000))
    content = LOG_FILE.read_text(encoding="utf-8", errors="replace").splitlines()
    return {"lines": content[-safe_lines:]}


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "2053"))
    uvicorn.run(app, host="0.0.0.0", port=port)
