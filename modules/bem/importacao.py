"""Importação de bens por planilha CSV.

Fluxo em duas etapas: simular (valida tudo e mostra o resultado, sem gravar)
e importar (grava linha a linha). Uma linha inválida não impede as demais,
e cada erro vem com o número da linha da planilha.

Colunas obrigatórias: nome, id_categoria, status, estado_conservacao, valor_aquisicao.
Opcionais: codigo_tombamento (se vazio, é gerado pela sigla da categoria), tipo,
marca, modelo, numero_serie, nota_fiscal, data_entrada (AAAA-MM-DD),
vida_util_meses, valor_residual, garantia_fim (AAAA-MM-DD).
"""
import csv
import io

from fastapi import HTTPException
from pydantic import ValidationError

from core.tombamento import is_valid_tombo
from modules.bem.schemas import BemCreate

LIMITE_LINHAS = 1000
LIMITE_BYTES = 2 * 1024 * 1024
OBRIGATORIAS = {"nome", "id_categoria", "status", "estado_conservacao", "valor_aquisicao"}
OPCIONAIS = {"codigo_tombamento", "tipo", "marca", "modelo", "numero_serie", "nota_fiscal",
             "data_entrada", "vida_util_meses", "valor_residual", "garantia_fim"}


def _numero(texto: str) -> str:
    """Aceita 1.234,56 e 1234.56."""
    texto = texto.strip()
    if "," in texto:
        texto = texto.replace(".", "").replace(",", ".")
    return texto


def ler_csv(dados: bytes) -> list[dict]:
    if len(dados) > LIMITE_BYTES:
        raise HTTPException(status_code=413, detail="Planilha muito grande. O limite é 2 MB.")
    try:
        texto = dados.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise HTTPException(status_code=400, detail="Arquivo com codificação inválida. Salve como CSV UTF-8.")
    leitor = csv.DictReader(io.StringIO(texto), delimiter=";" if ";" in texto.split("\n", 1)[0] else ",")
    cabecalho = {c.strip() for c in (leitor.fieldnames or [])}
    faltando = OBRIGATORIAS - cabecalho
    if faltando:
        raise HTTPException(status_code=400, detail="Colunas obrigatórias ausentes: " + ", ".join(sorted(faltando)))
    linhas = []
    for numero, linha in enumerate(leitor, start=2):  # linha 1 é o cabeçalho
        if not any((v or "").strip() for v in linha.values()):
            continue
        linhas.append((numero, {k.strip(): (v or "").strip() for k, v in linha.items() if k}))
    if len(linhas) > LIMITE_LINHAS:
        raise HTTPException(status_code=400, detail=f"A planilha tem mais de {LIMITE_LINHAS} linhas.")
    return linhas


def montar_bem(campos: dict) -> BemCreate:
    """Converte uma linha em BemCreate, tratando vazios e formatos brasileiros."""
    dados = {}
    for chave, valor in campos.items():
        if chave not in OBRIGATORIAS | OPCIONAIS or valor == "":
            continue
        dados[chave] = _numero(valor) if chave in {"valor_aquisicao", "valor_residual"} else valor
    dados.setdefault("codigo_tombamento", "")
    if dados["codigo_tombamento"] == "":
        dados["codigo_tombamento"] = "PENDENTE"  # gerado depois, na importação real
    for inteiro in ("id_categoria", "vida_util_meses"):
        if inteiro in dados:
            dados[inteiro] = int(float(dados[inteiro]))
    if "valor_aquisicao" in dados:
        dados["valor"] = float(dados["valor_aquisicao"])
        dados["valor_aquisicao"] = float(dados["valor_aquisicao"])
    if "valor_residual" in dados:
        dados["valor_residual"] = float(dados["valor_residual"])
    dados.setdefault("tipo", "Equipamento")
    return BemCreate(**dados)


def _erro_legivel(exc: ValidationError) -> str:
    return "; ".join(f"{'.'.join(str(p) for p in e['loc'])}: {e['msg']}" for e in exc.errors())


def processar(dados: bytes, simular: bool, usuario: dict, service_factory) -> dict:
    """Valida (e, se não for simulação, grava) cada linha. Devolve o relatório."""
    linhas = ler_csv(dados)
    relatorio = {"simulacao": simular, "total": len(linhas), "validas": 0, "importados": 0, "erros": []}
    service = service_factory()
    for numero, campos in linhas:
        try:
            bem = montar_bem(campos)
        except (ValidationError, ValueError, TypeError) as exc:
            msg = _erro_legivel(exc) if isinstance(exc, ValidationError) else f"valor inválido ({exc})"
            relatorio["erros"].append({"linha": numero, "erro": msg})
            continue
        if bem.codigo_tombamento == "PENDENTE":
            bem.codigo_tombamento = None
        if simular:
            if bem.codigo_tombamento is not None and not is_valid_tombo(bem.codigo_tombamento):
                relatorio["erros"].append({"linha": numero, "erro": "Número de tombo inválido — verifique a digitação"})
                continue
            relatorio["validas"] += 1
            continue
        relatorio["validas"] += 1
        try:
            if bem.codigo_tombamento is None:
                bem.codigo_tombamento = service.get_proximo_codigo(bem.id_categoria)
            service.create_bem(bem, usuario)
            relatorio["importados"] += 1
        except HTTPException as exc:
            relatorio["erros"].append({"linha": numero, "erro": str(exc.detail)})
    return relatorio
