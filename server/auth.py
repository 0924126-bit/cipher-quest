"""Site-wide password authentication for Identity E.

Single shared password (changeable) -> bearer session tokens.

- Password stored as salted SHA-256 in auth.json (never plaintext).
- Login issues a random session token (TTL 7 days), persisted so a
  server restart does not log everyone out mid-festival.
- Every /api/* call (except login/health) and every WebSocket must
  present the token: `Authorization: Bearer <t>` header or `?token=<t>`.
- Password change requires the CURRENT password plus a valid session.
"""
import hashlib
import json
import os
import secrets
import threading
import time

AUTH_FILE = os.path.join(os.path.dirname(__file__), "auth.json")

# Initial password until changed from the secret /#/passkey page.
DEFAULT_PASSWORD = "identity0924"

TOKEN_TTL = 7 * 24 * 3600  # 7 days

_lock = threading.Lock()


def _hash(password: str, salt: str) -> str:
    return hashlib.sha256((salt + ":" + password).encode("utf-8")).hexdigest()


class AuthStore:
    def __init__(self):
        self.salt = ""
        self.pw_hash = ""
        self.tokens = {}  # token -> issued_at (epoch sec)
        self._load()

    # ---------- persistence ----------
    def _load(self):
        with _lock:
            if os.path.isfile(AUTH_FILE):
                try:
                    with open(AUTH_FILE, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    self.salt = data.get("salt", "")
                    self.pw_hash = data.get("pw_hash", "")
                    self.tokens = {
                        t: float(ts)
                        for t, ts in (data.get("tokens") or {}).items()
                    }
                except Exception:
                    pass
            if not self.salt or not self.pw_hash:
                self.salt = secrets.token_hex(16)
                self.pw_hash = _hash(DEFAULT_PASSWORD, self.salt)
                self._save_locked()

    def _save_locked(self):
        try:
            tmp = AUTH_FILE + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(
                    {
                        "salt": self.salt,
                        "pw_hash": self.pw_hash,
                        "tokens": self.tokens,
                    },
                    f,
                )
            os.replace(tmp, AUTH_FILE)
        except Exception:
            pass

    # ---------- password ----------
    def check_password(self, password: str) -> bool:
        return secrets.compare_digest(_hash(password, self.salt), self.pw_hash)

    def change_password(self, old: str, new: str) -> bool:
        if not self.check_password(old):
            return False
        if not new or len(new) < 4:
            return False
        with _lock:
            self.salt = secrets.token_hex(16)
            self.pw_hash = _hash(new, self.salt)
            # revoke every existing session so old holders must re-enter
            self.tokens = {}
            self._save_locked()
        return True

    # ---------- sessions ----------
    def issue_token(self) -> str:
        token = secrets.token_urlsafe(32)
        with _lock:
            now = time.time()
            # prune expired
            self.tokens = {
                t: ts for t, ts in self.tokens.items()
                if now - ts < TOKEN_TTL
            }
            self.tokens[token] = now
            self._save_locked()
        return token

    def check_token(self, token) -> bool:
        if not token or not isinstance(token, str):
            return False
        ts = self.tokens.get(token)
        if ts is None:
            return False
        if time.time() - ts > TOKEN_TTL:
            with _lock:
                self.tokens.pop(token, None)
                self._save_locked()
            return False
        return True


auth_store = AuthStore()


def token_from_request(request) -> str:
    """Extract bearer token from an HTTP request (header or query)."""
    header = request.headers.get("authorization", "")
    if header.lower().startswith("bearer "):
        return header[7:].strip()
    return request.query_params.get("token", "")


def token_from_ws(ws) -> str:
    """Extract token from a WebSocket handshake (query param)."""
    try:
        return ws.query_params.get("token", "")
    except Exception:
        return ""
