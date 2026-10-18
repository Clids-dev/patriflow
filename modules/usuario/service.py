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
