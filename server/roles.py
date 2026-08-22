"""Role pages config store (chaser / cursed / hunter) for the festival.

Three extra experiences besides cipher machines:
- chaser : big alarm button, plays a siren for N seconds (like a personal
           security buzzer). Role title shown on screen is configurable.
- cursed : one-shot curse button with an operator-set cooldown. Button
           face can be replaced with an uploaded image. Every press
           notifies the operator dashboard and all hunter phones (sound).
- hunter : phone page for staff playing the hunter; receives curse
           notifications with sound + vibration.

All settings live in roles.json next to data.json and are editable live
from the operator dashboard.
"""
import json
import os
import threading
import time
import uuid

ROLES_FILE = os.path.join(os.path.dirname(__file__), "roles.json")
IMAGES_DIR = os.path.join(os.path.dirname(__file__), "role_images")
MAX_IMAGE_BYTES = 8 * 1024 * 1024  # 8 MB
ALLOWED_IMAGE_EXT = (".png", ".jpg", ".jpeg", ".webp", ".gif")

_lock = threading.Lock()


def _now_ms() -> int:
    return int(time.time() * 1000)


DEFAULTS = {
    "chaser": {
        "title": "あなたはチェイサーです",
        "subtitle": "ボタンを押すと大音量の警報が鳴り響く",
        "alarm_sec": 30,          # how long the siren plays (operator adjustable)
    },
    "cursed": {
        "title": "あなたは呪術師です",
        "subtitle": "呪いの刻印に触れよ…",
        "cooldown_sec": 30,       # wait between presses (operator adjustable)
        "button_image": "",       # /role_images/xxx.png ("" = built-in scary button)
        "notify_message": "呪術師が呪いを発動した！",
    },
    "hunter": {
        "title": "ハンター通知端末",
    },
}


class RoleStore:
    def __init__(self):
        self.config = json.loads(json.dumps(DEFAULTS))  # deep copy
        self.curse_events = []  # recent curse presses (for hunter page catch-up)
        os.makedirs(IMAGES_DIR, exist_ok=True)
        self._load()

    # ---------- persistence ----------
    def _load(self):
        if os.path.exists(ROLES_FILE):
            try:
                with open(ROLES_FILE, "r", encoding="utf-8") as f:
                    saved = json.load(f)
                for role, defaults in DEFAULTS.items():
                    block = saved.get(role, {})
                    merged = dict(defaults)
                    for k in defaults:
                        if k in block:
                            merged[k] = block[k]
                    self.config[role] = merged
            except Exception:
                pass

    def _save(self):
        try:
            with open(ROLES_FILE, "w", encoding="utf-8") as f:
                json.dump(self.config, f, ensure_ascii=False, indent=1)
        except Exception:
            pass

    # ---------- config ----------
    def get_config(self) -> dict:
        with _lock:
            return json.loads(json.dumps(self.config))

    def update(self, role: str, patch: dict) -> dict | None:
        """Patch one role's settings (only known keys, clamped)."""
        with _lock:
            if role not in self.config:
                return None
            block = self.config[role]
            for k, v in patch.items():
                if k not in block or v is None:
                    continue
                if k in ("alarm_sec", "cooldown_sec"):
                    try:
                        block[k] = max(3, min(600, int(v)))
                    except (TypeError, ValueError):
                        continue
                elif isinstance(block[k], str):
                    block[k] = str(v)[:200]
            self._save()
            return json.loads(json.dumps(block))

    # ---------- curse button image ----------
    @staticmethod
    def _shrink_image(data: bytes, ext: str) -> tuple:
        """Downscale big photos to <=512px WebP so phones load them fast.

        Returns (new_data, new_ext). Falls back to the original bytes if
        Pillow is unavailable or the image can't be parsed.
        """
        try:
            import io
            from PIL import Image
            img = Image.open(io.BytesIO(data))
            img.load()
            # keep small images as-is
            if max(img.size) <= 512 and len(data) <= 300 * 1024:
                return data, ext
            img.thumbnail((512, 512), Image.LANCZOS)
            if img.mode not in ("RGB", "RGBA"):
                img = img.convert("RGBA")
            out = io.BytesIO()
            img.save(out, format="WEBP", quality=85, method=4)
            return out.getvalue(), ".webp"
        except Exception:
            return data, ext

    def save_button_image(self, filename: str, data: bytes) -> str:
        ext = os.path.splitext(filename or "")[1].lower()
        if ext not in ALLOWED_IMAGE_EXT:
            raise ValueError("png / jpg / webp / gif の画像のみ使用できます")
        if len(data) > MAX_IMAGE_BYTES:
            raise ValueError("画像は8MB以下にしてください")
        # The button renders at ~250px; shrink huge camera photos so phones
        # don't download megabytes for a small circle. GIFs keep animation.
        if ext != ".gif":
            data, ext = self._shrink_image(data, ext)
        with _lock:
            # remove previous uploaded image files
            for old in os.listdir(IMAGES_DIR):
                try:
                    os.remove(os.path.join(IMAGES_DIR, old))
                except OSError:
                    pass
            name = f"curse_{uuid.uuid4().hex[:8]}{ext}"
            with open(os.path.join(IMAGES_DIR, name), "wb") as f:
                f.write(data)
            url = f"/role_images/{name}"
            self.config["cursed"]["button_image"] = url
            self._save()
            return url

    def clear_button_image(self):
        with _lock:
            for old in os.listdir(IMAGES_DIR):
                try:
                    os.remove(os.path.join(IMAGES_DIR, old))
                except OSError:
                    pass
            self.config["cursed"]["button_image"] = ""
            self._save()

    # ---------- curse events ----------
    def record_curse(self) -> dict:
        with _lock:
            ev = {
                "id": uuid.uuid4().hex[:8],
                "at": _now_ms(),
                "message": self.config["cursed"]["notify_message"],
            }
            self.curse_events.append(ev)
            self.curse_events = self.curse_events[-30:]
            return ev

    def recent_curses(self, limit: int = 10) -> list:
        with _lock:
            return list(self.curse_events[-limit:])


role_store = RoleStore()
