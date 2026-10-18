from core.database import DataBase
from modules.bem.schemas import BemCreate, BemUpdate, Bem, BemDetalhes
from modules.movimentacao.schemas import Movimentacao
from modules.bem import queries as queries


class BemRepository(DataBase):
    @staticmethod
    def _model(row):
        return Bem(
            id=row[0], nome=row[1], tipo=row[2], codigo_tombamento=row[3],
            valor=row[4], status=row[5], ativo=row[6], id_categoria=row[7],
            marca=row[8], modelo=row[9], numero_serie=row[10], valor_aquisicao=row[11],
            nota_fiscal=row[12], data_entrada=row[13], estado_conservacao=row[14]
        )

    def get_all(self):
        rows = DataBase().execute(queries.QUERY_BENS)
        return [self._model(row) for row in rows or []]

    def get_by_id(self, id: int):
        rows = DataBase().execute(queries.QUERY_BEM_ID, (id,))
        return self._model(rows[0]) if rows else None

    def get_detalhes(self, id: int):
        rows = DataBase().execute(queries.QUERY_BEM_DETALHES, (id,))
        if not rows:
            return None
        row = rows[0]
        return BemDetalhes(
            id=row[0], nome=row[1], tipo=row[2], codigo_tombamento=row[3], valor=row[4],
            status=row[5], ativo=row[6], setor_atual=row[7], data_ultima_movimentacao=row[8],
            justificativa=row[9], id_setor_atual=row[10], id_categoria=row[11], categoria_nome=row[12],
            marca=row[13], modelo=row[14], numero_serie=row[15], valor_aquisicao=row[16],
            nota_fiscal=row[17], data_entrada=row[18], estado_conservacao=row[19],
            predio_nome=row[20], andar_identificacao=row[21], sala_nome=row[22]
        )

    def save(self, bem: BemCreate):
        valor = bem.valor if bem.valor is not None else bem.valor_aquisicao
        valor_aquisicao = bem.valor_aquisicao if bem.valor_aquisicao is not None else valor
        result = DataBase().commit(queries.QUERY_CREATE_BEM, (
            bem.nome, bem.tipo, bem.codigo_tombamento, valor, bem.status, bem.id_categoria,
            bem.marca, bem.modelo, bem.numero_serie, valor_aquisicao, bem.nota_fiscal,
            bem.data_entrada, bem.estado_conservacao
        ))
        return Bem(
            id=result[0], nome=bem.nome, tipo=bem.tipo, codigo_tombamento=bem.codigo_tombamento,
            valor=valor, status=bem.status, ativo=True, id_categoria=bem.id_categoria,
            marca=bem.marca, modelo=bem.modelo, numero_serie=bem.numero_serie,
            valor_aquisicao=valor_aquisicao, nota_fiscal=bem.nota_fiscal,
            data_entrada=bem.data_entrada, estado_conservacao=bem.estado_conservacao
        )

    def count_by_categoria(self, id_categoria: int):
        rows = DataBase().execute(queries.QUERY_COUNT_BY_CATEGORIA, (id_categoria,))
        return rows[0][0] if rows else 0

    def put(self, id: int, bem_atualizado: BemUpdate):
        values = bem_atualizado.model_dump()
        row = DataBase().commit(queries.QUERY_PUT_BEM, (
            values["nome"], values["valor"], values["valor_aquisicao"], values["status"], values["marca"], values["modelo"],
            values["numero_serie"], values["valor_aquisicao"], values["valor"], values["nota_fiscal"],
            values["data_entrada"], values["estado_conservacao"], id
        ))
        return self._model(row) if row else None

    def delete(self, id: int):
        row = DataBase().commit(queries.QUERY_DELETE_BEM, (id,))
        return self._model(row) if row else None

    def get_by_codTombamento(self, codigo_tombamento: str):
        rows = DataBase().execute(queries.QUERY_BEM_CODTOMB, (codigo_tombamento,))
        return self._model(rows[0]) if rows else None

    def get_historico_by_bem(self, id: int):
        rows = DataBase().execute(queries.QUERY_HISTORICO, (id,))
        return [Movimentacao(
            id=row[0], bem_id=row[1], setor_origem_id=row[2], setor_destino_id=row[3],
            data=row[4], ativo=bool(row[5])
        ) for row in rows]

    def get_bens_por_setor(self, setor_id: int):
        rows = DataBase().execute(queries.QUERY_BENS_POR_SETOR, (setor_id,))
        return [self._model(row) for row in rows or []]

    def desativar(self, bem_id: int):
        return DataBase().commit(queries.QUERY_DESATIVAR, (bem_id,))

    def reativar(self, bem_id: int):
        return DataBase().commit(queries.QUERY_REATIVAR, (bem_id,))

    def relatorio_bens_ativos_por_status(self):
        rows = DataBase().execute(queries.QUERY_RELATORIO_ATIVOS)
        return [{"status": row[0], "quantidade": row[1]} for row in rows]

    def quantidade_total_bens(self):
        return DataBase().execute(queries.QUERY_QUANTIDADE_BENS)

    def quantidade_bens_ativos(self):
        return DataBase().execute(queries.QUERY_QUANTIDADE_BENS_ATIVOS)

    def quantidade_bens_inativos(self):
        return DataBase().execute(queries.QUERY_QUANTIDADE_BENS_INATIVOS)

    def get_registros_recentes(self):
        return DataBase().execute(queries.QUERY_RECENTES)
