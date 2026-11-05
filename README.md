# PatriFlow — Sistema de Tombamento

O **PatriFlow** é um sistema web e API REST para o controle do patrimônio: cadastro de bens com código de tombamento, localização hierárquica, transferências com aprovação, fotos, etiquetas QR, termo de responsabilidade, depreciação, garantias, baixas e auditoria completa das alterações.

---

## Funcionalidades

### Bens (patrimônio)
- Cadastro com nome, tipo, categoria, marca, modelo, número de série, valor de aquisição, nota fiscal, data de entrada, estado de conservação e garantia.
- **Código de tombamento automático** no formato `SIGLA-NNN-DV`, por exemplo `INF-001-0`, com dígito verificador módulo 11. O código é imutável e nunca é reaproveitado, nem depois da baixa.
- **Importação em lote** por CSV (com simulação antes de gravar).
- **Fotos** do bem em JPEG, PNG ou WebP, de até 5 MB, com registro imutável.
- **Etiquetas QR** para impressão, individuais ou em lote.
- **Termo de responsabilidade** para impressão, por responsável.
- **Depreciação linear** calculada a partir da aquisição, do valor residual e da vida útil.
- **Alertas de garantia** vencida ou a vencer nos próximos 60 dias.
- **Baixa** com motivo (doação, inservível, extravio, venda, sinistro ou descarte) e documento de referência. Baixas acima do limite de alçada exigem aprovação de outro servidor do patrimônio.
- **Histórico de auditoria** de cada bem, com os campos antes e depois de cada alteração.

### Estrutura
- **Categorias**, com a sigla usada na geração do tombamento.
- **Setores**, ligados a uma sala e a um responsável.
- **Responsáveis**, com cargo e setor.
- **Localizações** em hierarquia: prédio → andar → sala.
- Cada cadastro tem uma página própria com indicadores e a lista de bens vinculados.

### Movimentações (transferências)
- Solicitações entre o almoxarifado e o setor do solicitante. A solicitação exige justificativa.
- O **responsável do almoxarifado** autoriza ou recusa. A autorização exige foto do bem; a recusa exige o motivo, que fica visível para quem pediu.
- Solicitações sem resposta após o prazo (3 dias por padrão) são **escaladas** para a fila do setor de patrimônio.
- Movimentações feitas pelo setor de patrimônio são aprovadas na hora.

### Painel e relatórios
- Painel com indicadores de patrimônio ativo, total, baixados e garantias a vencer, além de uma lista do que pede atenção e gráficos por categoria e por status.
- Relatórios em PDF e Excel, com filtros por categoria, setor e status.

### Segurança
- Login com token JWT em cookie seguro e também em `Authorization: Bearer`.
- **Bloqueio temporário** após 5 tentativas erradas (15 minutos). As tentativas ficam registradas, sem a senha.
- Cadastro público: a conta fica pendente até o setor de patrimônio ativá-la e definir perfil e setor.
- Perfis de acesso:

| Perfil | Acesso |
|---|---|
| `setor_patrimonio` | Gestão completa: bens, estrutura, usuários, autorizações, escaladas, baixas e etiquetas. |
| `agente_campo` | Consulta e conferência dos bens; solicita movimentações. |
| `responsavel_setor` | Consulta o acervo do próprio setor; solicita bens; autoriza transferências quando é o responsável do almoxarifado. |
| `auditor` | Somente leitura. |

### Backup
- `tools/backup.sh` gera o dump do banco e um arquivo com as fotos, e remove backups com mais de 14 dias.
- `tools/restore.sh` restaura um backup em um banco **novo**, para teste, sem tocar no original.

---

## Tecnologias

