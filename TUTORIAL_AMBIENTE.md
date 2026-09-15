# Tutorial: iniciar o ambiente de desenvolvimento

Este guia explica como executar o PatriFlow localmente para desenvolvimento.

## Pré-requisitos

- Python 3.10 ou superior;
- PostgreSQL em execução;
- `pip` disponível no terminal.

## 1. Criar e ativar o ambiente virtual

Na raiz do projeto, execute:

```bash
python -m venv venv
```

Ative o ambiente virtual antes de instalar dependências ou iniciar o servidor.

No Linux/macOS:

```bash
source venv/bin/activate
```

No Windows (PowerShell):

```powershell
.\\venv\\Scripts\\Activate.ps1
```

Para sair do ambiente virtual ao terminar o trabalho:

```bash
deactivate
```

## 2. Instalar as dependências

Com o ambiente virtual ativo:

```bash
pip install -r requirements.txt
```

## 3. Preparar o banco de dados

1. Crie um banco PostgreSQL chamado `sistema_tombamento`.
2. Execute o arquivo `tabelasDados.sql` nesse banco para criar as tabelas e os dados iniciais.
3. Confira as credenciais em `core/config.py` e ajuste-as para o seu PostgreSQL. A configuração padrão é:

```python
DB_HOST = "127.0.0.1"
DB_PORT = 5433
DB_USER = "postgres"
DB_PASSWORD = "postgres"
DB_NAME = "sistema_tombamento"
```

Exemplo de importação pelo terminal, alterando usuário, porta e banco quando necessário:

```bash
psql -U postgres -p 5433 -d sistema_tombamento -f tabelasDados.sql
```

## 4. Iniciar a aplicação

Ainda na raiz do projeto e com o ambiente virtual ativo:

```bash
uvicorn main:app --reload
```

O parâmetro `--reload` reinicia o servidor automaticamente quando arquivos Python são alterados.

Abra no navegador:

- Interface web: http://127.0.0.1:8000/index
- Documentação da API (Swagger): http://127.0.0.1:8000/docs
- Documentação alternativa (ReDoc): http://127.0.0.1:8000/redoc

Para encerrar o servidor, pressione `Ctrl+C` no terminal em que ele está rodando.

## Aplicativo móvel (opcional)

Se também for desenvolver o aplicativo Flutter:

```bash
cd mobile
flutter pub get
flutter run
```

No app, informe a URL-base do servidor sem `/api/v1`. Em um emulador Android, para acessar o servidor local, use `http://10.0.2.2:8000`.
