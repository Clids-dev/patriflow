from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from modules.bem.schemas import EstadoConservacao

SituacaoItem = Literal["localizado", "outro_setor", "nao_localizado", "nao_cadastrado"]
FiltroItens = Literal["todos", "pendentes", "localizado", "outro_setor", "nao_localizado", "nao_cadastrado", "divergencias"]
FiltroInventarios = Literal["abertos", "fechados", "todos"]


class InventarioCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    descricao: str = Field(min_length=3, max_length=160)
    inicio: date
    fim: date
    setor_ids: list[int] = Field(min_length=1, max_length=500)

    @field_validator("setor_ids")
    @classmethod
    def _sem_repetidos(cls, valor: list[int]) -> list[int]:
        if any(s <= 0 for s in valor):
            raise ValueError("Ids de setor devem ser positivos.")
        return list(dict.fromkeys(valor))

    @model_validator(mode="after")
    def _periodo(self):
        if self.fim < self.inicio:
            raise ValueError("O fim do inventário não pode ser antes do início.")
        return self


class Conferencia(BaseModel):
    """Leitura de um bem em um setor do inventário (pela etiqueta ou pelo tombo digitado)."""
    model_config = ConfigDict(str_strip_whitespace=True)

    setor_id: int = Field(gt=0, description="Setor onde o bem foi encontrado")
    codigo_tombamento: str = Field(min_length=3, max_length=30)
    estado_encontrado: Optional[EstadoConservacao] = None
    observacao: Optional[str] = Field(default=None, max_length=500)

    @field_validator("codigo_tombamento")
    @classmethod
    def _maiusculo(cls, valor: str) -> str:
        return valor.upper()


class NaoCadastrado(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    setor_id: int = Field(gt=0)
    descricao: str = Field(min_length=3, max_length=200)
    codigo_lido: Optional[str] = Field(default=None, max_length=30, description="Etiqueta encontrada, se houver")
    observacao: Optional[str] = Field(default=None, max_length=500)


class SetorResumo(BaseModel):
    setor_id: int
    setor_nome: str
    esperados: int
    conferidos: int
    localizados: int
    outro_setor: int
    nao_localizados: int
    nao_cadastrados: int
    pendentes: int


class Inventario(BaseModel):
    id: int
    descricao: str
    inicio: date
    fim: date
    status: str
    aberto_por: Optional[str] = None
    aberto_em: datetime
    fechado_por: Optional[str] = None
    fechado_em: Optional[datetime] = None
    total_itens: int = 0
    pendentes: int = 0
    setores: list[SetorResumo] = []


class Item(BaseModel):
    id: int
    bem_id: Optional[int] = None
    codigo_tombamento: Optional[str] = None
    nome: str
    setor_esperado_id: Optional[int] = None
    setor_esperado: Optional[str] = None
    estado_esperado: Optional[str] = None
    ausencia_justificada: Optional[str] = None
    situacao: Optional[SituacaoItem] = None
    setor_encontrado_id: Optional[int] = None
    setor_encontrado: Optional[str] = None
    estado_encontrado: Optional[str] = None
    observacao: Optional[str] = None
    conferido_por: Optional[str] = None
    conferido_em: Optional[datetime] = None


class TransferenciaIgnorada(BaseModel):
    codigo_tombamento: str
    motivo: str


class ResumoFechamento(BaseModel):
    inventario_id: int
    localizados: int
    outro_setor: int
    nao_localizados: int
    ausencias_justificadas: int
    nao_cadastrados: int
    transferencias_abertas: int
    transferencias_ignoradas: list[TransferenciaIgnorada]
    pendencias_criadas: int
