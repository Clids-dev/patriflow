# Requisitos pendentes — PatriFlow (MOBILE - 2026.2)

Fonte: quadro Kanban da disciplina, projeto `681c6118-c4f3-457e-b954-ee02e9911442`
(kanban.repsys.com.br). Capturado em 05/11/2026, cruzado com o código do repositório.

Legenda: `[x]` atendido · `[~]` parcial ou a verificar · `[ ]` pendente

Este documento lista só o que está pendente (cards do Backlog e o card "Fazendo").
Os cards "Entregue" (W01, W02, A01) estão no fim, para referência.

---

## 0. Decisões de regra de negócio já tomadas (repositório)

Estas decisões vêm das respostas do `PERGUNTAS_W04.txt` e do README, e **valem sobre o quadro**
quando houver conflito. Ver seção 2.

- Almoxarifado único (`flag_almoxarifado`). Bem novo entra sempre pelo almoxarifado.
- Movimentação: o setor de patrimônio movimenta direto. Demais perfis só solicitam entre o
  almoxarifado e o próprio setor. A solicitação fica `pendente`.
- Quem autoriza: responsável do almoxarifado e setor de patrimônio.
- O app mostra Autorizar/Recusar só para o responsável do almoxarifado.
- Cadastro público cria conta **inativa** até o setor de patrimônio aprovar.
- Não existe rota de correção de movimentação (PUT removido). Correção é nova movimentação.
- Perfil `auditor` (somente leitura) foi criado (migração W05).
- Commits: um commit por mudança sensível, não um commit gigante.
- Documentação (README e tutorial mobile) foi atualizada para os perfis e regras W04.

## 1. Estado atual do repositório (resumo)

- Backend: 40 testes passando (`venv/bin/python -m pytest`).
- Concluído nesta análise: W03 (6/6), tratamento de tombo duplicado (409), próximo tombo
  por maior sequência (sem reaproveitar número de bem baixado).
- Sem nenhuma implementação: W04 (etiqueta QR), W05 (fotos), W07 (inventário),
  W08 (sincronização em lote), A03, A04, A06, A07, A10, A11, A12.
- Parcial: W06, W09, W10, A02, A05, A08, A09.

**Atenção à numeração:** o repositório usa W04 = "almoxarifado e autorização" e W05 =
"aprovação de cadastros e perfil auditor" (migrações `20261104_*`). O quadro usa W04 = etiqueta
QR e W05 = fotos. Confirmar com o professor qual lista vale antes de planejar.

---

## 2. Conflitos entre o quadro e as decisões do repositório

| # | Tema | Quadro diz | Repositório decidiu | Ação sugerida |
|---|------|-----------|---------------------|---------------|
| C1 | Perfis | Três perfis (patrimônio, agente, responsável) | Quatro: também `auditor` | Confirmar com professor; manter se aceito |
| C2 | Transferência (W06/A08) | Origem e destino livres | Só almoxarifado ↔ setor do usuário | Decidir qual modelo vale; afeta W06, A08, A09 |
| C3 | Quem aceita (W06/A09) | Qualquer usuário autorizado do destino | Só responsável do almoxarifado e patrimônio | Idem C2 |
| C4 | Aceite com foto (W06/A09) | Foto obrigatória | Sem foto | Implementar junto com W05 |
| C5 | Auditor | Não citado | Perfil de leitura | Manter e documentar |

---

## 3. Backlog — WEB (setor de patrimônio)

### W03 · Ficha completa do bem, dígito verificador e localização — `[x]` 6/6
- [x] Bem ganha marca, modelo, número de série, nota fiscal, data de entrada e estado de conservação
- [x] Estado aceita novo, bom, regular, ruim ou inservível e nasce preenchido
- [x] Dígito verificador módulo 11, documentado no README
- [x] API rejeita tombo com DV inválido com a mensagem "Número de tombo inválido — verifique a digitação"
- [x] Tombo imutável (trigger); tombo de bem baixado não é reaproveitado (índice único + sem exclusão + próximo número pelo maior usado)
- [x] Cadastro de prédio, andar e sala; setor aponta para a sala

