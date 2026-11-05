"""Alimenta o banco de DESENVOLVIMENTO com dados de exemplo.

Usa os mesmos serviços do sistema (regras, tombo com dígito verificador, auditoria).
Idempotente: o que já existe pelo nome é pulado. Execute na raiz do projeto:

    venv/bin/python tools/seed_dev.py
"""
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.database import DataBase  # noqa: E402
from modules.bem.schemas import BemCreate  # noqa: E402
from modules.bem.service import BemService  # noqa: E402
from modules.movimentacao.schemas import MovimentacaoCreate  # noqa: E402
from modules.movimentacao.service import MovimentacaoService  # noqa: E402
from modules.responsavel.schemas import ResponsavelCreate  # noqa: E402
from modules.responsavel.service import ResponsavelService  # noqa: E402
from modules.setor.schemas import SetorCreate  # noqa: E402
from modules.setor.service import SetorService  # noqa: E402

ADMIN = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}
HOJE = date.today()
db = DataBase()


def um(sql, params=()):
    rows = db.execute(sql, params) or []
    return rows[0][0] if rows else None


def predio(nome, endereco):
    db.commit("INSERT INTO predios (nome, endereco) VALUES (%s, %s) ON CONFLICT (nome) DO NOTHING", (nome, endereco))
    return um("SELECT id FROM predios WHERE nome = %s", (nome,))


def andar(predio_id, nome):
    db.commit("INSERT INTO andares (predio_id, identificacao) VALUES (%s, %s) ON CONFLICT DO NOTHING", (predio_id, nome))
    return um("SELECT id FROM andares WHERE predio_id = %s AND identificacao = %s", (predio_id, nome))


def sala(andar_id, nome):
    db.commit("INSERT INTO salas (andar_id, identificacao) VALUES (%s, %s) ON CONFLICT DO NOTHING", (andar_id, nome))
    return um("SELECT id FROM salas WHERE andar_id = %s AND identificacao = %s", (andar_id, nome))


def responsavel(nome, cargo):
    existente = um("SELECT id FROM responsaveis WHERE nome = %s", (nome,))
    if existente:
        return existente
    ResponsavelService().create_responsavel(ResponsavelCreate(nome=nome, cargo=cargo))
    return um("SELECT id FROM responsaveis WHERE nome = %s", (nome,))


def setor(nome, responsavel_id, sala_id):
    existente = um("SELECT id FROM setores WHERE nome = %s", (nome,))
    if existente:
        return existente
    SetorService().add_setor(SetorCreate(nome=nome, responsavel_id=responsavel_id, sala_id=sala_id), responsavel_id)
    return um("SELECT id FROM setores WHERE nome = %s", (nome,))


