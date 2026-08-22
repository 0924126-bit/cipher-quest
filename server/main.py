"""Cipher Quest backend - FastAPI

Serves:
- REST API      /api/*        (machine CRUD, QR data)
- WebSocket     /ws/machine/{id}   (exclusive; one client per machine)
- WebSocket     /ws/dashboard      (broadcast of all machine states)
- Static files  /              (Flutter web build, pre-gzipped + cached)

Run: uvicorn main:app --host 0.0.0.0 --port 5060
"""
import asyncio
import gzip
import mimetypes
import os

from fastapi import (FastAPI, File, Form, HTTPException, UploadFile,
                     WebSocket, WebSocketDisconnect)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.requests import Request
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from store import store
from sounds import SOUNDS_DIR, sound_store
from roles import IMAGES_DIR, role_store
from connections import manager
from game.routes import router as game_router, pump_loop

app = FastAPI(title="Cipher Quest API")
app.include_router(game_router)


@app.on_event("startup")
async def _startup():
    asyncio.create_task(pump_loop())
    # Pre-gzip the heavy Flutter bundles in a thread so the first
    # mobile visitor doesn't pay 13MB+ of uncompressed downloads.
    await asyncio.to_thread(_pregzip_web_build)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

WEB_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "build", "web")


# ---------- helpers ----------
def machine_public(m: dict) -> dict:
    return {**m, "locked": manager.is_machine_connected(m["id"])}


async def broadcast_state():
    machines = [machine_public(m) for m in store.list_machines()]
    await manager.broadcast_dashboards({
        "type": "state",
        "machines": machines,
        "all_completed": store.all_completed(),
    })


async def broadcast_event(ev: dict):
    await manager.broadcast_dashboards({"type": "event", "event": ev})


# ---------- REST models ----------
class MachineCreate(BaseModel):
    name: str = ""
    duration_sec: int = 60
    design: str = "classic"


class MachineUpdate(BaseModel):
    name: str | None = None
    duration_sec: int | None = None
    design: str | None = None
    speed_multiplier: float | None = None
    skill_enabled: bool | None = None
    skill_difficulty: int | None = None
    skill_success_bonus: float | None = None
    skill_fail_penalty: float | None = None


class SpeedUpdate(BaseModel):
    """Absolute multiplier OR relative delta in percent points (+10 / -10)."""
    speed_multiplier: float | None = None
    delta_percent: float | None = None


class SoundRole(BaseModel):
    role: str


class RolePatch(BaseModel):
    title: str | None = None
    subtitle: str | None = None
    alarm_sec: int | None = None
    cooldown_sec: int | None = None
    notify_message: str | None = None


# ---------- REST endpoints ----------
@app.get("/api/health")
async def health():
    return {"ok": True}


@app.get("/api/machines")
async def list_machines():
    return {"machines": [machine_public(m) for m in store.list_machines()],
            "all_completed": store.all_completed()}


@app.post("/api/machines")
async def create_machine(body: MachineCreate):
    m = store.create(body.name, body.duration_sec, body.design)
    store.add_event(m["id"], "created", f"{m['name']} を設置しました")
    await broadcast_state()
    return machine_public(m)


@app.get("/api/machines/{machine_id}")
async def get_machine(machine_id: str):
    m = store.get(machine_id)
    if not m:
        raise HTTPException(404, "machine not found")
    return machine_public(m)


@app.patch("/api/machines/{machine_id}")
async def update_machine(machine_id: str, body: MachineUpdate):
    m = store.update_settings(
        machine_id, body.name, body.duration_sec, body.design,
        speed_multiplier=body.speed_multiplier,
        skill_enabled=body.skill_enabled,
        skill_difficulty=body.skill_difficulty,
        skill_success_bonus=body.skill_success_bonus,
        skill_fail_penalty=body.skill_fail_penalty,
    )
    if not m:
        raise HTTPException(404, "machine not found")
    # notify the live machine page of new settings
    await manager.send_to_machine(machine_id, {"type": "settings", "machine": machine_public(m)})
    await broadcast_state()
    return machine_public(m)


