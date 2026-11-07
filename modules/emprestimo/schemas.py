from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

Situacao = Literal["abertos", "atrasados", "encerrados", "todos"]


class EmprestimoCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    bem_id: int = Field(gt=0)
    tomador: str = Field(min_length=3, max_length=120, description="Quem levou o bem")
    motivo: str = Field(min_length=3, max_length=500)
    devolucao_prevista: date


class Devolucao(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    observacao: Optional[str] = Field(default=None, max_length=500)


class Emprestimo(BaseModel):
    id: int
    bem_id: int
    bem_nome: str
    codigo_tombamento: str
    tomador: str
    motivo: str
    saida_em: datetime
    devolucao_prevista: date
    registrado_por: Optional[str] = None
    devolvido_em: Optional[datetime] = None
    recebido_por: Optional[str] = None
    observacao_devolucao: Optional[str] = None
    atrasado: bool
    dias_atraso: int
