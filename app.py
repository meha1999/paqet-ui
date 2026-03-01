import json
import os
import re
import shutil
import signal
import socket
import subprocess
import time
from datetime import datetime
from pathlib import Path
from threading import Lock
from typing import Any, Dict, List, Optional

from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session
from starlette.middleware.sessions import SessionMiddleware

from database import Base, SessionLocal, engine, get_db
from models import Configuration, Connection, Log, User

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Paqet UI Panel")

DATA_DIR = Path.home() / ".paqet-ui"
CONFIG_DIR = DATA_DIR / "configs"
LOG_DIR = DATA_DIR / "logs"
LOG_FILE = LOG_DIR / "paqet-runtime.log"
SIDECAR_FILE = DATA_DIR / "sidecar-rules.json"
APP_DIR = Path(__file__).resolve().parent
FRONTEND_DIST_DIR = APP_DIR / "frontend" / "dist"
FRONTEND_INDEX_FILE = FRONTEND_DIST_DIR / "index.html"
FRONTEND_ASSETS_DIR = FRONTEND_DIST_DIR / "assets"
LEGACY_WEB_DIR = APP_DIR / "web" / "html"
PAQET_BINARY = os.getenv("PAQET_BINARY", os.getenv("PAQET_BIN", "paqet"))
SESSION_SECRET = os.getenv("SESSION_SECRET", "paqet-ui-change-this-secret")
SESSION_COOKIE_NAME = os.getenv("SESSION_COOKIE_NAME", "paqet_ui_session")
SESSION_MAX_AGE = int(os.getenv("SESSION_MAX_AGE", "86400"))

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
        self.sidecar_proc: Optional[Any] = None
        self.proc_log_handle = None
        self.active_config_id: Optional[int] = None
        self.started_at: Optional[float] = None
        self.config_path: Optional[Path] = None
        self.sidecar_rule: Dict[str, Any] = {"enabled": False, "listen": "", "target": ""}
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

    def _parse_bind_address(self, address: str) -> tuple[str, str]:
        value = str(address or "").strip()
        if ":" not in value:
            raise ValueError("listen must be in host:port or :port format")

        host, port = value.rsplit(":", 1)
        host = host.strip() or "0.0.0.0"
        port = port.strip()
        if not port.isdigit():
            raise ValueError("listen port must be numeric")
        return host, port

    def _parse_target_address(self, address: str) -> tuple[str, str]:
        value = str(address or "").strip()
        if ":" not in value:
            raise ValueError("target must be in host:port format")

        host, port = value.rsplit(":", 1)
        host = host.strip()
        port = port.strip()
        if not host or not port.isdigit():
            raise ValueError("target must include host and numeric port")
        return host, port

    def _terminate_process(self, proc: Optional[Any]) -> None:
        if not proc:
            return
        if proc.poll() is not None:
            return

        try:
            if os.name != "nt":
                os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
            else:
                proc.terminate()
            proc.wait(timeout=8)
            return
        except Exception:
            pass

        try:
            if os.name != "nt":
                os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            else:
                proc.kill()
        except Exception:
            pass

    def _start_sidecar(self, rule: Dict[str, Any]) -> Dict[str, Any]:
        normalized = normalize_sidecar_rule(rule)
        if not normalized["enabled"]:
            self.sidecar_rule = {"enabled": False, "listen": "", "target": ""}
            return {"ok": True}

        socat_path = shutil.which("socat")
        if not socat_path:
            return {
                "ok": False,
                "error": (
                    "Sidecar relay is enabled but 'socat' is not installed. "
                    "Install socat or disable upstream relay."
                ),
            }

        try:
            bind_host, bind_port = self._parse_bind_address(normalized["listen"])
            target_host, target_port = self._parse_target_address(normalized["target"])
        except ValueError as exc:
            return {"ok": False, "error": f"Invalid sidecar relay address: {exc}"}

        listen_spec = f"TCP-LISTEN:{bind_port},fork,reuseaddr"
        if bind_host and bind_host != "0.0.0.0":
            listen_spec += f",bind={bind_host}"
        target_spec = f"TCP:{target_host}:{target_port}"
        cmd = [socat_path, listen_spec, target_spec]

        try:
            popen_kwargs: Dict[str, Any] = {
                "stdout": self.proc_log_handle,
                "stderr": subprocess.STDOUT,
                "cwd": str(DATA_DIR),
            }
            if os.name != "nt":
                popen_kwargs["start_new_session"] = True
            self.sidecar_proc = subprocess.Popen(cmd, **popen_kwargs)
        except Exception as exc:
            self.sidecar_proc = None
            return {"ok": False, "error": f"Failed to start sidecar relay: {exc}"}

        time.sleep(0.2)
        if self.sidecar_proc.poll() is not None:
            exit_code = self.sidecar_proc.returncode
            self.sidecar_proc = None
            return {
                "ok": False,
                "error": f"Sidecar relay exited immediately with code {exit_code}. Check {self.log_file_path}",
            }

        self.sidecar_rule = normalized
        return {"ok": True}

    def start(self, config_id: int, config_yaml: str, sidecar_rule: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        with self.lock:
            if self.is_running() or (self.sidecar_proc is not None and self.sidecar_proc.poll() is None):
                return {
                    "ok": False,
                    "error": "Paqet runtime is already running. Stop it before starting another config.",
                }
            self.sidecar_proc = None
            self.sidecar_rule = {"enabled": False, "listen": "", "target": ""}

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

            sidecar_result = self._start_sidecar(sidecar_rule or {"enabled": False, "listen": "", "target": ""})
            if not sidecar_result["ok"]:
                self._terminate_process(self.proc)
                self.proc = None
                self.started_at = None
                self.last_error = sidecar_result["error"]
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
            paqet_running = self.proc is not None and self.proc.poll() is None
            sidecar_running = self.sidecar_proc is not None and self.sidecar_proc.poll() is None

            if not paqet_running and not sidecar_running:
                self.proc = None
                self.sidecar_proc = None
                self.last_error = None
                self.started_at = None
                self.sidecar_rule = {"enabled": False, "listen": "", "target": ""}
                self._close_log()
                return {"ok": True, "message": "Paqet is already stopped."}

            self._terminate_process(self.sidecar_proc)
            self._terminate_process(self.proc)

            self.proc = None
            self.sidecar_proc = None
            self.started_at = None
            self.sidecar_rule = {"enabled": False, "listen": "", "target": ""}
            self._close_log()
            return {"ok": True, "message": "Paqet stopped."}

    def status(self) -> Dict[str, Any]:
        running = self.is_running()
        sidecar_running = self.sidecar_proc is not None and self.sidecar_proc.poll() is None
        pid = self.proc.pid if running and self.proc else None
        sidecar_pid = self.sidecar_proc.pid if sidecar_running and self.sidecar_proc else None
        uptime_seconds = int(time.time() - self.started_at) if running and self.started_at else 0
        started_at = datetime.utcfromtimestamp(self.started_at).isoformat() if running and self.started_at else None
        return {
            "running": running,
            "pid": pid,
            "sidecar_running": sidecar_running,
            "sidecar_pid": sidecar_pid,
            "sidecar": self.sidecar_rule,
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
    SessionMiddleware,
    secret_key=SESSION_SECRET,
    session_cookie=SESSION_COOKIE_NAME,
    max_age=SESSION_MAX_AGE,
    same_site="lax",
    https_only=False,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

if FRONTEND_ASSETS_DIR.exists():
    app.mount("/panel/assets", StaticFiles(directory=str(FRONTEND_ASSETS_DIR)), name="panel_assets")


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


def is_authenticated(request: Request) -> bool:
    return bool(request.session.get("user_id"))


def require_api_auth(request: Request) -> int:
    user_id = request.session.get("user_id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")
    return int(user_id)


def load_sidecar_rules() -> Dict[str, Dict[str, Any]]:
    if not SIDECAR_FILE.exists():
        return {}

    try:
        data = json.loads(SIDECAR_FILE.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def save_sidecar_rules(rules: Dict[str, Dict[str, Any]]) -> None:
    SIDECAR_FILE.write_text(json.dumps(rules, indent=2), encoding="utf-8")


def normalize_sidecar_rule(payload: Any) -> Dict[str, Any]:
    if not isinstance(payload, dict):
        return {"enabled": False, "listen": "", "target": ""}

    enabled = bool(payload.get("enabled", False))
    listen = str(payload.get("listen", "")).strip()
    target = str(payload.get("target", "")).strip()

    if enabled and (not listen or not target):
        raise HTTPException(
            status_code=400,
            detail="Sidecar relay requires both listen and target addresses.",
        )

    return {"enabled": enabled, "listen": listen, "target": target}


def get_sidecar_rule(config_id: int) -> Dict[str, Any]:
    rules = load_sidecar_rules()
    rule = rules.get(str(config_id), {})
    try:
        return normalize_sidecar_rule(rule)
    except HTTPException:
        return {"enabled": False, "listen": "", "target": ""}


def set_sidecar_rule(config_id: int, rule: Dict[str, Any]) -> None:
    rules = load_sidecar_rules()
    rules[str(config_id)] = normalize_sidecar_rule(rule)
    save_sidecar_rules(rules)


def delete_sidecar_rule(config_id: int) -> None:
    rules = load_sidecar_rules()
    key = str(config_id)
    if key in rules:
        del rules[key]
        save_sidecar_rules(rules)


def serve_panel_app(legacy_name: str) -> Any:
    if FRONTEND_INDEX_FILE.exists():
        return FileResponse(str(FRONTEND_INDEX_FILE))

    legacy_file = LEGACY_WEB_DIR / legacy_name
    if legacy_file.exists():
        return FileResponse(str(legacy_file))

    return HTMLResponse(
        (
            "<h2>Paqet UI frontend is not built.</h2>"
            "<p>Run <code>pnpm --dir frontend install</code> and <code>pnpm --dir frontend run build</code>.</p>"
        ),
        status_code=503,
    )


def _run_command(args: List[str]) -> str:
    try:
        return subprocess.check_output(
            args,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=2,
        ).strip()
    except Exception:
        return ""


def detect_system_defaults() -> Dict[str, Any]:
    interface = ""
    gateway = ""
    ipv4 = ""
    router_mac = ""

    if os.name != "nt" and shutil.which("ip"):
        default_route = _run_command(["ip", "route", "show", "default"])
        route_match = re.search(r"default via ([0-9.]+) dev (\S+)", default_route)
        if route_match:
            gateway = route_match.group(1)
            interface = route_match.group(2)
        else:
            dev_only_match = re.search(r"default dev (\S+)", default_route)
            if dev_only_match:
                interface = dev_only_match.group(1)

        if interface:
            addr_output = _run_command(["ip", "-4", "addr", "show", "dev", interface])
            ip_match = re.search(r"inet ([0-9.]+)/", addr_output)
            if ip_match:
                ipv4 = ip_match.group(1)

        if interface and gateway:
            neighbor = _run_command(["ip", "neigh", "show", gateway, "dev", interface])
            mac_match = re.search(r"lladdr\s+([0-9a-fA-F:]{17})", neighbor)
            if mac_match:
                router_mac = mac_match.group(1).lower()

    if not ipv4:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.connect(("8.8.8.8", 80))
            ipv4 = sock.getsockname()[0]
            sock.close()
        except Exception:
            ipv4 = "127.0.0.1"

    if not interface:
        interface = "eth0" if os.name != "nt" else "Ethernet"
    if not router_mac:
        router_mac = "00:00:00:00:00:00"

    hostname = socket.gethostname()
    kcp_key = "paqet-%s-change-me" % hostname.replace(" ", "-")
    if len(kcp_key) > 48:
        kcp_key = kcp_key[:48]

    return {
        "hostname": hostname,
        "interface": interface,
        "gateway": gateway,
        "ipv4": ipv4,
        "ipv4_bind": "%s:0" % ipv4,
        "router_mac": router_mac,
        "server_addr": "%s:9999" % ipv4,
        "listen_addr": ":9999",
        "kcp_key": kcp_key,
    }


@app.on_event("startup")
async def startup() -> None:
    init_default_user()
    print("Database initialized")


# Routes
@app.get("/panel")
@app.get("/panel/")
@app.get("/panel/dashboard")
async def serve_dashboard(request: Request) -> Any:
    if not is_authenticated(request):
        return RedirectResponse(url="/panel/login", status_code=302)
    return serve_panel_app("dashboard.html")


@app.get("/panel/login")
async def serve_login(request: Request) -> Any:
    if is_authenticated(request):
        return RedirectResponse(url="/panel/dashboard", status_code=302)
    return serve_panel_app("login.html")


@app.get("/panel/logout")
async def logout(request: Request) -> RedirectResponse:
    request.session.clear()
    return RedirectResponse(url="/panel/login", status_code=302)


@app.get("/panel/configurations")
async def serve_configurations(request: Request) -> Any:
    if not is_authenticated(request):
        return RedirectResponse(url="/panel/login", status_code=302)
    return serve_panel_app("configurations.html")


@app.get("/panel/connections")
async def serve_connections(request: Request) -> Any:
    if not is_authenticated(request):
        return RedirectResponse(url="/panel/login", status_code=302)
    return serve_panel_app("connections.html")


@app.get("/panel/settings")
async def serve_settings(request: Request) -> Any:
    if not is_authenticated(request):
        return RedirectResponse(url="/panel/login", status_code=302)
    return serve_panel_app("settings.html")


# API Routes
@app.get("/panel/api/system/default-config")
async def get_system_default_config(_user_id: int = Depends(require_api_auth)) -> Dict[str, Any]:
    return detect_system_defaults()


@app.post("/panel/api/auth/login")
async def login(request: Request, db: Session = Depends(get_db)) -> Dict[str, Any]:
    data = await request.json()
    username = data.get("username")
    password = data.get("password")

    user = db.query(User).filter(User.username == username).first()
    if not user or not verify_password(password, user.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    request.session["user_id"] = user.id
    request.session["username"] = user.username
    return {"status": "success", "user_id": user.id, "username": user.username}


@app.get("/panel/api/configurations")
async def get_configurations(db: Session = Depends(get_db), _user_id: int = Depends(require_api_auth)) -> Any:
    configs = db.query(Configuration).all()
    return [
        {
            "id": c.id,
            "name": c.name,
            "role": c.role,
            "config_yaml": c.config_yaml,
            "active": c.active,
            "sidecar": get_sidecar_rule(c.id),
            "created_at": c.created_at.isoformat() if c.created_at else None,
            "updated_at": c.updated_at.isoformat() if c.updated_at else None,
        }
        for c in configs
    ]


@app.get("/panel/api/configurations/{config_id}")
async def get_configuration(
    config_id: int,
    db: Session = Depends(get_db),
    _user_id: int = Depends(require_api_auth),
) -> Dict[str, Any]:
    config = db.query(Configuration).filter(Configuration.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Configuration not found")

    return {
        "id": config.id,
        "name": config.name,
        "role": config.role,
        "config_yaml": config.config_yaml,
        "active": config.active,
        "sidecar": get_sidecar_rule(config.id),
    }


@app.post("/panel/api/configurations")
async def create_configuration(
    request: Request,
    db: Session = Depends(get_db),
    _user_id: int = Depends(require_api_auth),
) -> Dict[str, Any]:
    data = await request.json()
    sidecar_rule = normalize_sidecar_rule(data.get("sidecar", {}))

    config = Configuration(
        name=data.get("name"),
        role=data.get("role"),
        config_yaml=data.get("config_yaml"),
        active=False,
    )
    db.add(config)
    db.commit()
    db.refresh(config)
    set_sidecar_rule(config.id, sidecar_rule)

    append_db_log(db, "info", "Created configuration '%s' (id=%d)." % (config.name, config.id), "config")
    return {"id": config.id, "status": "created"}


@app.put("/panel/api/configurations/{config_id}")
async def update_configuration(
    config_id: int,
    request: Request,
    db: Session = Depends(get_db),
    _user_id: int = Depends(require_api_auth),
) -> Dict[str, str]:
    config = db.query(Configuration).filter(Configuration.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Configuration not found")

    data = await request.json()
    config.name = data.get("name", config.name)
    config.role = data.get("role", config.role)
    config.config_yaml = data.get("config_yaml", config.config_yaml)
    config.updated_at = utc_now()
    if "sidecar" in data:
        set_sidecar_rule(config.id, normalize_sidecar_rule(data.get("sidecar")))

    db.commit()
    append_db_log(db, "info", "Updated configuration '%s' (id=%d)." % (config.name, config.id), "config")
    return {"status": "updated"}


@app.delete("/panel/api/configurations/{config_id}")
async def delete_configuration(
    config_id: int,
    db: Session = Depends(get_db),
    _user_id: int = Depends(require_api_auth),
) -> Dict[str, str]:
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
    delete_sidecar_rule(config_id)
    append_db_log(db, "info", "Deleted configuration '%s' (id=%d)." % (name, config_id), "config")
    return {"status": "deleted"}


@app.get("/panel/api/connections")
async def get_connections(db: Session = Depends(get_db), _user_id: int = Depends(require_api_auth)) -> Any:
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
async def activate_configuration(
    config_id: int,
    db: Session = Depends(get_db),
    _user_id: int = Depends(require_api_auth),
) -> Dict[str, str]:
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
async def get_status(db: Session = Depends(get_db), _user_id: int = Depends(require_api_auth)) -> Dict[str, Any]:
    active_config = db.query(Configuration).filter(Configuration.active.is_(True)).first()
    active_sidecar = get_sidecar_rule(active_config.id) if active_config else {"enabled": False, "listen": "", "target": ""}

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
        "active_sidecar": active_sidecar,
        "stats": {
            "total_connections": int(total_connections),
            "active_connections": int(active_connections),
            "total_bytes_in": int(total_bytes_in),
        },
        "panel": {"version": "1.1.0"},
    }


@app.post("/panel/api/runtime/start")
async def start_runtime(
    payload: RuntimeStartRequest,
    db: Session = Depends(get_db),
    _user_id: int = Depends(require_api_auth),
) -> Dict[str, Any]:
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

    sidecar_rule = get_sidecar_rule(config.id)
    result = runtime.start(config.id, config.config_yaml or "", sidecar_rule=sidecar_rule)
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
async def stop_runtime(db: Session = Depends(get_db), _user_id: int = Depends(require_api_auth)) -> Dict[str, Any]:
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
async def restart_runtime(
    payload: RuntimeStartRequest,
    db: Session = Depends(get_db),
    _user_id: int = Depends(require_api_auth),
) -> Dict[str, Any]:
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

    sidecar_rule = get_sidecar_rule(config.id)
    start_result = runtime.start(config.id, config.config_yaml or "", sidecar_rule=sidecar_rule)
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
async def runtime_logs(lines: int = 200, _user_id: int = Depends(require_api_auth)) -> Dict[str, Any]:
    if not LOG_FILE.exists():
        return {"lines": []}

    safe_lines = max(1, min(lines, 1000))
    content = LOG_FILE.read_text(encoding="utf-8", errors="replace").splitlines()
    return {"lines": content[-safe_lines:]}


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "2053"))
    uvicorn.run(app, host="0.0.0.0", port=port)