@app.post("/api/machines/{machine_id}/speed")
async def set_machine_speed(machine_id: str, body: SpeedUpdate):
    """Live decode-speed control from the operator dashboard.

    Accepts either an absolute multiplier (speed_multiplier=1.2)
    or a relative nudge in percent points (delta_percent=+10 / -10).
    """
    m = store.get(machine_id)
    if not m:
        raise HTTPException(404, "machine not found")
    if body.speed_multiplier is not None:
        new_mult = body.speed_multiplier
    elif body.delta_percent is not None:
        new_mult = m["speed_multiplier"] + body.delta_percent / 100.0
    else:
        raise HTTPException(400, "speed_multiplier or delta_percent required")
    m = store.update_settings(machine_id, speed_multiplier=new_mult)
    pct = round(m["speed_multiplier"] * 100)
    ev = store.add_event(machine_id, "speed",
                         f"{m['name']} の解読速度を {pct}% に変更しました")
    await manager.send_to_machine(
        machine_id, {"type": "settings", "machine": machine_public(m)})
    await broadcast_event(ev)
    await broadcast_state()
    return machine_public(m)


@app.delete("/api/machines/{machine_id}")
async def delete_machine(machine_id: str):
    m = store.delete(machine_id)
    if not m:
        raise HTTPException(404, "machine not found")
    await manager.send_to_machine(machine_id, {"type": "deleted"})
    store.add_event(machine_id, "deleted", f"{m['name']} を撤去しました")
    await broadcast_state()
    return {"ok": True}


@app.post("/api/machines/{machine_id}/reset")
async def reset_machine(machine_id: str):
    m = store.reset(machine_id)
    if not m:
        raise HTTPException(404, "machine not found")
    await manager.send_to_machine(machine_id, {"type": "reset"})
    store.add_event(machine_id, "reset", f"{m['name']} をリセットしました")
    await broadcast_state()
    return machine_public(m)


@app.get("/api/events")
async def get_events():
    return {"events": store.events[-50:]}


# ---------- REST: sound assets (mp3) ----------
@app.get("/api/sounds")
async def list_sounds():
    return {"sounds": sound_store.list_sounds(), "roles": sound_store.role_map()}


@app.post("/api/sounds")
async def upload_sound(file: UploadFile = File(...), role: str = Form("none")):
    name = file.filename or "sound.mp3"
    if not name.lower().endswith(".mp3"):
        raise HTTPException(400, "mp3ファイルのみアップロードできます")
    data = await file.read()
    try:
        s = sound_store.add(name, data, role)
    except ValueError as e:
        raise HTTPException(400, str(e))
    store.add_event("", "sound", f"サウンド「{s['original_name']}」を追加しました")
    await _notify_sounds()
    return s


@app.patch("/api/sounds/{sound_id}")
async def set_sound_role(sound_id: str, body: SoundRole):
    try:
        s = sound_store.set_role(sound_id, body.role)
    except ValueError as e:
        raise HTTPException(400, str(e))
    if not s:
        raise HTTPException(404, "sound not found")
    await _notify_sounds()
    return s


@app.delete("/api/sounds/{sound_id}")
async def delete_sound(sound_id: str):
    s = sound_store.delete(sound_id)
    if not s:
        raise HTTPException(404, "sound not found")
    await _notify_sounds()
    return {"ok": True}


async def _notify_sounds():
    """Push the latest role->url map to every open machine page + dashboards."""
    payload = {"type": "sounds", "roles": sound_store.role_map()}
    await manager.broadcast_machines(payload)
    await manager.broadcast_dashboards(payload)


# ---------- REST: role pages (chaser / cursed / hunter) ----------
@app.get("/api/roles")
async def get_roles():
    return {"roles": role_store.get_config(),
            "recent_curses": role_store.recent_curses()}


@app.patch("/api/roles/{role}")
async def patch_role(role: str, body: RolePatch):
    block = role_store.update(role, body.model_dump(exclude_none=True))
    if block is None:
        raise HTTPException(404, "role not found")
    await _notify_roles()
    return block


