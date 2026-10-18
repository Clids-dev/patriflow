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

### W03 — conferência física e identificação segura

O cadastro de bens armazena marca, modelo, número de série, valor de aquisição, nota fiscal, data de entrada e estado de conservação. O estado é obrigatório e aceita `novo`, `bom`, `regular`, `ruim` ou `inservivel`; em novos registros, a interface inicia em `novo`.

A localização segue a hierarquia **prédio → andar → sala → setor**. Cadastre cada nível pela API em `/api/v1/localizacao/predios`, `/api/v1/localizacao/andares` e `/api/v1/localizacao/salas`, nessa ordem. O cadastro de setor exige `sala_id`.

#### Dígito verificador módulo 11

O tombo tem o formato `BASE-DV`; por exemplo, `INF-001-0`. Para conferir o DV manualmente:

1. Separe o último algarismo, que é o DV. O restante é a base. No exemplo, a base é `INF-001` e o DV informado é `0`.
2. Remova os hífens e converta as letras para números: `A=10`, `B=11`, …, `Z=35`. Os algarismos mantêm o próprio valor. Assim, `INF-001` vira `18, 23, 15, 0, 0, 1`.
3. Percorra esses valores da direita para a esquerda, multiplicando por pesos que começam em 2 e seguem `2, 3, 4, 5, 6, 7, 8, 9`; depois do 9, volte para 2.
4. Some os produtos. Para `INF-001`: `1×2 + 0×3 + 0×4 + 15×5 + 23×6 + 18×7 = 341`.
5. Calcule `DV = (11 − (soma mod 11)) mod 11`. Se o resultado for 10, use 0, pois o DV é sempre um único algarismo. No exemplo, `341 mod 11 = 0`, então o DV é `0`.
6. Compare o resultado com o último algarismo do tombo. Se não coincidir, a API responde HTTP 400 com `Número de tombo inválido — verifique a digitação` antes de consultar o banco.

O DV também é conferido pelo banco. O número não pode ser atualizado nem reutilizado após a baixa: o tombo é único, permanece registrado no bem inativo, e exclusões físicas ou limpeza da tabela são bloqueadas.

Para atualizar uma base existente, aplique `database/migrations/20261018_w03_assets_locations_tombo.sql` após a migração W02. A migração acrescenta DV aos tombos históricos; reimprima as etiquetas com os novos códigos. Ela também associa os setores atuais a um local temporário “não informado”; atualize esses locais com os endereços reais depois.

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

Antes de iniciar a aplicação, configure a chave de assinatura JWT com um valor aleatório e privado (pelo menos 32 bytes). Para desenvolvimento local, crie um `.env` na raiz do projeto (ele é ignorado pelo Git):

```bash
python -c 'from pathlib import Path; import secrets; p=Path(".env"); p.exists() or p.write_text("PATRIFLOW_JWT_SECRET=" + secrets.token_urlsafe(48) + "\n")'
```

O `core/config.py` carrega essa chave automaticamente. Em produção, configure `PATRIFLOW_JWT_SECRET` no ambiente do serviço; essa variável tem prioridade sobre o `.env`. Não altere a chave a cada reinício, pois isso invalida os tokens emitidos anteriormente.

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
