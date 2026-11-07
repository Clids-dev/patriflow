"""Inventário: abertura (lista congelada), conferência, marcação de faltantes e fechamento.

Concorrência: conferências travam o inventário em modo compartilhado (FOR SHARE) e o fechamento em
modo exclusivo (FOR UPDATE). Assim várias pessoas conferem ao mesmo tempo, mas nenhuma conferência
é gravada depois que o fechamento começou.
"""
from datetime import date

from fastapi import HTTPException
from psycopg2 import errors

from core.database import DataBase
from core.tombamento import require_valid_tombo
from modules.inventario import queries as q
from modules.inventario.repository import InventarioRepository
from modules.inventario.schemas import Conferencia, InventarioCreate, NaoCadastrado

ADMIN = "setor_patrimonio"
COLABORADORES = ("agente_campo", "responsavel_setor")


def _exigir_patrimonio(usuario: dict, acao: str) -> None:
    if usuario["perfil"] != ADMIN:
        raise HTTPException(status_code=403, detail=f"Somente o setor de patrimônio pode {acao} inventários.")


def _exigir_conferente(usuario: dict, setor_id: int) -> None:
    """Patrimônio confere em qualquer setor; colaboradores, só no próprio setor."""
    if usuario["perfil"] == ADMIN:
        return
    if usuario["perfil"] not in COLABORADORES or usuario.get("setor_id") != setor_id:
        raise HTTPException(status_code=403, detail="Você só confere bens no seu setor.")


def _travar(cur, inventario_id: int, modo: str) -> tuple:
    cur.execute(q.TRAVAR_INVENTARIO.format(modo=modo), (inventario_id,))
    inv = cur.fetchone()
    if inv is None:
        raise HTTPException(status_code=404, detail=f"Inventário com id {inventario_id} não encontrado")
    return inv


def _exigir_aberto_para_conferir(cur, inventario_id: int, setor_id: int) -> None:
    _, status, inicio = _travar(cur, inventario_id, "SHARE")
    if status != "aberto":
        raise HTTPException(status_code=409, detail="Este inventário já foi fechado.")
    if date.today() < inicio:
        raise HTTPException(status_code=409, detail=f"O inventário começa em {inicio:%d/%m/%Y}.")
    cur.execute(q.SETOR_NO_INVENTARIO, (inventario_id, setor_id))
    if cur.fetchone() is None:
        raise HTTPException(status_code=400, detail="Este setor não faz parte do inventário.")