@app.post("/api/roles/cursed/press")
async def press_curse():
    """Curse button pressed -> notify dashboards + hunter phones (with sound)."""
    ev = role_store.record_curse()
    store.add_event("", "curse", ev["message"])
    payload = {"type": "curse", "event": ev}
    await manager.broadcast_dashboards(payload)
    await manager.broadcast_hunters(payload)
    return {"ok": True, "event": ev,
            "cooldown_sec": role_store.get_config()["cursed"]["cooldown_sec"]}


@app.post("/api/roles/cursed/image")
async def upload_curse_image(file: UploadFile = File(...)):
    data = await file.read()
    try:
        url = role_store.save_button_image(file.filename or "", data)
    except ValueError as e:
        raise HTTPException(400, str(e))
    await _notify_roles()
    return {"ok": True, "button_image": url}


@app.delete("/api/roles/cursed/image")
async def delete_curse_image():
    role_store.clear_button_image()
    await _notify_roles()
    return {"ok": True}


async def _notify_roles():
    """Push updated role config to dashboards + hunter phones live."""
    payload = {"type": "roles", "roles": role_store.get_config()}
    await manager.broadcast_dashboards(payload)
    await manager.broadcast_hunters(payload)


# ---------- WebSocket: machine (exclusive) ----------
@app.websocket("/ws/machine/{machine_id}")
async def ws_machine(ws: WebSocket, machine_id: str):
    await ws.accept()
    m = store.get(machine_id)
    if not m:
        await ws.send_json({"type": "error", "reason": "not_found"})
        await ws.close()
        return
    ok = await manager.connect_machine(machine_id, ws)
    if not ok:
        # already open somewhere else -> refuse
        await ws.send_json({"type": "error", "reason": "locked"})
        await ws.close()
        return

    store.set_connected(machine_id, True)
    await ws.send_json({
        "type": "init",
        "machine": machine_public(store.get(machine_id)),
        "sounds": sound_store.role_map(),
    })
    ev = store.add_event(machine_id, "connect", f"{m['name']} がオンラインになりました")
    await broadcast_event(ev)
    await broadcast_state()

    try:
        while True:
            data = await ws.receive_json()
            t = data.get("type")
            if t == "progress":
                st = data.get("status", "decoding")
                prev = store.get(machine_id)
                was_completed = prev and prev["status"] == "completed"
                store.update_progress(machine_id, data.get("progress", 0), st)
                if st == "completed" and not was_completed:
                    ev = store.add_event(
                        machine_id, "completed",
                        f"{m['name']} の解読が完了しました！")
                    await broadcast_event(ev)
                    if store.all_completed():
                        ev2 = store.add_event(
                            machine_id, "all_completed",
                            "全ての暗号機の解読が完了！ゲートが開通しました！")
                        await broadcast_event(ev2)
                await broadcast_state()
            elif t == "skill":
                # skill check result (success / fail) during decoding
                success = bool(data.get("success"))
                store.record_skill(machine_id, success)
                if success:
                    ev = store.add_event(
                        machine_id, "skill_success",
                        f"{m['name']} でスキルチェック成功！")
                else:
                    ev = store.add_event(
                        machine_id, "skill_miss",
                        f"{m['name']} でスキルチェック失敗…進捗が後退")
                await broadcast_event(ev)
                await broadcast_state()
            elif t == "ping":
                await ws.send_json({"type": "pong"})
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        manager.disconnect_machine(machine_id, ws)
        store.set_connected(machine_id, False)
        ev = store.add_event(machine_id, "disconnect", f"{m['name']} がオフラインになりました")
        await broadcast_event(ev)
        await broadcast_state()


# ---------- WebSocket: dashboard ----------
@app.websocket("/ws/dashboard")
async def ws_dashboard(ws: WebSocket):
    await ws.accept()
    await manager.connect_dashboard(ws)
    machines = [machine_public(m) for m in store.list_machines()]
    await ws.send_json({
        "type": "state",
        "machines": machines,
        "all_completed": store.all_completed(),
        "events": store.events[-50:],
    })
    try:
        while True:
            data = await ws.receive_json()
            if data.get("type") == "ping":
                await ws.send_json({"type": "pong"})
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        manager.disconnect_dashboard(ws)


