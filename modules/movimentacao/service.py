from datetime import datetime
from fastapi import HTTPException
from psycopg2 import errors

from modules.setor.repository import SetorRepository
from modules.bem.repository import BemRepository
from modules.movimentacao.repository import MovimentacaoRepository
from modules.movimentacao.schemas import MovimentacaoCreate
from core.tombamento import require_valid_tombo


ROLE_ADMIN = "setor_patrimonio"
ROLE_RESPONSAVEL = "responsavel_setor"


class MovimentacaoService:
    def get_movimentacoes(self):
        return MovimentacaoRepository().get_all()

    def get_detailed_movimentacoes(self):
        return MovimentacaoRepository().get_detailed()

    def get_movimentacoes_por_bem(self, codigo: str):
        require_valid_tombo(codigo)
        return MovimentacaoRepository().get_by_bem_codigo(codigo)

    def get_movimentacao_by_id(self, id: int):
        return MovimentacaoRepository().get_id(id)

    def listar_pendentes(self):
        return MovimentacaoRepository().get_pendentes()

    def add_movimentacao(self, movimentacao: MovimentacaoCreate, usuario: dict):
        """Registra uma movimentação aplicando as regras de almoxarifado.

        - Administradores (setor de patrimônio) movimentam diretamente.
        - Demais perfis só podem solicitar movimentações entre o almoxarifado
          e o próprio setor. Essas solicitações ficam 'pendentes' até decisão.
        """
        if movimentacao.bem_id <= 0 or movimentacao.setor_destino_id <= 0:
            raise HTTPException(status_code=400, detail="IDs devem ser números positivos.")

        if movimentacao.setor_origem_id is not None and movimentacao.setor_origem_id == movimentacao.setor_destino_id:
            raise HTTPException(status_code=400, detail="Setor de origem e destino não podem ser iguais.")

        bem = BemRepository().get_by_id(movimentacao.bem_id)
        if bem is None:
            raise HTTPException(status_code=404, detail=f"Bem com id {movimentacao.bem_id} não encontrado")

        if not bem.ativo:
            raise HTTPException(status_code=400, detail="Este bem está baixado/inativo e não pode ser movimentado.")

        if bem.status.lower() in ("manutenção", "manutencao"):
            if not movimentacao.justificativa or "concluído" not in movimentacao.justificativa.lower():
                raise HTTPException(
                    status_code=400,
                    detail="Equipamentos em manutenção não podem ser movimentados sem a conclusão do reparo (informe na justificativa)."
                )

        setor_repository = SetorRepository()
        if movimentacao.setor_origem_id is not None and setor_repository.get_id(movimentacao.setor_origem_id) is None:
            raise HTTPException(status_code=404, detail=f"Setor de origem com id {movimentacao.setor_origem_id} não encontrado")
        if setor_repository.get_id(movimentacao.setor_destino_id) is None:
            raise HTTPException(status_code=404, detail=f"Setor de destino com id {movimentacao.setor_destino_id} não encontrado")

        almoxarifado = setor_repository.get_almoxarifado()
        if almoxarifado is None:
            raise HTTPException(status_code=400, detail="Cadastre um almoxarifado antes de movimentar bens.")

        repository = MovimentacaoRepository()
        atual = repository.get_localizacao_atual(movimentacao.bem_id)
        perfil = usuario["perfil"]

        if atual is None:
            # Bem sem localização: a única entrada permitida é no almoxarifado.
            if perfil != ROLE_ADMIN:
                raise HTTPException(status_code=403, detail="Somente o setor de patrimônio registra a entrada de bens.")
            if movimentacao.setor_destino_id != almoxarifado.id:
                raise HTTPException(status_code=400, detail="A entrada de um bem deve ser feita no almoxarifado.")
            return repository.save(movimentacao, None, "aprovada", usuario["id"], usuario["id"], datetime.now())

        if movimentacao.setor_origem_id is not None and movimentacao.setor_origem_id != atual:
            raise HTTPException(status_code=400, detail="A origem informada não corresponde ao local atual do bem.")

        if perfil == ROLE_ADMIN:
            return repository.save(movimentacao, atual, "aprovada", usuario["id"], usuario["id"], datetime.now())

        setor_usuario = usuario.get("setor_id")
        if setor_usuario is None:
            raise HTTPException(status_code=403, detail="Seu usuário não está vinculado a um setor.")

        saida = atual == almoxarifado.id and movimentacao.setor_destino_id == setor_usuario
        devolucao = atual == setor_usuario and movimentacao.setor_destino_id == almoxarifado.id
        if not (saida or devolucao):
            raise HTTPException(
                status_code=403,
                detail="Movimentação permitida somente entre o almoxarifado e o seu setor.",
            )
        if not (movimentacao.justificativa or "").strip():
            raise HTTPException(status_code=400, detail="Informe o motivo da transferência.")
        return repository.save(movimentacao, atual, "pendente", usuario["id"])

    def decidir_movimentacao(self, id: int, usuario: dict, aprovar: bool, motivo: str | None = None):
        if not aprovar and not (motivo or "").strip():
            raise HTTPException(status_code=400, detail="Informe o motivo da recusa. Quem solicitou precisa saber por quê.")
        repository = MovimentacaoRepository()
        mov = repository.get_id(id)
        if mov is None:
            raise HTTPException(status_code=404, detail=f"Movimentação com id {id} não encontrada")
        if mov.status != "pendente":
            raise HTTPException(status_code=409, detail="Esta movimentação já foi decidida.")
        if mov.solicitante_id == usuario["id"]:
            raise HTTPException(status_code=403, detail="Você não pode decidir a própria solicitação.")

        almoxarifado = SetorRepository().get_almoxarifado()
        if almoxarifado is None:
            raise HTTPException(status_code=400, detail="Nenhum almoxarifado cadastrado.")

        perfil = usuario["perfil"]
        autorizado = perfil == ROLE_ADMIN or (
            perfil == ROLE_RESPONSAVEL and usuario.get("setor_id") == almoxarifado.id
        )
        if not autorizado:
            raise HTTPException(
                status_code=403,
                detail="Somente o responsável do almoxarifado ou o setor de patrimônio podem decidir.",
            )

        resultado, decidida = repository.decidir(
            id, mov.bem_id, mov.setor_origem_id, aprovar, usuario["id"], datetime.now(), (motivo or "").strip() or None
        )
        if resultado == "bem_inativo":
            raise HTTPException(status_code=400, detail="Este bem foi baixado e não pode mais ser movimentado.")
        if resultado == "ja_decidida":
            raise HTTPException(status_code=409, detail="Esta movimentação já foi decidida.")
        if resultado == "local_mudou":
            raise HTTPException(
                status_code=409,
                detail="O bem mudou de local desde a solicitação. Recuse e solicite novamente.",
            )
        return decidida