- **Backend:** [FastAPI](https://fastapi.tiangolo.com/) com Pydantic v2 e Uvicorn.
- **Banco de dados:** PostgreSQL, com SQL direto via `psycopg2-binary`, sem ORM.
- **Interface web:** Jinja2, Bootstrap, Bootstrap Icons, Chart.js e um tema baseado no Mazer.
- **Documentos:** `fpdf2` (PDF), `openpyxl` e `pandas` (Excel), `segno` (QR Code).
- **Aplicativo móvel:** Flutter, em [`mobile/`](mobile/README.md).

---

## Estrutura do projeto

```
├── main.py                 # Ponto de entrada da aplicação
├── requirements.txt        # Dependências Python
├── tabelasDados.sql        # Script inicial do banco
├── database/migrations/    # Alterações do banco, em ordem cronológica
├── core/                   # Configuração, conexão com o banco e regras de tombamento
├── modules/                # Domínios: bem, categoria, setor, responsavel, localizacao,
│                           # movimentacao, foto, etiqueta, termo, auditoria, usuario, relatorio
│   └── <dominio>/          # router, service, repository, queries e schemas
├── api/v1/                 # Rotas da API REST e controle de permissões (ROLE_PERMISSIONS)
├── web/                    # Rotas que entregam as páginas HTML
├── templates/              # Páginas Jinja2
├── static/                 # CSS, JavaScript e imagens
├── tools/                  # Dados de desenvolvimento, backup e restauração
├── docs/                   # Documentação de requisitos
├── test_*.py               # Testes automatizados
└── mobile/                 # Aplicativo Flutter
```

---

## Instalação

### Pré-requisitos
- Python 3.10 ou superior.
- PostgreSQL em execução.

### 1. Ambiente virtual e dependências

```bash
python -m venv venv
source venv/bin/activate        # Linux/macOS
venv\Scripts\activate           # Windows

pip install -r requirements.txt
```

### 2. Banco de dados

1. Crie o banco `sistema_tombamento` (ou outro nome).
2. Execute `tabelasDados.sql` no seu cliente de banco (DBeaver, pgAdmin etc.).
3. Em uma base já existente, aplique os arquivos de `database/migrations/` em ordem de nome.
4. Ajuste as conexões em `core/config.py` (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`).

### 3. Variáveis de ambiente

Crie um arquivo `.env` na raiz (ele é ignorado pelo Git) com a chave de assinatura dos tokens:

```bash
python -c 'from pathlib import Path; import secrets; p=Path(".env"); p.exists() or p.write_text("PATRIFLOW_JWT_SECRET=" + secrets.token_urlsafe(48) + "\n")'
```

Variáveis opcionais:

| Variável | Padrão | Função |
|---|---|---|
| `PATRIFLOW_JWT_SECRET` | — | Chave dos tokens. Obrigatória. Não a troque a cada reinício. |
| `PATRIFLOW_JWT_EXPIRES_SECONDS` | `3600` | Validade do token de acesso. |
| `PATRIFLOW_PRAZO_TRANSFERENCIA_DIAS` | `3` | Dias até a escalada de uma solicitação. |
| `PATRIFLOW_ALCADA_BAIXA_VALOR` | `5000` | Valor a partir do qual a baixa exige aprovação de outro servidor. |
| `PATRIFLOW_FOTOS_DIR` | `uploads/fotos` | Pasta onde as fotos são guardadas. |
| `PATRIFLOW_FOTO_MAX_BYTES` | `5242880` | Tamanho máximo de cada foto (5 MB). |

Em produção, defina essas variáveis no ambiente do serviço. Elas têm prioridade sobre o `.env`.

### 4. Executar

```bash
uvicorn main:app --reload
```

- **Interface web:** http://127.0.0.1:8000/index (faça login antes)
- **Swagger (API):** http://127.0.0.1:8000/docs
- **ReDoc:** http://127.0.0.1:8000/redoc

### 5. Dados de exemplo (somente desenvolvimento)

```bash
venv/bin/python tools/seed_dev.py
```

O script é idempotente: o que já existe pelo nome é pulado. Ele usa as mesmas regras do sistema.

---

## Testes

```bash
pytest
```

Os testes de integração usam o banco configurado em `core/config.py`.

---

## Backup e restauração

```bash
PGPASSWORD=... tools/backup.sh
PGPASSWORD=... tools/restore.sh backups/banco-AAAAMMDD-HHMMSS.dump banco_de_teste
```

Variáveis úteis: `PATRIFLOW_BACKUP_DIR`, `PATRIFLOW_BACKUP_RETENCAO_DIAS`, `PATRIFLOW_DB_HOST`, `PATRIFLOW_DB_PORT`, `PATRIFLOW_DB_USER`, `PATRIFLOW_DB_NAME`.

Antes de restaurar no banco de produção, faça a restauração de teste e confira os dados.

---

## Aplicativo móvel

O app fica em [`mobile/`](mobile/README.md). Ele serve a todos os perfis. Antes do login, informe o endereço do servidor sem `/api/v1`, por exemplo `http://192.168.0.10:8000`. Para o emulador Android acessar uma API local, use `http://10.0.2.2:8000`.

```bash
cd mobile
flutter pub get
flutter run
```

---

## Equipe

- **José Euclides H Barros**
- **Pedro Henrique do Santos**
- **Guilherme Henrique M. G. Santana**

Desenvolvedores do projeto *Sistema de Tombamento*.
