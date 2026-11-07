from datetime import datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

from modules.bem.schemas import EstadoConservacao
from modules.inventario.schemas import Conferencia, NaoCadastrado

# Identificadores gerados no aparelho (ex.: UUID). Restritos para não aceitar texto arbitrário.
Identificador = Field(min_length=8, max_length=64, pattern=r"^[A-Za-z0-9_\-]+$")
StatusOperacao = Literal["aceita", "recusada", "conflito", "erro", "processando"]


class Operacao(BaseModel):
    id: str = Identificador
    tipo: str = Field(min_length=3, max_length=40)
    criada_em: datetime = Field(description="Quando a operação foi feita no aparelho")
    dados: dict[str, Any]


class Lote(BaseModel):
    dispositivo_id: str = Identificador
    operacoes: list[Operacao] = Field(min_length=1, max_length=500)


class ResultadoOperacao(BaseModel):
    id: str
    status: StatusOperacao
    mensagem: Optional[str] = None
    resultado: Optional[dict[str, Any]] = None
    # True quando a operação já tinha sido recebida antes: nada foi gravado de novo.
    repetida: bool = False


class RespostaLote(BaseModel):
    sincronizacao_id: int
    recebida_em: datetime
    resultados: list[ResultadoOperacao]


class UltimaSincronizacao(BaseModel):
    sincronizacao_id: int
    recebida_em: datetime
    concluida_em: Optional[datetime] = None
    total: int
    aceitas: int
    recusadas: int
    conflitos: int
    repetidas: int
    erros: int


# --- Dados de cada tipo de operação ------------------------------------------------------------

class ConferenciaOp(Conferencia):
    inventario_id: int = Field(gt=0)


class NaoCadastradoOp(NaoCadastrado):
    inventario_id: int = Field(gt=0)


class TransferenciaEtapa(BaseModel):
    movimentacao_id: int = Field(gt=0)


class TransferenciaRecusa(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    movimentacao_id: int = Field(gt=0)
    motivo: str = Field(min_length=3, max_length=500)
    # Etapa que o aparelho viu ao recusar: se a transferência avançou, é conflito.
    etapa: Literal["liberar", "receber"]


class EmprestimoDevolucao(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    emprestimo_id: int = Field(gt=0)
    observacao: Optional[str] = Field(default=None, max_length=500)
    imprevisto: Optional[str] = Field(default=None, max_length=500)


class ManutencaoRetorno(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    manutencao_id: int = Field(gt=0)
    servico_realizado: str = Field(min_length=3, max_length=500)
    estado_retorno: EstadoConservacao
    imprevisto: Optional[str] = Field(default=None, max_length=500)
