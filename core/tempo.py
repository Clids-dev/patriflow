"""Data das operações feitas no aparelho sem rede (decisão D8).

O fato (saída do empréstimo, envio para manutenção, conferência) usa a data em que aconteceu no
aparelho; o servidor guarda à parte quando recebeu. Para conter relógio errado, a data não pode estar
no futuro nem ser mais antiga que o limite (PATRIFLOW_OFFLINE_LIMITE_DIAS, padrão 7 dias).
"""
from datetime import datetime, timedelta

from fastapi import HTTPException

from core import config

TOLERANCIA_FUTURO = timedelta(minutes=5)


def momento_da_operacao(ocorrido_em: datetime | None) -> datetime | None:
    """None = operação online (o banco usa a hora atual). Com data: valida e devolve em hora local."""
    if ocorrido_em is None:
        return None
    if ocorrido_em.tzinfo is not None:
        ocorrido_em = ocorrido_em.astimezone().replace(tzinfo=None)
    agora = datetime.now()
    if ocorrido_em > agora + TOLERANCIA_FUTURO:
        raise HTTPException(status_code=400, detail="A data da operação está no futuro. Confira o relógio do aparelho.")
    if ocorrido_em < agora - timedelta(days=config.OFFLINE_LIMITE_DIAS):
        raise HTTPException(
            status_code=400,
            detail=f"A operação foi feita há mais de {config.OFFLINE_LIMITE_DIAS} dias e não pode mais ser enviada. "
                   "Procure o setor de patrimônio.")
    return ocorrido_em
