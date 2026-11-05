"""Termo de responsabilidade: lista os bens sob a guarda de um responsável,
em folha para impressão e assinatura. Não guarda nada no banco."""
import html
from datetime import date

from fastapi import HTTPException

from core.database import DataBase

QUERY_RESPONSAVEL = "SELECT id, nome, cargo FROM responsaveis WHERE id = %s"
QUERY_BENS_DO_RESPONSAVEL = """
    SELECT b.codigo_tombamento, b.nome, b.estado_conservacao, b.valor_aquisicao, s.nome AS setor
    FROM bens b
    JOIN (
        SELECT DISTINCT ON (bem_id) bem_id, setor_destino_id
        FROM movimentacoes
        WHERE ativo = TRUE AND status = 'aprovada'
        ORDER BY bem_id, COALESCE(data_decisao, data_movimentacao) DESC, id DESC
    ) m ON m.bem_id = b.id
    JOIN setores s ON s.id = m.setor_destino_id
    WHERE s.responsavel_id = %s AND b.ativo = TRUE
    ORDER BY b.codigo_tombamento
"""


def _moeda(valor) -> str:
    """Formata no padrão brasileiro: 1.234,56."""
    texto = f"{float(valor or 0):,.2f}"
    return texto.replace(",", "X").replace(".", ",").replace("X", ".")


def termo_html(responsavel_id: int) -> str:
    resp = DataBase().execute(QUERY_RESPONSAVEL, (responsavel_id,))
    if not resp:
        raise HTTPException(status_code=404, detail=f"Responsável com id {responsavel_id} não encontrado")
    _, nome, cargo = resp[0]
    bens = DataBase().execute(QUERY_BENS_DO_RESPONSAVEL, (responsavel_id,)) or []
    linhas = "\n".join(
        f"<tr><td>{html.escape(cod)}</td><td>{html.escape(n)}</td><td>{html.escape(est or '')}</td>"
        f"<td>{html.escape(setor or '')}</td>"
        f"<td class='num'>R$ {_moeda(valor)}</td></tr>"
        for cod, n, est, valor, setor in bens
    ) or "<tr><td colspan='5' class='vazio'>Nenhum bem sob esta guarda.</td></tr>"
    total = sum(float(valor or 0) for _, _, _, valor, _ in bens)
    hoje = date.today().strftime("%d/%m/%Y")
    return _MODELO.format(
        nome=html.escape(nome), cargo=html.escape(cargo), linhas=linhas, quantidade=len(bens),
        total=_moeda(total), hoje=hoje,
    )


_MODELO = """<!DOCTYPE html>
<html lang="pt-br">
<head>
<meta charset="UTF-8">
<title>Termo de responsabilidade — {nome}</title>
<style>
  body {{ font-family: sans-serif; color: #1c1c1e; margin: 0; padding: 24px; }}
  .barra {{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }}
  .barra button {{ background: #820ad1; color: #fff; border: 0; border-radius: 12px; padding: 10px 18px; font-weight: 600; cursor: pointer; }}
  h1 {{ font-size: 20px; margin: 0 0 4px; }}
  .sub {{ color: #6e6e73; margin: 0 0 16px; }}
  p.texto {{ line-height: 1.5; }}
  table {{ width: 100%; border-collapse: collapse; font-size: 13px; }}
  th, td {{ border: 1px solid #c7c7cc; padding: 6px 8px; text-align: left; }}
  th {{ background: #f5f5f7; text-transform: uppercase; font-size: 11px; letter-spacing: .04em; }}
  td.num {{ text-align: right; white-space: nowrap; }}
  td.vazio {{ text-align: center; color: #6e6e73; }}
  .assinatura {{ margin-top: 56px; display: flex; gap: 48px; }}
  .assinatura div {{ flex: 1; border-top: 1px solid #1c1c1e; padding-top: 6px; font-size: 13px; text-align: center; }}
  @media print {{ .barra {{ display: none; }} body {{ padding: 0; }} @page {{ margin: 12mm; }} }}
</style>
</head>
<body>
  <div class="barra">
    <strong>Termo de responsabilidade</strong>
    <button type="button" onclick="window.print()">Imprimir</button>
  </div>
  <h1>Termo de responsabilidade pela guarda de bens</h1>
  <p class="sub">PatriFlow · emitido em {hoje}</p>
  <p class="texto">Declaro, para os devidos fins, que recebo sob minha guarda os bens patrimoniais
  listados abaixo ({quantidade} itens, valor de aquisição total R$ {total}), comprometendo-me a zelar
  por sua conservação e a comunicar ao setor de patrimônio qualquer transferência, empréstimo,
  manutenção, extravio ou dano.</p>
  <p class="texto"><strong>Responsável:</strong> {nome} — {cargo}</p>
  <table>
    <thead><tr><th>Tombo</th><th>Descrição</th><th>Conservação</th><th>Setor atual</th><th>Aquisição</th></tr></thead>
    <tbody>
{linhas}
    </tbody>
  </table>
  <div class="assinatura">
    <div>{nome}<br>Responsável</div>
    <div>Setor de patrimônio<br>Responsável pela emissão</div>
  </div>
</body>
</html>
"""
