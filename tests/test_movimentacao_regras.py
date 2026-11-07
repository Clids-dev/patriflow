import pytest
from unittest.mock import MagicMock, patch
from fastapi import HTTPException
from modules.movimentacao.service import MovimentacaoService
from modules.movimentacao.schemas import MovimentacaoCreate
from modules.bem.schemas import Bem


@pytest.fixture(autouse=True)
def sem_emprestimo_aberto(monkeypatch):
    """Teste unitário: nenhum bem emprestado, sem consultar o banco."""
    repo = MagicMock()
    repo.existe_aberto.return_value = False
    monkeypatch.setattr("modules.movimentacao.service.EmprestimoRepository", lambda: repo)
    monkeypatch.setattr("modules.movimentacao.service.setores_em_inventario", lambda ids: [])
    return repo


ADMIN = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}

@pytest.fixture
def service():
    return MovimentacaoService()

@pytest.fixture
def mock_bem():
    return Bem(
        id=1,
        nome="Equipamento Teste",
        tipo="Eletrônico",
        codigo_tombamento="TEST-001",
        valor=1000.0,
        status="Disponível",
        ativo=True,
        id_categoria=1
    )

@patch('modules.movimentacao.service.BemRepository')
def test_movimentacao_setor_igual(mock_bem_repo, service, mock_bem):
    """Garante que não permite movimentar para o mesmo setor."""
    mock_bem_repo.return_value.get_by_id.return_value = mock_bem
    mov = MovimentacaoCreate(bem_id=1, setor_origem_id=10, setor_destino_id=10)
    
    with pytest.raises(HTTPException) as exc:
        service.add_movimentacao(mov, ADMIN)
    
    assert exc.value.status_code == 400
    assert "iguais" in exc.value.detail.lower()

@patch('modules.movimentacao.service.BemRepository')
def test_movimentacao_bem_inativo(mock_repo_class, service, mock_bem):
    """Garante que não permite movimentar bens inativos (baixados)."""
    mock_bem.ativo = False
    mock_repo_instance = mock_repo_class.return_value
    mock_repo_instance.get_by_id.return_value = mock_bem
    
    mov = MovimentacaoCreate(bem_id=1, setor_destino_id=20)
    
    with pytest.raises(HTTPException) as exc:
        service.add_movimentacao(mov, ADMIN)
    
    assert exc.value.status_code == 400
    assert "baixado/inativo" in exc.value.detail.lower()

@patch('modules.movimentacao.service.BemRepository')
def test_movimentacao_manutencao_sem_concluido(mock_repo_class, service, mock_bem):
    """Garante bloqueio de item em manutenção sem justificativa de conclusão."""
    mock_bem.status = "Manutenção"
    mock_repo_instance = mock_repo_class.return_value
    mock_repo_instance.get_by_id.return_value = mock_bem
    
    mov = MovimentacaoCreate(bem_id=1, setor_destino_id=20, justificativa="Transferindo apenas")
    
    with pytest.raises(HTTPException) as exc:
        service.add_movimentacao(mov, ADMIN)
    
    assert exc.value.status_code == 400
    assert "conclusão do reparo" in exc.value.detail.lower()

@patch('modules.movimentacao.service.MovimentacaoRepository')
@patch('modules.movimentacao.service.SetorRepository')
@patch('modules.movimentacao.service.BemRepository')
def test_movimentacao_manutencao_com_concluido(mock_bem_repo, mock_setor_repo, mock_mov_repo, service, mock_bem):
    """Garante que permite movimentar item em manutenção se houver conclusão."""
    mock_bem.status = "Manutenção"
    mock_bem_repo.return_value.get_by_id.return_value = mock_bem
    mock_setor_repo.return_value.get_id.return_value = MagicMock() # Setor existe
    
    mov = MovimentacaoCreate(bem_id=1, setor_destino_id=20, justificativa="Reparo concluído com sucesso")
    
    # Não deve subir exceção
    service.add_movimentacao(mov, ADMIN)
    assert mock_mov_repo.return_value.save.called


def test_movimentacao_nao_pode_ser_apagada():
    """Histórico de movimentações é só de acréscimo: nenhuma rota DELETE existe."""
    from api.v1.router import api_router
    metodos = {m for rota in api_router.routes if "movimentacao" in getattr(rota, "path", "") for m in getattr(rota, "methods", set())}
    assert "DELETE" not in metodos
