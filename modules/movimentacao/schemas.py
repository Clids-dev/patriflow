from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class Movimentacao(BaseModel):
    id: int
    bem_id: int
    setor_origem_id: int | None = None
    setor_destino_id: int | None = None
    data: datetime
    justificativa: Optional[str] = None
    ativo: bool
    status: str = "aprovada"
    solicitante_id: Optional[int] = None


class MovimentacaoCreate(BaseModel):
    bem_id: int
    setor_origem_id: Optional[int] = None
    setor_destino_id: int
    justificativa: Optional[str] = None


class MovimentacaoUpdate(BaseModel):
    setor_destino_id: int
    data: datetime
    justificativa: Optional[str] = None


class MovimentacaoDetailed(BaseModel):
    id: int
    bem_nome: str
    codigo_tombamento: str
    setor_origem_nome: Optional[str] = None
    setor_destino_nome: str
    data_movimentacao: datetime
    justificativa: Optional[str] = None
    ativo: bool
    status: str = "aprovada"
    solicitante_nome: Optional[str] = None
    escalada: bool = False


class DecisaoRecusa(BaseModel):
    motivo: str = Field(min_length=3, max_length=500)
