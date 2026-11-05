"""Depreciação linear (método mais usado para bens de uso).

Base depreciável = valor de aquisição - valor residual. A quota mensal é a
base dividida pela vida útil em meses. O valor contábil nunca fica abaixo do
valor residual nem acima do valor de aquisição.
"""
from datetime import date


def meses_decorridos(inicio: date, hoje: date) -> int:
    """Meses completos entre a data de entrada e hoje."""
    meses = (hoje.year - inicio.year) * 12 + (hoje.month - inicio.month)
    if hoje.day < inicio.day:
        meses -= 1
    return max(meses, 0)


def calcular(valor_aquisicao, valor_residual, vida_util_meses, data_entrada, hoje: date) -> dict:
    if valor_aquisicao is None:
        return {"depreciacao_mensal": None, "depreciacao_acumulada": None, "valor_contabil": None}
    residual = valor_residual or 0
    if not vida_util_meses or not data_entrada:
        # Sem vida útil ou data de entrada não há como depreciar: valor contábil é o de aquisição.
        return {"depreciacao_mensal": None, "depreciacao_acumulada": None, "valor_contabil": round(valor_aquisicao, 2)}
    base = max(valor_aquisicao - residual, 0)
    mensal = base / vida_util_meses
    meses = min(meses_decorridos(data_entrada, hoje), vida_util_meses)
    acumulada = round(mensal * meses, 2)
    contabil = round(max(valor_aquisicao - acumulada, residual), 2)
    return {
        "depreciacao_mensal": round(mensal, 2),
        "depreciacao_acumulada": acumulada,
        "valor_contabil": contabil,
    }
