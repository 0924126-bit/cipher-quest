"""FastAPI routes for the 3D game: player WS, admin REST, countdown pump."""
import asyncio
import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from .config import game_config as gc
from .match import match

router = APIRouter()


# --------------------------------------------------------------------------
# REST: status & admin controls
# --------------------------------------------------------------------------
@router.get("/api/game/status")
async def game_status():
    return match.admin_snapshot()


class GameConfigBody(BaseModel):
    difficulty: float | None = None
    auto_start: bool | None = None


@router.patch("/api/game/config")
async def set_game_config(body: GameConfigBody):
    if body.difficulty is not None:
        gc.difficulty = max(0.0, min(1.0, float(body.difficulty)))
    if body.auto_start is not None:
        gc.auto_start = bool(body.auto_start)
    gc.save()
    await match.notify_spectators()
    return gc.as_dict()


@router.post("/api/game/force_start")
async def force_start():
    """Admin: start the match immediately (bots fill empty slots)."""
    if match.phase in ("lobby", "countdown"):
        await match.start_match()
    return match.admin_snapshot()


@router.post("/api/game/force_end")
async def force_end():
    """Admin: abort a running match."""
    if match.phase == "running":
        match.match_end_at = 0  # loop will detect time_up next tick
    return match.admin_snapshot()


# --------------------------------------------------------------------------
# WebSocket: game players
# --------------------------------------------------------------------------
@router.websocket("/ws/game")
async def ws_game(ws: WebSocket):
    await ws.accept()
    player = None
    try:
        # first message must be {"type":"join","name":...}
        raw = await ws.receive_text()
        data = json.loads(raw)
        if data.get("type") != "join":
            await ws.send_text(json.dumps({"type": "error", "reason": "bad_join"}))
            await ws.close()
            return

        player = await match.join(ws, str(data.get("name", "")))
        if player is None:
            # match running or full -> wait mode (no mid-join)
            await ws.send_text(json.dumps({
                "type": "wait",
                "reason": "match_running" if match.phase == "running" else "full",
                "status": match.admin_snapshot(),
            }, ensure_ascii=False))
            # keep socket open; push status until joinable, then auto-join
            while True:
                try:
                    msg = await asyncio.wait_for(ws.receive_text(), timeout=2.0)
                    d = json.loads(msg)
                    if d.get("type") == "leave":
                        await ws.close()
                        return
                except asyncio.TimeoutError:
                    pass
                if match.can_join():
                    player = await match.join(ws, str(data.get("name", "")))
                    if player:
                        break
                await ws.send_text(json.dumps({
                    "type": "wait",
                    "reason": "match_running" if match.phase == "running" else "full",
                    "status": match.admin_snapshot(),
                }, ensure_ascii=False))

        await ws.send_text(json.dumps({
            "type": "joined", "token": player.token,
            **match.lobby_snapshot(),
        }, ensure_ascii=False))
        await match.notify_spectators()

        # main input loop
        while True:
            raw = await ws.receive_text()
            d = json.loads(raw)
            t = d.get("type")
            if t == "input" and player.survivor_id:
                s = match._survivor(player.survivor_id)
                if s and s.state == "alive":
                    s.in_x = float(d.get("x", 0))
                    s.in_z = float(d.get("z", 0))
                    s.in_decode = bool(d.get("decode", False))
            elif t == "skill" and player.survivor_id:
                match.handle_skill_reply(
                    player.survivor_id, int(d.get("seq", -1)),
                    bool(d.get("success")), bool(d.get("great")))
            elif t == "ping":
                await ws.send_text('{"type":"pong"}')
    except (WebSocketDisconnect, Exception):
        pass
    finally:
        if player is not None:
            await match.leave(player.token)
            await match.notify_spectators()


# --------------------------------------------------------------------------
# WebSocket: game spectators (dashboard live status)
# --------------------------------------------------------------------------
@router.websocket("/ws/game/spectate")
async def ws_game_spectate(ws: WebSocket):
    await ws.accept()
    match.spectators.append(ws)
    await ws.send_text(json.dumps(
        {"type": "game_status", **match.admin_snapshot()}, ensure_ascii=False))
    try:
        while True:
            raw = await ws.receive_text()
            d = json.loads(raw)
            if d.get("type") == "ping":
                await ws.send_text('{"type":"pong"}')
    except (WebSocketDisconnect, Exception):
        pass
    finally:
        try:
            match.spectators.remove(ws)
        except ValueError:
            pass


# --------------------------------------------------------------------------
# background pump: lobby countdown / spectator heartbeat
# --------------------------------------------------------------------------
async def pump_loop():
    while True:
        try:
            await match.pump()
            await match.notify_spectators()
        except Exception as e:
            print("pump error:", e)
        await asyncio.sleep(1.0)
