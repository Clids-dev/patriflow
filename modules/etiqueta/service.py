"""W04: etiqueta com QR Code do número de tombamento.

A etiqueta é gerada sob demanda, sem guardar nada no banco: pode ser
reimpressa quantas vezes for preciso. O QR codifica o tombo completo
(com dígito verificador) e o mesmo tombo aparece em texto legível abaixo.
"""
import html

import segno
from fastapi import HTTPException

from modules.bem.repository import BemRepository

LIMITE_LOTE = 200
_QR_TAMANHO = 240  # área do QR dentro da etiqueta (px)
_LARGURA, _ALTURA = 300, 380


def _caminho_qr(tombo: str) -> str:
    qr = segno.make(tombo, error="q")
    n = qr.symbol_size(scale=1, border=0)[0]
    trechos = []
    for y, linha in enumerate(qr.matrix_iter(scale=1, border=0)):
        for x, escuro in enumerate(linha):
            if escuro:
                trechos.append(f"M{x},{y}h1v1h-1z")
    return n, "".join(trechos)


def etiqueta_svg(tombo: str, nome: str | None) -> str:
    n, caminho = _caminho_qr(tombo)
    # Zona de silêncio de 4 módulos em volta do QR, como recomenda a norma ISO/IEC 18004.
    modulo = _QR_TAMANHO / (n + 8)
    origem_x = (_LARGURA - (n + 8) * modulo) / 2 + 4 * modulo
    origem_y = 20 + 4 * modulo
    nome_curto = (nome or "")[:34]
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {_LARGURA} {_ALTURA}" '
        f'width="{_LARGURA}" height="{_ALTURA}" role="img" aria-label="Etiqueta {html.escape(tombo)}">'
        f'<rect width="{_LARGURA}" height="{_ALTURA}" fill="#ffffff"/>'
        f'<g transform="translate({origem_x},{origem_y}) scale({modulo})" fill="#000000">'
        f'<path d="{caminho}"/></g>'
        f'<text x="{_LARGURA / 2}" y="{_QR_TAMANHO + 60}" text-anchor="middle" '
        f'font-family="monospace" font-size="26" font-weight="700" fill="#000000">{html.escape(tombo)}</text>'
        f'<text x="{_LARGURA / 2}" y="{_QR_TAMANHO + 90}" text-anchor="middle" '
        f'font-family="sans-serif" font-size="14" fill="#333333">{html.escape(nome_curto)}</text>'
        "</svg>"
    )


def _bem_ou_404(bem_id: int):
    bem = BemRepository().get_detalhes(bem_id)
    if bem is None:
        raise HTTPException(status_code=404, detail=f"Bem com id {bem_id} não encontrado")
    return bem


def etiqueta_do_bem(bem_id: int) -> str:
    bem = _bem_ou_404(bem_id)
    return etiqueta_svg(bem.codigo_tombamento, bem.nome)


def pagina_lote(ids: list[int]) -> str:
    if not ids:
        raise HTTPException(status_code=400, detail="Informe ao menos um bem para gerar etiquetas.")
    if len(ids) > LIMITE_LOTE:
        raise HTTPException(status_code=400, detail=f"Cada lote aceita no máximo {LIMITE_LOTE} etiquetas.")
    etiquetas = []
    for bem_id in dict.fromkeys(ids):  # remove repetidos, mantém a ordem
        bem = _bem_ou_404(bem_id)
        etiquetas.append(f'<div class="etiqueta">{etiqueta_svg(bem.codigo_tombamento, bem.nome)}</div>')
    return _PAGINA.replace("{{ETIQUETAS}}", "\n".join(etiquetas))


_PAGINA = """<!DOCTYPE html>
<html lang="pt-br">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Etiquetas de patrimônio — PatriFlow</title>
<style>
  body { font-family: sans-serif; margin: 0; padding: 16px; background: #f5f5f7; color: #1c1c1e; }
  .barra { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  .barra button { background: #820ad1; color: #fff; border: 0; border-radius: 12px; padding: 10px 18px; font-weight: 600; cursor: pointer; }
  .folha { display: flex; flex-wrap: wrap; gap: 12px; }
  .etiqueta { background: #fff; border: 1px dashed #c7c7cc; border-radius: 6px; padding: 4px; }
  .etiqueta svg { display: block; width: 60mm; height: auto; }
  @media print {
    body { background: #fff; padding: 0; }
    .barra { display: none; }
    .folha { gap: 4mm; }
    .etiqueta { border: 0; border-radius: 0; padding: 0; break-inside: avoid; }
    @page { margin: 8mm; }
  }
</style>
</head>
<body>
  <div class="barra">
    <strong>Etiquetas de patrimônio</strong>
    <button type="button" onclick="window.print()">Imprimir</button>
  </div>
  <div class="folha">
{{ETIQUETAS}}
  </div>
</body>
</html>
"""
