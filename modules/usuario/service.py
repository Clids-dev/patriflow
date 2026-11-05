from core.security import hash_password, verify_password
import re

class UsuarioService:
    def __init__(self, repo):
        self.repo = repo

    def login(self, username, senha):
        user = self.repo.buscar_por_username(username)

        if not user:
            return None

        if not verify_password(senha, user[2]):
            return None

        if not user[4]:  # ativo
            return None

        return user

    def criar_conta(self, username: str, senha: str, nome: str, setor_id: int | None = None):
        username = username.strip().lower()
        nome = nome.strip()
        if not re.fullmatch(r"[A-Za-z0-9_.-]{3,50}", username):
            raise ValueError("O utilizador deve ter 3 a 50 caracteres: letras, números, ponto, hífen ou sublinhado")
        if not nome or len(nome) > 120:
            raise ValueError("O nome é obrigatório e deve ter até 120 caracteres")
        if len(senha) < 8:
            raise ValueError("A senha deve ter pelo menos 8 caracteres")
        password_hash = hash_password(senha)
        return self.repo.criar(username, password_hash, nome, setor_id)

    def conta_pendente(self, username, senha) -> bool:
        """True se a senha confere, mas a conta ainda não foi aprovada."""
        user = self.repo.buscar_por_username(username)
        return bool(user) and verify_password(senha, user[2]) and not user[4]

    def listar(self):
        return self.repo.listar()

    def atualizar(self, user_id: int, admin: dict, perfil: str, setor_id, ativo: bool):
        from modules.setor.repository import SetorRepository
        from fastapi import HTTPException

        perfis = {"setor_patrimonio", "agente_campo", "responsavel_setor", "auditor"}
        if perfil not in perfis:
            raise HTTPException(status_code=400, detail="Perfil inválido.")
        if setor_id is not None and SetorRepository().get_id(setor_id) is None:
            raise HTTPException(status_code=400, detail="Setor não encontrado ou inativo.")
        if perfil == "responsavel_setor" and setor_id is None:
            raise HTTPException(status_code=400, detail="Responsável de setor precisa de um setor vinculado.")
        if user_id == admin["id"] and (not ativo or perfil != "setor_patrimonio"):
            raise HTTPException(status_code=400, detail="Você não pode desativar nem rebaixar a própria conta.")
        row = self.repo.atualizar(user_id, perfil, setor_id, ativo)
        if row is None:
            raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        return {"id": row[0], "username": row[1], "nome": row[2], "perfil": row[3],
                "ativo": bool(row[4]), "setor_id": row[5]}

