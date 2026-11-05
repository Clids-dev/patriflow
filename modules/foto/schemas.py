from datetime import datetime
from typing import Literal

from pydantic import BaseModel

RegistroTipo = Literal["conferencia", "aceite_transferencia", "bem_nao_cadastrado"]


class FotoOut(BaseModel):
    id: int
    registro_tipo: RegistroTipo
    registro_id: int
    content_type: str
    tamanho_bytes: int
    enviado_por: int
    enviado_em: datetime
    url: str