### W04 · Etiqueta com QR Code e consulta por tombo — `[x]` 6/6
- [x] Botão de gerar etiqueta na ficha do bem e na listagem, com seleção em lote (tela de equipamentos)
- [x] QR Code codifica o tombo com dígito verificador (biblioteca `segno`, zona de silêncio de 4 módulos)
- [x] Etiqueta mostra o tombo em texto legível abaixo do QR e pode ser reimpressa (gerada sob demanda, nada guardado)
- [x] Geração em lote produz uma folha com várias etiquetas, pronta para impressão (`GET /api/v1/etiquetas/lote?ids=`)
- [x] API busca o bem pelo tombo e devolve a ficha completa: setor atual, localização e responsável (`/api/v1/bem/buscar`)
- [x] Busca por tombo valida o dígito verificador antes de consultar o banco

Verificação: QR de etiquetas de exemplo lidos de volta com `zxing-cpp` (tombo correto); `test_etiquetas.py`.

### W05 · Fotos: envio, guarda e entrega — `[~]` 4/6 (API pronta)
- [x] API recebe foto (`POST /api/v1/fotos/`) e guarda o arquivo no servidor (`FOTOS_DIR`)
- [x] Autor e data/hora são marcados pelo servidor (`enviado_por`, `enviado_em` com `NOW()`)
- [~] Foto fica vinculada a `conferencia`, `aceite_transferencia` ou `bem_nao_cadastrado` pelo tipo e id do registro. Os registros ainda não existem na API; a validação de existência entra junto com eles
- [x] Limite de tamanho (5 MB, `PATRIFLOW_FOTO_MAX_BYTES`) e formatos JPEG/PNG/WebP (checados pelo conteúdo), com mensagem clara (413/415)
- [ ] Foto é entregue pela API (`GET /api/v1/fotos/{id}` pronto) e aparece na tela web do registro. A tela depende das telas de conferência, aceite e bem não cadastrado
- [x] Foto nunca é apagada nem substituída: trigger no banco bloqueia UPDATE e DELETE

Migração: `database/migrations/20261105_w05_fotos.sql` (executar uma vez no banco de desenvolvimento).
Testes: `test_fotos.py`.

### W06 · Transferência com dupla confirmação — `[~]` parcial
- [~] Estados: existem `pendente`, `aprovada` e `recusada` (quadro pede SOLICITADA, EFETIVADA, RECUSADA). Solicitação exige destino; motivo a verificar
- [x] Enquanto pendente, o bem continua contabilizado na origem (checagem `local_mudou` na decisão)
- [~] API lista pendentes, mas `/movimentacao/pendentes` não filtra pelo usuário logado
- [ ] Aceite exige foto do recebimento (depende de W05)
- [~] Aceite: hoje só patrimônio e responsável do almoxarifado; o quadro diz qualquer usuário do destino (ver C3)
- [ ] Transferência sem resposta após prazo configurável é escalada ao patrimônio
- [~] Nada apagado: `DELETE /movimentacao/` existe (restrito ao patrimônio). Ver W09

### W07 · Inventário: abertura, congelamento e fechamento — `[ ]` 0/7
- [ ] Abertura define período e setores
- [ ] Abertura congela a lista esperada por setor (não muda com movimentações depois)
- [ ] API entrega a lista congelada ao app e recebe a conferência de volta
- [ ] Não é possível abrir dois inventários para o mesmo setor ao mesmo tempo
- [ ] Fechamento classifica cada bem em: localizado, localizado em outro setor, não localizado, não cadastrado
- [ ] Inventário não fecha enquanto houver bem sem situação
- [ ] Localizado em outro setor abre transferência; não localizado e não cadastrado viram pendência

Obs.: o PDF "Relatório de Inventário de Bens" existe, mas é só exportação do acervo.

### W08 · Sincronização em lote, com conflito sinalizado — `[ ]` 0/6
- [ ] API recebe lote de operações numa única chamada
- [ ] Resposta diz, por operação, se foi aceita, recusada ou está em conflito
- [ ] Cada operação tem identificador do aparelho; reenvio não grava duas vezes (idempotência)
- [ ] Operações são aplicadas na ordem de criação
- [ ] Conflito fica registrado e vai para o patrimônio decidir
- [ ] Nenhuma operação é descartada em silêncio; API registra data/hora de cada sincronização

### W09 · Trilha de auditoria, baixa, empréstimo e manutenção — `[~]` parcial
- [~] Histórico do bem é linha do tempo de eventos (hoje só movimentações: `/movimentacao/bem/{codigo}`)
- [ ] Cadastro, conferência, transferência, empréstimo, manutenção, inventário e baixa entram na trilha
- [ ] Nenhum evento pode ser editado ou apagado. `DELETE /movimentacao/` existe e contradiz este item
- [ ] Empréstimo: quem levou, motivo, data de saída, devolução prevista, atraso sinalizado, guarda na origem
- [~] Manutenção: status "Manutenção" bloqueia movimentação; falta registrar envio e retorno com serviço e novo estado
- [~] Baixa: `POST /bem/{id}/desativar` existe, sem motivo (doação, inservível, extravio), justificativa nem documento
- [~] API entrega histórico completo do bem (só movimentações)

