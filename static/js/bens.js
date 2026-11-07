import { $, api, ui, esc } from '/static/js/utils.js';

/**
 * Bens.js - Gerenciamento de Equipamentos
 */

let todosBens = [];
let filtrados = [];
let categorias = [];
let paginaAtual = 1;
const itensPorPagina = 10;

async function init() {
    await Promise.all([
        carregarBens(),
        carregarCategorias()
    ]);
    setupListeners();
    await aplicarFiltrosDaUrl();
}

// Filtros vindos de links do painel inicial. Cada parâmetro corresponde ao cartão de origem:
//   ?busca=<código>          item específico (painel de atenção)
//   ?status=baixado          KPI "Itens baixados"
//   ?situacao=ativos         KPI "Patrimônio ativo"
//   ?garantia=alerta         KPI "Garantias a vencer" (mesma regra da API: 60 dias e vencidas)
let apenasAtivos = false;
let codigosGarantia = null; // null = filtro não usado

async function aplicarFiltrosDaUrl() {
    const params = new URLSearchParams(window.location.search);
    const busca = params.get('busca');
    const status = params.get('status');
    apenasAtivos = params.get('situacao') === 'ativos';
    const porGarantia = params.get('garantia') === 'alerta';

    if (porGarantia) {
        try {
            const alertas = await api.get('/api/v1/bem/alertas/garantias?dias=60');
            codigosGarantia = new Set(alertas.map(a => a.codigo_tombamento));
        } catch (erro) {
            codigosGarantia = new Set();
        }
    }

    if (busca) $("#inputBusca").value = busca;
    if (status) $("#filtroStatus").value = status;

    const descricoes = [];
    if (busca) descricoes.push(`código ${busca}`);
    if (status) descricoes.push(`status: ${$("#filtroStatus").selectedOptions[0]?.text ?? status}`);
    if (apenasAtivos) descricoes.push('somente ativos');
    if (porGarantia) descricoes.push('garantias vencidas ou a vencer em 60 dias');
    if (descricoes.length) {
        const aviso = $("#contextoFiltro");
        aviso.innerHTML = `<i class="bi bi-funnel me-2"></i>Filtro do painel: ${esc(descricoes.join(' · '))} <a href="/bens" class="ms-2 fw-semibold">Limpar</a>`;
        aviso.classList.remove('d-none');
    }
    filtrarBens();
}

async function carregarBens() {
    try {
        todosBens = await api.get("/api/v1/bem/");
        // Recarga (ex.: depois de uma ação na ficha) mantém o filtro e a página em que o usuário estava.
        aplicarFiltros();
        const ultimaPagina = Math.max(1, Math.ceil(filtrados.length / itensPorPagina));
        paginaAtual = Math.min(paginaAtual || 1, ultimaPagina);
        renderizarTabela();
    } catch (error) {
        ui.showNotification("Erro ao carregar bens.", "error");
    }
    carregarBaixasPendentes();
}

// Baixas aguardando aprovação: só aparecem para o setor de patrimônio.
async function carregarBaixasPendentes() {
    const cartao = $("#cardBaixas");
    try {
        const pendentes = await api.get("/api/v1/bem/baixas/pendentes");
        cartao.classList.toggle("d-none", pendentes.length === 0);
        $("#listaBaixas").innerHTML = pendentes.map(b => `
            <div class="border rounded-3 p-3 mb-2 d-flex flex-wrap justify-content-between align-items-center gap-2">
                <div>
                    <div class="fw-semibold">${esc(b.bem_nome)} <code>${esc(b.codigo_tombamento)}</code></div>
                    <div class="small text-muted">Motivo: ${esc(b.motivo)} · Valor R$ ${Number(b.valor).toLocaleString("pt-BR", {minimumFractionDigits: 2})} · Documento: ${esc(b.documento_ref)}</div>
                    <div class="small text-muted">Pedida por ${esc(b.solicitante)}: ${esc(b.justificativa)}</div>
                </div>
                <div class="d-flex gap-2">
                    <button class="btn btn-primary btn-sm pill-btn" data-aprovar-baixa="${esc(b.id)}">Aprovar</button>
                    <button class="btn btn-outline-danger btn-sm pill-btn" data-recusar-baixa="${esc(b.id)}">Recusar</button>
                </div>
            </div>`).join("");
    } catch (error) {
        cartao.classList.add("d-none");
    }
}

async function decidirBaixa(id, aprovar) {
    let motivo = null;
    if (!aprovar) {
        motivo = window.prompt("Motivo da recusa (quem pediu vai ver):");
        if (!motivo || motivo.trim().length < 3) return;
    }
    try {
        await api.post(`/api/v1/bem/baixas/${id}/${aprovar ? "aprovar" : "recusar"}`, aprovar ? undefined : { motivo: motivo.trim() });
        ui.showNotification(aprovar ? "Baixa aprovada." : "Baixa recusada.");
        carregarBens();
    } catch (error) {
        ui.showNotification(error.message, "error");
    }
}

