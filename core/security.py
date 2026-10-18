"""Password hashing and small HS256 JWT implementation (stdlib only)."""
import base64
import hashlib
import hmac
import json
import os
import time

ITERATIONS = 310_000


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, ITERATIONS)
    return f"pbkdf2_sha256${ITERATIONS}${_b64(salt)}${_b64(digest)}"


def verify_password(password: str, encoded: str) -> bool:
    try:
        scheme, rounds, salt, expected = encoded.split("$")
        if scheme != "pbkdf2_sha256":
            return False
        actual = hashlib.pbkdf2_hmac("sha256", password.encode(), _unb64(salt), int(rounds))
        return hmac.compare_digest(actual, _unb64(expected))
    except (ValueError, TypeError):
        return False


def create_access_token(user: dict, secret: str, expires_seconds: int = 3600) -> str:
    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {"sub": str(user["id"]), "iat": now, "exp": now + expires_seconds}
    signing_input = f"{_encode_json(header)}.{_encode_json(payload)}"
    signature = hmac.new(secret.encode(), signing_input.encode(), hashlib.sha256).digest()
    return f"{signing_input}.{_b64(signature)}"


def decode_access_token(token: str, secret: str) -> dict:
    header, payload, signature = token.split(".")
    signing_input = f"{header}.{payload}"
    expected = hmac.new(secret.encode(), signing_input.encode(), hashlib.sha256).digest()
    if not hmac.compare_digest(expected, _unb64(signature)):
        raise ValueError("invalid signature")
    claims = json.loads(_unb64(payload))
    if claims.get("exp", 0) <= int(time.time()) or not claims.get("sub"):
        raise ValueError("expired or invalid token")
    return claims


def _b64(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode()


def _unb64(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def _encode_json(value: dict) -> str:
    return _b64(json.dumps(value, separators=(",", ":")).encode())
