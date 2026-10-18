from fastapi import APIRouter

from core.database import DataBase
from modules.localizacao.schemas import AndarCreate, PredioCreate, SalaCreate

router = APIRouter(prefix="/localizacao", tags=["Localização física"])


def as_objects(rows, fields):
    return [dict(zip(fields, row)) for row in rows or []]


@router.get("/predios")
def list_predios():
    rows = DataBase().execute("SELECT id, nome, endereco FROM predios ORDER BY nome")
    return as_objects(rows, ("id", "nome", "endereco"))


@router.post("/predios", status_code=201)
def create_predio(predio: PredioCreate):
    row = DataBase().commit(
        "INSERT INTO predios (nome, endereco) VALUES (%s, %s) RETURNING id, nome, endereco",
        (predio.nome.strip(), predio.endereco)
    )
    return dict(zip(("id", "nome", "endereco"), row))


@router.get("/andares")
def list_andares(predio_id: int | None = None):
    query = "SELECT a.id, a.predio_id, a.identificacao, p.nome FROM andares a JOIN predios p ON p.id = a.predio_id"
    if predio_id is not None:
        rows = DataBase().execute(query + " WHERE a.predio_id = %s ORDER BY a.identificacao", (predio_id,))
    else:
        rows = DataBase().execute(query + " ORDER BY p.nome, a.identificacao")
    return as_objects(rows, ("id", "predio_id", "identificacao", "predio_nome"))


@router.post("/andares", status_code=201)
def create_andar(andar: AndarCreate):
    row = DataBase().commit(
        "INSERT INTO andares (predio_id, identificacao) VALUES (%s, %s) RETURNING id, predio_id, identificacao",
        (andar.predio_id, andar.identificacao.strip())
    )
    return dict(zip(("id", "predio_id", "identificacao"), row))


@router.get("/salas")
def list_salas(andar_id: int | None = None):
    query = """SELECT s.id, s.andar_id, s.identificacao, a.identificacao, p.id, p.nome
               FROM salas s JOIN andares a ON a.id = s.andar_id JOIN predios p ON p.id = a.predio_id"""
    if andar_id is not None:
        rows = DataBase().execute(query + " WHERE s.andar_id = %s ORDER BY s.identificacao", (andar_id,))
    else:
        rows = DataBase().execute(query + " ORDER BY p.nome, a.identificacao, s.identificacao")
    return as_objects(rows, ("id", "andar_id", "identificacao", "andar_identificacao", "predio_id", "predio_nome"))


@router.post("/salas", status_code=201)
def create_sala(sala: SalaCreate):
    row = DataBase().commit(
        "INSERT INTO salas (andar_id, identificacao) VALUES (%s, %s) RETURNING id, andar_id, identificacao",
        (sala.andar_id, sala.identificacao.strip())
    )
    return dict(zip(("id", "andar_id", "identificacao"), row))
