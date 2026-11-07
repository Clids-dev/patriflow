from datetime import datetime
from fastapi import HTTPException

from modules.setor.repository import SetorRepository
from modules.bem.repository import BemRepository
from modules.movimentacao.repository import MovimentacaoRepository
from modules.movimentacao.schemas import MovimentacaoCreate
from core.tombamento import require_valid_tombo
from core import config
from modules.foto.repository import FotoRepository
from modules.emprestimo.repository import EmprestimoRepository


ROLE_ADMIN = "setor_patrimonio"
ROLE_RESPONSAVEL = "responsavel_setor"
ROLE_AGENTE = "agente_campo"
# Quem pode pedir transferências. O auditor só lê.
ROLE_SOLICITANTE = (ROLE_AGENTE, ROLE_RESPONSAVEL)
# Estados em que a transferência ainda pode ser decidida ou intervida.
ABERTAS = ("pendente", "liberada")


def _responsavel_do_setor(usuario: dict, setor_id) -> bool:
    """Responsável do setor indicado (origem ou destino). Só ele libera ou confirma."""
    return (
        usuario["perfil"] == ROLE_RESPONSAVEL
        and setor_id is not None
        and usuario.get("setor_id") == setor_id
    )


def _traduzir(resultado: str, decidida):
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

    def listar_pendentes(self, usuario: dict):
        """Transferências que este usuário pode decidir agora, cada uma com a etapa:
        - "liberar": o responsável do setor de origem libera o bem;
        - "receber": o responsável do setor de destino confirma o recebimento (com foto).
        Transferências antigas (fluxo simples) continuam com o responsável do almoxarifado."""
        almox = SetorRepository().get_almoxarifado()
        resultado = []
        for m in MovimentacaoRepository().get_em_andamento(config.PRAZO_TRANSFERENCIA_DIAS):
            m.etapa = "liberar" if m.status == "pendente" else "receber"
            if usuario["perfil"] == ROLE_ADMIN:
                resultado.append(m)
            elif m.fluxo == "simples":
                if m.status == "pendente" and almox is not None and _responsavel_do_setor(usuario, almox.id):
                    resultado.append(m)
            elif m.etapa == "liberar" and _responsavel_do_setor(usuario, m.setor_origem_id):
                resultado.append(m)
            elif m.etapa == "receber" and _responsavel_do_setor(usuario, m.setor_destino_id):
                resultado.append(m)
        return resultado

    def acompanhamento(self, usuario: dict):
        """Notificação do almoxarifado: todas as transferências abertas do sistema, para
        acompanhar e, se necessário, intervir. Disponível ao setor de patrimônio e ao
        responsável do almoxarifado."""
        almox = SetorRepository().get_almoxarifado()
        if usuario["perfil"] != ROLE_ADMIN and not (almox and _responsavel_do_setor(usuario, almox.id)):
            raise HTTPException(status_code=403, detail="Somente o almoxarifado acompanha as transferências.")
        itens = []
        for m in MovimentacaoRepository().get_em_andamento(config.PRAZO_TRANSFERENCIA_DIAS):
            m.etapa = "liberar" if m.status == "pendente" else "receber"
            if m.fluxo == "duplo":
                itens.append(m)
        return itens

    def listar_escaladas(self, usuario: dict):
        """Fila do setor de patrimônio: transferências sem resposta além do prazo."""
        if usuario["perfil"] != ROLE_ADMIN:
            raise HTTPException(status_code=403, detail="Somente o setor de patrimônio acompanha as escaladas.")
        return [m for m in MovimentacaoRepository().get_em_andamento(config.PRAZO_TRANSFERENCIA_DIAS) if m.escalada]

    def add_movimentacao(self, movimentacao: MovimentacaoCreate, usuario: dict):
        """Registra uma movimentação.

        - Setor de patrimônio movimenta diretamente, sem aprovação.
        - Agentes e responsáveis solicitam bens para o próprio setor, de qualquer setor de
          origem. A solicitação fica 'pendente' até o responsável da origem liberar o bem;
          depois o responsável do destino confirma o recebimento (dupla confirmação).
        - O auditor não solicita.
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

        # Emprestado, o bem continua sob a guarda da origem até a devolução.
        if EmprestimoRepository().existe_aberto(movimentacao.bem_id):
            raise HTTPException(status_code=409, detail="Este bem está emprestado. Registre a devolução antes de transferir.")

        setor_repository = SetorRepository()
        if movimentacao.setor_origem_id is not None and setor_repository.get_id(movimentacao.setor_origem_id) is None:
            raise HTTPException(status_code=404, detail=f"Setor de origem com id {movimentacao.setor_origem_id} não encontrado")
        if setor_repository.get_id(movimentacao.setor_destino_id) is None:
            raise HTTPException(status_code=404, detail=f"Setor de destino com id {movimentacao.setor_destino_id} não encontrado")

        repository = MovimentacaoRepository()
        atual = repository.get_localizacao_atual(movimentacao.bem_id)
        perfil = usuario["perfil"]

        almoxarifado = setor_repository.get_almoxarifado()
        if almoxarifado is None:
            raise HTTPException(status_code=400, detail="Cadastre um almoxarifado antes de movimentar bens.")

        if perfil == ROLE_ADMIN:
            if atual is None:
                # Bem sem localização: a única entrada permitida é no almoxarifado.
                if movimentacao.setor_destino_id != almoxarifado.id:
                    raise HTTPException(status_code=400, detail="A entrada de um bem deve ser feita no almoxarifado.")
                return repository.save(movimentacao, None, "aprovada", usuario["id"], usuario["id"], datetime.now())
            if movimentacao.setor_origem_id is not None and movimentacao.setor_origem_id != atual:
                raise HTTPException(status_code=400, detail="A origem informada não corresponde ao local atual do bem.")
            return repository.save(movimentacao, atual, "aprovada", usuario["id"], usuario["id"], datetime.now())

        if perfil not in ROLE_SOLICITANTE:
            raise HTTPException(status_code=403, detail="Seu perfil não pode solicitar transferências.")

        setor_usuario = usuario.get("setor_id")
        if setor_usuario is None:
            raise HTTPException(status_code=403, detail="Seu usuário não está vinculado a um setor.")
        if movimentacao.setor_destino_id != setor_usuario:
            raise HTTPException(status_code=403, detail="Você só solicita bens para o seu próprio setor.")
        if atual is None:
            raise HTTPException(status_code=400, detail="Este bem ainda não tem localização. Procure o almoxarifado.")
        if movimentacao.setor_origem_id is not None and movimentacao.setor_origem_id != atual:
            raise HTTPException(status_code=400, detail="A origem informada não corresponde ao local atual do bem.")
        if atual == setor_usuario:
            raise HTTPException(status_code=400, detail="Este bem já está no seu setor.")
        if not (movimentacao.justificativa or "").strip():
            raise HTTPException(status_code=400, detail="Informe o motivo da transferência.")
        if repository.existe_aberta(movimentacao.bem_id):
            raise HTTPException(status_code=409, detail="Já existe uma transferência em andamento para este bem.")
        return repository.save(movimentacao, atual, "pendente", usuario["id"], fluxo="duplo")

    def decidir_movimentacao(self, id: int, usuario: dict, aprovar: bool, motivo: str | None = None):
        motivo = (motivo or "").strip() or None
        if not aprovar and not motivo:
            raise HTTPException(status_code=400, detail="Informe o motivo da recusa. Quem solicitou precisa saber por quê.")
        repository = MovimentacaoRepository()
        mov = repository.get_id(id)
        if mov is None:
            raise HTTPException(status_code=404, detail=f"Movimentação com id {id} não encontrada")
        if mov.status not in ABERTAS:
            raise HTTPException(status_code=409, detail="Esta movimentação já foi decidida.")
        if mov.solicitante_id == usuario["id"]:
            raise HTTPException(status_code=403, detail="Você não pode decidir a própria solicitação.")
        if mov.fluxo == "simples":
            return self._decidir_simples(id, mov, usuario, aprovar, motivo)

        admin = usuario["perfil"] == ROLE_ADMIN

        if mov.status == "pendente":
            # Etapa 1: o responsável do setor de origem libera (ou recusa) o bem.
            if not (admin or _responsavel_do_setor(usuario, mov.setor_origem_id)):
                raise HTTPException(status_code=403, detail="Somente o responsável do setor de origem libera o bem.")
            novo_status = "liberada" if aprovar else "recusada"
            resultado, decidida = repository.transicionar(
                id, mov.bem_id, mov.setor_origem_id, ("pendente",), novo_status,
                usuario["id"], datetime.now(), motivo, verificar_local=False,
            )
            return _traduzir(resultado, decidida)

        # Etapa 2: o responsável do setor de destino confirma o recebimento com foto.
        if not (admin or _responsavel_do_setor(usuario, mov.setor_destino_id)):
            raise HTTPException(status_code=403, detail="Somente o responsável do setor de destino confirma o recebimento.")
        if aprovar:
            if FotoRepository().contar("aceite_transferencia", id) == 0:
                raise HTTPException(status_code=400, detail="Envie a foto do recebimento do bem antes de confirmar.")
            novo_status = "aprovada"
        else:
            novo_status = "recusada"
        resultado, decidida = repository.transicionar(
            id, mov.bem_id, mov.setor_origem_id, ("liberada",), novo_status,
            usuario["id"], datetime.now(), motivo, verificar_local=aprovar,
        )
        return _traduzir(resultado, decidida)

    def _decidir_simples(self, id: int, mov, usuario: dict, aprovar: bool, motivo: str | None):
        """Regra anterior, mantida para as transferências já existentes (fluxo simples)."""
        if aprovar and FotoRepository().contar("aceite_transferencia", id) == 0:
            raise HTTPException(status_code=400, detail="Envie a foto do recebimento do bem antes de autorizar a transferência.")
        if not aprovar and not (motivo or "").strip():
            raise HTTPException(status_code=400, detail="Informe o motivo da recusa. Quem solicitou precisa saber por quê.")
        almoxarifado = SetorRepository().get_almoxarifado()
        if almoxarifado is None:
            raise HTTPException(status_code=400, detail="Nenhum almoxarifado cadastrado.")
        perfil = usuario["perfil"]
        autorizado = perfil == ROLE_ADMIN or _responsavel_do_setor(usuario, almoxarifado.id)
        if not autorizado:
            raise HTTPException(
                status_code=403,
                detail="Somente o responsável do almoxarifado ou o setor de patrimônio podem decidir.",
            )
        resultado, decidida = MovimentacaoRepository().decidir(
            id, mov.bem_id, mov.setor_origem_id, aprovar, usuario["id"], datetime.now(),
            (motivo or "").strip() or None,
        )
        return _traduzir(resultado, decidida)

    def intervir(self, id: int, usuario: dict, motivo: str):
        """Intervenção do almoxarifado (ou do setor de patrimônio): cancela uma transferência
        aberta que esteja fora dos conformes. Exige motivo, que fica registrado."""
        motivo = (motivo or "").strip()
        if len(motivo) < 3:
            raise HTTPException(status_code=400, detail="Informe o motivo da intervenção.")
        almoxarifado = SetorRepository().get_almoxarifado()
        autorizado = usuario["perfil"] == ROLE_ADMIN or (
            almoxarifado is not None and _responsavel_do_setor(usuario, almoxarifado.id)
        )
        if not autorizado:
            raise HTTPException(
                status_code=403,
                detail="Somente o almoxarifado ou o setor de patrimônio podem intervir em transferências.",
            )
        repository = MovimentacaoRepository()
        mov = repository.get_id(id)
        if mov is None:
            raise HTTPException(status_code=404, detail=f"Movimentação com id {id} não encontrada")
        if mov.status not in ABERTAS:
            raise HTTPException(status_code=409, detail="Esta movimentação já foi decidida.")
        resultado, decidida = repository.transicionar(
            id, mov.bem_id, None, ABERTAS, "cancelada", usuario["id"], datetime.now(), motivo, verificar_local=False,
        )
        return _traduzir(resultado, decidida)
