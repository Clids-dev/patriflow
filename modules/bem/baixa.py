"""REQ-EX-01: baixa com motivo e documento. Acima do valor de alçada, a baixa espera a aprovação de
outro servidor do setor de patrimônio. Quem pediu não pode aprovar a própria baixa."""
from fastapi import HTTPException

from core import config
from core.database import DataBase
from modules.auditoria.service import registrar_acao
from modules.bem.repository import BemRepository

MOTIVOS = ("doacao", "inservivel", "extravio", "venda", "sinistro", "descarte")
ADMIN = "setor_patrimonio"


def _somente_patrimonio(usuario: dict):
    if usuario["perfil"] != ADMIN:
        raise HTTPException(status_code=403, detail="Somente o setor de patrimônio dá baixa em bens.")


def _aplicar(baixa_id: int, bem_id: int, valor, motivo: str, documento: str, usuario: dict, decisor_id: int):
    BemRepository().desativar(bem_id)
    registrar_acao("bem", bem_id, "baixar", usuario, {"ativo": True},
                   {"ativo": False, "motivo": motivo, "documento": documento, "baixa_id": baixa_id})
    DataBase().commit(
        """UPDATE baixas SET status = 'aprovada', decisor_id = %s, decidida_em = NOW() WHERE id = %s""",
        (decisor_id, baixa_id))


def solicitar(bem_id: int, dados, usuario: dict) -> dict:
    _somente_patrimonio(usuario)
    bem = BemRepository().get_by_id(bem_id)
    if bem is None:
        raise HTTPException(status_code=404, detail=f"Bem com id {bem_id} não encontrado")
    if not bem.ativo:
        raise HTTPException(status_code=400, detail="Este bem já está baixado.")
    valor = float(bem.valor_aquisicao if bem.valor_aquisicao is not None else bem.valor)
    try:
        baixa_id = DataBase().commit(
            """INSERT INTO baixas (bem_id, motivo, justificativa, documento_ref, valor_bem, solicitante_id)
               VALUES (%s, %s, %s, %s, %s, %s) RETURNING id""",
            (bem_id, dados.motivo, dados.justificativa, dados.documento_ref, valor, usuario["id"]))[0]
    except Exception as exc:
        if "baixas_pendente_por_bem" in str(exc):
            raise HTTPException(status_code=409, detail="Já existe uma baixa aguardando aprovação para este bem.")
        raise
    if valor < config.ALCADA_BAIXA_VALOR:
        _aplicar(baixa_id, bem_id, valor, dados.motivo, dados.documento_ref, usuario, usuario["id"])
        return {"id": baixa_id, "status": "aprovada", "mensagem": "Bem baixado."}
    return {"id": baixa_id, "status": "pendente",
            "mensagem": f"Valor acima de R$ {config.ALCADA_BAIXA_VALOR:,.2f}. A baixa aguarda a aprovação de outro servidor do patrimônio."}


def pendentes(usuario: dict) -> list[dict]:
    _somente_patrimonio(usuario)
    rows = DataBase().execute(
        """SELECT b.id, b.bem_id, bem.nome, bem.codigo_tombamento, b.motivo, b.justificativa, b.documento_ref,
                  b.valor_bem, u.nome, b.solicitante_id, b.criada_em
           FROM baixas b JOIN bens bem ON bem.id = b.bem_id JOIN usuarios u ON u.id = b.solicitante_id
           WHERE b.status = 'pendente' ORDER BY b.criada_em""") or []
    return [{"id": r[0], "bem_id": r[1], "bem_nome": r[2], "codigo_tombamento": r[3], "motivo": r[4],
             "justificativa": r[5], "documento_ref": r[6], "valor": float(r[7]), "solicitante": r[8],
             "solicitante_id": r[9], "criada_em": r[10]} for r in rows]


def decidir(baixa_id: int, aprovar: bool, motivo: str | None, usuario: dict) -> dict:
    _somente_patrimonio(usuario)
    rows = DataBase().execute(
        "SELECT bem_id, motivo, documento_ref, solicitante_id, status FROM baixas WHERE id = %s", (baixa_id,)) or []
    if not rows:
        raise HTTPException(status_code=404, detail="Baixa não encontrada")
    bem_id, motivo_baixa, documento, solicitante_id, status = rows[0]
    if status != "pendente":
        raise HTTPException(status_code=409, detail="Esta baixa já foi decidida.")
    if solicitante_id == usuario["id"]:
        raise HTTPException(status_code=403, detail="Quem pediu a baixa não pode aprovar a própria baixa.")
    if aprovar:
        _aplicar(baixa_id, bem_id, None, motivo_baixa, documento, usuario, usuario["id"])
        return {"id": baixa_id, "status": "aprovada"}
    if not (motivo or "").strip():
        raise HTTPException(status_code=400, detail="Informe o motivo da recusa.")
    DataBase().commit(
        """UPDATE baixas SET status = 'recusada', decisor_id = %s, decidida_em = NOW(), motivo_decisao = %s
           WHERE id = %s""", (usuario["id"], motivo.strip(), baixa_id))
    return {"id": baixa_id, "status": "recusada"}
