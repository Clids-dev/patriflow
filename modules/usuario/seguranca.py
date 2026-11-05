"""REQ-EX-02: bloqueio temporário após tentativas erradas e registro de acessos."""
from core.database import DataBase

LIMITE_TENTATIVAS = 5
BLOQUEIO_MINUTOS = 15


class ContaBloqueada(Exception):
    def __init__(self, minutos_restantes: int):
        super().__init__(f"Conta bloqueada por excesso de tentativas. Tente de novo em {minutos_restantes} minuto(s).")
        self.minutos_restantes = minutos_restantes


def estado(user_id: int):
    """(tentativas_falhas, minutos_restantes_de_bloqueio) — minutos é 0 se não estiver bloqueada."""
    rows = DataBase().execute(
        """SELECT tentativas_falhas,
                  GREATEST(0, CEIL(EXTRACT(EPOCH FROM (bloqueado_ate - NOW())) / 60))::int
           FROM usuarios WHERE id = %s""", (user_id,), many=False)
    return rows if rows else (0, 0)


def registrar_falha(user_id: int, username: str) -> bool:
    """Soma uma falha. Devolve True se a conta acabou de ser bloqueada."""
    db = DataBase()
    tentativas = db.commit(
        "UPDATE usuarios SET tentativas_falhas = tentativas_falhas + 1 WHERE id = %s RETURNING tentativas_falhas",
        (user_id,))[0]
    bloqueou = tentativas >= LIMITE_TENTATIVAS
    if bloqueou:
        db.commit(
            """UPDATE usuarios SET bloqueado_ate = NOW() + make_interval(mins => %s), tentativas_falhas = 0
               WHERE id = %s""", (BLOQUEIO_MINUTOS, user_id))
    registrar_acesso(username, False, "senha_incorreta" if not bloqueou else "bloqueio_ativado")
    return bloqueou


def registrar_sucesso(user_id: int, username: str) -> None:
    DataBase().commit("UPDATE usuarios SET tentativas_falhas = 0, bloqueado_ate = NULL WHERE id = %s", (user_id,))
    registrar_acesso(username, True, None)


def registrar_acesso(username: str, sucesso: bool, motivo: str | None) -> None:
    DataBase().commit("INSERT INTO acessos (usuario, sucesso, motivo) VALUES (%s, %s, %s)",
                      (username[:50], sucesso, motivo))