async function carregarCategorias() {
    try {
        categorias = await api.get("/api/v1/categoria/");
        console.log("Categorias carregadas:", categorias); // Debug
        const select = $("#id_categoria");
        if (select) {
            select.innerHTML = '<option value="">Selecione uma categoria...</option>' +
                categorias.map(c => `<option value="${esc(c.id)}">${esc(c.nome)} (${esc(c.sigla)})</option>`).join('');
        }
    } catch (error) {
        console.error("Erro ao carregar categorias:", error);
    }
}

// Seleção de bens para gerar etiquetas (guardada entre páginas da tabela).
const selecionados = new Set();

function alternarSelecao(id, marcado) {
    marcado ? selecionados.add(String(id)) : selecionados.delete(String(id));
    atualizarBotaoEtiquetas();
}

function atualizarBotaoEtiquetas() {
    const botao = $("#btnEtiquetasLote");
    botao.disabled = selecionados.size === 0;
    $("#qtdEtiquetas").textContent = `(${selecionados.size})`;
}

function atualizarSelecaoTodos(itensPagina) {
    const chkTodos = $("#chkTodos");
    const marcados = itensPagina.filter(bem => selecionados.has(String(bem.id))).length;
    chkTodos.checked = itensPagina.length > 0 && marcados === itensPagina.length;
    chkTodos.indeterminate = marcados > 0 && marcados < itensPagina.length;
}

// Envia a planilha; em simulação só mostra o resultado, sem gravar.
async function enviarImportacao(simular) {
    const arquivo = $("#arquivoImportar").files[0];
    const saida = $("#resultadoImportar");
    if (!arquivo) { saida.innerHTML = '<div class="alert alert-warning">Escolha um arquivo CSV.</div>'; return; }
    const form = new FormData();
    form.append('arquivo', arquivo);
    form.append('simular', simular ? 'true' : 'false');
    saida.innerHTML = '<div class="text-center py-3"><div class="spinner-border text-primary" role="status"></div></div>';
    try {
        const resposta = await fetch('/api/v1/bem/importar', { method: 'POST', body: form, credentials: 'same-origin' });
        const dados = await resposta.json();
        if (!resposta.ok) throw new Error(dados.detail || 'Falha na importação.');
        const erros = dados.erros.map(e => `<li>Linha ${esc(e.linha)}: ${esc(e.erro)}</li>`).join('');
        saida.innerHTML = `
            <div class="alert ${dados.erros.length ? 'alert-warning' : 'alert-success'}">
                <strong>${simular ? 'Simulação' : 'Importação'}:</strong>
                ${dados.total} linha(s) lida(s), ${simular ? dados.validas + ' válida(s)' : dados.importados + ' importada(s)'},
                ${dados.erros.length} com erro.
            </div>
            ${erros ? `<ul class="small">${erros}</ul>` : ''}`;
        if (simular && dados.validas > 0) $("#btnImportar").disabled = false;
        if (!simular) { await carregarBens(); }
    } catch (erro) {
        saida.innerHTML = `<div class="alert alert-danger">${esc(erro.message)}</div>`;
    }
}

// A altura do iframe só pode ser medida com a folha carregada E o modal visível (um documento
// escondido mede 0 px). Por isso é chamada nos dois eventos; vale a medida do que ocorrer por último.
function ajustarAlturaEtiquetas() {
    const frame = $("#frameEtiquetas");
    const doc = frame.contentDocument;
    if (frame.classList.contains('d-none') || !doc?.querySelector('.folha')) return;
    // Mede o conteúdo (body), não a janela do iframe: scrollHeight nunca fica menor que a altura atual
    // do iframe, então uma medida feita com o modal ainda estreito ficaria presa.
    frame.style.height = `${Math.ceil(doc.body.getBoundingClientRect().height)}px`;
}

// Mostra as etiquetas num modal. O conteúdo é a mesma folha usada na impressão (a API aceita o
// cookie de sessão), carregada num iframe em modo "incorporado", sem a barra própria da página.
function abrirEtiquetas(ids) {
    if (!ids.length) return;
    const lista = ids.map(encodeURIComponent).join(',');
    const frame = $("#frameEtiquetas");
    const estado = $("#etiquetasEstado");
    const imprimir = $("#btnImprimirEtiquetas");

    $("#modalEtiquetasTitulo").innerHTML =
        `<i class="bi bi-qr-code me-2"></i>${ids.length === 1 ? 'Etiqueta' : `Etiquetas (${ids.length})`}`;
    $("#linkEtiquetasNovaAba").href = `/api/v1/etiquetas/lote?ids=${lista}`;
    imprimir.disabled = true;
    frame.style.height = '';
    frame.classList.add('d-none');
    estado.textContent = 'Gerando etiquetas…';
    estado.classList.remove('d-none');

    frame.onload = () => {
        if (frame.src === 'about:blank') return;
        const doc = frame.contentDocument;
        if (!doc?.querySelector('.folha')) {
            // A API respondeu com erro (JSON), por exemplo lote acima do limite.
            let mensagem = 'Não foi possível gerar as etiquetas.';
            try { mensagem = JSON.parse(doc.body.innerText).detail || mensagem; } catch (erro) { /* mantém a padrão */ }
            estado.textContent = mensagem;
            return;
        }
        estado.classList.add('d-none');
        frame.classList.remove('d-none');
        imprimir.disabled = false;
        ajustarAlturaEtiquetas();
    };
    frame.src = `/api/v1/etiquetas/lote?ids=${lista}&incorporado=true`;

    // A ficha do bem também tem o botão de etiqueta: fecha a ficha para não empilhar modais.
    bootstrap.Modal.getInstance($("#modalDetalhesBem"))?.hide();
    bootstrap.Modal.getOrCreateInstance($("#modalEtiquetas")).show();
}

