"""Sincronização em lote: aplica, na ordem em que foram feitas, as operações registradas sem rede.

Cada operação passa pelo mesmo serviço usado pela API e pela web, com as mesmas regras e permissões.
O desfecho de cada uma:
- aceita:    aplicada.
- conflito:  o servidor mudou desde que o aparelho registrou a operação (ex.: transferência já decidida
             por outra pessoa, bem já emprestado). Fica registrada e vira pendência para o patrimônio.
- recusada:  a operação é inválida (dados, permissão, registro inexistente). Não adianta reenviar.
- erro:      falha inesperada no servidor. Pode ser reenviada; o reenvio é processado de novo.
Reenviar uma operação já concluída devolve o mesmo desfecho, sem gravar nada (idempotência).
"""
import logging
from collections import Counter
from typing import Callable

from fastapi import HTTPException
from pydantic import BaseModel, ValidationError

from modules.emprestimo.schemas import EmprestimoCreate
from modules.emprestimo.service import EmprestimoService
from modules.inventario.schemas import Conferencia, NaoCadastrado
from modules.inventario.service import InventarioService
from modules.manutencao.schemas import ManutencaoCreate, Retorno
from modules.manutencao.service import ManutencaoService
from modules.movimentacao.repository import MovimentacaoRepository
from modules.movimentacao.schemas import MovimentacaoCreate
from modules.movimentacao.service import MovimentacaoService
from modules.sincronizacao import schemas as s
from modules.sincronizacao.repository import SincronizacaoRepository

logger = logging.getLogger(__name__)

# Etapa esperada de cada ação sobre uma transferência. "liberar" e "receber" usam a mesma ação no
# serviço (aprovar), que decide pela etapa atual; por isso o aparelho declara qual etapa viu.
_STATUS_DA_ETAPA = {"liberar": "pendente", "receber": "liberada"}

NOMES = {
    "conferencia": "Conferência de inventário",
    "bem_nao_cadastrado": "Bem sem cadastro",
    "transferencia_solicitar": "Pedido de transferência",
    "transferencia_liberar": "Liberação de transferência",
    "transferencia_receber": "Recebimento de transferência",
    "transferencia_recusar": "Recusa de transferência",
    "emprestimo_registrar": "Empréstimo",
    "emprestimo_devolver": "Devolução de empréstimo",
    "manutencao_enviar": "Envio para manutenção",
    "manutencao_retorno": "Retorno de manutenção",
}


def _exigir_etapa(movimentacao_id: int, etapa: str) -> None:
    mov = MovimentacaoRepository().get_id(movimentacao_id)
    if mov is None:
        raise HTTPException(status_code=404, detail=f"Transferência {movimentacao_id} não encontrada.")
    if mov.status != _STATUS_DA_ETAPA[etapa]:
        raise HTTPException(status_code=409,
                            detail=f"A transferência mudou desde que a operação foi feita (situação atual: {mov.status}).")


def _conferencia(d: s.ConferenciaOp, usuario, quando):
    item = InventarioService().conferir(d.inventario_id, Conferencia(**d.model_dump(exclude={"inventario_id"})), usuario,
                                        quando)
    return {"item_id": item.id, "situacao": item.situacao}


def _nao_cadastrado(d: s.NaoCadastradoOp, usuario, quando):
    item = InventarioService().registrar_nao_cadastrado(
        d.inventario_id, NaoCadastrado(**d.model_dump(exclude={"inventario_id"})), usuario, quando)
    return {"item_id": item.id}


def _solicitar(d: MovimentacaoCreate, usuario, quando):
    mov = MovimentacaoService().add_movimentacao(d, usuario)
    return {"movimentacao_id": mov.id, "status": mov.status}


def _avancar(etapa: str):
    def aplicar(d: s.TransferenciaEtapa, usuario, quando):
        _exigir_etapa(d.movimentacao_id, etapa)
        mov = MovimentacaoService().decidir_movimentacao(d.movimentacao_id, usuario, aprovar=True)
        return {"movimentacao_id": mov.id, "status": mov.status}
    return aplicar


def _recusar(d: s.TransferenciaRecusa, usuario, quando):
    _exigir_etapa(d.movimentacao_id, d.etapa)
    mov = MovimentacaoService().decidir_movimentacao(d.movimentacao_id, usuario, aprovar=False, motivo=d.motivo)
    return {"movimentacao_id": mov.id, "status": mov.status}


def _emprestar(d: EmprestimoCreate, usuario, quando):
    return {"emprestimo_id": EmprestimoService().registrar(d, usuario, quando).id}


def _devolver(d: s.EmprestimoDevolucao, usuario, quando):
    return {"emprestimo_id": EmprestimoService().devolver(d.emprestimo_id, d.observacao, usuario, quando,
                                                          d.imprevisto).id}


def _enviar_manutencao(d: ManutencaoCreate, usuario, quando):
    return {"manutencao_id": ManutencaoService().enviar(d, usuario, quando).id}


def _retorno_manutencao(d: s.ManutencaoRetorno, usuario, quando):
    retorno = Retorno(servico_realizado=d.servico_realizado, estado_retorno=d.estado_retorno, imprevisto=d.imprevisto)
    return {"manutencao_id": ManutencaoService().registrar_retorno(d.manutencao_id, retorno, usuario, quando).id}


