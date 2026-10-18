from core.database import DataBase
from psycopg2.errors import ForeignKeyViolation, UniqueViolation
from . import queries

class UsuarioRepository:
    def buscar_por_username(self, username: str):
        db = DataBase()
        try:
            result = db.execute(queries.QUERY_BUSCAR_POR_USERNAME, (username,), many=False)
            return result
        except Exception as e:
            print(f"ERRO NO BANCO: {e}")
            return None

    def buscar_por_id(self, user_id: int):
        db = DataBase()
        return db.execute(queries.QUERY_BUSCAR_POR_ID, (user_id,), many=False)

    def criar(self, username: str, password_hash: str, nome: str, setor_id: int | None):
        db = DataBase()
        try:
            if setor_id is not None:
                setor = db.execute("SELECT id FROM setores WHERE id = %s AND ativo = TRUE", (setor_id,), many=False)
                if not setor:
                    raise ValueError("O setor informado não existe ou está inativo")
            return db.commit(queries.QUERY_CRIAR_USUARIO, (username, password_hash, nome, setor_id))
        except UniqueViolation as exc:
            raise ValueError("Este nome de utilizador já está em uso") from exc
        except ForeignKeyViolation as exc:
            raise ValueError("O setor informado não existe") from exc
