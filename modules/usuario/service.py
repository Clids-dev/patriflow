from core.security import hash_password, verify_password
import re

class UsuarioService:
    def __init__(self, repo):
        self.repo = repo

    def login(self, username, senha):
        from modules.usuario import seguranca
        user = self.repo.buscar_por_username(username)

        if not user:
            seguranca.registrar_acesso(username, False, "usuario_inexistente")
            return None

        _, bloqueio = seguranca.estado(user[0])
        if bloqueio > 0:
            seguranca.registrar_acesso(username, False, "bloqueada")
            raise seguranca.ContaBloqueada(bloqueio)

        if not verify_password(senha, user[2]):
            seguranca.registrar_falha(user[0], username)
            return None

        if not user[4]:  # ativo
            return None

        seguranca.registrar_sucesso(user[0], username)
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

    def situacao_da_conta(self, username, senha) -> str | None:
        """Situação do cadastro (D3) quando a senha confere e a conta não está ativa; senão, None."""
        user = self.repo.buscar_por_username(username)
        if not user or user[4] or not verify_password(senha, user[2]):
            return None
        return self.repo.situacao(user[0])

    def listar(self, situacao: str | None = None):
        return self.repo.listar(situacao)

    def atualizar(self, user_id: int, admin: dict, perfil: str, setor_id, ativo: bool | None = None,
                  situacao: str | None = None):
        from modules.setor.repository import SetorRepository
        from fastapi import HTTPException

        perfis = {"setor_patrimonio", "agente_campo", "responsavel_setor", "auditor"}
        if perfil not in perfis:
            raise HTTPException(status_code=400, detail="Perfil inválido.")
        if setor_id is not None and SetorRepository().get_id(setor_id) is None:
            raise HTTPException(status_code=400, detail="Setor não encontrado ou inativo.")
        if perfil == "responsavel_setor" and setor_id is None:
            raise HTTPException(status_code=400, detail="Responsável de setor precisa de um setor vinculado.")
        if admin["perfil"] != "setor_patrimonio":
            raise HTTPException(status_code=403, detail="Somente o setor de patrimônio altera usuários.")
        atual = self.repo.situacao(user_id)
        if atual is None:
            raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        if situacao is None:
            # Cliente antigo, só com "ativo": desligar um cadastro que aguarda não o tira da fila.
            situacao = "ativo" if ativo else ("desativado" if atual == "ativo" else atual)
        if situacao == "recusado" and atual != "aguardando":
            raise HTTPException(status_code=409, detail="Só um cadastro aguardando aprovação pode ser recusado.")
        if user_id == admin["id"] and (situacao != "ativo" or perfil != "setor_patrimonio"):
            raise HTTPException(status_code=400, detail="Você não pode desativar nem rebaixar a própria conta.")
        row = self.repo.atualizar(user_id, perfil, setor_id, situacao, admin["id"])
        return {"id": row[0], "username": row[1], "nome": row[2], "perfil": row[3],
                "ativo": bool(row[4]), "setor_id": row[5], "situacao": row[6]}