function renderizarTabela() {
    const tabela = $("#tabela-bens");
    const info = $("#infoPaginacao");
    
    if (filtrados.length === 0) {
        tabela.innerHTML = `<tr><td colspan="6" class="text-center py-4 text-muted">Nenhum equipamento encontrado.</td></tr>`;
        info.innerText = "Mostrando 0 de 0 itens";
        renderizarPaginacao(0);
        return;
    }

    // Ordenação consistente por ID decrescente (mais novos primeiro)
    filtrados.sort((a, b) => b.id - a.id);

    const inicio = (paginaAtual - 1) * itensPorPagina;
    const fim = inicio + itensPorPagina;
    const itensPagina = filtrados.slice(inicio, fim);

    tabela.innerHTML = itensPagina.map(bem => `
        <tr>
            <td class="ps-4"><input class="form-check-input chk-etiqueta" type="checkbox" data-id="${esc(bem.id)}" ${selecionados.has(String(bem.id)) ? 'checked' : ''} aria-label="Selecionar bem ${esc(bem.id)}"></td>
            <td><span class="text-muted">#${esc(bem.id)}</span></td>
            <td><span class="fw-bold text-dark">${esc(bem.nome)}</span></td>
            <td><code>${esc(bem.codigo_tombamento)}</code></td>
            <td>R$ ${parseFloat(bem.valor_aquisicao ?? bem.valor).toLocaleString('pt-BR', {minimumFractionDigits: 2})}</td>
            <td>${getStatusBadge(bem.status, bem.ativo)}</td>
            <td class="text-end pe-4">
                <div class="btn-group">
                    <button class="btn btn-sm btn-light text-primary btn-detalhes" data-id="${esc(bem.id)}" title="Ver Detalhes"><i class="bi bi-eye"></i></button>
                    <button class="btn btn-sm btn-light text-dark btn-etiqueta" data-id="${esc(bem.id)}" title="Gerar etiqueta"><i class="bi bi-qr-code"></i></button>
                    ${bem.ativo ? `<button class="btn btn-sm btn-light text-warning btn-editar" data-id="${esc(bem.id)}" title="Editar"><i class="bi bi-pencil-square"></i></button>` : ''}
                    ${bem.ativo ? 
                        `<button class="btn btn-sm btn-light text-danger btn-deletar" data-id="${esc(bem.id)}" title="Desativar"><i class="bi bi-trash"></i></button>` :
                        `<button class="btn btn-sm btn-light text-success btn-reativar" data-id="${esc(bem.id)}" title="Reativar"><i class="bi bi-arrow-counterclockwise"></i></button>`
                    }
                </div>
            </td>
        </tr>
    `).join('');

    tabela.querySelectorAll('.btn-editar').forEach(btn => {
        btn.addEventListener('click', () => editarBem(btn.dataset.id));
    });

    atualizarSelecaoTodos(itensPagina);

    const totalItens = filtrados.length;
    const mostradoFim = Math.min(fim, totalItens);
    info.innerText = `Mostrando ${totalItens > 0 ? inicio + 1 : 0} a ${mostradoFim} de ${totalItens} itens`;
    renderizarPaginacao(totalItens);
}

function renderizarPaginacao(totalItens) {
    const totalPaginas = Math.ceil(totalItens / itensPorPagina);
    const container = $("#pagination");
    container.innerHTML = "";

    if (totalPaginas <= 1) return;

    let html = `
        <li class="page-item ${esc(paginaAtual === 1 ? 'disabled' : '')}">
            <a class="page-link" href="#" data-page="${paginaAtual - 1}"><i class="bi bi-chevron-left"></i></a>
        </li>
    `;

    for (let i = 1; i <= totalPaginas; i++) {
        html += `
            <li class="page-item ${esc(paginaAtual === i ? 'active' : '')}">
                <a class="page-link" href="#" data-page="${i}">${i}</a>
            </li>
        `;
    }

    html += `
        <li class="page-item ${esc(paginaAtual === totalPaginas ? 'disabled' : '')}">
            <a class="page-link" href="#" data-page="${paginaAtual + 1}"><i class="bi bi-chevron-right"></i></a>
        </li>
    `;
    
    container.innerHTML = html;
}

