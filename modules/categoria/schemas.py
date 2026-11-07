import re
import unicodedata

from pydantic import BaseModel, field_validator

SIGLA_MENSAGEM = "A sigla deve ter exatamente 3 letras (ex.: INF)."


def normalizar_sigla(texto: str) -> str:
    """Tira acentos e espaços e passa para maiúsculas: "inf " e "Ínf" viram "INF"."""
    sem_acento = unicodedata.normalize("NFKD", texto or "")
    return "".join(c for c in sem_acento if not unicodedata.combining(c)).upper().strip()


class Categoria(BaseModel):
    id: int
    nome: str
    sigla: str
    ativo: bool


class CategoriaCreate(BaseModel):
    nome: str
    sigla: str

    @field_validator("nome")
    @classmethod
    def _nome(cls, valor: str) -> str:
        valor = (valor or "").strip()
        if len(valor) < 2:
            raise ValueError("Informe o nome da categoria.")
        if len(valor) > 100:
            raise ValueError("O nome da categoria pode ter no máximo 100 caracteres.")
        return valor

    @field_validator("sigla")
    @classmethod
    def _sigla(cls, valor: str) -> str:
        # A sigla é o prefixo do tombo (ex.: INF-001-0): três letras, sem números nem símbolos.
        valor = normalizar_sigla(valor)
        if not re.fullmatch(r"[A-Z]{3}", valor):
            raise ValueError(SIGLA_MENSAGEM)
        return valor
