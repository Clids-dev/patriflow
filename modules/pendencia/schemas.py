from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

Situacao = Literal["abertas", "resolvidas", "todas"]


class Resolucao(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    acao: str = Field(min_length=3, max_length=30, description="Ação do tipo da pendência (ver GET /pendencias/acoes)")
    resolucao: str = Field(min_length=3, max_length=400, description="O que foi decidido ou feito")
    documento: Optional[str] = Field(default=None, max_length=120, description="Boletim de ocorrência (baixa por extravio)")
    setor_id: Optional[int] = Field(default=None, gt=0, description="Onde o bem foi encontrado")
    bem_id: Optional[int] = Field(default=None, gt=0, description="Bem cadastrado a partir da pendência")


class Pendencia(BaseModel):
    id: int
    tipo: str
    descricao: str
    bem_id: Optional[int] = None
    codigo_tombamento: Optional[str] = None
    setor_id: Optional[int] = None
    setor_nome: Optional[str] = None
    inventario_id: Optional[int] = None
    inventario_item_id: Optional[int] = None
    sync_operacao_id: Optional[int] = None
    criada_por: Optional[str] = None
    criada_em: datetime
    resolvida_por: Optional[str] = None
    resolvida_em: Optional[datetime] = None
    resolucao: Optional[str] = None
    acao: Optional[str] = None
    referencia_id: Optional[int] = None
    fotos: list[int] = []