// ----- Ficha do bem: situação atual, ações (empréstimo e manutenção) e linha do tempo -----

const ICONE_EVENTO = {
    cadastro: 'bi-plus-circle', edicao: 'bi-pencil', baixa: 'bi-x-octagon', reativacao: 'bi-arrow-counterclockwise',
    transferencia_solicitada: 'bi-send', transferencia_aprovada: 'bi-arrow-left-right',
    transferencia_recusada: 'bi-x-circle', transferencia_cancelada: 'bi-shield-exclamation',
    emprestimo_saida: 'bi-box-arrow-up-right', emprestimo_devolucao: 'bi-box-arrow-in-down-left',
    manutencao_envio: 'bi-tools', manutencao_retorno: 'bi-wrench-adjustable-circle',
    baixa_solicitada: 'bi-hourglass-split', baixa_recusada: 'bi-x-circle',
    conferencia_localizado: 'bi-check2-square', conferencia_outro_setor: 'bi-signpost-split',
    conferencia_nao_localizado: 'bi-question-circle',
};
const dataBR = (valor) => new Date(`${valor}T00:00:00`).toLocaleDateString('pt-BR');
const dataHoraBR = (valor) => new Date(valor).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
const hojeISO = () => new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 10);

async function verDetalhes(id) {
    const container = $("#conteudoDetalhes");
    container.innerHTML = `<div class="text-center py-4"><div class="spinner-border text-primary" role="status"></div></div>`;
    bootstrap.Modal.getOrCreateInstance($("#modalDetalhesBem")).show();

    // As quatro consultas são independentes: rodam em paralelo.
    const [bemR, eventosR, emprestimosR, manutencoesR] = await Promise.allSettled([
        api.get(`/api/v1/bem/${id}/detalhes`),
        api.get(`/api/v1/bem/${id}/historico`),
        api.get(`/api/v1/emprestimos/?situacao=abertos&bem_id=${id}`),
        api.get(`/api/v1/manutencoes/?situacao=abertas&bem_id=${id}`),
    ]);
    if (bemR.status === 'rejected') {
        container.innerHTML = `<div class="alert alert-danger">Erro ao carregar detalhes do equipamento.</div>`;
        return;
    }
    const bem = bemR.value;
    const emprestimo = emprestimosR.status === 'fulfilled' ? emprestimosR.value[0] : null;
    const manutencao = manutencoesR.status === 'fulfilled' ? manutencoesR.value[0] : null;

    container.innerHTML = `
        <div class="mb-4">
            <small class="text-muted text-uppercase fw-bold d-block mb-1">Informações Básicas</small>
            <h4 class="fw-bold text-primary mb-0">${esc(bem.nome)}</h4>
            <p class="text-muted mb-0">Código: <code>${esc(bem.codigo_tombamento)}</code> | Categoria: <span class="badge bg-secondary">${esc(bem.categoria_nome || 'N/A')}</span></p>
            <p class="text-muted mb-0 small">Setor: <span class="text-dark">${esc(bem.setor_atual || 'Não alocado')}</span> | Responsável: <span class="text-dark">${esc(bem.responsavel_nome || '—')}</span></p>
            <button class="btn btn-outline-primary btn-sm mt-3 btn-etiqueta-ficha" data-id="${esc(bem.id)}"><i class="bi bi-qr-code me-1"></i> Gerar etiqueta</button>
        </div>

        <div class="row g-3 mb-4">
            <div class="col-6">
                <div class="p-3 bg-light rounded-3">
                    <small class="text-muted d-block mb-1">Setor Atual</small>
                    <span class="fw-bold text-dark"><i class="bi bi-geo-alt-fill text-primary me-2"></i>${esc(bem.setor_atual || "Não alocado")}</span>
                </div>
            </div>
            <div class="col-6">
                <div class="p-3 bg-light rounded-3">
                    <small class="text-muted d-block mb-1">Status</small>
                    ${getStatusBadge(bem.status, bem.ativo)}
                </div>
            </div>
        </div>

        ${renderizarSituacao(bem, emprestimo, manutencao)}

        <div class="border-top pt-3 mb-4">
            <small class="text-muted text-uppercase fw-bold d-block mb-2">Identificação e conservação</small>
            <div class="row g-2 small">
                <div class="col-6"><strong>Marca:</strong> ${esc(bem.marca || '—')}</div>
                <div class="col-6"><strong>Modelo:</strong> ${esc(bem.modelo || '—')}</div>
                <div class="col-6"><strong>Nº de série:</strong> ${esc(bem.numero_serie || '—')}</div>
                <div class="col-6"><strong>Conservação:</strong> ${esc(bem.estado_conservacao || '—')}</div>
                <div class="col-12"><strong>Localização física:</strong> ${bem.predio_nome ? `${esc(bem.predio_nome)} — ${esc(bem.andar_identificacao)} — ${esc(bem.sala_nome)}` : '—'}</div>
                <div class="col-6"><strong>Aquisição:</strong> R$ ${Number(bem.valor_aquisicao ?? bem.valor).toLocaleString('pt-BR', {minimumFractionDigits: 2})}</div>
                <div class="col-6"><strong>Nota fiscal:</strong> ${esc(bem.nota_fiscal || '—')}</div>
                <div class="col-6"><strong>Entrada:</strong> ${bem.data_entrada ? dataBR(esc(bem.data_entrada)) : '—'}</div>
            </div>
        </div>

        <div class="border-top pt-4">
            <h6 class="fw-bold mb-3"><i class="bi bi-clock-history me-2 text-primary"></i>Linha do tempo</h6>
            ${eventosR.status === 'fulfilled'
                ? renderizarTimeline(eventosR.value)
                : '<p class="text-muted small">Não foi possível carregar o histórico.</p>'}
        </div>
    `;
}

