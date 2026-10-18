from fastapi import HTTPException

from modules.responsavel.repository import ResponsavelRepository
from modules.setor.repository import SetorRepository
from modules.setor.schemas import SetorCreate


class SetorService:
    def get_setores(self):
        repository = SetorRepository()
        return repository.get_all()

    def get_setor_by_id(self, id: int):
        try:
            repository = SetorRepository()
            if repository.get_id(id) is None:
                raise ValueError
            return repository.get_id(id)
        except ValueError:
            raise HTTPException(status_code=404, detail="Setor não encontrado")

    def add_setor(self, setor: SetorCreate, responsavel_id: int):
        try:
            responsavel_repository = ResponsavelRepository()
            if responsavel_repository.get_id(responsavel_id) is None:
                raise ValueError("Responsável não encontrado")
            setor_repository = SetorRepository()
            for setores in setor_repository.get_all():
                if setores.nome == setor.nome:
                    raise FileNotFoundError
            if setor.nome == "":
                raise ValueError
            if responsavel_id is None:
                raise ValueError
            return setor_repository.save(setor)
        except FileNotFoundError:
            raise HTTPException(status_code=409, detail="Setor já existente")
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))

    def put_setor(self, id: int, novo_nome: str, novo_responsavel_id: int, novo_sala_id: int | None = None):
        try:
            setor_atual = self.get_setor_by_id(id)
            if setor_atual is None:
                raise HTTPException(status_code=404, detail=f"Setor com id {id} não encontrado")
            
            if not novo_nome and novo_responsavel_id is None and novo_sala_id is None:
                    raise ValueError("Nenhum dado fornecido para atualização.")
            
            if not novo_nome:
                novo_nome = setor_atual.nome
            if novo_responsavel_id is None:
                novo_responsavel_id = setor_atual.responsavel_id
            if novo_sala_id is None:
                novo_sala_id = setor_atual.sala_id
            
            if novo_nome == setor_atual.nome and novo_responsavel_id == setor_atual.responsavel_id and novo_sala_id == setor_atual.sala_id:
                raise ValueError("Os dados fornecidos são iguais aos atuais.")

            repository = SetorRepository()
            return repository.put(int(id), novo_nome, int(novo_responsavel_id), int(novo_sala_id))
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))

    def delete_setor(self, id: int):
        repository = SetorRepository()
        setor = repository.get_id(id)
        if not setor:
            raise HTTPException(status_code=404, detail=f"Setor com id {id} não encontrado")
        return repository.delete(id)
