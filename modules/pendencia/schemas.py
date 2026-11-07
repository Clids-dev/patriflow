from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

Situacao = Literal["abertas", "resolvidas", "todas"]


class Resolucao(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    resolucao: str = Field(min_length=3, max_length=500, description="O que foi decidido ou feito")


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
    fotos: list[int] = []
