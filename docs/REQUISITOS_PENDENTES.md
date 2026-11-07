# Requisitos pendentes — PatriFlow (MOBILE - 2026.2)

Fonte: quadro Kanban da disciplina, projeto `681c6118-c4f3-457e-b954-ee02e9911442`
(kanban.repsys.com.br). Capturado em 05/11/2026, cruzado com o código do repositório.
Atualizado em 07/11/2026 com as entregas de inventário, sincronização, histórico e trabalho offline.

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
- Documentação (README e tutorial mobile) foi atualizada para os perfis e regras W04. O tutorial mobile
  genérico foi removido do repositório; o README segue como documento principal.
- Bens sem localização (antes das novas regras): criar a entrada no almoxarifado usando a data de entrada
  cadastrada em cada bem. O setor de destino de cada bem é escolhido manualmente pelo responsável.
  **Pendente:** a planilha `ATRIBUICAO_SETORES_W04.txt` (13 bens, setores em branco) foi removida; a lista
  pode ser gerada novamente pelo banco quando a tarefa for feita.
- Setores duplicados no banco de desenvolvimento ("Produção" repetido e "Produçãi"): recriar os setores e
  apagar os que têm nome errado. **Pendente:** confirmar os ids antes de executar.

## 1. Estado atual do repositório (resumo)

- Testes: 206 no backend (`venv/bin/python -m pytest`, incluindo integração num banco próprio, recriado
  a cada teste) e 17 no aplicativo (`flutter test`).
- Banco: migrations aplicadas por `tools/migrar.py`, que registra o que já rodou em cada banco.
- Completos: W03, W04, W05, W06, W07, W08, W09; A02, A03, A12.
- Parciais: W10 (faltam relatórios por responsável e por estado, e filtros/exportação), A04, A05, A08, A09, A10.
- Sem implementação no app: A06, A07, A11. A API de cada um já existe (conferência, bem não cadastrado
  e inventário via `/inventarios` e `/sincronizacao`); falta a tela.

**Numeração (decidida):** o progresso é reportado pela numeração do quadro da disciplina (W04 = etiqueta
QR e consulta por tombo; W05 = fotos). Os códigos internos antigos do repositório deixam de ser usados como
número de requisito e passam a ser descritos por nome: "autorização de movimentações" (antigo W04 interno,
migração `20261104_almoxarifado_autorizacao`) e "aprovação de cadastros e perfil auditor" (antigo W05
interno, migração `20261104_usuarios_aprovacao_auditor`). A migração `20261105_fotos` é o W05 do quadro.

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

### W05 · Fotos: envio, guarda e entrega — `[x]` 6/6
- [x] API recebe foto (`POST /api/v1/fotos/`) e guarda o arquivo no servidor (`FOTOS_DIR`)
- [x] Autor e data/hora são marcados pelo servidor (`enviado_por`, `enviado_em` com `NOW()`)
- [x] Foto fica vinculada a `conferencia`, `aceite_transferencia` ou `bem_nao_cadastrado` pelo tipo e id do registro,
  e a API recusa (404) foto de registro que não existe, sem deixar arquivo órfão no disco
- [x] Limite de tamanho (5 MB, `PATRIFLOW_FOTO_MAX_BYTES`) e formatos JPEG/PNG/WebP (checados pelo conteúdo), com mensagem clara (413/415)
- [x] Foto é entregue pela API (`GET /api/v1/fotos/{id}`) e aparece na web: linha do tempo do bem (recebimento e
  conferência) e caixa de pendências (bem não cadastrado)
- [x] Foto nunca é apagada nem substituída: trigger no banco bloqueia UPDATE e DELETE

Migração: `database/migrations/20261105_fotos.sql`. Testes: `test_fotos.py`, `test_inventario.py`.

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

### W07 · Inventário: abertura, congelamento e fechamento — `[x]` 7/7
- [x] Abertura define período e setores (`POST /inventarios`, só o setor de patrimônio)
- [x] Abertura congela a lista esperada por setor; movimentações depois não a alteram (cópia em `inventario_itens`)
- [x] API entrega a lista congelada (`GET /inventarios/{id}/itens`) e recebe a conferência pelo tombo
  (`POST /inventarios/{id}/conferencias`, também por `/sincronizacao`); releitura não duplica