# ---------- WebSocket: hunter phone ----------
@app.websocket("/ws/hunter")
async def ws_hunter(ws: WebSocket):
    await ws.accept()
    await manager.connect_hunter(ws)
    await ws.send_json({
        "type": "init",
        "roles": role_store.get_config(),
        "recent_curses": role_store.recent_curses(),
    })
    try:
        while True:
            data = await ws.receive_json()
            if data.get("type") == "ping":
                await ws.send_json({"type": "pong"})
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        manager.disconnect_hunter(ws)


# ---------- Static sound files ----------
app.mount("/sounds", StaticFiles(directory=SOUNDS_DIR), name="sounds")
app.mount("/role_images", StaticFiles(directory=IMAGES_DIR), name="role_images")


# ---------- Static Flutter web (pre-gzipped + cache headers) ----------
# Extensions worth compressing (text-ish / wasm). Images & fonts skip gzip.
_GZ_EXTS = {".js", ".wasm", ".json", ".html", ".css", ".symbols", ".map", ".txt"}
# Long-cache: content-hashed or version-pinned files that never change in place.
_IMMUTABLE_HINTS = ("canvaskit", "assets/fonts", "assets/FontManifest",
                    "assets/AssetManifest", "assets/NOTICES")


def _pregzip_web_build():
    """Create .gz siblings for heavy static files (idempotent, mtime-aware)."""
    if not os.path.isdir(WEB_DIR):
        return
    total = 0
    for root, _dirs, files in os.walk(WEB_DIR):
        for name in files:
            ext = os.path.splitext(name)[1].lower()
            if ext not in _GZ_EXTS:
                continue
            src = os.path.join(root, name)
            dst = src + ".gz"
            try:
                if (os.path.exists(dst)
                        and os.path.getmtime(dst) >= os.path.getmtime(src)):
                    continue
                if os.path.getsize(src) < 4096:
                    continue  # not worth it
                with open(src, "rb") as f:
                    data = f.read()
                with open(dst, "wb") as f:
                    f.write(gzip.compress(data, compresslevel=7))
                total += 1
            except OSError:
                pass
    if total:
        print(f"[static] pre-gzipped {total} files")


def _static_response(full: str, path: str, request: Request) -> FileResponse:
    """Serve a static file, preferring the .gz sibling when accepted."""
    headers = {}
    # cache policy: index/bootstrap short, hashed assets long
    base = os.path.basename(full)
    if base in ("index.html", "flutter_bootstrap.js", "flutter_service_worker.js",
                "version.json", "manifest.json"):
        headers["Cache-Control"] = "no-cache"
    elif any(h in path for h in _IMMUTABLE_HINTS) or base == "main.dart.js":
        # main.dart.js changes on rebuild; rely on ETag revalidation but allow
        # short-term reuse so repeat visits during the festival are instant.
        headers["Cache-Control"] = "public, max-age=3600, stale-while-revalidate=86400"
    else:
        headers["Cache-Control"] = "public, max-age=600"

    accept = request.headers.get("accept-encoding", "")
    gz = full + ".gz"
    if "gzip" in accept and os.path.isfile(gz):
        media_type = mimetypes.guess_type(full)[0] or "application/octet-stream"
        headers["Content-Encoding"] = "gzip"
        headers["Vary"] = "Accept-Encoding"
        return FileResponse(gz, media_type=media_type, headers=headers)
    return FileResponse(full, headers=headers)


if os.path.isdir(WEB_DIR):

    @app.api_route("/{path:path}", methods=["GET", "HEAD"])
    async def serve_web(path: str, request: Request):
        full = os.path.join(WEB_DIR, path)
        if path and os.path.isfile(full):
            return _static_response(full, path, request)
        # directory index (e.g. /game -> game/index.html)
        if path and os.path.isdir(full):
            idx = os.path.join(full, "index.html")
            if os.path.isfile(idx):
                return _static_response(idx, path + "/index.html", request)
        return _static_response(
            os.path.join(WEB_DIR, "index.html"), "index.html", request)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5060)
