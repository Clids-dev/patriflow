from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

Situacao = Literal["abertos", "atrasados", "encerrados", "todos"]


class EmprestimoCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    bem_id: int = Field(gt=0)
    tomador: str = Field(min_length=3, max_length=120, description="Nome de quem leva o bem")
    # O bem não sai da instituição (D9): quem leva é identificado pela matrícula e diz para onde vai.
    matricula: str = Field(min_length=2, max_length=30, description="Matrícula de quem leva")
    setor_destino_id: int = Field(gt=0, description="Setor da instituição para onde o bem vai")
    motivo: str = Field(min_length=3, max_length=500)
    devolucao_prevista: date
    imprevisto: Optional[str] = Field(default=None, max_length=500,
                                      description="Agente fora dos setores designados: motivo do imprevisto")


class Devolucao(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    observacao: Optional[str] = Field(default=None, max_length=500)
    imprevisto: Optional[str] = Field(default=None, max_length=500)


class Emprestimo(BaseModel):
    id: int
    bem_id: int
    bem_nome: str
    codigo_tombamento: str
    tomador: str
    matricula: Optional[str] = None
    setor_destino_id: Optional[int] = None
    setor_destino: Optional[str] = None
    motivo: str
    saida_em: datetime
    devolucao_prevista: date
    registrado_por: Optional[str] = None
    devolvido_em: Optional[datetime] = None
    recebido_por: Optional[str] = None
    observacao_devolucao: Optional[str] = None
    atrasado: bool
    dias_atraso: int
