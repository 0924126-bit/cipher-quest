"""Game tuning constants + admin-adjustable CPU difficulty.

Difficulty is a float 0.0 (very easy) .. 1.0 (nightmare), persisted to
game_config.json so it survives restarts. All derived hunter/bot stats
are computed from it here, in one place.
"""
import json
import os
import threading

CONFIG_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "game_config.json")
_lock = threading.Lock()

# ---------- static match rules ----------
TICK_RATE = 20              # server simulation Hz
SNAPSHOT_RATE = 10          # state broadcast Hz
MAX_SURVIVORS = 4
MATCH_TIME_SEC = 300        # 5 min hard limit
LOBBY_COUNTDOWN_SEC = 15    # auto start countdown once >=1 player
RESULT_SCREEN_SEC = 12
CIPHERS_REQUIRED = 5
DECODE_TIME_SEC = 18        # per cipher, one survivor
DECODE_RADIUS = 2.2
ATTACK_RADIUS = 1.8
GATE_RADIUS = 2.5
SURVIVOR_SPEED = 6.0        # m/s
SURVIVOR_HIT_BOOST = 1.5    # speed multiplier after being hit
HIT_BOOST_SEC = 3.0
SURVIVOR_HP = 2
PLAYER_TIMEOUT_SEC = 6      # drop silent players


class GameConfig:
    def __init__(self):
        self.difficulty = 0.5   # 0..1
        self.auto_start = True
        self._load()

    # ---------- persistence ----------
    def _load(self):
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    d = json.load(f)
                self.difficulty = float(d.get("difficulty", 0.5))
                self.auto_start = bool(d.get("auto_start", True))
            except Exception:
                pass

    def save(self):
        with _lock:
            try:
                with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                    json.dump({"difficulty": self.difficulty,
                               "auto_start": self.auto_start}, f)
            except Exception:
                pass

    # ---------- derived stats (all from difficulty d) ----------
    @property
    def hunter_speed(self) -> float:
        # easy 5.6 .. hard 7.6  (survivor = 6.0)
        return 5.6 + 2.0 * self.difficulty

    @property
    def hunter_vision(self) -> float:
        # detection radius in meters
        return 10.0 + 14.0 * self.difficulty

    @property
    def hunter_attack_cooldown(self) -> float:
        return 2.6 - 1.2 * self.difficulty

    @property
    def bot_decode_mult(self) -> float:
        """CPU survivor decode speed vs human (they help less on hard)."""
        return 1.0 - 0.45 * self.difficulty

    @property
    def bot_flee_skill(self) -> float:
        """0..1 how well CPU survivors dodge the hunter."""
        return 0.35 + 0.5 * (1 - self.difficulty)

    def as_dict(self) -> dict:
        return {
            "difficulty": self.difficulty,
            "auto_start": self.auto_start,
            "hunter_speed": round(self.hunter_speed, 2),
            "hunter_vision": round(self.hunter_vision, 1),
            "hunter_attack_cooldown": round(self.hunter_attack_cooldown, 2),
        }


game_config = GameConfig()