### W10 · Relatórios de divergência e caixa de pendências — `[~]` parcial
- [ ] Relatório de bens por responsável com valor total sob a guarda
- [ ] Relatório de bens por estado de conservação com quantidade e percentual
- [ ] Relatório de divergências do inventário (depende de W07)
- [ ] Filtros por setor, período, categoria e estado; exportação XLSX e PDF (hoje `/relatorio/exportar` só tem categoria, setor e status)
- [~] Caixa de pendências: hoje só movimentações pendentes (`/movimentacao/pendentes`). Falta bem não cadastrado, conflito de sincronização e bem não localizado
- [ ] Cada pendência mostra origem, autor, data e foto, e tem ação que a encerra
- [ ] Pendência encerrada sai da caixa e fica no histórico do bem

---

## 4. Backlog — APP (agente de campo, responsável de setor)

Estado do app: versão administrativa **online**. Não há armazenamento local, fila offline,
câmera nem leitor de QR (`mobile/pubspec.yaml`: só `http`, `shared_preferences`,
`flutter_secure_storage`, `share_plus`).

**Problema de apresentação:** no menu do agente, "Leitura", "Conferência" e "Inventário" abrem a
lista genérica de bens (`mobile/lib/features/home/home_placeholder_page.dart`, `HomeTab.bens`), e
"Sincronização" abre uma tela vazia de Relatórios. Itens sem função real.

### A02 · Login e sessão no aplicativo — `[~]` 5/6 (card em "Fazendo")
- [x] Tela de login envia usuário e senha à API e recebe o token
- [x] Token guardado no aparelho (armazenamento seguro) e enviado em toda chamada
- [x] Credencial errada mostra mensagem sem dizer se foi usuário ou senha
- [x] Reabrir o app com token válido não pede login (splash com `/auth/me`)
- [x] Menu montado pelo perfil devolvido pela API
- [~] Token vencido avisa e volta ao login, mas a fila de sincronização ainda não existe (depende de A12)

### A03 · Baixar o acervo do setor para o aparelho — `[ ]` 0/6
- [ ] Agente escolhe o setor e o app baixa bens com ficha completa
- [ ] Categorias, localizações e foto de referência vêm junto e ficam no banco local
- [ ] Tela mostra data/hora do último download e quantidade de bens
- [ ] Acervo consultável sem internet
- [ ] Baixar de novo não apaga a fila de sincronização
- [ ] Falha no download avisa e mantém o acervo anterior

### A04 · Leitura da etiqueta pela câmera e digitação do tombo — `[ ]` 0/6
- [ ] Câmera abre na tela de leitura e decodifica o QR sem confirmação
- [ ] Tombo lido busca o bem no banco local e abre a ficha
- [ ] Campo de digitação manual na mesma tela da câmera
- [ ] Tombo digitado com DV inválido avisa antes de buscar
- [ ] Tombo válido fora do acervo oferece registrar como bem não cadastrado
- [ ] Leitura e busca funcionam sem internet

### A05 · Ficha do bem e histórico no aplicativo — `[~]` 0/6 completos
- [~] Detalhe online (tela admin de ativos) mostra nome, tombo e status
- [ ] Ficha mostra tombo, descrição, categoria, marca, modelo, série, estado, setor, localização e responsável
- [ ] Foto mais recente aparece na ficha
- [ ] Ações de conferir, transferir, emprestar e enviar para manutenção partem da ficha
- [ ] Histórico vem da API em ordem, com data, autor, tipo e foto
- [ ] Nenhum evento pode ser editado ou apagado pelo app
- [ ] Sem rede, ficha e histórico baixados continuam abrindo, com data de atualização

### A06 · Conferência do bem, com foto — `[ ]` 0/6
- [ ] Tela mostra dados do bem e estado de conservação cadastrado
- [ ] Agente confirma presença e escolhe novo estado
- [ ] Foto é obrigatória para salvar
- [ ] Mudança de estado é destacada antes de salvar
- [ ] Conferência gravada no banco local e na fila, sem rede
- [ ] Sincronizada, chega à API com foto e aparece no histórico

