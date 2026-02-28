import os
from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from datetime import datetime
import hashlib

from database import engine, Base, get_db, SessionLocal
from models import User, Configuration, Connection, Log, Setting

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Paqet UI Panel")

# Serve static files
app.mount("/panel/static", StaticFiles(directory="web/html"), name="static")

# Initialize default user
def init_default_user():
    db = SessionLocal()
    try:
        existing_user = db.query(User).filter(User.username == "admin").first()
        if not existing_user:
            hashed_password = hashlib.sha256("admin".encode()).hexdigest()
            user = User(username="admin", password=hashed_password)
            db.add(user)
            db.commit()
            print("✓ Default user 'admin' created")
    finally:
        db.close()

# Initialize on startup
def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

def verify_password(plain: str, hashed: str) -> bool:
    return hash_password(plain) == hashed

@app.on_event("startup")
async def startup():
    init_default_user()
    print("✓ Database initialized")

# Routes
@app.get("/panel")
@app.get("/panel/")
async def serve_dashboard():
    return FileResponse("web/html/dashboard.html")

@app.get("/panel/configurations")
async def serve_configurations():
    return FileResponse("web/html/configurations.html")

@app.get("/panel/connections")
async def serve_connections():
    return FileResponse("web/html/connections.html")

@app.get("/panel/settings")
async def serve_settings():
    return FileResponse("web/html/settings.html")

# API Routes
@app.post("/panel/api/auth/login")
async def login(request: Request, db: Session = Depends(get_db)):
    data = await request.json()
    username = data.get("username")
    password = data.get("password")
    
    user = db.query(User).filter(User.username == username).first()
    if not user or not verify_password(password, user.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    return {"status": "success", "user_id": user.id, "username": user.username}

@app.get("/panel/api/configurations")
async def get_configurations(db: Session = Depends(get_db)):
    configs = db.query(Configuration).all()
    return [
        {
            "id": c.id,
            "name": c.name,
            "role": c.role,
            "config_yaml": c.config_yaml,
            "active": c.active,
            "created_at": c.created_at.isoformat(),
            "updated_at": c.updated_at.isoformat()
        }
        for c in configs
    ]

@app.get("/panel/api/configurations/{config_id}")
async def get_configuration(config_id: int, db: Session = Depends(get_db)):
    config = db.query(Configuration).filter(Configuration.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Configuration not found")
    
    return {
        "id": config.id,
        "name": config.name,
        "role": config.role,
        "config_yaml": config.config_yaml,
        "active": config.active
    }

@app.post("/panel/api/configurations")
async def create_configuration(request: Request, db: Session = Depends(get_db)):
    data = await request.json()
    
    config = Configuration(
        name=data.get("name"),
        role=data.get("role"),
        config_yaml=data.get("config_yaml"),
        active=False
    )
    db.add(config)
    db.commit()
    db.refresh(config)
    
    return {"id": config.id, "status": "created"}

@app.put("/panel/api/configurations/{config_id}")
async def update_configuration(config_id: int, request: Request, db: Session = Depends(get_db)):
    config = db.query(Configuration).filter(Configuration.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Configuration not found")
    
    data = await request.json()
    config.name = data.get("name", config.name)
    config.role = data.get("role", config.role)
    config.config_yaml = data.get("config_yaml", config.config_yaml)
    config.updated_at = datetime.utcnow()
    
    db.commit()
    return {"status": "updated"}

@app.delete("/panel/api/configurations/{config_id}")
async def delete_configuration(config_id: int, db: Session = Depends(get_db)):
    config = db.query(Configuration).filter(Configuration.id == config_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Configuration not found")
    
    db.delete(config)
    db.commit()
    return {"status": "deleted"}

@app.get("/panel/api/connections")
async def get_connections(db: Session = Depends(get_db)):
    connections = db.query(Connection).all()
    return [
        {
            "id": c.id,
            "config_id": c.config_id,
            "status": c.status,
            "bytes_in": c.bytes_in,
            "bytes_out": c.bytes_out,
            "last_activity_at": c.last_activity_at.isoformat()
        }
        for c in connections
    ]

@app.patch("/panel/api/configurations/{config_id}/activate")
async def activate_configuration(config_id: int, db: Session = Depends(get_db)):
    # Deactivate all others
    db.query(Configuration).update({Configuration.active: False})
    
    # Activate this one
    config = db.query(Configuration).filter(Configuration.id == config_id).first()
    if config:
        config.active = True
        db.commit()
    
    return {"status": "activated"}

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 2053))
    uvicorn.run(app, host="0.0.0.0", port=port)