class InventarioService:
    def __init__(self, repository: InventarioRepository | None = None):
        self.repo = repository or InventarioRepository()

    # --- Abertura --------------------------------------------------------------------------------
    def abrir(self, dados: InventarioCreate, usuario: dict):
        _exigir_patrimonio(usuario, "abrir")
        with DataBase().transacao() as cur:
            cur.execute(q.SETORES_INVALIDOS, {"setores": dados.setor_ids})
            invalidos = [r[0] for r in cur.fetchall()]
            if invalidos:
                raise HTTPException(status_code=400, detail=f"Setores inexistentes ou inativos: {invalidos}")
            cur.execute(q.SETORES_EM_INVENTARIO_ABERTO, {"setores": dados.setor_ids})
            ocupados = [r[0] for r in cur.fetchall()]
            if ocupados:
                raise HTTPException(status_code=409,
                                    detail=f"Já em inventário aberto: {', '.join(ocupados)}. Feche-o antes.")
            cur.execute(q.INSERIR_INVENTARIO, (dados.descricao, dados.inicio, dados.fim, usuario["id"]))
            inventario_id = cur.fetchone()[0]
            try:
                cur.execute(q.INSERIR_SETORES, {"inv": inventario_id, "setores": dados.setor_ids})
            except errors.UniqueViolation:
                # Outro inventário abriu o mesmo setor entre a verificação e a gravação.
                raise HTTPException(status_code=409, detail="Um dos setores acabou de entrar em outro inventário.")
            cur.execute(q.CONGELAR_LISTA, {"inv": inventario_id, "setores": dados.setor_ids})
        return self.detalhar(inventario_id)

    # --- Conferência -----------------------------------------------------------------------------
    def conferir(self, inventario_id: int, dados: Conferencia, usuario: dict):
        _exigir_conferente(usuario, dados.setor_id)
        require_valid_tombo(dados.codigo_tombamento)
        with DataBase().transacao() as cur:
            _exigir_aberto_para_conferir(cur, inventario_id, dados.setor_id)
            cur.execute(q.BEM_PELO_TOMBO, (dados.codigo_tombamento,))
            bem = cur.fetchone()
            if bem is None:
                raise HTTPException(status_code=404,
                                    detail="Tombo não cadastrado. Registre o bem como não cadastrado.")
            bem_id, ativo = bem
            if not ativo:
                raise HTTPException(status_code=409, detail="Este bem foi baixado. Informe o patrimônio.")
            params = {"setor": dados.setor_id, "estado": dados.estado_encontrado, "obs": dados.observacao,
                      "usuario": usuario["id"]}
            cur.execute(q.ITEM_DO_BEM, (inventario_id, bem_id))
            item = cur.fetchone()
            if item is None:
                # Bem fora da lista congelada: encontrado aqui, mas pertence a outro lugar.
                cur.execute(q.LOCAL_DO_BEM, (bem_id,))
                local = cur.fetchone()
                cur.execute(q.INSERIR_EXCEDENTE, {**params, "inv": inventario_id, "bem": bem_id,
                                                  "setor_atual": local[0] if local else None})
                item_id = cur.fetchone()[0]
            else:
                item_id, setor_esperado, _ = item
                situacao = "localizado" if setor_esperado == dados.setor_id else "outro_setor"
                # Ler de novo o mesmo bem só atualiza a conferência (a última leitura vale).
                cur.execute(q.REGISTRAR_CONFERENCIA, {**params, "situacao": situacao, "item": item_id})
        return self.repo.item(item_id)

    def registrar_nao_cadastrado(self, inventario_id: int, dados: NaoCadastrado, usuario: dict):
        _exigir_conferente(usuario, dados.setor_id)
        codigo = dados.codigo_lido.upper() if dados.codigo_lido else None
        with DataBase().transacao() as cur:
            _exigir_aberto_para_conferir(cur, inventario_id, dados.setor_id)
            if codigo:
                cur.execute(q.BEM_PELO_TOMBO, (codigo,))
                if cur.fetchone() is not None:
                    raise HTTPException(status_code=409,
                                        detail="Este tombo está cadastrado. Faça a conferência pelo código.")
            cur.execute(q.INSERIR_NAO_CADASTRADO, {"inv": inventario_id, "codigo": codigo, "descricao": dados.descricao,
                                                   "setor": dados.setor_id, "obs": dados.observacao,
                                                   "usuario": usuario["id"]})
            item_id = cur.fetchone()[0]
        return self.repo.item(item_id)

    def marcar_nao_localizado(self, inventario_id: int, item_id: int, usuario: dict):
        item = self.repo.item(item_id)
        if item is None or item.bem_id is None:
            raise HTTPException(status_code=404, detail=f"Item {item_id} não encontrado")
        _exigir_conferente(usuario, item.setor_esperado_id)
        with DataBase().transacao() as cur:
            _exigir_aberto_para_conferir(cur, inventario_id, item.setor_esperado_id)
            cur.execute(q.MARCAR_ITEM_NAO_LOCALIZADO, (usuario["id"], item_id, inventario_id))
            if cur.fetchone() is None:
                raise HTTPException(status_code=409, detail="Este item já foi conferido.")
        return self.repo.item(item_id)

    def marcar_faltantes(self, inventario_id: int, setor_id: int, usuario: dict) -> dict:
        """Encerra a contagem de um setor: tudo o que não foi lido vira "não localizado"."""
        _exigir_conferente(usuario, setor_id)
        with DataBase().transacao() as cur:
            _exigir_aberto_para_conferir(cur, inventario_id, setor_id)
            cur.execute(q.MARCAR_FALTANTES_DO_SETOR, (usuario["id"], inventario_id, setor_id))
            marcados = cur.rowcount
        return {"marcados": marcados}

    # --- Fechamento ------------------------------------------------------------------------------
    def fechar(self, inventario_id: int, usuario: dict) -> dict:
        _exigir_patrimonio(usuario, "fechar")
        resumo = {"inventario_id": inventario_id, "localizados": 0, "outro_setor": 0, "nao_localizados": 0,
                  "ausencias_justificadas": 0, "nao_cadastrados": 0, "transferencias_abertas": 0,
                  "transferencias_ignoradas": [], "pendencias_criadas": 0}
        with DataBase().transacao() as cur:
            _, status, _ = _travar(cur, inventario_id, "UPDATE")
            if status != "aberto":
                raise HTTPException(status_code=409, detail="Este inventário já foi fechado.")
            cur.execute(q.CONTAR_SEM_SITUACAO, (inventario_id,))
            faltam = cur.fetchone()[0]
            if faltam:
                raise HTTPException(status_code=409,
                                    detail=f"Ainda há {faltam} bem(ns) sem situação. Confira ou marque como não localizado.")

            cur.execute(q.ITENS_PARA_FECHAMENTO, (inventario_id,))
            for item_id, bem_id, codigo, nome, situacao, esperado, encontrado, justificada in cur.fetchall():
                if situacao == "localizado":
                    resumo["localizados"] += 1
                elif situacao == "outro_setor":
                    resumo["outro_setor"] += 1
                    motivo = self._abrir_transferencia(cur, inventario_id, bem_id, encontrado, usuario)
                    if motivo:
                        resumo["transferencias_ignoradas"].append({"codigo_tombamento": codigo, "motivo": motivo})
                    else:
                        resumo["transferencias_abertas"] += 1
                elif situacao == "nao_localizado":
                    resumo["nao_localizados"] += 1
                    if justificada:
                        # Emprestado ou em manutenção: o registro dessa operação já explica a ausência.
                        resumo["ausencias_justificadas"] += 1
                        continue
                    cur.execute(q.INSERIR_PENDENCIA, ("bem_nao_localizado", item_id, bem_id, esperado,
                                                      f"{codigo} · {nome}: não localizado no inventário #{inventario_id}",
                                                      usuario["id"]))
                    resumo["pendencias_criadas"] += 1
                elif situacao == "nao_cadastrado":
                    resumo["nao_cadastrados"] += 1
                    etiqueta = f" (etiqueta {codigo})" if codigo else ""
                    cur.execute(q.INSERIR_PENDENCIA, ("bem_nao_cadastrado", item_id, None, encontrado,
                                                      f"{nome}{etiqueta}: encontrado e não cadastrado (inventário #{inventario_id})",
                                                      usuario["id"]))
                    resumo["pendencias_criadas"] += 1

            cur.execute(q.FECHAR, (usuario["id"], inventario_id))
            cur.execute(q.LIBERAR_SETORES, (inventario_id,))
        return resumo

    @staticmethod
    def _abrir_transferencia(cur, inventario_id: int, bem_id: int, destino: int, usuario: dict) -> str | None:
        """Abre a transferência do local atual para onde o bem foi encontrado. Devolve o motivo se não abrir."""
        cur.execute("SELECT ativo FROM bens WHERE id = %s FOR UPDATE", (bem_id,))
        if not cur.fetchone()[0]:
            return "bem baixado"
        cur.execute(q.LOCAL_DO_BEM, (bem_id,))
        local = cur.fetchone()
        origem = local[0] if local else None
        if origem is None:
            return "bem sem localização: registre a entrada pelo almoxarifado"
        if origem == destino:
            return "o bem já está no setor onde foi encontrado"
        cur.execute(q.EXISTE_TRANSFERENCIA_ABERTA, (bem_id,))
        if cur.fetchone() is not None:
            return "já existe transferência em andamento"
        cur.execute(q.ABRIR_TRANSFERENCIA, (bem_id, origem, destino,
                                            f"Inventário #{inventario_id}: bem localizado em outro setor", usuario["id"]))
        return None

    # --- Leitura ---------------------------------------------------------------------------------
    def listar(self, situacao: str):
        return self.repo.listar(situacao)

    def detalhar(self, inventario_id: int):
        inventario = self.repo.buscar(inventario_id)
        if inventario is None:
            raise HTTPException(status_code=404, detail=f"Inventário com id {inventario_id} não encontrado")
        return inventario

    def itens(self, inventario_id: int, setor_id: int | None, filtro: str):
        self.detalhar(inventario_id)
        return self.repo.itens(inventario_id, setor_id, filtro)