### A07 · Bem localizado não cadastrado — `[ ]` 0/6
- [ ] Acessível a partir da leitura que não achou o tombo e pelo menu
- [ ] Formulário exige descrição, local (setor e sala) e foto
- [ ] Gravado no banco local e na fila, sem rede
- [ ] App mostra os registros ainda não sincronizados
- [ ] Sincronizado, chega com foto e aparece na caixa de pendências do patrimônio
- [ ] Continua aberto até o patrimônio tratar

### A08 · Solicitar a transferência de um bem — `[ ]` 0/6 (parcial no backend)
- [ ] Solicitação parte da ficha do bem e exige setor de destino e motivo
- [ ] Tela deixa claro que o bem continua na origem enquanto SOLICITADA
- [~] Solicitação vai à API (`POST /movimentacao/` existe, mas só almoxarifado ↔ setor, ver C2)
- [ ] Agente vê a lista das transferências que solicitou, com estado
- [ ] Solicitação sem rede entra na fila e aparece como pendente de envio
- [ ] Transferência já solicitada não pode ser solicitada de novo

Obs.: o diálogo "Nova transferência" existe em `movements_screen.dart`, mas só é acessível pelo
painel do setor de patrimônio. Não há ação de solicitar na tela de movimentações do agente.

### A09 · Aceitar ou recusar a transferência, com foto — `[~]` 0/6 completos
- [~] Lista de pendentes vem da API (tela do responsável com Autorizar/Recusar, pedindo confirmação)
- [ ] Aceite exige foto do recebimento
- [~] Aceita, guarda passa ao destino (existe via aprovar; sem foto)
- [~] Recusa exige justificativa (a verificar)
- [ ] Aceite ou recusa sem rede entra na fila
- [ ] Respondida, sai da lista e fica no histórico

### A10 · Empréstimo e manutenção pelo aplicativo — `[ ]` 0/7
- [ ] Empréstimo exige quem levou, motivo, data de saída e devolução prevista
- [ ] Devolução registra data efetiva e volta o status normal
- [ ] Empréstimo vencido aparece destacado na lista do agente
- [ ] Envio para manutenção exige descrição, data e destino
- [ ] Retorno registra serviço, data e novo estado de conservação
- [ ] Emprestado e em manutenção continuam na guarda da origem
- [ ] Os quatro registros vão à API e aparecem no histórico

### A11 · Execução do inventário, offline — `[ ]` 0/7
- [ ] Agente escolhe o inventário aberto do setor e o app carrega a lista congelada
- [ ] Contadores de esperados, encontrados, faltantes e excedentes atualizados a cada leitura
- [ ] Comparação calculada no aparelho, sem rede
- [ ] Bem de outro setor lido entra como excedente, com setor de origem
- [ ] Lista do que falta consultável, com descrição e foto
- [ ] Cada bem lido é conferido com estado e foto
- [ ] Tudo lido entra na fila e é enviado na sincronização

### A12 · Fila de sincronização e status da conexão — `[ ]` 0/7
- [ ] Status online/offline visível em todas as telas de campo
- [ ] Quantidade de operações na fila e data da última sincronização à vista
- [ ] Fila consultável: tipo, bem e data de cada operação
- [ ] Sincronização envia o lote na ordem de criação
- [ ] Resultado de cada operação mostrado: enviada, recusada com motivo, ou em conflito
- [ ] Recusada ou em conflito permanece visível; fila só esvazia do que o servidor confirmou
- [ ] Reenvio após interrupção não duplica registros

---

## 5. Ordem sugerida (dependências)

1. **W05 (fotos)**: base para C4, A06, A07, A09 e W06.
2. **W08 (sincronização em lote)** e **A03 + A12 (armazenamento local e fila)**: base para todo o trabalho offline.
3. **W04 (etiqueta QR)** e **A04 (leitura)**: dependem do W03, que já está pronto.
4. **W07 (inventário)** → **A11**, e **W10** (relatório de divergências).
5. **W09** (trilha, empréstimo, manutenção, baixa) → **A10**.
6. **W06 / A08 / A09** após decidir C2 e C3.
7. **A05, A07** e o restante do app.

Antes de começar: resolver C1 a C3 com o professor e confirmar a numeração de W04 e W05 (seção 1).

---

## 6. Já entregue (referência)

- W01 · O que o PatriFlow já entrega — 13/13
- W02 · Autenticação da API e os três perfis — 6/6
- A01 · Casca do aplicativo, navegação e endereço do servidor — 6/6