// Situação atual e as ações possíveis. A API confere permissões e regras (guarda do setor, bem livre).
function renderizarSituacao(bem, emprestimo, manutencao) {
    if (!bem.ativo) return '';
    let aviso = '';
    let botoes = '';
    if (emprestimo) {
        const atraso = emprestimo.atrasado ? ` · <strong class="text-danger">${emprestimo.dias_atraso} dia(s) de atraso</strong>` : '';
        aviso = `<i class="bi bi-box-arrow-up-right me-2"></i>Emprestado para <strong>${esc(emprestimo.tomador)}</strong>
                 até ${dataBR(emprestimo.devolucao_prevista)}${atraso}`;
        botoes = `<button class="btn btn-primary btn-sm btn-acao-bem" data-acao="devolver" data-id="${emprestimo.id}">
                      <i class="bi bi-box-arrow-in-down-left me-1"></i>Registrar devolução</button>`;
    } else if (manutencao) {
        aviso = `<i class="bi bi-tools me-2"></i>Em manutenção em <strong>${esc(manutencao.destino)}</strong>
                 há ${manutencao.dias_fora} dia(s) · ${esc(manutencao.descricao)}`;
        botoes = `<button class="btn btn-primary btn-sm btn-acao-bem" data-acao="retorno" data-id="${manutencao.id}">
                      <i class="bi bi-wrench-adjustable-circle me-1"></i>Registrar retorno</button>`;
    } else {
        botoes = `
            <button class="btn btn-outline-primary btn-sm btn-acao-bem" data-acao="emprestar" data-id="${bem.id}">
                <i class="bi bi-box-arrow-up-right me-1"></i>Emprestar</button>
            <button class="btn btn-outline-primary btn-sm btn-acao-bem" data-acao="manutencao" data-id="${bem.id}">
                <i class="bi bi-tools me-1"></i>Enviar para manutenção</button>`;
    }
    return `
        <div class="mb-4" id="situacaoBem" data-bem="${bem.id}">
            ${aviso ? `<div class="alert ${emprestimo?.atrasado ? 'alert-danger' : 'alert-warning'} py-2 small mb-2">${aviso}</div>` : ''}
            <div class="d-flex flex-wrap gap-2">${botoes}</div>
            <form id="formAcaoBem" class="d-none mt-3 p-3 bg-light rounded-3" novalidate></form>
        </div>`;
}

const FORMULARIOS = {
    emprestar: () => `
        <h6 class="fw-bold mb-3">Emprestar bem</h6>
        <div class="mb-2"><label class="form-label small fw-semibold" for="acaoTomador">Quem vai levar</label>
            <input class="form-control" id="acaoTomador" required minlength="3" maxlength="120"></div>
        <div class="mb-2"><label class="form-label small fw-semibold" for="acaoMotivo">Motivo</label>
            <input class="form-control" id="acaoMotivo" required minlength="3" maxlength="500"></div>
        <div class="mb-3"><label class="form-label small fw-semibold" for="acaoPrazo">Devolução prevista</label>
            <input type="date" class="form-control" id="acaoPrazo" required min="${hojeISO()}"></div>`,
    devolver: () => `
        <h6 class="fw-bold mb-3">Registrar devolução</h6>
        <div class="mb-3"><label class="form-label small fw-semibold" for="acaoObservacao">Observação (opcional)</label>
            <input class="form-control" id="acaoObservacao" maxlength="500" placeholder="Ex.: voltou sem o carregador"></div>`,
    manutencao: () => `
        <h6 class="fw-bold mb-3">Enviar para manutenção</h6>
        <div class="mb-2"><label class="form-label small fw-semibold" for="acaoDescricao">Problema</label>
            <input class="form-control" id="acaoDescricao" required minlength="3" maxlength="500"></div>
        <div class="mb-3"><label class="form-label small fw-semibold" for="acaoDestino">Para onde vai</label>
            <input class="form-control" id="acaoDestino" required minlength="2" maxlength="160" placeholder="Assistência ou oficina"></div>`,
    retorno: () => `
        <h6 class="fw-bold mb-3">Registrar retorno da manutenção</h6>
        <div class="mb-2"><label class="form-label small fw-semibold" for="acaoServico">Serviço realizado</label>
            <input class="form-control" id="acaoServico" required minlength="3" maxlength="500"></div>
        <div class="mb-3"><label class="form-label small fw-semibold" for="acaoEstado">Estado de conservação</label>
            <select class="form-select" id="acaoEstado" required>
                <option value="novo">Novo</option><option value="bom" selected>Bom</option><option value="regular">Regular</option>
                <option value="ruim">Ruim</option><option value="inservivel">Inservível</option>
            </select></div>`,
};

