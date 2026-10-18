from pydantic import BaseModel, Field


class PredioCreate(BaseModel):
    nome: str = Field(min_length=1, max_length=120)
    endereco: str | None = Field(default=None, max_length=250)


class AndarCreate(BaseModel):
    predio_id: int = Field(gt=0)
    identificacao: str = Field(min_length=1, max_length=80)


class SalaCreate(BaseModel):
    andar_id: int = Field(gt=0)
    identificacao: str = Field(min_length=1, max_length=80)


class Predio(BaseModel):
    id: int
    nome: str
    endereco: str | None = None


class Andar(BaseModel):
    id: int
    predio_id: int
    identificacao: str
    predio_nome: str


class Sala(BaseModel):
    id: int
    andar_id: int
    identificacao: str
    andar_identificacao: str
    predio_id: int
    predio_nome: str
