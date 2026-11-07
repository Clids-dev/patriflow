from typing import Optional

from fastapi import APIRouter, Depends, Query, status

from api.v1.auth import current_user
from modules.emprestimo.schemas import Devolucao, Emprestimo, EmprestimoCreate, Situacao
from modules.emprestimo.service import EmprestimoService

router = APIRouter(prefix="/emprestimos", tags=["Empréstimos"])


@router.get("/", response_model=list[Emprestimo])
def listar(situacao: Situacao = Query("abertos"), bem_id: Optional[int] = Query(None, gt=0)):
    """Empréstimos por situação. Abertos e atrasados vêm pelo prazo, o mais urgente primeiro."""
    return EmprestimoService().listar(situacao, bem_id)


@router.get("/{emprestimo_id}", response_model=Emprestimo)
def buscar(emprestimo_id: int):
    return EmprestimoService().buscar(emprestimo_id)


@router.post("/", response_model=Emprestimo, status_code=status.HTTP_201_CREATED)
def registrar(dados: EmprestimoCreate, usuario=Depends(current_user)):
    return EmprestimoService().registrar(dados, usuario)


@router.post("/{emprestimo_id}/devolver", response_model=Emprestimo)
def devolver(emprestimo_id: int, dados: Optional[Devolucao] = None, usuario=Depends(current_user)):
    return EmprestimoService().devolver(emprestimo_id, dados.observacao if dados else None, usuario,
                                        imprevisto=dados.imprevisto if dados else None)
