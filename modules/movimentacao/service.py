from datetime import datetime
from fastapi import HTTPException
from psycopg2 import errors

from fastapi import HTTPException
from modules.setor.repository import SetorRepository
from modules.bem.repository import BemRepository
from modules.movimentacao.repository import MovimentacaoRepository
from modules.movimentacao.schemas import MovimentacaoCreate
from core.tombamento import require_valid_tombo


class MovimentacaoService:
    def get_movimentacoes(self):
        repository = MovimentacaoRepository()
        return repository.get_all()

    def get_detailed_movimentacoes(self):
        repository = MovimentacaoRepository()
        return repository.get_detailed()

    def get_movimentacoes_por_bem(self, codigo: str):
        require_valid_tombo(codigo)
        repository = MovimentacaoRepository()
        return repository.get_by_bem_codigo(codigo)

    def get_movimentacao_by_id(self, id: int):
        repository = MovimentacaoRepository()
        return repository.get_id(id)

    def add_movimentacao(self, movimentacao: MovimentacaoCreate):
        try:
            if movimentacao.bem_id <= 0 or movimentacao.setor_destino_id <= 0:
                raise HTTPException(status_code=400, detail="IDs devem ser números positivos.")
            
            if movimentacao.setor_origem_id is not None and movimentacao.setor_origem_id == movimentacao.setor_destino_id:
                raise HTTPException(status_code=400, detail="Setor de origem e destino não podem ser iguais.")
            
            # --- Validação de Regras de Negócio ---
            bem_repository = BemRepository()
            bem = bem_repository.get_by_id(movimentacao.bem_id)
            
            if bem is None:
                raise HTTPException(status_code=404, detail=f"Bem com id {movimentacao.bem_id} não encontrado")

            # 1. Não permite movimentar bem inativo (Baixado)
            if not bem.ativo:
                raise HTTPException(
                    status_code=400, 
                    detail="Este bem está baixado/inativo e não pode ser movimentado."
                )

            # 2. Não permite movimentar bem que esteja em manutenção para uso comum
            # (Aqui poderíamos validar o tipo do setor de destino, mas vamos simplificar com o status)
            if bem.status.lower() == 'manutenção' or bem.status.lower() == 'manutencao':
                # Regra: Se está em manutenção, só pode ser movimentado se a justificativa contiver 'concluído'
                # Ou simplesmente impedir se o status não for alterado primeiro.
                # Vamos seguir a regra: "Bem em manutenção não pode ser movimentado sem finalizar o reparo"
                if not movimentacao.justificativa or "concluído" not in movimentacao.justificativa.lower():
                    raise HTTPException(
                        status_code=400, 
                        detail="Equipamentos em manutenção não podem ser movimentados sem a conclusão do reparo (informe na justificativa)."
                    )

            # 3. Validação de Setores
            setor_repository = SetorRepository()
            if movimentacao.setor_origem_id is not None:
                if setor_repository.get_id(movimentacao.setor_origem_id) is None:
                    raise HTTPException(status_code=404, detail=f"Setor de origem com id {movimentacao.setor_origem_id} não encontrado")
            
            if setor_repository.get_id(movimentacao.setor_destino_id) is None:
                raise HTTPException(status_code=404, detail=f"Setor de destino com id {movimentacao.setor_destino_id} não encontrado")
            
            repository = MovimentacaoRepository()
            return repository.save(movimentacao)
        except HTTPException as e:
            raise e

    def put_movimentacao(self, id: int, data: datetime, setor_destino_id: int, justificativa=None):
        try:
            repository = MovimentacaoRepository()
            return repository.put(id, data, setor_destino_id, justificativa)
        except errors.NoDataFound:
            raise HTTPException(status_code=404, detail=f"Movimentação com id {id} não encontrada")

    def delete_movimentacao(self, id: int):
        try:
            repository = MovimentacaoRepository()
            return repository.delete(id)
        except errors.NoDataFound:
            raise HTTPException(status_code=404, detail=f"Movimentação com id {id} não encontrada")
