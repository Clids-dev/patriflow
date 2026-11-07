from fastapi import HTTPException
from psycopg2 import errors

from modules.categoria.repository import CategoriaRepository
from modules.categoria.schemas import Categoria, CategoriaCreate


class CategoriaService:
    def __init__(self, repository: CategoriaRepository = None):
        self.repository = repository or CategoriaRepository()

    def get_categorias(self, incluir_inativas: bool = False) -> list[Categoria]:
        return self.repository.get_all(incluir_inativas)

    def create_categoria(self, categoria: CategoriaCreate) -> Categoria:
        try:
            return self.repository.save(categoria)
        except errors.UniqueViolation:
            raise HTTPException(status_code=409, detail=f"A sigla {categoria.sigla} já está em uso")

    def get_categoria_id(self, id: int) -> Categoria:
        """Ficha da categoria, ativa ou não (a tela mostra a situação)."""
        return self._existente(self.repository.get_id(id, incluir_inativa=True), id)

    def renomear(self, id: int, novo_nome: str) -> Categoria:
        """Só o nome muda: a sigla é o prefixo dos tombos já emitidos."""
        novo_nome = (novo_nome or "").strip()
        if len(novo_nome) < 2 or len(novo_nome) > 100:
            raise HTTPException(status_code=400, detail="O nome da categoria deve ter de 2 a 100 caracteres.")
        return self._existente(self.repository.renomear(id, novo_nome), id)

    def delete_categoria(self, id: int) -> Categoria:
        """Inativa (nada é apagado). Bens já cadastrados continuam com a categoria; novos não podem usá-la."""
        return self._existente(self.repository.delete(id), id)

    def reativar(self, id: int) -> Categoria:
        return self._existente(self.repository.reativar(id), id)

    @staticmethod
    def _existente(categoria: Categoria | None, id: int) -> Categoria:
        if categoria is None:
            raise HTTPException(status_code=404, detail=f"Categoria com id {id} não encontrada")
        return categoria
