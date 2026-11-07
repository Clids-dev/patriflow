import json

from core.database import DataBase

# Registra a operação como "processando". Se o par (dispositivo, operação) já existe, só a retoma se a
# tentativa anterior terminou em erro e é do mesmo usuário; caso contrário não devolve linha (repetida).
_REIVINDICAR = """
    INSERT INTO sync_operacoes (dispositivo_id, operacao_id, usuario_id, sincronizacao_id, tipo, criada_em, dados)
    VALUES (%(disp)s, %(op)s, %(usuario)s, %(sync)s, %(tipo)s, %(criada)s, %(dados)s::jsonb)
    ON CONFLICT (dispositivo_id, operacao_id) DO UPDATE
        SET sincronizacao_id = EXCLUDED.sincronizacao_id, status = 'processando', mensagem = NULL,
            resultado = NULL, recebida_em = NOW(), processada_em = NULL
        WHERE sync_operacoes.status = 'erro' AND sync_operacoes.usuario_id = EXCLUDED.usuario_id
    RETURNING id
"""


class SincronizacaoRepository:
    def iniciar(self, dispositivo_id: str, usuario_id: int, total: int) -> tuple[int, object]:
        row = DataBase().commit(
            "INSERT INTO sincronizacoes (dispositivo_id, usuario_id, total) VALUES (%s, %s, %s) RETURNING id, recebida_em",
            (dispositivo_id, usuario_id, total))
        return row[0], row[1]

    def reivindicar(self, sync_id: int, dispositivo_id: str, operacao, usuario_id: int) -> int | None:
        row = DataBase().commit(_REIVINDICAR, {
            "disp": dispositivo_id, "op": operacao.id, "usuario": usuario_id, "sync": sync_id, "tipo": operacao.tipo,
            "criada": operacao.criada_em, "dados": json.dumps(operacao.dados, default=str)})
        return row[0] if row else None

    def existente(self, dispositivo_id: str, operacao_id: str):
        """(usuario_id, status, mensagem, resultado) da operação já recebida."""
        return DataBase().execute(
            "SELECT usuario_id, status, mensagem, resultado FROM sync_operacoes WHERE dispositivo_id = %s AND operacao_id = %s",
            (dispositivo_id, operacao_id), many=False)

    def concluir(self, registro_id: int, status: str, mensagem: str | None, resultado: dict | None,
                 pendencia: str | None, usuario_id: int) -> None:
        """Grava o desfecho e, se for conflito, a pendência para o patrimônio, na mesma transação."""
        with DataBase().transacao() as cur:
            cur.execute(
                """UPDATE sync_operacoes SET status = %s, mensagem = %s, resultado = %s::jsonb, processada_em = NOW()
                   WHERE id = %s""",
                (status, mensagem, json.dumps(resultado, default=str) if resultado is not None else None, registro_id))
            if pendencia:
                cur.execute(
                    """INSERT INTO pendencias (tipo, sync_operacao_id, descricao, criada_por)
                       VALUES ('conflito_sincronizacao', %s, %s, %s)""",
                    (registro_id, pendencia, usuario_id))

    def finalizar(self, sync_id: int, contagem: dict) -> None:
        DataBase().commit(
            """UPDATE sincronizacoes SET concluida_em = NOW(), aceitas = %s, recusadas = %s, conflitos = %s,
                      repetidas = %s, erros = %s
               WHERE id = %s""",
            (contagem["aceita"], contagem["recusada"], contagem["conflito"], contagem["repetida"], contagem["erro"], sync_id))

    def ultima(self, dispositivo_id: str, usuario_id: int):
        return DataBase().execute(
            """SELECT id, recebida_em, concluida_em, total, aceitas, recusadas, conflitos, repetidas, erros
               FROM sincronizacoes WHERE dispositivo_id = %s AND usuario_id = %s
               ORDER BY recebida_em DESC, id DESC LIMIT 1""",
            (dispositivo_id, usuario_id), many=False)
