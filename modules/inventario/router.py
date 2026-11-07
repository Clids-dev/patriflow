from typing import Optional

from fastapi import APIRouter, Depends, Query, status

from api.v1.auth import current_user
from modules.inventario.schemas import (Conferencia, FiltroInventarios, FiltroItens, Inventario, InventarioCreate,
                                        Item, NaoCadastrado, ResumoFechamento)
from modules.inventario.service import InventarioService

router = APIRouter(prefix="/inventarios", tags=["Inventário"])


@router.get("/", response_model=list[Inventario])
def listar(situacao: FiltroInventarios = Query("abertos")):
    return InventarioService().listar(situacao)


@router.post("/", response_model=Inventario, status_code=status.HTTP_201_CREATED)
def abrir(dados: InventarioCreate, usuario=Depends(current_user)):
    """Abre o inventário e congela a lista de bens esperados de cada setor."""
    return InventarioService().abrir(dados, usuario)


@router.get("/{inventario_id}", response_model=Inventario)
def detalhar(inventario_id: int):
    """Cabeçalho e andamento por setor (esperados, conferidos e situação de cada um)."""
    return InventarioService().detalhar(inventario_id)


@router.get("/{inventario_id}/itens", response_model=list[Item])
def itens(inventario_id: int, setor_id: Optional[int] = Query(None, gt=0), filtro: FiltroItens = Query("todos")):
    """Lista congelada com a situação de cada item. `filtro=divergencias` é o relatório de divergências."""
    return InventarioService().itens(inventario_id, setor_id, filtro)


@router.post("/{inventario_id}/conferencias", response_model=Item)
def conferir(inventario_id: int, dados: Conferencia, usuario=Depends(current_user)):
    """Registra a leitura de um bem em um setor. Ler de novo o mesmo bem só atualiza a conferência."""
    return InventarioService().conferir(inventario_id, dados, usuario)


@router.post("/{inventario_id}/nao-cadastrados", response_model=Item, status_code=status.HTTP_201_CREATED)
def registrar_nao_cadastrado(inventario_id: int, dados: NaoCadastrado, usuario=Depends(current_user)):
    return InventarioService().registrar_nao_cadastrado(inventario_id, dados, usuario)


@router.post("/{inventario_id}/itens/{item_id}/nao-localizado", response_model=Item)
def marcar_nao_localizado(inventario_id: int, item_id: int, usuario=Depends(current_user)):
    return InventarioService().marcar_nao_localizado(inventario_id, item_id, usuario)


@router.post("/{inventario_id}/setores/{setor_id}/faltantes")
def marcar_faltantes(inventario_id: int, setor_id: int, usuario=Depends(current_user)):
    """Encerra a contagem do setor: os bens ainda não lidos viram "não localizado"."""
    return InventarioService().marcar_faltantes(inventario_id, setor_id, usuario)


@router.post("/{inventario_id}/fechar", response_model=ResumoFechamento)
def fechar(inventario_id: int, usuario=Depends(current_user)):
    """Fecha o inventário: abre transferências dos bens achados em outro setor e cria as pendências."""
    return InventarioService().fechar(inventario_id, usuario)
