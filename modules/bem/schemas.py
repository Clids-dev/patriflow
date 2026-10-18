from datetime import date, datetime
from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, model_validator

EstadoConservacao = Literal["novo", "bom", "regular", "ruim", "inservivel"]


class BemCampos(BaseModel):
    marca: Optional[str] = None
    modelo: Optional[str] = None
    numero_serie: Optional[str] = None
    valor_aquisicao: Optional[float] = Field(default=None, ge=0)
    nota_fiscal: Optional[str] = None
    data_entrada: Optional[date] = None
    estado_conservacao: EstadoConservacao = "novo"

class Bem(BemCampos):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nome: str
    tipo: str
    codigo_tombamento: str
    valor: float
    status: str
    ativo: bool
    id_categoria: Optional[int] = None

class BemCreate(BemCampos):
    nome: str
    tipo: str = "Equipamento"
    codigo_tombamento: str
    valor: Optional[float] = None
    status: str
    id_categoria: int
    estado_conservacao: EstadoConservacao

    @model_validator(mode="after")
    def require_a_value(self):
        if self.valor is None and self.valor_aquisicao is None:
            raise ValueError("Informe o valor de aquisição do bem")
        return self

class BemUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nome: Optional[str] = None
    valor: Optional[float] = Field(default=None, ge=0)
    status: Optional[str] = None
    marca: Optional[str] = None
    modelo: Optional[str] = None
    numero_serie: Optional[str] = None
    valor_aquisicao: Optional[float] = Field(default=None, ge=0)
    nota_fiscal: Optional[str] = None
    data_entrada: Optional[date] = None
    estado_conservacao: Optional[EstadoConservacao] = None

class BemDeleteResponse(BaseModel):
    message: str
    id: int
    ativo: bool

class BemDetalhes(Bem):
    setor_atual: Optional[str] = None
    id_setor_atual: Optional[int] = None
    data_ultima_movimentacao: Optional[datetime] = None
    justificativa: Optional[str] = None
    categoria_nome: Optional[str] = None
    predio_nome: Optional[str] = None
    andar_identificacao: Optional[str] = None
    sala_nome: Optional[str] = None
