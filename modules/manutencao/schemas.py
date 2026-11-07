from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

from modules.bem.schemas import EstadoConservacao

Situacao = Literal["abertas", "encerradas", "todas"]


class ManutencaoCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    bem_id: int = Field(gt=0)
    descricao: str = Field(min_length=3, max_length=500, description="Problema ou serviço solicitado")
    destino: str = Field(min_length=2, max_length=160, description="Assistência ou oficina")
    imprevisto: Optional[str] = Field(default=None, max_length=500,
                                      description="Agente fora dos setores designados: motivo do imprevisto")


class Retorno(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    servico_realizado: str = Field(min_length=3, max_length=500)
    estado_retorno: EstadoConservacao
    imprevisto: Optional[str] = Field(default=None, max_length=500)


class Manutencao(BaseModel):
    id: int
    bem_id: int
    bem_nome: str
    codigo_tombamento: str
    descricao: str
    destino: str
    enviado_em: datetime
    enviado_por: Optional[str] = None
    status_anterior: str
    retorno_em: Optional[datetime] = None
    recebido_por: Optional[str] = None
    servico_realizado: Optional[str] = None
    estado_retorno: Optional[str] = None
    dias_fora: int
