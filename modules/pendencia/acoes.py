"""Ações guiadas para resolver pendências (decisão D6).

Cada tipo de pendência tem as suas ações. Algumas só registram a decisão; outras executam algo no
sistema antes de resolver (abrir a baixa por extravio, aplicar de novo uma operação em conflito).
Se a execução falhar, a pendência continua aberta.
"""
from fastapi import HTTPException

from core.database import DataBase

ACOES = {
    "bem_nao_localizado": {
        "encontrado": "Foi encontrado",
        "baixa_extravio": "Abrir baixa por extravio",
        "aguardar": "Aguardar o próximo inventário",
    },
    "bem_nao_cadastrado": {
        "cadastrado": "Cadastrado no sistema",
        "nao_patrimonio": "Não é patrimônio",
    },
    "conflito_sincronizacao": {
        "aplicar": "Aplicar mesmo assim",
        "descartar": "Descartar",
    },
    "operacao_imprevista": {"ciente": "Ciente"},
    "bem_baixado_encontrado": {"ciente": "Ciente"},
}


def acoes_do_tipo(tipo: str) -> dict[str, str]:
    return ACOES.get(tipo, {})


def executar(pendencia, dados, usuario: dict) -> tuple[str, int | None]:
    """Executa o efeito da ação, se houver. Devolve (prefixo do texto da resolução, id do registro gerado)."""
    acao = dados.acao
    if acao not in acoes_do_tipo(pendencia.tipo):
        raise HTTPException(status_code=400, detail="Esta ação não se aplica a este tipo de pendência.")

    if acao == "encontrado":
        if not dados.setor_id:
            raise HTTPException(status_code=400, detail="Informe o setor onde o bem foi encontrado.")
        setor = DataBase().execute("SELECT nome FROM setores WHERE id = %s AND ativo = TRUE", (dados.setor_id,),
                                   many=False)
        if setor is None:
            raise HTTPException(status_code=400, detail="Setor não encontrado ou inativo.")
        return f"Encontrado em {setor[0]}. ", dados.setor_id

    if acao == "baixa_extravio":
        from modules.bem import baixa
        from modules.bem.schemas import BaixaCreate
        if not pendencia.bem_id:
            raise HTTPException(status_code=400, detail="Esta pendência não tem bem associado.")
        documento = (dados.documento or "").strip()
        if len(documento) < 3:
            raise HTTPException(status_code=400, detail="Informe o número do boletim de ocorrência.")
        criada = baixa.solicitar(pendencia.bem_id, BaixaCreate(motivo="extravio", justificativa=dados.resolucao,
                                                               documento_ref=documento), usuario)
        return f"Baixa por extravio aberta ({criada.get('status', 'registrada')}). ", criada.get("id")

    if acao == "cadastrado":
        if not dados.bem_id or DataBase().execute("SELECT 1 FROM bens WHERE id = %s", (dados.bem_id,), many=False) is None:
            raise HTTPException(status_code=400, detail="Informe o bem cadastrado.")
        return "Bem cadastrado. ", dados.bem_id

    if acao == "aplicar":
        return _aplicar_operacao(pendencia, usuario), None

    return "", None


def _aplicar_operacao(pendencia, usuario: dict) -> str:
    """Aplica de novo a operação em conflito, agora, como o usuário do patrimônio."""
    from modules.sincronizacao.service import OPERACOES
    row = DataBase().execute("SELECT tipo, dados FROM sync_operacoes WHERE id = %s", (pendencia.sync_operacao_id,),
                             many=False)
    if row is None:
        raise HTTPException(status_code=404, detail="Operação de origem não encontrada.")
    tipo, dados = row
    modelo, aplicar = OPERACOES[tipo]
    try:
        aplicar(modelo.model_validate(dados), usuario, None)
    except HTTPException as erro:
        raise HTTPException(status_code=409, detail=f"Ainda não é possível aplicar: {erro.detail}")
    return "Operação aplicada pelo patrimônio. "
