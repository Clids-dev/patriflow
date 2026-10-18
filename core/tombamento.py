import re

from fastapi import HTTPException


INVALID_TOMBO_MESSAGE = "Número de tombo inválido — verifique a digitação"
_TOMBO_PATTERN = re.compile(r"^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*-[0-9]$")


def calculate_check_digit(base: str) -> str:
    """Calculate a Mod 11 digit for an alphanumeric code, ignoring separators."""
    normalized = re.sub(r"[^A-Za-z0-9]", "", base).upper()
    if not normalized:
        raise ValueError("A base do tombo não pode ser vazia")

    total = 0
    weight = 2
    for character in reversed(normalized):
        value = int(character) if character.isdigit() else ord(character) - ord("A") + 10
        total += value * weight
        weight = 2 if weight == 9 else weight + 1

    digit = (11 - total % 11) % 11
    return str(digit if digit < 10 else 0)


def format_tombo(base: str) -> str:
    base = base.rstrip("-")
    return f"{base}-{calculate_check_digit(base)}"


def is_valid_tombo(code: str) -> bool:
    if not isinstance(code, str) or not _TOMBO_PATTERN.fullmatch(code):
        return False
    base, check_digit = code.rsplit("-", 1)
    return calculate_check_digit(base) == check_digit


def require_valid_tombo(code: str) -> None:
    if not is_valid_tombo(code):
        raise HTTPException(status_code=400, detail=INVALID_TOMBO_MESSAGE)
