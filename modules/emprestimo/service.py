"""Empréstimo de bens: saída com tomador, motivo e devolução prevista; devolução registra a data efetiva.

O bem continua sob a guarda do setor de origem: a localização não muda, e enquanto o empréstimo
estiver aberto o bem não pode ser transferido, emprestado de novo nem enviado para manutenção.
O bem não sai da instituição (D9): quem leva tem matrícula e o empréstimo diz o setor de destino;
o prazo máximo de devolução é PATRIFLOW_EMPRESTIMO_PRAZO_MAX_DIAS (30 dias).
"""
from datetime import date, datetime, timedelta

from fastapi import HTTPException

from core import config
from core.database import DataBase
from core.tempo import momento_da_operacao
from modules.bem import guarda
from modules.emprestimo.repository import EmprestimoRepository
from modules.emprestimo.schemas import EmprestimoCreate


class EmprestimoService:
    def __init__(self, repository: EmprestimoRepository | None = None):
        self.repo = repository or EmprestimoRepository()

    def registrar(self, dados: EmprestimoCreate, usuario: dict, ocorrido_em: datetime | None = None):
        """`ocorrido_em`: quando aconteceu no aparelho (operação feita sem rede); None = agora."""
        quando = momento_da_operacao(ocorrido_em)
        saida = quando.date() if quando else date.today()
        if dados.devolucao_prevista < saida:
            raise HTTPException(status_code=400, detail="A devolução prevista não pode ser uma data passada.")
        if dados.devolucao_prevista > saida + timedelta(days=config.EMPRESTIMO_PRAZO_MAX_DIAS):
            raise HTTPException(status_code=400,
                                detail=f"O prazo máximo de empréstimo é de {config.EMPRESTIMO_PRAZO_MAX_DIAS} dias.")
        with DataBase().transacao() as cur:
            cur.execute("SELECT 1 FROM setores WHERE id = %s AND ativo = TRUE", (dados.setor_destino_id,))
            if cur.fetchone() is None:
                raise HTTPException(status_code=400, detail="O setor de destino não existe ou está inativo.")
            bem = guarda.travar_bem(cur, dados.bem_id)
            imprevisto = guarda.exigir_guarda(cur, usuario, bem["id"], dados.imprevisto)
            guarda.exigir_livre(cur, bem)
            emprestimo_id = self.repo.inserir(cur, dados, usuario["id"], quando)
            if imprevisto:
                guarda.registrar_imprevisto(cur, usuario, bem, "Empréstimo", dados.imprevisto)
        return self.repo.buscar(emprestimo_id)

    def devolver(self, emprestimo_id: int, observacao: str | None, usuario: dict, ocorrido_em: datetime | None = None,
                 imprevisto: str | None = None):
        quando = momento_da_operacao(ocorrido_em)
        with DataBase().transacao() as cur:
            atual = self.repo.travar_aberto(cur, emprestimo_id)
            if atual is None:
                raise HTTPException(status_code=404, detail=f"Empréstimo com id {emprestimo_id} não encontrado")
            bem_id, devolvido_em, saida_em = atual
            if devolvido_em is not None:
                raise HTTPException(status_code=409, detail="Este empréstimo já foi devolvido.")
            if quando is not None and quando < saida_em:
                raise HTTPException(status_code=409, detail="A devolução não pode ser anterior à saída do empréstimo.")
            bem = guarda.travar_bem(cur, bem_id)
            if guarda.exigir_guarda(cur, usuario, bem_id, imprevisto):
                guarda.registrar_imprevisto(cur, usuario, bem, "Devolução de empréstimo", imprevisto)
            self.repo.encerrar(cur, emprestimo_id, usuario["id"], observacao or None, quando)
        return self.repo.buscar(emprestimo_id)

    def listar(self, situacao: str, bem_id: int | None):
        return self.repo.listar(situacao, bem_id)

    def buscar(self, emprestimo_id: int):
        emprestimo = self.repo.buscar(emprestimo_id)
        if emprestimo is None:
            raise HTTPException(status_code=404, detail=f"Empréstimo com id {emprestimo_id} não encontrado")
        return emprestimo
