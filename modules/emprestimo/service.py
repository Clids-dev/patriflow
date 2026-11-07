"""Empréstimo de bens: saída com tomador, motivo e devolução prevista; devolução registra a data efetiva.

O bem continua sob a guarda do setor de origem: a localização não muda, e enquanto o empréstimo
estiver aberto o bem não pode ser transferido, emprestado de novo nem enviado para manutenção.
"""
from datetime import date

from fastapi import HTTPException

from core.database import DataBase
from modules.bem import guarda
from modules.emprestimo.repository import EmprestimoRepository
from modules.emprestimo.schemas import EmprestimoCreate


class EmprestimoService:
    def __init__(self, repository: EmprestimoRepository | None = None):
        self.repo = repository or EmprestimoRepository()

    def registrar(self, dados: EmprestimoCreate, usuario: dict):
        if dados.devolucao_prevista < date.today():
            raise HTTPException(status_code=400, detail="A devolução prevista não pode ser uma data passada.")
        with DataBase().transacao() as cur:
            bem = guarda.travar_bem(cur, dados.bem_id)
            guarda.exigir_guarda(cur, usuario, bem["id"])
            guarda.exigir_livre(cur, bem)
            emprestimo_id = self.repo.inserir(cur, dados, usuario["id"])
        return self.repo.buscar(emprestimo_id)

    def devolver(self, emprestimo_id: int, observacao: str | None, usuario: dict):
        with DataBase().transacao() as cur:
            atual = self.repo.travar_aberto(cur, emprestimo_id)
            if atual is None:
                raise HTTPException(status_code=404, detail=f"Empréstimo com id {emprestimo_id} não encontrado")
            bem_id, devolvido_em = atual
            if devolvido_em is not None:
                raise HTTPException(status_code=409, detail="Este empréstimo já foi devolvido.")
            guarda.exigir_guarda(cur, usuario, bem_id)
            self.repo.encerrar(cur, emprestimo_id, usuario["id"], observacao or None)
        return self.repo.buscar(emprestimo_id)

    def listar(self, situacao: str, bem_id: int | None):
        return self.repo.listar(situacao, bem_id)

    def buscar(self, emprestimo_id: int):
        emprestimo = self.repo.buscar(emprestimo_id)
        if emprestimo is None:
            raise HTTPException(status_code=404, detail=f"Empréstimo com id {emprestimo_id} não encontrado")
        return emprestimo