- [x] Não é possível abrir dois inventários para o mesmo setor ao mesmo tempo (índice único, com teste de concorrência)
- [x] Fechamento classifica cada bem: localizado, localizado em outro setor, não localizado, não cadastrado
- [x] Inventário não fecha enquanto houver bem sem situação; "encerrar contagem do setor" marca os faltantes
- [x] Localizado em outro setor abre transferência com dupla confirmação; não localizado (sem ausência justificada
  por empréstimo ou manutenção) e não cadastrado viram pendência

Web: tela Inventários, pronta para leitor de etiquetas. Fechado, o inventário não muda mais (trigger).
Migração: `20261112_inventario_pendencias.sql`. Testes: `test_inventario.py`.

### W08 · Sincronização em lote, com conflito sinalizado — `[x]` 6/6
- [x] API recebe lote de operações numa única chamada (`POST /sincronizacao`, até 500)
- [x] Resposta diz, por operação, se foi aceita, recusada (com motivo) ou está em conflito
- [x] Cada operação tem identificador do aparelho; reenvio não grava duas vezes (inclusive envios simultâneos)
- [x] Operações são aplicadas na ordem de criação no aparelho
- [x] Conflito fica registrado e vai para o patrimônio decidir (caixa de pendências)
- [x] Nenhuma operação é descartada em silêncio; cada sincronização tem data/hora e contagem (`GET /sincronizacao/ultima`)

Tipos aceitos: conferência, bem não cadastrado, pedido/liberação/recebimento/recusa de transferência, empréstimo,
devolução, envio e retorno de manutenção. Migração: `20261113_sincronizacao_lote.sql`. Testes: `test_sincronizacao.py`.

### W09 · Trilha de auditoria, baixa, empréstimo e manutenção — `[x]` 7/7
- [x] Histórico do bem é linha do tempo de eventos (`GET /bem/{id}/historico`, ficha do bem na web)
- [x] Cadastro, edição, conferência, transferência, empréstimo, manutenção, inventário e baixa entram na trilha
- [x] Nenhum evento pode ser editado ou apagado: triggers impedem exclusão de transferências, baixas, empréstimos,
  manutenções e itens de inventário, e alteração da auditoria (não existe rota de exclusão de movimentação)
- [x] Empréstimo: quem levou, motivo, data de saída, devolução prevista, atraso sinalizado, guarda na origem
- [x] Manutenção: envio e retorno com serviço realizado e novo estado de conservação; bloqueia transferência e empréstimo
- [x] Baixa com motivo (lista fechada), justificativa e documento; acima da alçada, aprovação de outro servidor
- [x] API entrega o histórico completo do bem, com as fotos de cada evento

Migração: `20261111_emprestimo_manutencao_eventos_imutaveis.sql`. Testes: `test_emprestimo_manutencao.py`.

### W10 · Relatórios de divergência e caixa de pendências — `[~]` 3/7
- [ ] Relatório de bens por responsável com valor total sob a guarda
- [ ] Relatório de bens por estado de conservação com quantidade e percentual
- [x] Relatório de divergências do inventário (`GET /inventarios/{id}/itens?filtro=divergencias`, filtro na web)
- [ ] Filtros por setor, período, categoria e estado; exportação XLSX e PDF (hoje `/relatorio/exportar` só tem categoria, setor e status)
- [x] Caixa de pendências com bem não localizado, bem não cadastrado e conflito de sincronização (`/pendencias`);
  transferências pendentes e escaladas aparecem no painel "O que pede atenção"
- [x] Cada pendência mostra origem, autor, data e foto, e tem ação que a encerra (resolução obrigatória)
- [~] Pendência encerrada sai da caixa e fica registrada (filtro "Resolvidas"); ainda não aparece na linha do tempo do bem

---

## 4. Backlog — APP (agente de campo, responsável de setor)

