import uuid
from pathlib import Path

from fastapi import HTTPException

from core import config
from modules.foto.repository import FotoRepository

FORMATOS = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}


def detectar_formato(dados: bytes) -> str | None:
    """Identifica o formato pelo conteúdo do arquivo, não pelo nome ou cabeçalho enviado."""
    if dados.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if dados.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if len(dados) >= 12 and dados[:4] == b"RIFF" and dados[8:12] == b"WEBP":
        return "image/webp"
    return None


def _pasta() -> Path:
    return Path(config.FOTOS_DIR)


class FotoService:
    def __init__(self, repository: FotoRepository | None = None):
        self.repository = repository or FotoRepository()

    def registrar(self, dados: bytes, registro_tipo: str, registro_id: int, usuario: dict) -> dict:
        if not dados:
            raise HTTPException(status_code=400, detail="Arquivo vazio. Envie uma foto.")
        if len(dados) > config.FOTO_MAX_BYTES:
            limite = config.FOTO_MAX_BYTES // (1024 * 1024)
            raise HTTPException(
                status_code=413,
                detail=f"Foto muito grande. O limite é {limite} MB por arquivo.",
            )
        formato = detectar_formato(dados)
        if formato is None:
            raise HTTPException(
                status_code=415,
                detail="Formato não suportado. Envie uma foto em JPEG, PNG ou WebP.",
            )

        nome = f"{uuid.uuid4().hex}{FORMATOS[formato]}"
        destino = _pasta() / nome
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_bytes(dados)
        try:
            return self.repository.inserir(registro_tipo, registro_id, nome, formato, len(dados), usuario["id"])
        except Exception:
            # Sem registro no banco, o arquivo não pode ficar órfão no disco.
            destino.unlink(missing_ok=True)
            raise

    def listar(self, registro_tipo: str, registro_id: int) -> list[dict]:
        return self.repository.listar(registro_tipo, registro_id)

    def arquivo_da_foto(self, foto_id: int) -> tuple[dict, Path]:
        foto = self.repository.buscar(foto_id)
        if foto is None:
            raise HTTPException(status_code=404, detail=f"Foto com id {foto_id} não encontrada")
        caminho = _pasta() / foto.pop("arquivo")
        if not caminho.is_file():
            raise HTTPException(status_code=404, detail="Arquivo da foto não está disponível no servidor")
        return foto, caminho
