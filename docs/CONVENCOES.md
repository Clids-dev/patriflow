# Convenções do projeto

Este documento define como nomear arquivos, pastas e identificadores e em que idioma escrever cada coisa.
Quando houver dúvida, siga o que está aqui; se a regra precisar mudar, altere este arquivo no mesmo commit.

## 1. Idioma

| Onde | Idioma | Exemplos |
|---|---|---|
| Conceitos do domínio (patrimônio) | Português | `bem`, `setor`, `responsavel`, `localizacao`, `movimentacao`, `tombo`, `baixa` |
| Papéis técnicos e infraestrutura | Inglês | `router`, `service`, `repository`, `schemas`, `config`, `migrations`, `tests` |
| Documentação, comentários e textos da interface | Português (pt-BR) | README, docs, mensagens ao usuário, rótulos das telas |
| Mensagens de commit e de pull request | Português | `feat(bens): depreciação linear` |

**Por que essa divisão:** o projeto modela um domínio brasileiro e o usuário final fala português. Traduzir
`bem` para `asset` criaria uma distância entre o código e o banco, as telas e o vocabulário da equipe.
Já os nomes técnicos seguem o padrão de mercado, para que qualquer pessoa da área os reconheça.

## 2. Arquivos e pastas

- Minúsculas, `snake_case`, sem acento, sem espaço.
- Pasta de domínio em `modules/<dominio>/` com os mesmos arquivos em todos: `router.py`, `service.py`,
  `repository.py`, `schemas.py` e, quando houver, `queries.py`.
- Documentação em `docs/`, exceto o `README.md` da raiz e o de `mobile/`.
- Scripts de banco em `database/`: `schema.sql` para a criação inicial e `migrations/` para alterações.

## 3. Migrations

- Nome: `AAAAMMDD_descricao_curta.sql`, por exemplo `20261115_historico_localizacao.sql`.
- Use a data em que a migration foi criada. Ordem é dada pelo nome.
- Não use códigos internos de requisito no nome (`w04`, `req-ex-03` etc.). Esses códigos só fazem sentido
  para quem usa o quadro da disciplina.
- **Nunca renomeie uma migration já aplicada em algum banco.** Os nomes antigos com `w0X` permanecem por esse
  motivo.
- Cada migration deve ser idempotente quando possível (`IF NOT EXISTS`, `CREATE OR REPLACE`).

## 4. Testes

- Todos ficam em `tests/`, com nome `test_<assunto>.py`.
- A suíte roda com `pytest` na raiz do projeto; a configuração está em `pytest.ini`.
- Teste novo não deve ser ignorado pelo `.gitignore`. Se o arquivo não aparecer em `git status`, verifique a regra.

## 5. Commits

- Formato: `tipo(escopo): descrição no imperativo`, com `feat`, `fix`, `docs`, `chore`, `refactor` ou `test`.
- Descreva a mudança em linguagem comum. Não use códigos de requisito na mensagem.
- Uma mudança sensível por commit. Migrations, alterações de regra de negócio e remoções ficam em commits
  separados.

## 6. Exceções conhecidas (legado)

- `modules/bem` e `tests/test_bem_regras.py` / `tests/test_business_rules.py` cobrem o mesmo assunto com nomes
  diferentes. Não renomear sem revisar o conteúdo.
- Migrations com `w0X` no nome, mantidas por causa da regra da seção 3.
