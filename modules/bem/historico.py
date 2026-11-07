"""Linha do tempo do bem: todos os eventos, do mais recente para o mais antigo, numa única consulta.

Fontes: auditoria (cadastro, edição, baixa, reativação), transferências, empréstimos, manutenções,
conferências de inventário e pedidos de baixa. Cada fonte usa um índice por bem, então o custo cresce com o histórico do bem,
não com o tamanho das tabelas.

Regras para não duplicar eventos:
- Transferência feita direto pelo patrimônio (quem pediu = quem decidiu) é um evento só.
- Baixa abaixo da alçada (quem pediu = quem decidiu) aparece só como "baixa", pela auditoria.
- Envio e retorno de manutenção vêm da tabela de manutenções, não da auditoria.
"""
from fastapi import HTTPException

from core.database import DataBase

_EVENTOS = """
WITH eventos AS (
    -- Auditoria do bem (cadastro, edição, baixa efetivada, reativação)
    SELECT CASE a.acao WHEN 'criar' THEN 'cadastro' WHEN 'editar' THEN 'edicao'
                       WHEN 'baixar' THEN 'baixa' WHEN 'reativar' THEN 'reativacao' END AS tipo,
           a.em, u.nome AS autor, a.id AS referencia,
           jsonb_build_object('antes', a.antes, 'depois', a.depois) AS dados
    FROM auditoria a LEFT JOIN usuarios u ON u.id = a.usuario_id
    WHERE a.entidade = 'bem' AND a.registro_id = %(bem)s AND a.acao IN ('criar', 'editar', 'baixar', 'reativar')

    UNION ALL
    -- Cadastro de bens antigos, anteriores à auditoria
    SELECT 'cadastro', b.data_cadastro, NULL, b.id, '{}'::jsonb
    FROM bens b
    WHERE b.id = %(bem)s AND b.data_cadastro IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM auditoria a
                      WHERE a.entidade = 'bem' AND a.registro_id = b.id AND a.acao = 'criar')

    UNION ALL
    -- Pedido de transferência (quando alguém pediu e outra pessoa decide)
    SELECT 'transferencia_solicitada', m.data_movimentacao, us.nome, m.id,
           jsonb_build_object('origem', so.nome, 'destino', sd.nome, 'motivo', m.justificativa, 'situacao', m.status)
    FROM movimentacoes m
    LEFT JOIN usuarios us ON us.id = m.solicitante_id
    LEFT JOIN setores so ON so.id = m.setor_origem_id
    LEFT JOIN setores sd ON sd.id = m.setor_destino_id
    WHERE m.bem_id = %(bem)s AND m.solicitante_id IS NOT NULL
      AND (m.status <> 'aprovada' OR m.decisor_id IS DISTINCT FROM m.solicitante_id)

    UNION ALL
    -- Desfecho da transferência (concluída, recusada ou cancelada), com as fotos do recebimento
    SELECT 'transferencia_' || m.status, COALESCE(m.data_decisao, m.data_movimentacao), ud.nome, m.id,
           jsonb_build_object('origem', so.nome, 'destino', sd.nome, 'motivo', m.motivo_decisao,
                              'fotos', (SELECT COALESCE(jsonb_agg(f.id ORDER BY f.id), '[]'::jsonb) FROM fotos f
                                        WHERE f.registro_tipo = 'aceite_transferencia' AND f.registro_id = m.id))
    FROM movimentacoes m
    LEFT JOIN usuarios ud ON ud.id = m.decisor_id
    LEFT JOIN setores so ON so.id = m.setor_origem_id
    LEFT JOIN setores sd ON sd.id = m.setor_destino_id
    WHERE m.bem_id = %(bem)s AND m.status IN ('aprovada', 'recusada', 'cancelada')

    UNION ALL
    SELECT 'emprestimo_saida', e.saida_em, u.nome, e.id,
           jsonb_build_object('tomador', e.tomador, 'motivo', e.motivo, 'devolucao_prevista', e.devolucao_prevista)
    FROM emprestimos e LEFT JOIN usuarios u ON u.id = e.registrado_por
    WHERE e.bem_id = %(bem)s

    UNION ALL
    SELECT 'emprestimo_devolucao', e.devolvido_em, u.nome, e.id,
           jsonb_build_object('tomador', e.tomador, 'observacao', e.observacao_devolucao,
                              'dias_atraso', GREATEST(e.devolvido_em::date - e.devolucao_prevista, 0))
    FROM emprestimos e LEFT JOIN usuarios u ON u.id = e.recebido_por
    WHERE e.bem_id = %(bem)s AND e.devolvido_em IS NOT NULL

    UNION ALL
    SELECT 'manutencao_envio', m.enviado_em, u.nome, m.id,
           jsonb_build_object('descricao', m.descricao, 'destino', m.destino)
    FROM manutencoes m LEFT JOIN usuarios u ON u.id = m.enviado_por
    WHERE m.bem_id = %(bem)s

    UNION ALL
    SELECT 'manutencao_retorno', m.retorno_em, u.nome, m.id,
           jsonb_build_object('servico', m.servico_realizado, 'estado', m.estado_retorno, 'destino', m.destino)
    FROM manutencoes m LEFT JOIN usuarios u ON u.id = m.recebido_por
    WHERE m.bem_id = %(bem)s AND m.retorno_em IS NOT NULL

    UNION ALL
    -- Conferência em inventário, com as fotos da conferência
    SELECT 'conferencia_' || it.situacao, it.conferido_em, u.nome, it.id,
           jsonb_build_object('inventario', it.inventario_id, 'esperado', se.nome, 'encontrado', sf.nome,
                              'estado', it.estado_encontrado,
                              'fotos', (SELECT COALESCE(jsonb_agg(f.id ORDER BY f.id), '[]'::jsonb) FROM fotos f
                                        WHERE f.registro_tipo = 'conferencia' AND f.registro_id = it.id))
    FROM inventario_itens it
    LEFT JOIN usuarios u ON u.id = it.conferido_por
    LEFT JOIN setores se ON se.id = it.setor_esperado_id
    LEFT JOIN setores sf ON sf.id = it.setor_encontrado_id
    WHERE it.bem_id = %(bem)s AND it.situacao IS NOT NULL

    UNION ALL
    -- Pedido de baixa que dependeu de outra pessoa (acima da alçada)
    SELECT 'baixa_solicitada', b.criada_em, u.nome, b.id,
           jsonb_build_object('motivo', b.motivo, 'justificativa', b.justificativa,
                              'documento', b.documento_ref, 'situacao', b.status)
    FROM baixas b LEFT JOIN usuarios u ON u.id = b.solicitante_id
    WHERE b.bem_id = %(bem)s AND b.decisor_id IS DISTINCT FROM b.solicitante_id

    UNION ALL
    SELECT 'baixa_recusada', b.decidida_em, u.nome, b.id, jsonb_build_object('motivo', b.motivo_decisao)
    FROM baixas b LEFT JOIN usuarios u ON u.id = b.decisor_id
    WHERE b.bem_id = %(bem)s AND b.status = 'recusada'
)
SELECT tipo, em, autor, referencia, dados FROM eventos
ORDER BY em DESC, referencia DESC
LIMIT %(limite)s
"""

