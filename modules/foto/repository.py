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


# Cada tipo de foto pertence a um registro que precisa existir (e estar na situação certa).
_REGISTRO_EXISTE = {
    "aceite_transferencia": "SELECT 1 FROM movimentacoes WHERE id = %s",
    "conferencia": """SELECT 1 FROM inventario_itens
                      WHERE id = %s AND bem_id IS NOT NULL AND situacao IN ('localizado', 'outro_setor')""",
    "bem_nao_cadastrado": "SELECT 1 FROM inventario_itens WHERE id = %s AND situacao = 'nao_cadastrado'",
}


class FotoRepository(DataBase):
    def registro_existe(self, registro_tipo: str, registro_id: int) -> bool:
        return self.execute(_REGISTRO_EXISTE[registro_tipo], (registro_id,), many=False) is not None

    def contar(self, registro_tipo, registro_id) -> int:
        rows = self.execute('SELECT count(*) FROM fotos WHERE registro_tipo = %s AND registro_id = %s', (registro_tipo, registro_id)) or [(0,)]
        return rows[0][0]

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