def main():
    # Locais físicos
    sede = predio("Sede Central", "Av. Principal, 1000")
    anexo = predio("Anexo Norte", "Rua das Acácias, 250")
    terreo = andar(sede, "Térreo")
    primeiro = andar(sede, "1º andar")
    segundo = andar(sede, "2º andar")
    unico = andar(anexo, "Único")
    sala_admin = sala(terreo, "Sala 102")
    sala_compras = sala(primeiro, "Sala 101")
    sala_lab = sala(segundo, "Laboratório de TI")
    sala_deposito = sala(unico, "Depósito de Infraestrutura")

    # Responsáveis
    carla = responsavel("Carla Mendes", "Coordenadora administrativa")
    rafael = responsavel("Rafael Duarte", "Gerente de compras")
    juliana = responsavel("Juliana Souza", "Chefe de laboratório")
    marcos = responsavel("Marcos Teixeira", "Supervisor de infraestrutura")

    # Setores
    s_admin = setor("Administração", carla, sala_admin)
    s_compras = setor("Compras", rafael, sala_compras)
    s_lab = setor("Laboratório de Pesquisa", juliana, sala_lab)
    s_infra = setor("Infraestrutura", marcos, sala_deposito)

    # Categorias existentes: 1 Informática, 2 Mobiliário, 3 Veículos, 4 Eletrônicos, 6 Produção, 7 Acessórios
    # Cada bem: (nome, categoria, valor, marca, modelo, vida útil em meses, residual, entrada, dias até a garantia, conservação, status, setor)
    bens = [
        ("Notebook Dell Latitude 5440", 1, 6200, "Dell", "Latitude 5440", 60, 500, HOJE - timedelta(days=640), 400, "bom", "Em Uso", s_compras),
        ("Monitor LG 27UK850", 1, 1890, "LG", "27UK850", 60, 150, HOJE - timedelta(days=600), 20, "novo", "Disponível", s_compras),
        ("Impressora HP LaserJet Pro M404dn", 4, 1450, "HP", "M404dn", 60, 100, HOJE - timedelta(days=1200), -90, "regular", "Manutenção", None),
        ("Servidor Dell PowerEdge R650", 1, 28500, "Dell", "PowerEdge R650", 120, 2000, HOJE - timedelta(days=1080), 15, "bom", "Em Uso", s_infra),
        ("Cadeira ergonômica Flex 3", 2, 1200, "Flex", "Ergo 3", 120, 0, HOJE - timedelta(days=910), None, "bom", "Em Uso", s_admin),
        ("Mesa de reunião 6 lugares", 2, 2300, "Tok", "MR6", 120, 0, HOJE - timedelta(days=910), None, "novo", "Disponível", s_admin),
        ("Osciloscópio digital TBS1052B", 6, 8900, "Tektronix", "TBS1052B", 84, 500, HOJE - timedelta(days=1000), 760, "bom", "Em Uso", s_lab),
        ("Van Renault Master", 3, 185000, "Renault", "Master", 96, 30000, HOJE - timedelta(days=1600), None, "bom", "Em Uso", s_infra),
        ("Projetor Epson PowerLite X49", 4, 3200, "Epson", "X49", 60, 200, HOJE - timedelta(days=490), 50, "bom", "Disponível", s_lab),
        ("Switch Cisco CBS350 24 portas", 1, 4800, "Cisco", "CBS350", 60, 300, HOJE - timedelta(days=580), 1400, "novo", "Disponível", s_infra),
        ("Kit teclado e mouse MK270", 4, 150, "Logitech", "MK270", 24, 0, HOJE - timedelta(days=420), None, "novo", "Disponível", None),
        ("Ar-condicionado split 12000 BTU", 6, 2600, "Springer", "Eco", 120, 200, HOJE - timedelta(days=760), None, "bom", "Em Uso", s_admin),
    ]

    criados = pulados = 0
    for nome, cat, valor, marca, modelo, vida, residual, entrada, dias_garantia, estado, status, setor_id in bens:
        if um("SELECT id FROM bens WHERE nome = %s", (nome,)):
            pulados += 1
            continue
        tombo = BemService().get_proximo_codigo(cat)
        garantia = HOJE + timedelta(days=dias_garantia) if dias_garantia is not None else None
        bem = BemCreate(
            nome=nome, tipo="Equipamento", codigo_tombamento=tombo, valor=valor, valor_aquisicao=valor,
            status=status, id_categoria=cat, estado_conservacao=estado, marca=marca, modelo=modelo,
            data_entrada=entrada, vida_util_meses=vida, valor_residual=residual, garantia_fim=garantia,
        )
        criado = BemService().create_bem(bem, ADMIN)
        if setor_id:
            MovimentacaoService().add_movimentacao(
                MovimentacaoCreate(bem_id=criado.id, setor_destino_id=setor_id, justificativa="Distribuição inicial"),
                ADMIN)
        criados += 1
    print(f"Bens criados: {criados}, já existentes (pulados): {pulados}")
    print("Pronto.")


if __name__ == "__main__":
    main()