Estado do app (atualizado em 07/11/2026): versão online com trabalho offline para o colaborador. Há banco local
(SQLite) com o acervo do setor e a fila de sincronização, indicador de conexão e da fila em todas as telas, e as
ações de guarda (empréstimo, devolução, envio e retorno de manutenção) funcionam sem rede. Ainda não há
conferência nem inventário no app (A06, A11) nem registro de bem não cadastrado (A07).

Branches do trabalho de 07/11 (empilhadas, nesta ordem): `chore/infra-banco`, `feat/historico-emprestimo-manutencao`,
`feat/inventario`, `feat/sincronizacao-lote`, `feat/app-offline`, `docs/requisitos-atualizados`.

### A02 · Login e sessão no aplicativo — `[x]` 6/6
- [x] Tela de login envia usuário e senha à API e recebe o token
- [x] Token guardado no aparelho (armazenamento seguro) e enviado em toda chamada
- [x] Credencial errada mostra mensagem sem dizer se foi usuário ou senha
- [x] Reabrir o app com token válido não pede login (splash com `/auth/me`)
- [x] Menu montado pelo perfil devolvido pela API
- [x] Token vencido avisa e volta ao login sem apagar a fila offline nem o acervo do aparelho

### A03 · Baixar o acervo do setor para o aparelho — `[x]` 6/6
- [x] Colaborador baixa o acervo do próprio setor (o patrimônio escolhe qualquer setor), com ficha completa
  (`GET /acervo/setor/{id}`, uma chamada)
- [x] Categorias, setores, localizações e foto de referência vêm junto e ficam no banco local
- [x] Tela mostra data/hora do último download e quantidade de bens
- [x] Acervo consultável sem internet (busca por nome ou tombo e ficha do bem)
- [x] Baixar de novo não apaga a fila de sincronização (tabelas separadas, com teste)
- [x] Falha no download avisa e mantém o acervo anterior (dados e fotos trocam juntos)

### A04 · Leitura da etiqueta pela câmera e digitação do tombo — `[~]` 3/6
- [x] Câmera abre na tela de leitura e decodifica o QR sem confirmação (atalho central da barra inferior)
- [x] Tombo lido busca o bem pela API (`/bem/buscar`) e abre a ficha
- [x] Campo de digitação manual na mesma tela da câmera
- [~] Tombo digitado com DV inválido: a API recusa e o app mostra a mensagem, mas a checagem ainda não é feita no aparelho, antes da busca
- [ ] Tombo válido fora do acervo oferece registrar como bem não cadastrado (depende de A07)
- [ ] Leitura e busca funcionam sem internet (depende de A03)

### A05 · Ficha do bem e histórico no aplicativo — `[~]` 4/7 completos
- [x] Ficha mostra tombo, nome, categoria, marca, modelo, série, estado, setor, localização, responsável, garantia e depreciação/valor contábil
- [~] Foto mais recente aparece na ficha offline (foto de referência do acervo); a ficha online ainda não a mostra
- [~] Ações de transferir, emprestar e enviar para manutenção partem da ficha (empréstimo e manutenção na ficha offline); conferir ainda não
- [~] Histórico vem da API em ordem, com data, autor e tipo; a API já entrega as fotos de cada evento (`/bem/{id}/historico`), falta usá-la no app
- [x] Nenhum evento pode ser editado ou apagado pelo app
- [~] Sem rede, a ficha baixada abre; o histórico ainda não é baixado

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
- [x] Solicitação vai à API (origem e destino livres, ver C2)
- [x] Agente vê a lista das transferências que solicitou, com estado e motivo da decisão
- [ ] Solicitação sem rede entra na fila: a fila e o tipo `transferencia_solicitar` já existem; falta a tela usar a fila
- [x] Transferência já solicitada não pode ser solicitada de novo (API recusa com 409)

Obs.: a solicitação é feita a partir de "Minhas solicitações", do Início e da ficha do bem.

