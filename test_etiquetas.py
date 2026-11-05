"""W04: etiquetas com QR Code, lote de impressão e ficha do bem pelo tombo."""
import re
from unittest.mock import MagicMock

import pytest
from fastapi import HTTPException

from api.v1.auth import ROLE_PERMISSIONS, action_for
from modules.bem import service as bem_service
from modules.bem.schemas import BemDetalhes
from modules.etiqueta import service as etq
from modules.etiqueta.service import etiqueta_svg, pagina_lote

USUARIO = {"id": 1, "perfil": "agente_campo", "setor_id": 1}


def _bem(i, nome="Notebook <Dell>"):
    return BemDetalhes(id=i, nome=nome, tipo="Equipamento", codigo_tombamento=f"TMB-00{i}-1",
                       valor=1.0, status="Disponível", ativo=True)


def test_qr_codifica_o_tombo_com_dv_e_mostra_texto_abaixo():
    svg = etiqueta_svg("TMB-001-4", "Notebook")
    assert svg.startswith("<svg")
    assert ">TMB-001-4</text>" in svg  # tombo legível abaixo do QR
    assert "<path d=" in svg           # QR desenhado como vetor


def test_qr_tem_o_mesmo_numero_de_modulos_escuros_da_matriz():
    import segno
    qr = segno.make("TMB-001-4", error="q")
    escuros = sum(sum(1 for v in linha if v) for linha in qr.matrix_iter(scale=1, border=0))
    svg = etiqueta_svg("TMB-001-4", "Notebook")
    quadrados = len(re.findall(r"h1v1h-1z", svg))
    assert quadrados == escuros


def test_nome_do_bem_e_escapado_no_svg():
    svg = etiqueta_svg("TMB-001-4", "<script>x</script>")
    assert "<script>" not in svg and "&lt;script&gt;" in svg


def test_lote_gera_uma_etiqueta_por_bem_sem_repetir(monkeypatch):
    repo = MagicMock()
    repo.get_detalhes.side_effect = lambda i: _bem(i)
    monkeypatch.setattr(etq, "BemRepository", lambda: repo)
    html = pagina_lote([1, 2, 2, 3])
    assert html.count('class="etiqueta"') == 3
    assert "window.print()" in html and "@media print" in html


def test_lote_rejeita_vazio_e_excesso(monkeypatch):
    with pytest.raises(HTTPException) as exc:
        pagina_lote([])
    assert exc.value.status_code == 400
    with pytest.raises(HTTPException) as exc2:
        pagina_lote(list(range(1, etq.LIMITE_LOTE + 2)))
    assert exc2.value.status_code == 400


def test_lote_informa_bem_inexistente(monkeypatch):
    repo = MagicMock()
    repo.get_detalhes.return_value = None
    monkeypatch.setattr(etq, "BemRepository", lambda: repo)
    with pytest.raises(HTTPException) as exc:
        pagina_lote([99])
    assert exc.value.status_code == 404


def test_etiqueta_nao_guarda_nada_no_banco(monkeypatch):
    """Etiqueta é gerada sob demanda: não há repositório de escrita envolvido."""
    import modules.etiqueta.service as modulo
    assert not any(n.startswith(("inserir", "salvar", "gravar")) for n in dir(modulo))


def test_ficha_pelo_tombo_devolve_setor_localizacao_e_responsavel(monkeypatch):
    repo = MagicMock()
    repo.get_detalhes_por_tombo.return_value = BemDetalhes(
        id=1, nome="Notebook", tipo="Equipamento", codigo_tombamento="TMB-001-4", valor=1.0,
        status="Disponível", ativo=True, setor_atual="Financeiro", predio_nome="Sede",
        andar_identificacao="1º andar", sala_nome="Sala 12", responsavel_nome="Ana", responsavel_cargo="Gerente")
    monkeypatch.setattr(bem_service, "BemRepository", lambda: repo)
    ficha = bem_service.BemService().get_by_codTomb("TMB-001-4")
    assert ficha.setor_atual == "Financeiro"
    assert ficha.sala_nome == "Sala 12" and ficha.responsavel_nome == "Ana"


def test_ficha_pelo_tombo_valida_dv_antes_do_banco(monkeypatch):
    repo = MagicMock()
    monkeypatch.setattr(bem_service, "BemRepository", lambda: repo)
    with pytest.raises(HTTPException) as exc:
        bem_service.BemService().get_by_codTomb("TMB-001-9")
    assert exc.value.status_code == 400
    repo.get_detalhes_por_tombo.assert_not_called()


def test_permissoes_de_etiquetas():
    assert action_for("GET", "etiquetas/lote") == "etiquetas:read"
    assert "etiquetas:read" in ROLE_PERMISSIONS["agente_campo"]
    assert "etiquetas:*" in ROLE_PERMISSIONS["setor_patrimonio"]
    assert "etiquetas:create" not in ROLE_PERMISSIONS["auditor"]
