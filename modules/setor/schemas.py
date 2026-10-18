from pydantic import BaseModel
from typing import Optional

from modules.responsavel.schemas import Responsavel


class Setor(BaseModel):
    id: int
    nome: str
    responsavel_id: int
    flag_almoxarifado: bool = False
    ativo: bool
    sala_id: int

class SetorCreate(BaseModel):
    nome: str
    responsavel_id: int
    flag_almoxarifado: bool = False
    sala_id: int

class SetorFlat(BaseModel):
    id: int
    nome: str
    responsavel_id: Optional[int] = None
    responsavel_nome: Optional[str] = None
    cargo_responsavel: Optional[str] = None
    flag_almoxarifado: bool = False
    ativo: bool
    sala_id: int
    sala_nome: Optional[str] = None
    andar_identificacao: Optional[str] = None
    predio_nome: Optional[str] = None
