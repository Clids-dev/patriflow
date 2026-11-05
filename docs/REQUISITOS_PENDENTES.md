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
- Transferência (decisão do professor): pode ir de **qualquer setor para qualquer setor**; não precisa
  passar pelo almoxarifado.
- Dupla confirmação (decisão do professor): a transferência só se efetiva quando o **responsável do setor de
  origem** libera o bem e o **responsável do setor de destino** confirma o recebimento, com foto.
- Almoxarifado: é **notificado** de toda transferência e pode **intervir** (suspender ou cancelar) quando algo
  estiver fora dos conformes. Intervenção exige motivo.
- Setor de patrimônio movimenta direto (sem aprovação) e mantém a intervenção do almoxarifado.
- Cadastro público cria conta **inativa** até o setor de patrimônio aprovar.
- Não existe rota de correção de movimentação (PUT removido). Correção é nova movimentação.
- Perfil `auditor` (somente leitura) foi criado (migração W05) e foi aceito pelo professor.
- Commits: um commit por mudança sensível, não um commit gigante.
- Documentação (README e tutorial mobile) foi atualizada para os perfis e regras W04.

## 1. Estado atual do repositório (resumo)

- Backend: 40 testes passando (`venv/bin/python -m pytest`).
- Concluído nesta análise: W03 (6/6), tratamento de tombo duplicado (409), próximo tombo
  por maior sequência (sem reaproveitar número de bem baixado).
- Sem nenhuma implementação: W04 (etiqueta QR), W05 (fotos), W07 (inventário),
  W08 (sincronização em lote), A03, A04, A06, A07, A10, A11, A12.
- Parcial: W06, W09, W10, A02, A04, A05, A08, A09 (app: transferências, leitura por QR, ficha e importação).

**Atenção à numeração:** o repositório usa W04 = "almoxarifado e autorização" e W05 =
"aprovação de cadastros e perfil auditor" (migrações `20261104_*`). O quadro usa W04 = etiqueta
QR e W05 = fotos. Confirmar com o professor qual lista vale antes de planejar.

---

## 2. Conflitos entre o quadro e as decisões do repositório

| # | Tema | Quadro diz | Repositório decidiu | Ação sugerida |
|---|------|-----------|---------------------|---------------|
| C1 | Perfis | Três perfis (patrimônio, agente, responsável) | Quatro: também `auditor` | **Decidido:** auditor mantido (aceito pelo professor) |
| C2 | Transferência (W06/A08) | Origem e destino livres | Só almoxarifado ↔ setor do usuário | **Decidido:** origem e destino livres (qualquer setor); implementar na API e no app |
| C3 | Quem aceita (W06/A09) | Qualquer usuário autorizado do destino | Só responsável do almoxarifado e patrimônio | **Decidido:** dupla confirmação (responsável da origem libera; responsável do destino recebe); almoxarifado notificado e pode intervir |
| C4 | Aceite com foto (W06/A09) | Foto obrigatória | Foto obrigatória no aceite (implementada) | Resolvido: foto no recebimento do destino |
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

### W06 · Transferência com dupla confirmação — `[x]` 10/10 (API, app e web)
Regra (decidida com o professor): origem e destino livres. Um colaborador do setor de destino solicita;
o responsável do setor de origem libera; o responsável do setor de destino confirma o recebimento com foto;
o almoxarifado é notificado de toda transferência e pode intervir com motivo.
- [x] Estados: pendente (aguarda liberação), liberada (aguarda recebimento), aprovada, recusada, cancelada
- [x] Enquanto a transferência não é concluída, o bem continua na origem (localização só muda em "aprovada")
- [x] Solicitação exige motivo e não pode repetir uma transferência já aberta para o mesmo bem
- [x] Pendentes são listadas para quem decide, com a etapa ("liberar" ou "receber")
- [x] Confirmação de recebimento exige a foto (tipo `aceite_transferencia`)
- [x] Recusa, em qualquer etapa, exige o motivo; o motivo fica gravado (`motivo_decisao`) para quem solicitou
- [x] Almoxarifado acompanha todas as transferências abertas (`GET /movimentacao/acompanhamento`)
- [x] Intervenção do almoxarifado cancela uma transferência aberta, com motivo (`POST /movimentacao/{id}/intervir`)
- [x] Transferências sem resposta além do prazo são escaladas ao setor de patrimônio
- [x] Transferências antigas (fluxo "simples") continuam com a regra anterior
- [x] Web: solicitação de qualquer bem, liberação, confirmação com foto, acompanhamento e intervenção
- [x] App: solicitação de qualquer bem (e a partir da ficha), liberação, confirmação com foto e intervenção

Migração: `database/migrations/20261110_transferencia_dupla_confirmacao.sql`.
Testes: `test_transferencia_dupla.py`, e os testes antigos ajustados para o fluxo "simples".

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

