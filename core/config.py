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