function abrirFormularioAcao(acao, id) {
    const form = $("#formAcaoBem");
    form.dataset.acao = acao;
    form.dataset.id = id;
    form.innerHTML = FORMULARIOS[acao]() + `
        <div class="d-flex gap-2 justify-content-end">
            <button type="button" class="btn btn-light btn-sm" id="btnCancelarAcao">Cancelar</button>
            <button type="submit" class="btn btn-primary btn-sm">Confirmar</button>
        </div>`;
    form.classList.remove('d-none');
    form.querySelector('input, select')?.focus();
}

async function enviarAcaoBem(evento) {
    evento.preventDefault();
    const form = evento.target;
    if (!form.checkValidity()) {
        form.classList.add('was-validated');
        return;
    }
    const { acao, id } = form.dataset;
    const bemId = $("#situacaoBem").dataset.bem;
    const valor = (campo) => $(campo).value.trim();
    const pedidos = {
        emprestar: () => api.post('/api/v1/emprestimos/', {
            bem_id: Number(id), tomador: valor('#acaoTomador'), motivo: valor('#acaoMotivo'), devolucao_prevista: valor('#acaoPrazo') }),
        devolver: () => api.post(`/api/v1/emprestimos/${id}/devolver`, { observacao: valor('#acaoObservacao') || null }),
        manutencao: () => api.post('/api/v1/manutencoes/', {
            bem_id: Number(id), descricao: valor('#acaoDescricao'), destino: valor('#acaoDestino') }),
        retorno: () => api.post(`/api/v1/manutencoes/${id}/retorno`, {
            servico_realizado: valor('#acaoServico'), estado_retorno: $('#acaoEstado').value }),
    };
    const botao = form.querySelector('button[type="submit"]');
    botao.disabled = true;
    try {
        await pedidos[acao]();
        ui.showNotification('Registrado com sucesso.', 'success');
        await Promise.all([verDetalhes(bemId), carregarBens()]);
    } catch (erro) {
        ui.showNotification(erro.message || 'Não foi possível registrar.', 'error');
        botao.disabled = false;
    }
}

function renderizarTimeline(eventos) {
    if (!eventos || eventos.length === 0) {
        return `<p class="text-muted fst-italic small">Nenhum evento registrado para este bem.</p>`;
    }
    return `
        <div class="timeline">
            ${eventos.map(e => `
                <div class="timeline-item">
                    <div class="timeline-marker"></div>
                    <div class="timeline-content">
                        <span class="timeline-date">${dataHoraBR(e.em)}${e.autor ? ` · ${esc(e.autor)}` : ''}</span>
                        <div class="fw-bold text-dark small"><i class="bi ${ICONE_EVENTO[e.tipo] || 'bi-dot'} me-1 text-primary"></i>${esc(e.titulo)}</div>
                        ${e.detalhe ? `<div class="text-muted mt-1" style="font-size: 0.85rem;">${esc(e.detalhe)}</div>` : ''}
                        ${e.fotos.length ? `<div class="mt-1 small">${e.fotos.map((f, i) =>
                            `<a href="/api/v1/fotos/${f}" target="_blank" rel="noopener" class="me-2"><i class="bi bi-image me-1"></i>Foto ${i + 1}</a>`).join('')}</div>` : ''}
                    </div>
                </div>
            `).join('')}
        </div>
    `;
}

function getStatusBadge(status, ativo = true) {
    if (!ativo) return '<span class="badge bg-danger-subtle text-danger rounded-pill px-3"><i class="bi bi-slash-circle me-1"></i>Inativo / Baixado</span>';
    
    const s = status.toLowerCase();
    if (s.includes('disponivel')) 
        return '<span class="badge bg-success text-white rounded-pill px-3 shadow-sm"><i class="bi bi-check-circle-fill me-1"></i>Disponível</span>';
    
    if (s === 'em uso' || s === 'em_uso') 
        return '<span class="badge bg-primary-subtle text-primary rounded-pill px-3"><i class="bi bi-person-check me-1"></i>Em Uso</span>';
    
    if (s.includes('manutencao')) 
        return '<span class="badge bg-warning-subtle text-warning-emphasis rounded-pill px-3"><i class="bi bi-tools me-1"></i>Manutenção</span>';

    return `<span class="badge bg-secondary-subtle text-secondary rounded-pill px-3">${esc(status)}</span>`;
}