Estado do app (atualizado): versão **online**, com menu e barra inferior no padrão da web. Já existem
câmera para leitura de etiqueta (`mobile_scanner`, só QR Code), busca por tombo, ficha do bem, transferências
com motivo, foto na autorização e recusa com motivo, baixa com motivo e documento, importação CSV, etiquetas
(individual e em lote), termo de responsabilidade e o menu do agente sem itens sem função. Ainda **não há**
armazenamento local, fila offline nem conferência no app (A03, A06, A11, A12).

Branches com esse trabalho: `feat/app-regras-transferencia` (já na `main`), `feat/app-importacao-etiquetas-termo`
e `feat/app-leitura-qr-ficha` (ainda não mescladas na `main`).

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

### A04 · Leitura da etiqueta pela câmera e digitação do tombo — `[~]` 3/6
- [x] Câmera abre na tela de leitura e decodifica o QR sem confirmação (atalho central da barra inferior)
- [x] Tombo lido busca o bem pela API (`/bem/buscar`) e abre a ficha
- [x] Campo de digitação manual na mesma tela da câmera
- [~] Tombo digitado com DV inválido: a API recusa e o app mostra a mensagem, mas a checagem ainda não é feita no aparelho, antes da busca
- [ ] Tombo válido fora do acervo oferece registrar como bem não cadastrado (depende de A07)
- [ ] Leitura e busca funcionam sem internet (depende de A03)

### A05 · Ficha do bem e histórico no aplicativo — `[~]` 4/7 completos
- [x] Ficha mostra tombo, nome, categoria, marca, modelo, série, estado, setor, localização, responsável, garantia e depreciação/valor contábil
- [~] Foto mais recente aparece na ficha: falta a API listar fotos por bem (hoje as fotos são por registro)
- [ ] Ações de conferir, transferir, emprestar e enviar para manutenção partem da ficha (a ficha é somente leitura)
- [~] Histórico vem da API em ordem, com data, autor e tipo; falta a foto em cada evento
- [x] Nenhum evento pode ser editado ou apagado pelo app
- [ ] Sem rede, ficha e histórico baixados continuam abrindo (depende de A03)

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

### A08 · Solicitar a transferência de um bem — `[~]` 5/6
- [x] Solicitação exige setor de destino e motivo
- [x] Tela deixa claro que o bem continua na origem enquanto SOLICITADA (etapa "Aguarda liberação")
- [x] Solicitação vai à API (almoxarifado ↔ setor, ver C2)
- [x] Agente vê a lista das transferências que solicitou, com estado e motivo da decisão
- [ ] Solicitação sem rede entra na fila e aparece como pendente de envio (depende de A12)
- [x] Transferência já solicitada não pode ser solicitada de novo (API recusa com 409)

Obs.: a solicitação é feita a partir de "Minhas solicitações", do Início e da ficha do bem.

### A09 · Aceitar ou recusar a transferência, com foto — `[~]` 5/6 (liberação pela origem e confirmação com foto pelo destino)
- [x] Lista de pendentes vem da API (aba Autorizações e Movimentações > Pendentes)
- [x] Aceite exige foto do recebimento (câmera ou galeria, enviada antes da autorização)
- [x] Aceita, o bem passa ao destino
- [x] Recusa exige motivo, que fica visível para quem solicitou
- [ ] Aceite ou recusa sem rede entra na fila (depende de A12)
- [x] Respondida, sai da lista de pendentes e aparece em "Minhas solicitações" e no histórico do bem

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

---

## 7. Recomendações adicionais — andamento

Concluídas (ver seção 8 para o detalhamento):
- [x] Remover a exclusão de movimentações (histórico só recebe lançamentos)
- [x] Auditoria de criação, edição, baixa e reativação de bens
- [x] Baixa e reativação registram o usuário
- [x] Depreciação linear com valor contábil na ficha
- [x] Garantia do bem e alerta de garantia vencida ou a vencer
- [x] Termo de responsabilidade por responsável
- [x] Importação de bens por CSV, com simulação e relatório por linha

Feitos nesta etapa: REQ-EX-01 (alçada na baixa), REQ-EX-02 (bloqueio de login), REQ-EX-03 (backup e restauração testada). Parciais: REQ-EX-02 e REQ-EX-04. Pendentes: demais itens da seção 8.


---

## 8. Requisitos extras (pendentes)

Origem: recomendações de funções e regras de negócio para uso de sistemas de patrimônio em
empresas e órgãos públicos. Não fazem parte do quadro da disciplina. Cada item traz a
descrição e os critérios de aceite. Prioridade: P1 (fazer antes), P2 (médio prazo), P3 (opcional).