### A09 · Aceitar ou recusar a transferência, com foto — `[~]` 5/6 (liberação pela origem e confirmação com foto pelo destino)
- [x] Lista de pendentes vem da API (aba Autorizações e Movimentações > Pendentes)
- [x] Aceite exige foto do recebimento (câmera ou galeria, enviada antes da autorização)
- [x] Aceita, o bem passa ao destino
- [x] Recusa exige motivo, que fica visível para quem solicitou
- [ ] Aceite ou recusa sem rede entra na fila: a sincronização já trata liberação, recebimento e recusa (com a
  etapa vista no aparelho); falta a tela usar a fila e guardar a foto até haver conexão
- [x] Respondida, sai da lista de pendentes e aparece em "Minhas solicitações" e no histórico do bem

### A10 · Empréstimo e manutenção pelo aplicativo — `[~]` 6/7
- [x] Empréstimo exige quem levou, motivo e devolução prevista; a data de saída é a do servidor
- [x] Devolução registra data efetiva e encerra o empréstimo
- [~] Empréstimo aparece marcado na lista do acervo; o atraso ainda não é destacado no app (na web, sim)
- [x] Envio para manutenção exige descrição e destino; a data é a do servidor
- [x] Retorno registra serviço, data e novo estado de conservação; o bem volta ao status anterior
- [x] Emprestado e em manutenção continuam na guarda da origem
- [x] Os quatro registros vão à API (direto ou pela fila offline) e aparecem no histórico

### A11 · Execução do inventário, offline — `[ ]` 0/7 (API pronta: lista congelada e conferência por `/sincronizacao`)
- [ ] Agente escolhe o inventário aberto do setor e o app carrega a lista congelada
- [ ] Contadores de esperados, encontrados, faltantes e excedentes atualizados a cada leitura
- [ ] Comparação calculada no aparelho, sem rede
- [ ] Bem de outro setor lido entra como excedente, com setor de origem
- [ ] Lista do que falta consultável, com descrição e foto
- [ ] Cada bem lido é conferido com estado e foto
- [ ] Tudo lido entra na fila e é enviado na sincronização

### A12 · Fila de sincronização e status da conexão — `[x]` 7/7
- [x] Status online/offline visível em todas as telas (indicador na barra superior; "online" = servidor respondeu)
- [x] Quantidade de operações na fila e data da última sincronização à vista
- [x] Fila consultável: tipo, bem e data de cada operação
- [x] Sincronização envia o lote na ordem de criação (e começa sozinha quando o servidor volta)
- [x] Resultado de cada operação mostrado: enviada, recusada com motivo, ou em conflito
- [x] Recusada ou em conflito permanece visível; fila só esvazia do que o servidor confirmou
- [x] Reenvio após interrupção não duplica registros (id por operação, com testes de queda de rede)

---

## 5. Ordem sugerida (dependências)

A base offline (W08, A03, A12), o inventário (W07) e a trilha (W09) estão prontos. Próximos passos:

1. **A11 (inventário no app)**: usa a lista congelada do W07 e a fila do A12; é o próximo de maior valor.
2. **A06 (conferência com foto)** e **A07 (bem não cadastrado)**: mesmas operações do inventário, com foto guardada
   no aparelho até a sincronização.
3. **A04 offline**: leitura da etiqueta consultando o acervo baixado quando não há rede, e checagem do dígito
   verificador no aparelho.
4. **A08 e A09 offline**: pedido, liberação, recebimento e recusa pela fila (a API já aceita).
5. **W10**: relatórios por responsável e por estado de conservação, filtros e exportação.
6. **REQ-EX-02**: expiração de sessão por inatividade no app (a fila já é preservada).

Decisões de regra (C1 a C3) já foram confirmadas com o professor, e a numeração segue o quadro (seção 1).

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
Estado: bloqueio e registro de acessos feitos. Pendentes: recuperação de senha por e-mail (precisa de serviço de e-mail) e expiração por inatividade no app (a fila offline já existe e é preservada ao expirar a sessão).
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
- [x] Motivo da baixa obrigatório, com lista fechada (doação, inservível, extravio, venda, sinistro, descarte)
- [~] Documento obrigatório em toda baixa; ainda não varia conforme o destino (ex.: boletim de ocorrência para extravio)
- [~] Bem baixado fica fora do inventário e do acervo offline e continua no histórico; na lista de bens aparece
  marcado como baixado (o filtro "somente ativos" o esconde)

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
