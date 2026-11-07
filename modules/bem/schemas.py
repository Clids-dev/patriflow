from datetime import date, datetime
from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, model_validator

EstadoConservacao = Literal["novo", "bom", "regular", "ruim", "inservivel"]
StatusBem = Literal["Disponível", "Em Uso", "Manutenção", "Baixado"]


class EventoHistorico(BaseModel):
    """Um evento da linha do tempo do bem. `fotos` traz os ids das fotos ligadas ao evento."""
    tipo: str
    em: datetime
    autor: Optional[str] = None
    titulo: str
    detalhe: str = ""
    referencia_id: int
    fotos: list[int] = []


class BemCampos(BaseModel):
    garantia_fim: Optional[date] = None
    vida_util_meses: Optional[int] = Field(default=None, gt=0)
    valor_residual: float = Field(default=0, ge=0)
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
    status: StatusBem
    id_categoria: int
    estado_conservacao: EstadoConservacao

    @model_validator(mode="after")
    def require_a_value(self):
        if self.valor is None and self.valor_aquisicao is None:
            raise ValueError("Informe o valor de aquisição do bem")
        return self

class BemUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    garantia_fim: Optional[date] = None
    vida_util_meses: Optional[int] = Field(default=None, gt=0)
    valor_residual: Optional[float] = Field(default=None, ge=0)
    nome: Optional[str] = None
    valor: Optional[float] = Field(default=None, ge=0)
    status: Optional[StatusBem] = None
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
    responsavel_nome: Optional[str] = None
    responsavel_cargo: Optional[str] = None
    depreciacao_mensal: Optional[float] = None
    depreciacao_acumulada: Optional[float] = None
    valor_contabil: Optional[float] = None


class BaixaCreate(BaseModel):
    motivo: Literal["doacao", "inservivel", "extravio", "venda", "sinistro", "descarte"]
    justificativa: str = Field(min_length=3, max_length=500)
    documento_ref: str = Field(min_length=2, max_length=120)


class DecisaoRecusa(BaseModel):
    motivo: str = Field(min_length=3, max_length=500)