function normalizarString(str) {
    return str.toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/\s+/g, '')
        .replace(/_/g, '');
}

// Novo filtro digitado ou escolhido: volta para a primeira página.
function filtrarBens() {
    aplicarFiltros();
    paginaAtual = 1;
    renderizarTabela();
}

// Aplica busca, status e filtros vindos da URL sobre a lista carregada.
function aplicarFiltros() {
    const termo = $("#inputBusca").value.toLowerCase();
    const statusFiltro = $("#filtroStatus").value.toLowerCase();

    filtrados = todosBens.filter(bem => {
        if (apenasAtivos && !bem.ativo) return false;
        if (codigosGarantia && !codigosGarantia.has(bem.codigo_tombamento)) return false;
        const matchesBusca = bem.nome.toLowerCase().includes(termo) || 
                             bem.codigo_tombamento.toLowerCase().includes(termo);
        
        if (statusFiltro === "") return matchesBusca;

        const sFiltroNorm = normalizarString(statusFiltro);
        let sBemNorm = normalizarString(bem.status);
        
        if (!bem.ativo) sBemNorm = "baixado";

        return matchesBusca && sBemNorm === sFiltroNorm;
    });

}

function setupListeners() {
    // Filtros
    $("#inputBusca").onkeyup = filtrarBens;
    $("#filtroStatus").onchange = filtrarBens;

    // Ações da Tabela (Delegation)
    $("#tabela-bens").addEventListener('click', async (e) => {
        const btn = e.target.closest('button');
        if (!btn) return;

        const id = btn.dataset.id;
        if (btn.classList.contains('btn-detalhes')) verDetalhes(id);
        if (btn.classList.contains('btn-deletar')) await deletar(id);
        if (btn.classList.contains('btn-reativar')) await reativar(id);
        if (btn.classList.contains('btn-etiqueta')) abrirEtiquetas([id]);
    });

    // Ações da ficha (empréstimo e manutenção): formulário dentro da própria ficha.
    $("#conteudoDetalhes").addEventListener('click', (e) => {
        const acao = e.target.closest('.btn-acao-bem');
        if (acao) abrirFormularioAcao(acao.dataset.acao, acao.dataset.id);
        if (e.target.closest('#btnCancelarAcao')) $("#formAcaoBem").classList.add('d-none');
    });
    $("#conteudoDetalhes").addEventListener('submit', (e) => {
        if (e.target.id === 'formAcaoBem') enviarAcaoBem(e);
    });
    $("#conteudoDetalhes").addEventListener('click', (e) => {
        const btn = e.target.closest('.btn-etiqueta-ficha');
        if (btn) abrirEtiquetas([btn.dataset.id]);
    });

    // Seleção para etiquetas em lote
    $("#tabela-bens").addEventListener('change', (e) => {
        const chk = e.target;
        if (!chk.classList.contains('chk-etiqueta')) return;
        alternarSelecao(chk.dataset.id, chk.checked);
    });
    $("#chkTodos").addEventListener('change', (e) => {
        document.querySelectorAll('#tabela-bens .chk-etiqueta').forEach(chk => {
            chk.checked = e.target.checked;
            alternarSelecao(chk.dataset.id, e.target.checked);
        });
    });
    $("#btnEtiquetasLote").addEventListener('click', () => abrirEtiquetas([...selecionados]));
    $("#btnImprimirEtiquetas").addEventListener('click', () => $("#frameEtiquetas").contentWindow.print());
    // Ao fechar, descarrega a folha para não manter etiquetas antigas na próxima abertura.
    $("#modalEtiquetas").addEventListener('shown.bs.modal', ajustarAlturaEtiquetas);
    $("#modalEtiquetas").addEventListener('hidden.bs.modal', () => { $("#frameEtiquetas").src = 'about:blank'; });

    // Importação por planilha: simular primeiro, depois gravar.
    $("#btnSimularImportacao").addEventListener('click', () => enviarImportacao(true));
    $("#btnImportar").addEventListener('click', () => enviarImportacao(false));
    $("#arquivoImportar").addEventListener('change', () => { $("#btnImportar").disabled = true; });

    // Paginacao (Delegation)
    $("#pagination").addEventListener('click', (e) => {
        e.preventDefault();
        const link = e.target.closest('.page-link');
        if (link && !link.parentElement.classList.contains('disabled')) {
            paginaAtual = parseInt(link.dataset.page);
            renderizarTabela();
        }
    });

    // Lógica de Automação de Código
    $("#id_categoria").onchange = async (e) => {
        const idCat = e.target.value;
        const inputCodigo = $("#codigo");
        
        if (!idCat) {
            inputCodigo.value = "";
            inputCodigo.placeholder = "Selecione uma categoria...";
            return;
        }

        try {
            inputCodigo.value = "Gerando...";
            const data = await api.get(`/api/v1/bem/proximo-codigo/${idCat}`);
            inputCodigo.value = data.codigo;
        } catch (error) {
            ui.showNotification("Erro ao gerar código.", "error");
            inputCodigo.value = "Erro";
        }
    };

    // Form Novo Bem
    $("#formNovoBem").onsubmit = async (e) => {
        e.preventDefault();
        const btn = e.target.querySelector('button[type="submit"]');
        const originalContent = btn.innerHTML;
        
        const bem = {
            id_categoria: parseInt($("#id_categoria").value),
            nome: $("#nome").value,
            codigo_tombamento: $("#codigo").value,
            valor: parseFloat($("#valor").value),
            valor_aquisicao: parseFloat($("#valor").value),
            status: $("#status").value,
            marca: $("#marca").value || null,
            modelo: $("#modelo").value || null,
            numero_serie: $("#numero_serie").value || null,
            nota_fiscal: $("#nota_fiscal").value || null,
            data_entrada: $("#data_entrada").value || null,
            estado_conservacao: $("#estado_conservacao").value
        };

        try {
            btn.disabled = true;
            btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Salvando...';
            
            await api.post("/api/v1/bem/", bem);
            ui.showNotification("Equipamento cadastrado com sucesso!");
            
            bootstrap.Modal.getInstance($("#modalNovoBem")).hide();
            e.target.reset();
            $("#codigo").value = "";
            carregarBens();
        } catch (error) {
            ui.showNotification(error.message, "error");
        } finally {
            btn.disabled = false;
            btn.innerHTML = originalContent;
        }
    };

    $("#formEditarBem").onsubmit = async (e) => {
        e.preventDefault();
        const id = $("#editar_id").value;
        const bem = {
            nome: $("#editar_nome").value,
            valor: parseFloat($("#editar_valor").value),
            valor_aquisicao: parseFloat($("#editar_valor").value),
            status: $("#editar_status").value
        };

        try {
            await api.put(`/api/v1/bem/${id}`, bem);
            bootstrap.Modal.getInstance($("#modalEditarBem")).hide();
            ui.showNotification("Equipamento atualizado com sucesso!");
            carregarBens();
        } catch (error) {
            ui.showNotification(error.message, "error");
        }
    };
}

