import os
from pathlib import Path

from dotenv import load_dotenv

# Carrega a configuração local independente do diretório em que o Uvicorn
# foi iniciado. Variáveis exportadas pelo ambiente têm prioridade sobre .env.
load_dotenv(Path(__file__).resolve().parent.parent / ".env", override=False)

DB_HOST = "127.0.0.1"
DB_PORT = 5433
DB_USER = "postgres"
DB_PASSWORD = "postgres"
DB_NAME = "sistema_tombamento"
JWT_SECRET = os.getenv("PATRIFLOW_JWT_SECRET", "")
JWT_EXPIRES_SECONDS = int(os.getenv("PATRIFLOW_JWT_EXPIRES_SECONDS", "3600"))

# Fotos (W05): pasta de guarda no servidor e tamanho máximo por arquivo.
FOTOS_DIR = os.getenv("PATRIFLOW_FOTOS_DIR", str(Path(__file__).resolve().parent.parent / "uploads" / "fotos"))
FOTO_MAX_BYTES = int(os.getenv("PATRIFLOW_FOTO_MAX_BYTES", str(5 * 1024 * 1024)))

# Transferências sem resposta do almoxarifado além deste prazo são escaladas ao setor de patrimônio.
PRAZO_TRANSFERENCIA_DIAS = int(os.getenv("PATRIFLOW_PRAZO_TRANSFERENCIA_DIAS", "3"))

# Baixas de bens com valor igual ou acima deste limite exigem aprovação de outro servidor do patrimônio.
ALCADA_BAIXA_VALOR = float(os.getenv("PATRIFLOW_ALCADA_BAIXA_VALOR", "5000"))
