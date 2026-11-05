from fastapi import HTTPException
from modules.bem.repository import BemRepository
from modules.bem.schemas import BemCreate, BemUpdate
from modules.auditoria.service import registrar_acao, registrar_alteracao
from modules.categoria.repository import CategoriaRepository
from modules.setor.repository import SetorRepository
from modules.bem.queries_stats import QUERY_STATS_CATEGORIA, QUERY_STATS_STATUS
from core.database import DataBase
from psycopg2 import errors
from core.tombamento import format_tombo, require_valid_tombo
import re

def _com_depreciacao(bem):
    from datetime import date
    from modules.bem import depreciacao
    dados = depreciacao.calcular(bem.valor_aquisicao, bem.valor_residual, bem.vida_util_meses,
                                 bem.data_entrada, date.today())
    for chave, valor in dados.items():
        setattr(bem, chave, valor)
    return bem


class BemService:
    def get_bens(self):
        repository = BemRepository()
        return repository.get_all()

    def get_stats_categoria(self):
        db = DataBase()
        return db.execute(QUERY_STATS_CATEGORIA)

    def get_stats_status(self):
        db = DataBase()
        return db.execute(QUERY_STATS_STATUS)

    def get_bem_by_id(self, id: int):
        try:
            repository = BemRepository()
            if id == "":
                raise ValueError("ID do bem não pode ser vazio.")
            bem = repository.get_by_id(id)
            if bem is None:
                raise ValueError("Nenhum bem encontrado.")
            return bem
        except ValueError as e:
            raise HTTPException(status_code=404, detail=str(e))

    def get_bem_detalhes(self, id: int):
        repository = BemRepository()
        bem = repository.get_detalhes(id)
        if not bem:
            raise HTTPException(status_code=404, detail="Bem não encontrado")
        return _com_depreciacao(bem)

    def alertas_garantia(self, dias: int = 60) -> list[dict]:
        """Bens ativos com garantia vencida ou vencendo nos próximos `dias` dias."""
        return BemRepository().garantias_a_vencer(dias)

    def create_bem(self, bem: BemCreate, usuario: dict):
        require_valid_tombo(bem.codigo_tombamento)
        bem.codigo_tombamento = bem.codigo_tombamento.upper()
        almoxarifado = SetorRepository().get_almoxarifado()
        if almoxarifado is None:
            raise HTTPException(status_code=400, detail="Cadastre um almoxarifado antes de cadastrar bens.")
        repository = BemRepository()
        try:
            criado = repository.save(bem, almoxarifado.id, usuario["id"])
            registrar_acao("bem", criado.id, "criar", usuario, None, criado.model_dump())
            return criado
        except errors.UniqueViolation as exc:
            # O índice único cobre também bens baixados: tombo nunca é reaproveitado.
            raise HTTPException(
                status_code=409,
                detail=(
                    f"Já existe um bem com o tombo {bem.codigo_tombamento}. "
                    "Números de tombo não são reaproveitados, mesmo de bens baixados."
                ),
            ) from exc

    def put_bem(self, id: int, bem_atualizado: BemUpdate, usuario: dict):
        repository = BemRepository()
        antes = repository.get_by_id(id)
        if antes is None:
            raise HTTPException(status_code=404, detail=f"Bem com id {id} não encontrado")
        if bem_atualizado.status is not None:
            atual = antes
            # Tirar um bem da manutenção sem o reparo concluído é decisão do setor de patrimônio.
            if (atual.status == "Manutenção" and bem_atualizado.status != "Manutenção"
                    and usuario["perfil"] != "setor_patrimonio"):
                raise HTTPException(
                    status_code=403,
                    detail="Somente o setor de patrimônio pode tirar um bem da manutenção.",
                )
        bem = repository.put(id, bem_atualizado)
        if not bem:
            raise HTTPException(status_code=404, detail=f"Bem com id {id} não encontrado")
        registrar_alteracao("bem", id, usuario, antes.model_dump(), bem.model_dump())
        return bem

    def delete_bem(self, id: int):
        try:
            repository = BemRepository()
            return repository.delete(id)
        except errors.NoDataFound:
            raise HTTPException(status_code=404, detail=f"Bem com id {id} não encontrado")

    def get_by_codTomb(self, codigo_tombamento: str):
        require_valid_tombo(codigo_tombamento)
        codigo_tombamento = codigo_tombamento.upper()
        repository = BemRepository()
        bem = repository.get_detalhes_por_tombo(codigo_tombamento)
        if not bem:
            raise HTTPException(
                status_code=404,
                detail="Bem não encontrado com esse código de tombamento"
            )
        return bem

    def get_proximo_codigo(self, id_categoria: int):
        repo_cat = CategoriaRepository()
        repo_bem = BemRepository()
        
        categoria = repo_cat.get_id(id_categoria)
        if not categoria:
            raise HTTPException(status_code=404, detail="Categoria não encontrada")
        
        
        sigla = re.sub(r"[^A-Za-z0-9]", "", categoria.sigla)
        if not sigla:
            raise HTTPException(status_code=400, detail="A sigla da categoria não pode gerar um número de tombo")
        # Próximo número depois do maior já usado pela sigla (inclusive bens baixados).
        # Contar bens não serve: tombo manual ou lacuna faz a contagem repetir número.
        proximo_numero = repo_bem.max_sequencia_tombo(sigla) + 1
        base = f"{sigla}-{str(proximo_numero).zfill(3)}"
        return format_tombo(base)

    def quantidade_bens(self):
        repo = BemRepository()
        res = repo.quantidade_total_bens()
        return res[0][0] if res else 0

    def quantidade_bens_ativos(self):
        repo = BemRepository()
        res = repo.quantidade_bens_ativos()
        return res[0][0] if res else 0

    def quantidade_bens_inativos(self):
        repo = BemRepository()
        res = repo.quantidade_bens_inativos()
        return res[0][0] if res else 0

    def bens_recentes(self):
        repo = BemRepository()
        return repo.get_registros_recentes()

    def get_historico_by_bem(self, bem_id: int):
        repository = BemRepository()
        return repository.get_historico_by_bem(bem_id)

    def get_por_setor(self, setor_id: int):
        repository = BemRepository()
        return repository.get_bens_por_setor(setor_id)

    def desativar_bem(self, bem_id: int, usuario: dict | None = None):
        repo = BemRepository()
        bem = repo.get_by_id(bem_id)
        if not bem:
            raise HTTPException(404, "Bem não encontrado")
        repo.desativar(bem_id)
        registrar_acao("bem", bem_id, "baixar", usuario, {"ativo": True}, {"ativo": False})
        return {"id": bem_id, "ativo": False}

    def reativar_bem(self, bem_id: int, usuario: dict | None = None):
        repo = BemRepository()
        bem = repo.get_by_id(bem_id)
        if not bem:
            raise HTTPException(404, "Bem não encontrado")
        repo.reativar(bem_id)
        registrar_acao("bem", bem_id, "reativar", usuario, {"ativo": False}, {"ativo": True})
        return {"id": bem_id, "ativo": True}
