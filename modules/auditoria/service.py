from modules.auditoria.repository import AuditoriaRepository


def diferencas(antes: dict, depois: dict) -> tuple[dict, dict]:
    """Devolve só os campos que mudaram, com o valor antes e depois."""
    campos = set(antes) | set(depois)
    mudou = {c for c in campos if antes.get(c) != depois.get(c)}
    return ({c: antes.get(c) for c in mudou}, {c: depois.get(c) for c in mudou})


def registrar_alteracao(entidade: str, registro_id: int, usuario: dict | None,
                        antes: dict, depois: dict) -> None:
    de, para = diferencas(antes, depois)
    if not de:
        return  # nada mudou: não há o que registrar
    AuditoriaRepository().registrar(entidade, registro_id, "editar", (usuario or {}).get("id"), de, para)


def registrar_acao(entidade: str, registro_id: int, acao: str, usuario: dict | None,
                   antes: dict | None = None, depois: dict | None = None, cur=None) -> None:
    """Registra uma ação. Passe `cur` para gravar dentro da transação da própria operação."""
    AuditoriaRepository().registrar(entidade, registro_id, acao, (usuario or {}).get("id"), antes, depois, cur=cur)