function editarBem(id) {
    const bem = todosBens.find(item => item.id === Number(id));
    if (!bem) return;
    $("#editar_id").value = bem.id;
    $("#editar_nome").value = bem.nome;
    $("#editar_valor").value = bem.valor;
    $("#editar_status").value = bem.status;
    bootstrap.Modal.getOrCreateInstance($("#modalEditarBem")).show();
}

// Baixa: pede motivo, justificativa e documento. Acima da alçada, espera aprovação.
async function deletar(id) {
    const bem = todosBens.find(b => String(b.id) === String(id));
    $("#baixaBemId").value = id;
    $("#baixaResumo").textContent = bem ? `${bem.nome} (${bem.codigo_tombamento})` : "";
    $("#baixaAlcada").textContent = "Valores acima da alçada precisam ser aprovados por outro servidor do patrimônio.";
    bootstrap.Modal.getOrCreateInstance($("#modalBaixa")).show();
}

async function confirmarBaixa(evento) {
    evento.preventDefault();
    const id = $("#baixaBemId").value;
    const corpo = {
        motivo: $("#baixaMotivo").value,
        justificativa: $("#baixaJustificativa").value.trim(),
        documento_ref: $("#baixaDocumento").value.trim(),
    };
    try {
        const resposta = await api.post(`/api/v1/bem/${id}/desativar`, corpo);
        bootstrap.Modal.getInstance($("#modalBaixa"))?.hide();
        $("#formBaixa").reset();
        ui.showNotification(resposta.mensagem || "Bem baixado.");
        carregarBens();
    } catch (error) { ui.showNotification(error.message, "error"); }
}

async function reativar(id) {
    try {
        await api.post(`/api/v1/bem/${id}/reativar`);
        ui.showNotification("Equipamento reativado!");
        carregarBens();
    } catch (error) { ui.showNotification(error.message, "error"); }
}

const limparFiltros = () => {
    $("#inputBusca").value = "";
    $("#filtroStatus").value = "";
    apenasAtivos = false;
    codigosGarantia = null;
    $("#contextoFiltro").classList.add('d-none');
    filtrarBens();
};

init();

$('#btnLimparFiltros')?.addEventListener('click', limparFiltros);

$('#formBaixa')?.addEventListener('submit', confirmarBaixa);
document.addEventListener('click', (e) => {
    const aprovar = e.target.closest('[data-aprovar-baixa]');
    if (aprovar) decidirBaixa(aprovar.dataset.aprovarBaixa, true);
    const recusar = e.target.closest('[data-recusar-baixa]');
    if (recusar) decidirBaixa(recusar.dataset.recusarBaixa, false);
});