OPERACOES: dict[str, tuple[type[BaseModel], Callable]] = {
    "conferencia": (s.ConferenciaOp, _conferencia),
    "bem_nao_cadastrado": (s.NaoCadastradoOp, _nao_cadastrado),
    "transferencia_solicitar": (MovimentacaoCreate, _solicitar),
    "transferencia_liberar": (s.TransferenciaEtapa, _avancar("liberar")),
    "transferencia_receber": (s.TransferenciaEtapa, _avancar("receber")),
    "transferencia_recusar": (s.TransferenciaRecusa, _recusar),
    "emprestimo_registrar": (EmprestimoCreate, _emprestar),
    "emprestimo_devolver": (s.EmprestimoDevolucao, _devolver),
    "manutencao_enviar": (ManutencaoCreate, _enviar_manutencao),
    "manutencao_retorno": (s.ManutencaoRetorno, _retorno_manutencao),
}


def _mensagem_de_validacao(erro: ValidationError) -> str:
    primeiro = erro.errors()[0]
    campo = ".".join(str(p) for p in primeiro.get("loc", ())) or "dados"
    return f"Dados inválidos em '{campo}': {primeiro.get('msg')}"


class SincronizacaoService:
    def __init__(self, repository: SincronizacaoRepository | None = None):
        self.repo = repository or SincronizacaoRepository()

    def sincronizar(self, lote: s.Lote, usuario: dict) -> dict:
        sync_id, recebida_em = self.repo.iniciar(lote.dispositivo_id, usuario["id"], len(lote.operacoes))
        # Ordem de criação no aparelho; empate mantém a ordem do lote (sort é estável).
        ordem = sorted(range(len(lote.operacoes)), key=lambda i: lote.operacoes[i].criada_em)
        resultados: dict[int, s.ResultadoOperacao] = {}
        contagem: Counter = Counter()
        for indice in ordem:
            resultado = self._processar(sync_id, lote.dispositivo_id, lote.operacoes[indice], usuario)
            resultados[indice] = resultado
            contagem["repetida" if resultado.repetida else resultado.status] += 1
        self.repo.finalizar(sync_id, {k: contagem.get(k, 0) for k in ("aceita", "recusada", "conflito", "repetida", "erro")})
        # A resposta segue a ordem em que o aparelho enviou, para facilitar a conciliação da fila.
        return {"sincronizacao_id": sync_id, "recebida_em": recebida_em,
                "resultados": [resultados[i] for i in range(len(lote.operacoes))]}

    def _processar(self, sync_id: int, dispositivo_id: str, op: s.Operacao, usuario: dict) -> s.ResultadoOperacao:
        registro_id = self.repo.reivindicar(sync_id, dispositivo_id, op, usuario["id"])
        if registro_id is None:
            return self._repetida(dispositivo_id, op, usuario)

        status, mensagem, resultado, pendencia = "aceita", None, None, None
        try:
            if op.tipo not in OPERACOES:
                raise HTTPException(status_code=400, detail=f"Tipo de operação desconhecido: {op.tipo}.")
            modelo, aplicar = OPERACOES[op.tipo]
            # Empréstimo, manutenção e conferência usam a data do aparelho (D8); transferências, a do
            # servidor, porque envolvem duas pessoas em sequência.
            resultado = aplicar(modelo.model_validate(op.dados), usuario, op.criada_em)
        except ValidationError as erro:
            status, mensagem = "recusada", _mensagem_de_validacao(erro)
        except HTTPException as erro:
            status, mensagem = ("conflito" if erro.status_code == 409 else "recusada"), str(erro.detail)
            if status == "conflito":
                pendencia = (f"{NOMES.get(op.tipo, op.tipo)} (operação feita sem rede em "
                             f"{op.criada_em:%d/%m/%Y %H:%M}): {mensagem}")
        except Exception:  # noqa: BLE001 - nenhuma operação pode ser perdida em silêncio
            logger.exception("Falha ao aplicar a operação %s do dispositivo %s", op.id, dispositivo_id)
            status, mensagem = "erro", "Erro interno ao aplicar a operação. Reenvie mais tarde."
        self.repo.concluir(registro_id, status, mensagem, resultado, pendencia, usuario["id"])
        return s.ResultadoOperacao(id=op.id, status=status, mensagem=mensagem, resultado=resultado)

    def _repetida(self, dispositivo_id: str, op: s.Operacao, usuario: dict) -> s.ResultadoOperacao:
        usuario_id, status, mensagem, resultado = self.repo.existente(dispositivo_id, op.id)
        if usuario_id != usuario["id"]:
            return s.ResultadoOperacao(id=op.id, status="recusada",
                                       mensagem="Este identificador de operação já pertence a outro usuário.")
        return s.ResultadoOperacao(id=op.id, status=status, mensagem=mensagem, resultado=resultado, repetida=True)

    def ultima(self, dispositivo_id: str, usuario: dict):
        row = self.repo.ultima(dispositivo_id, usuario["id"])
        if row is None:
            raise HTTPException(status_code=404, detail="Este aparelho ainda não sincronizou.")
        return s.UltimaSincronizacao(sincronizacao_id=row[0], recebida_em=row[1], concluida_em=row[2], total=row[3],
                                     aceitas=row[4], recusadas=row[5], conflitos=row[6], repetidas=row[7], erros=row[8])
