"""Sound asset management for Cipher Quest.

Operators upload mp3 files from the dashboard and assign each file a role:

  rhythm    - music played during the rhythm-game decode challenge
  decode    - loop played while a machine is being decoded (hold)
  complete  - one-shot fanfare when a machine reaches 100%

Files live in server/sounds/ and are served at /sounds/{stored_name}.
Metadata is persisted to server/sounds/sounds.json so uploads survive
server restarts. Only one sound may hold a given role at a time.
"""
import json
import os
import re
import threading
import time
import uuid

SOUNDS_DIR = os.path.join(os.path.dirname(__file__), "sounds")
META_FILE = os.path.join(SOUNDS_DIR, "sounds.json")

VALID_ROLES = ("rhythm", "decode", "complete", "none")
MAX_FILE_BYTES = 15 * 1024 * 1024  # 15 MB per mp3

_lock = threading.Lock()


def _safe_name(name: str) -> str:
    """Keep a readable but filesystem-safe version of the original name."""
    base = os.path.basename(name or "sound.mp3")
    base = re.sub(r"[^\w.\-ぁ-んァ-ヶ一-龠ー]", "_", base)
    if not base.lower().endswith(".mp3"):
        base += ".mp3"
    return base[:80]


class SoundStore:
    def __init__(self):
        os.makedirs(SOUNDS_DIR, exist_ok=True)
        self.sounds = {}  # id -> dict
        self._load()

    # ---------- persistence ----------
    def _load(self):
        if os.path.exists(META_FILE):
            try:
                with open(META_FILE, "r", encoding="utf-8") as f:
                    self.sounds = json.load(f).get("sounds", {})
                # drop records whose file vanished
                self.sounds = {
                    sid: s for sid, s in self.sounds.items()
                    if os.path.exists(os.path.join(SOUNDS_DIR, s["stored_name"]))
                }
            except Exception:
                self.sounds = {}

    def _save(self):
        try:
            with open(META_FILE, "w", encoding="utf-8") as f:
                json.dump({"sounds": self.sounds}, f, ensure_ascii=False, indent=1)
        except Exception:
            pass

    # ---------- API ----------
    def list_sounds(self):
        with _lock:
            return sorted(self.sounds.values(), key=lambda s: s["created_at"])

    def role_map(self):
        """role -> public url for every assigned role."""
        with _lock:
            out = {}
            for s in self.sounds.values():
                if s["role"] in ("rhythm", "decode", "complete"):
                    out[s["role"]] = f"/sounds/{s['stored_name']}"
            return out

    def add(self, original_name: str, data: bytes, role: str = "none"):
        if len(data) > MAX_FILE_BYTES:
            raise ValueError("file too large (max 15MB)")
        if len(data) < 128:
            raise ValueError("file too small")
        role = role if role in VALID_ROLES else "none"
        with _lock:
            sid = uuid.uuid4().hex[:8]
            stored = f"{sid}_{_safe_name(original_name)}"
            with open(os.path.join(SOUNDS_DIR, stored), "wb") as f:
                f.write(data)
            if role != "none":
                self._clear_role(role)
            self.sounds[sid] = {
                "id": sid,
                "original_name": original_name or stored,
                "stored_name": stored,
                "size": len(data),
                "role": role,
                "created_at": int(time.time() * 1000),
            }
            self._save()
            return self.sounds[sid]

    def set_role(self, sound_id: str, role: str):
        if role not in VALID_ROLES:
            raise ValueError("invalid role")
        with _lock:
            s = self.sounds.get(sound_id)
            if not s:
                return None
            if role != "none":
                self._clear_role(role)
            s["role"] = role
            self._save()
            return s

    def delete(self, sound_id: str):
        with _lock:
            s = self.sounds.pop(sound_id, None)
            if s:
                try:
                    os.remove(os.path.join(SOUNDS_DIR, s["stored_name"]))
                except OSError:
                    pass
                self._save()
            return s

    def _clear_role(self, role: str):
        """Un-assign `role` from any sound currently holding it (caller locks)."""
        for s in self.sounds.values():
            if s["role"] == role:
                s["role"] = "none"


sound_store = SoundStore()
