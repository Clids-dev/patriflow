"""Regras de guarda do bem, usadas dentro de uma transação (DataBase().transacao()).

Empréstimo e manutenção não mudam a localização: o bem continua sob a guarda do setor onde está.
Quem opera o bem (decisão D1):
- setor de patrimônio: qualquer bem;
- responsável de setor: bens do próprio setor;
- agente de campo: bens do próprio setor e dos setores designados a ele. Fora deles, só num imprevisto,
  informando o motivo; a operação fica registrada e vira aviso para o patrimônio.

Todas as funções recebem o cursor da transação em andamento. `travar_bem` usa SELECT ... FOR UPDATE:
duas operações simultâneas sobre o mesmo bem são serializadas, e a segunda vê o resultado da primeira.
"""
from fastapi import HTTPException

ADMIN = "setor_patrimonio"
COLABORADORES = ("agente_campo", "responsavel_setor")
STATUS_MANUTENCAO = "Manutenção"

_SETOR_ATUAL = """
    SELECT setor_destino_id FROM movimentacoes
    WHERE bem_id = %s AND ativo = TRUE AND status = 'aprovada'
    ORDER BY COALESCE(data_decisao, data_movimentacao) DESC, id DESC
    LIMIT 1
"""

_OCUPACAO = """
    SELECT EXISTS (SELECT 1 FROM emprestimos WHERE bem_id = %(bem)s AND devolvido_em IS NULL),
           EXISTS (SELECT 1 FROM manutencoes WHERE bem_id = %(bem)s AND retorno_em IS NULL),
           EXISTS (SELECT 1 FROM movimentacoes
                   WHERE bem_id = %(bem)s AND ativo = TRUE AND status IN ('pendente', 'liberada'))
"""


def travar_bem(cur, bem_id: int) -> dict:
    cur.execute(
        "SELECT id, nome, codigo_tombamento, ativo, status, estado_conservacao FROM bens WHERE id = %s FOR UPDATE",
        (bem_id,),
    )
    row = cur.fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail=f"Bem com id {bem_id} não encontrado")
    return {"id": row[0], "nome": row[1], "codigo_tombamento": row[2], "ativo": row[3],
            "status": row[4], "estado_conservacao": row[5]}


def setor_atual(cur, bem_id: int) -> int | None:
    cur.execute(_SETOR_ATUAL, (bem_id,))
    row = cur.fetchone()
    return row[0] if row else None


def exigir_livre(cur, bem: dict, *, aceitar_status_manutencao: bool = False) -> None:
    """O bem precisa estar ativo e sem outra operação aberta (empréstimo, manutenção ou transferência).

    `aceitar_status_manutencao`: bens marcados como "Manutenção" pela edição antiga, sem registro
    aberto, podem ter a manutenção registrada agora.
    """
    if not bem["ativo"]:
        raise HTTPException(status_code=400, detail="Este bem foi baixado e não pode mais ser movimentado.")
    cur.execute(_OCUPACAO, {"bem": bem["id"]})
    emprestado, em_manutencao, em_transferencia = cur.fetchone()
    if emprestado:
        raise HTTPException(status_code=409, detail="Este bem está emprestado. Registre a devolução antes.")
    if em_manutencao or (bem["status"] == STATUS_MANUTENCAO and not aceitar_status_manutencao):
        raise HTTPException(status_code=409, detail="Este bem está em manutenção. Registre o retorno antes.")
    if em_transferencia:
        raise HTTPException(status_code=409, detail="Este bem tem uma transferência em andamento.")


MOTIVO_IMPREVISTO_MINIMO = 10

_SETORES_DO_AGENTE = "SELECT setor_id FROM agente_setores WHERE usuario_id = %s"


def setores_do_colaborador(cur, usuario: dict) -> set[int]:
    """Setores em que o colaborador atua: o próprio e, para o agente, os designados pelo patrimônio."""
    setores = {usuario["setor_id"]} if usuario.get("setor_id") else set()
    if usuario["perfil"] == "agente_campo":
        cur.execute(_SETORES_DO_AGENTE, (usuario["id"],))
        setores |= {r[0] for r in cur.fetchall()}
    return setores


def exigir_guarda(cur, usuario: dict, bem_id: int, imprevisto: str | None = None) -> bool:
    """Confere se o usuário pode operar o bem. Devolve True quando a operação é um imprevisto
    (agente fora dos setores designados, com motivo): quem chama registra o aviso ao patrimônio."""
    perfil = usuario["perfil"]
    if perfil == ADMIN:
        return False
    if perfil not in COLABORADORES:
        raise HTTPException(status_code=403, detail="Seu perfil não pode registrar esta operação.")
    setor = setor_atual(cur, bem_id)
    if setor is not None and setor in setores_do_colaborador(cur, usuario):
        return False
    if perfil == "agente_campo":
        if len((imprevisto or "").strip()) >= MOTIVO_IMPREVISTO_MINIMO:
            return True
        raise HTTPException(status_code=403,
                            detail="Este bem é de um setor que não foi designado a você. Em caso de imprevisto, "
                                   f"informe o motivo (pelo menos {MOTIVO_IMPREVISTO_MINIMO} caracteres).")
    raise HTTPException(status_code=403, detail="Você só registra operações de bens do seu setor.")


def registrar_imprevisto(cur, usuario: dict, bem: dict, operacao: str, motivo: str) -> None:
    """Aviso ao patrimônio: operação de agente fora dos setores designados (pendência para ciência)."""
    cur.execute(
        """INSERT INTO pendencias (tipo, bem_id, setor_id, descricao, criada_por)
           VALUES ('operacao_imprevista', %s, %s, %s, %s)""",
        (bem["id"], setor_atual(cur, bem["id"]),
         f"{operacao} de {bem['codigo_tombamento']} · {bem['nome']} fora dos setores designados. "
         f"Motivo: {motivo.strip()}", usuario["id"]))