### REQ-EX-01 · Alçada por valor na baixa — P1
Baixa de bem acima de um valor configurável (ex.: R$ 5.000) só se efetiva após aprovação de um
segundo usuário do setor de patrimônio.
- [x] Valor limite configurável pelo setor de patrimônio
- [x] Baixa acima do limite fica "aguardando aprovação"; não altera o bem até aprovada
- [x] Quem solicita não pode aprovar a própria baixa
- [x] Aprovação e recusa entram na auditoria

### REQ-EX-02 · Segurança de acesso: senha e sessão — P1
Estado: bloqueio e registro de acessos feitos. Pendentes: recuperação de senha por e-mail (precisa de serviço de e-mail) e expiração por inatividade no app (depende da fila offline, A12).
Recuperação de senha, bloqueio após tentativas erradas e expiração de sessão no login web e no app.
- [ ] Recuperação de senha por link de uso único com validade curta
- [x] Conta bloqueada temporariamente após N tentativas erradas, com aviso claro
- [ ] Sessão expira por inatividade; app pede login de novo sem perder a fila offline
- [x] Tentativas de login (sucesso e falha) registradas, sem guardar a senha

### REQ-EX-03 · Backup e restauração — P1
Cópia automática do banco e da pasta de fotos, com teste de restauração.
- [x] Backup diário do banco (pg_dump) e da pasta de fotos, com retenção definida
- [x] Script de restauração documentado
- [x] Teste de restauração feito em banco separado e registrado

### REQ-EX-04 · Card de alertas no dashboard — P1
Estado: parcial. O painel já mostra garantias vencendo e transferências para autorizar (com escaladas). Falta "bens sem conferência há muito tempo", que depende da conferência em campo.
Painel com os alertas que pedem ação: garantias vencendo, transferências paradas, bens sem conferência há muito tempo.
- [ ] Card lista os alertas com a contagem e link para a tela correspondente
- [ ] Dados vêm de endpoints já existentes ou novos, sem cálculo no navegador

### REQ-EX-05 · Ciclo de vida completo da baixa — P2
Venda, doação, sinistro, extravio e descarte, cada um com documento próprio.
- [ ] Motivo da baixa obrigatório, com lista fechada de destinos
- [ ] Documento obrigatório conforme o destino (ex.: boletim de ocorrência para extravio e sinistro)
- [ ] Bem baixado sai das listagens ativas e do inventário, mas continua no histórico

### REQ-EX-06 · Anexos em PDF nos cadastros — P2
Nota fiscal, laudo técnico e outros documentos anexados ao bem.
- [ ] Upload de PDF até 10 MB, com verificação do conteúdo (não só da extensão)
- [ ] Anexos não são apagados nem substituídos; correção é anexo novo
- [ ] Download pela API e exibição na ficha do bem

### REQ-EX-07 · Inventário cíclico e indicadores — P2
Contagem rotativa por setor, sem parar todo o acervo, e indicadores no painel.
- [ ] Ciclo de inventário por setor com período e responsável definidos
- [ ] Indicadores: percentual conferido por setor, divergências abertas, idade média do acervo, valor sob guarda por responsável
- [ ] Indicadores calculados no servidor

### REQ-EX-08 · Fornecedor, ordem de compra e centro de custo — P2
Vincular o bem a quem vendeu, à ordem de compra e ao centro de custo.
- [ ] Cadastro de fornecedor (CNPJ/CPF validado)
- [ ] Bem guarda fornecedor, número da ordem de compra e centro de custo
- [ ] Relatório de custo por centro de custo

### REQ-EX-09 · Notificações — P2
Avisos por e-mail ou push para pendências e alertas.
- [ ] Notificação para o responsável quando há transferência a aceitar
- [ ] Resumo diário de alertas para o setor de patrimônio
- [ ] Usuário escolhe o canal; envio registrado

### REQ-EX-10 · Exportação para contabilidade e fiscal (CIAP) — P3
Exportar bens e valores no formato usado pela contabilidade e pelo crédito de ICMS sobre o ativo imobilizado.
- [ ] Exportação com valor de aquisição, data de entrada, depreciação e valor contábil
- [ ] Layout definido junto com a contabilidade antes de implementar

### REQ-EX-11 · Chave de API para integrações — P3
Integrações com outros sistemas usam chave própria, separada da sessão do usuário.
- [ ] Chave criada e revogada pelo setor de patrimônio, com nome e validade
- [ ] Chave só aparece uma vez na criação; no banco fica apenas o hash
- [ ] Permissões da chave são limitadas por escopo

### REQ-EX-12 · Leitura de código de barras/QR nos setores e salas — P3
Confirmar a localização física lendo a etiqueta da sala ou do setor.
- [ ] Etiqueta de sala e de setor gerada no mesmo modelo das etiquetas de bens
- [ ] App lê a etiqueta e confirma o local antes de conferir bens
