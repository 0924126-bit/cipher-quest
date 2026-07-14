"""WebSocket connection manager.

- Machine sockets: strictly ONE connection per machine id (exclusive lock).
- Dashboard sockets: unlimited, receive broadcast of all machine states.
"""
import json
from typing import Dict, Set
from fastapi import WebSocket


class ConnectionManager:
    def __init__(self):
        self.machine_sockets: Dict[str, WebSocket] = {}
        self.dashboard_sockets: Set[WebSocket] = set()

    # ---------- machine side ----------
    def is_machine_connected(self, machine_id: str) -> bool:
        return machine_id in self.machine_sockets

    async def connect_machine(self, machine_id: str, ws: WebSocket) -> bool:
        """Returns False if the machine page is already open elsewhere."""
        if machine_id in self.machine_sockets:
            return False
        self.machine_sockets[machine_id] = ws
        return True

    def disconnect_machine(self, machine_id: str, ws: WebSocket):
        if self.machine_sockets.get(machine_id) is ws:
            del self.machine_sockets[machine_id]

    async def send_to_machine(self, machine_id: str, payload: dict):
        ws = self.machine_sockets.get(machine_id)
        if ws is not None:
            try:
                await ws.send_text(json.dumps(payload, ensure_ascii=False))
            except Exception:
                pass

    # ---------- dashboard side ----------
    async def connect_dashboard(self, ws: WebSocket):
        self.dashboard_sockets.add(ws)

    def disconnect_dashboard(self, ws: WebSocket):
        self.dashboard_sockets.discard(ws)

    async def broadcast_dashboards(self, payload: dict):
        text = json.dumps(payload, ensure_ascii=False)
        dead = []
        for ws in self.dashboard_sockets:
            try:
                await ws.send_text(text)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.dashboard_sockets.discard(ws)


manager = ConnectionManager()
