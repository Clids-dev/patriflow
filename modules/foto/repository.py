from core.database import DataBase
from modules.foto.schemas import FotoOut

COLUNAS = "id, registro_tipo, registro_id, arquivo, content_type, tamanho_bytes, enviado_por, enviado_em"

QUERY_INSERIR = f"""
    INSERT INTO fotos (registro_tipo, registro_id, arquivo, content_type, tamanho_bytes, enviado_por)
    VALUES (%s, %s, %s, %s, %s, %s)
    RETURNING {COLUNAS}
"""
QUERY_LISTAR = f"""
    SELECT {COLUNAS} FROM fotos
    WHERE registro_tipo = %s AND registro_id = %s
    ORDER BY enviado_em, id
"""
QUERY_BUSCAR = f"SELECT {COLUNAS} FROM fotos WHERE id = %s"


def _para_saida(row) -> dict:
    return {
        "id": row[0], "registro_tipo": row[1], "registro_id": row[2],
        "content_type": row[4], "tamanho_bytes": row[5],
        "enviado_por": row[6], "enviado_em": row[7],
        "url": f"/api/v1/fotos/{row[0]}",
    }


class FotoRepository(DataBase):
    def inserir(self, registro_tipo, registro_id, arquivo, content_type, tamanho, usuario_id) -> dict:
        row = self.commit(QUERY_INSERIR, (registro_tipo, registro_id, arquivo, content_type, tamanho, usuario_id))
        return _para_saida(row)

    def listar(self, registro_tipo, registro_id) -> list[dict]:
        rows = self.execute(QUERY_LISTAR, (registro_tipo, registro_id)) or []
        return [_para_saida(r) for r in rows]

    def buscar(self, foto_id: int) -> dict | None:
        rows = self.execute(QUERY_BUSCAR, (foto_id,)) or []
        if not rows:
            return None
        saida = _para_saida(rows[0])
        saida["arquivo"] = rows[0][3]
        return saida