_ESTADOS = {"novo": "novo", "bom": "bom", "regular": "regular", "ruim": "ruim", "inservivel": "inservível"}


def _data(valor) -> str:
    """Datas vêm do JSON como texto ISO (AAAA-MM-DD); mostra no formato brasileiro."""
    if not valor:
        return "—"
    ano, mes, dia = str(valor)[:10].split("-")
    return f"{dia}/{mes}/{ano}"


def _descrever(tipo: str, d: dict) -> tuple[str, str]:
    """Título e detalhe legíveis de cada tipo de evento."""
    origem, destino = d.get("origem"), d.get("destino")
    if tipo == "cadastro":
        return "Cadastro do bem", ""
    if tipo == "edicao":
        campos = sorted((d.get("depois") or {}).keys())
        return "Cadastro alterado", ("Campos: " + ", ".join(campos)) if campos else ""
    if tipo == "baixa":
        depois = d.get("depois") or {}
        return "Baixa do bem", " · ".join(filter(None, [depois.get("motivo"), depois.get("documento")]))
    if tipo == "reativacao":
        return "Bem reativado", ""
    if tipo == "transferencia_solicitada":
        situacao = {"pendente": "aguarda liberação", "liberada": "aguarda recebimento"}.get(d.get("situacao"), "")
        return "Transferência solicitada", " · ".join(
            filter(None, [f"{origem or '—'} → {destino}", d.get("motivo"), situacao]))
    if tipo == "transferencia_aprovada":
        titulo = "Entrada no almoxarifado" if origem is None else "Transferência concluída"
        return titulo, f"{origem} → {destino}" if origem else (destino or "")
    if tipo == "transferencia_recusada":
        return "Transferência recusada", " · ".join(filter(None, [f"{origem or '—'} → {destino}", d.get("motivo")]))
    if tipo == "transferencia_cancelada":
        return "Transferência cancelada pelo almoxarifado", " · ".join(
            filter(None, [f"{origem or '—'} → {destino}", d.get("motivo")]))
    if tipo == "emprestimo_saida":
        return "Emprestado", f"Para {d.get('tomador')} · {d.get('motivo')} · devolução prevista {_data(d.get('devolucao_prevista'))}"
    if tipo == "emprestimo_devolucao":
        atraso = d.get("dias_atraso") or 0
        partes = [f"Devolvido por {d.get('tomador')}", f"{atraso} dia(s) de atraso" if atraso else "no prazo",
                  d.get("observacao")]
        return "Devolução do empréstimo", " · ".join(filter(None, partes))
    if tipo == "manutencao_envio":
        return "Enviado para manutenção", f"{d.get('descricao')} · {d.get('destino')}"
    if tipo == "manutencao_retorno":
        return "Retorno da manutenção", f"{d.get('servico')} · estado: {_ESTADOS.get(d.get('estado'), d.get('estado'))}"
    if tipo == "baixa_solicitada":
        situacao = {"pendente": "aguarda aprovação", "aprovada": "aprovada", "recusada": "recusada"}.get(d.get("situacao"), "")
        return "Baixa solicitada", " · ".join(filter(None, [d.get("motivo"), d.get("documento"), situacao]))
    if tipo == "conferencia_localizado":
        estado = d.get("estado")
        partes = [f"Inventário #{d.get('inventario')}", f"localizado em {d.get('encontrado')}",
                  f"estado: {_ESTADOS.get(estado, estado)}" if estado else None]
        return "Conferido no inventário", " · ".join(filter(None, partes))
    if tipo == "conferencia_outro_setor":
        return "Encontrado em outro setor", (f"Inventário #{d.get('inventario')} · esperado em {d.get('esperado') or '—'}, "
                                             f"encontrado em {d.get('encontrado')}")
    if tipo == "conferencia_nao_localizado":
        return "Não localizado no inventário", f"Inventário #{d.get('inventario')} · esperado em {d.get('esperado') or '—'}"
    if tipo == "baixa_recusada":
        return "Baixa recusada", d.get("motivo") or ""
    return tipo, ""


def linha_do_tempo(bem_id: int, limite: int = 200) -> list[dict]:
    if DataBase().execute("SELECT 1 FROM bens WHERE id = %s", (bem_id,), many=False) is None:
        raise HTTPException(status_code=404, detail=f"Bem com id {bem_id} não encontrado")
    rows = DataBase().execute(_EVENTOS, {"bem": bem_id, "limite": limite}) or []
    eventos = []
    for tipo, em, autor, referencia, dados in rows:
        titulo, detalhe = _descrever(tipo, dados or {})
        eventos.append({"tipo": tipo, "em": em, "autor": autor, "titulo": titulo, "detalhe": detalhe,
                        "referencia_id": referencia, "fotos": (dados or {}).get("fotos", [])})
    return eventos
