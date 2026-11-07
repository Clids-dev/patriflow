"""Caixa de pendências do setor de patrimônio: o que precisa de decisão humana.

Nasce do fechamento do inventário (bem não localizado, bem não cadastrado) e dos conflitos da
sincronização do aplicativo. Resolver exige dizer o que foi feito, e a resolução fica registrada;
a pendência não pode ser reaberta nem apagada.
"""
from fastapi import HTTPException

from modules.pendencia.repository import PendenciaRepository

ADMIN = "setor_patrimonio"


class PendenciaService:
    def __init__(self, repository: PendenciaRepository | None = None):
        self.repo = repository or PendenciaRepository()

    def listar(self, situacao: str):
        return self.repo.listar(situacao)

    def resolver(self, pendencia_id: int, resolucao: str, usuario: dict):
        if usuario["perfil"] != ADMIN:
            raise HTTPException(status_code=403, detail="Somente o setor de patrimônio resolve pendências.")
        if self.repo.buscar(pendencia_id) is None:
            raise HTTPException(status_code=404, detail=f"Pendência com id {pendencia_id} não encontrada")
        # A atualização só acontece se ainda estiver aberta: duas resoluções simultâneas não se sobrepõem.
        if not self.repo.resolver(pendencia_id, usuario["id"], resolucao):
            raise HTTPException(status_code=409, detail="Esta pendência já foi resolvida.")
        return self.repo.buscar(pendencia_id)
