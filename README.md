# Sistema de Tombamento (PatriFlow)

O **Sistema de Tombamento (PatriFlow)** é uma solução web e API REST moderna, desenvolvida para o gerenciamento, controle e auditoria de bens patrimoniais corporativos, seus setores, categorias e responsáveis. Ele permite rastrear a movimentação de cada ativo, gerenciar os níveis de acesso de usuários, visualizar indicadores estatísticos e exportar relatórios customizados em formato PDF e Excel.

---

## Recursos Principais

### 1. Gestão de Ativos (Bens)
- **Cadastro Detalhado:** Registro de bens com nome, valor, categoria, status e setor de localização.
- **Códigos de Tombamento Automáticos:** Geração padronizada no formato `SIGLA-00X`, onde a sigla (sem acentos) é derivada automaticamente da categoria.
- **Ciclo de Vida (Soft Delete):** Inativação lógica (`ativo = FALSE`) que preserva o histórico de movimentações e auditoria.
- **Histórico Completo (Timeline):** Visualização gráfica e cronológica das transferências de um bem no modal de detalhes.

### 2. Gestão de Entidades de Apoio
- **Categorias:** Organização dos bens (ex.: Informática, Mobiliário) com parametrização de siglas de tombamento.
- **Setores:** Controle físico ou lógico das localizações onde os bens estão alocados.
- **Responsáveis:** Associação de pessoal qualificado (gestores de setores) encarregados pelo patrimônio.

### 3. Movimentações e Auditoria
- **Histórico de Transferências:** Registro de todas as movimentações de bens entre setores.
- **Transferência Rápida:** Funcionalidade para mover um bem de setor em poucos cliques com validação automática.

### 4. Inteligência e Relatórios (Avançado)
- **Dashboard Estatístico:** Painel interativo com gráficos desenvolvidos em **Chart.js** exibindo:
  - Distribuição de bens ativos e inativos.
  - Distribuição quantitativa e financeira de bens por categoria.
  - Status dos ativos no sistema (Ex.: Em Uso, Manutenção, Baixado).
- **Exportação Customizada de Relatórios:**
  - Em formato **Excel (XLSX)** e **PDF**.
  - Filtros avançados por categoria, setor e status do bem.

### 5. Segurança e Controle de Acesso
- **Autenticação de Usuários:** Sistema de login com persistência de sessão baseada em cookies seguros.
- **Níveis de Permissão:** Controle do tipo de usuário (`admin` para gestão total e alterações cadastrais, e `comum` para consultas e operações básicas).

---

## Tecnologias e Dependências

- **Backend:** [FastAPI](https://fastapi.tiangolo.com/) (Python 3.x) — Framework de alta performance, fácil de estender e com validação robusta baseada em **Pydantic**.
- **Banco de Dados:** PostgreSQL — Execução de **Raw SQL** de alta performance via `psycopg2-binary`, sem a sobrecarga de ORMs.
- **Frontend:** HTML5, CSS3 Customizado, **Bootstrap 5**, e Jinja2 Templates para renderização dinâmica no servidor.
- **JavaScript:** ES6+ Modular com desacoplamento de arquivos JS (ex.: `dashboard.js`, `bens.js`, `utils.js`).
- **Geração de Documentos:** `fpdf2` (para PDFs) e `pandas`/`openpyxl` (para planilhas Excel).

---

## Arquitetura do Projeto

O projeto segue uma arquitetura modular por domínio:

```
├── main.py                     # Ponto de entrada do FastAPI
├── requirements.txt            # Dependências do Python
├── tabelasDados.sql            # Script de inicialização do banco PostgreSQL
├── core/                       # Configurações globais e classe de banco
│   ├── config.py               # Credenciais e conexões do BD
│   └── database.py             # Pooling de conexão e execução SQL
├── modules/                    # Módulos de domínio da aplicação
│   ├── bem/                    # CRUD de bens, queries e estatísticas
│   ├── categoria/              # CRUD de categorias e siglas de tombamento
│   ├── setor/                  # CRUD de setores e relacionamento
│   ├── responsavel/            # CRUD de responsáveis e cargos
│   ├── movimentacao/           # Histórico de transferências de bens
│   ├── relatorio/              # Lógica de exportação (Excel e PDF)
│   └── usuario/                # Autenticação e credenciais do sistema
├── api/v1/                     # Roteamento da API JSON REST
├── web/                        # Rotas web que servem os templates Jinja2
├── templates/                  # Arquivos HTML Jinja2 (base.html, index.html, etc.)
└── static/                     # Arquivos estáticos (CSS, JS, Imagens)
```

---

## Configuração e Instalação

### Pré-requisitos
- Python 3.10+ instalado.
- Banco de Dados PostgreSQL ativo.

### 1. Clonar o projeto e criar o Ambiente Virtual

```bash
# Crie o ambiente virtual
python -m venv venv

# Ative o ambiente virtual
# No Linux/macOS:
source venv/bin/activate
# No Windows:
venv\Scripts\activate
```

### 2. Instalar as Dependências

```bash
pip install -r requirements.txt
```

### 3. Configurar o Banco de Dados

1. Certifique-se de que o PostgreSQL está rodando.
2. Crie um banco de dados no PostgreSQL (por padrão, chamado `sistema_tombamento`).
3. Execute o script `tabelasDados.sql` no seu gerenciador de banco de dados (ex.: DBeaver, pgAdmin) para criar as tabelas e dados iniciais.
4. Ajuste as credenciais no arquivo `core/config.py`:

```python
DB_HOST = "127.0.0.1"
DB_PORT = 5433 # Altere para a sua porta do PostgreSQL se for diferente (padrão 5432)
DB_USER = "postgres"
DB_PASSWORD = "sua_senha"
DB_NAME = "sistema_tombamento"
```

### 4. Executar o Servidor de Desenvolvimento

Execute o comando Uvicorn para iniciar a aplicação:

```bash
uvicorn main:app --reload
```

A aplicação estará disponível em:
- **Interface Web:** [http://127.0.0.1:8000/index](http://127.0.0.1:8000/index) (necessita de login prévio ou use os dados de teste do SQL)
- **Documentação Swagger (API REST):** [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **Documentação ReDoc:** [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)

### Aplicativo móvel Flutter

O aplicativo fica em [`mobile/`](mobile/README.md). Ele é uma única instalação para todos os perfis e, antes do login, permite informar e salvar no aparelho o endereço-base do servidor PatriFlow.

```bash
cd mobile
flutter pub get
flutter run
```

Informe a origem do servidor sem `/api/v1`, como `http://192.168.0.10:8000`. Para acessar a API local pelo emulador Android, use `http://10.0.2.2:8000`.

---

## 👥 Equipe

- **José Euclides H Barros**
- **Pedro Henrique do Santos**
- **Guilherme Henrique M. G. Santana**

Desenvolvedores do projeto *Sistema de Tombamento*.
