"""Manutenção de bens: envio (problema e destino) e retorno (serviço realizado e novo estado).

Enquanto está fora, o bem fica com status "Manutenção" e não pode ser transferido nem emprestado.
No retorno, o bem volta ao status que tinha antes do envio e recebe o novo estado de conservação.
O bem continua sob a guarda do setor de origem (a localização não muda).
"""
from fastapi import HTTPException

from core.database import DataBase
from modules.auditoria.service import registrar_acao
from modules.bem import guarda
from modules.manutencao.repository import ManutencaoRepository
from modules.manutencao.schemas import ManutencaoCreate, Retorno

STATUS_PADRAO = "Disponível"


class ManutencaoService:
    def __init__(self, repository: ManutencaoRepository | None = None):
        self.repo = repository or ManutencaoRepository()

    def enviar(self, dados: ManutencaoCreate, usuario: dict):
        with DataBase().transacao() as cur:
            bem = guarda.travar_bem(cur, dados.bem_id)
            guarda.exigir_guarda(cur, usuario, bem["id"])
            # Bens marcados como "Manutenção" pela edição antiga, sem registro aberto, podem ser registrados.
            guarda.exigir_livre(cur, bem, aceitar_status_manutencao=True)
            anterior = bem["status"] if bem["status"] != guarda.STATUS_MANUTENCAO else STATUS_PADRAO
            manutencao_id = self.repo.inserir(cur, dados, anterior, usuario["id"])
            self.repo.atualizar_bem(cur, bem["id"], guarda.STATUS_MANUTENCAO)
            registrar_acao("bem", bem["id"], "enviar_manutencao", usuario, {"status": bem["status"]},
                           {"status": guarda.STATUS_MANUTENCAO, "manutencao_id": manutencao_id}, cur=cur)
        return self.repo.buscar(manutencao_id)

    def registrar_retorno(self, manutencao_id: int, dados: Retorno, usuario: dict):
        with DataBase().transacao() as cur:
            atual = self.repo.travar(cur, manutencao_id)
            if atual is None:
                raise HTTPException(status_code=404, detail=f"Manutenção com id {manutencao_id} não encontrada")
            bem_id, retorno_em, status_anterior = atual
            if retorno_em is not None:
                raise HTTPException(status_code=409, detail="O retorno desta manutenção já foi registrado.")
            bem = guarda.travar_bem(cur, bem_id)
            guarda.exigir_guarda(cur, usuario, bem_id)
            self.repo.encerrar(cur, manutencao_id, usuario["id"], dados)
            self.repo.atualizar_bem(cur, bem_id, status_anterior, dados.estado_retorno)
            registrar_acao("bem", bem_id, "retorno_manutencao", usuario,
                           {"status": bem["status"], "estado_conservacao": bem["estado_conservacao"]},
                           {"status": status_anterior, "estado_conservacao": dados.estado_retorno,
                            "manutencao_id": manutencao_id}, cur=cur)
        return self.repo.buscar(manutencao_id)

    def listar(self, situacao: str, bem_id: int | None):
        return self.repo.listar(situacao, bem_id)

    def buscar(self, manutencao_id: int):
        manutencao = self.repo.buscar(manutencao_id)
        if manutencao is None:
            raise HTTPException(status_code=404, detail=f"Manutenção com id {manutencao_id} não encontrada")
        return manutencao
