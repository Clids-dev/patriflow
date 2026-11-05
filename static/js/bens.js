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
}

async function carregarBens() {
    try {
        todosBens = await api.get("/api/v1/bem/");
        filtrados = [...todosBens];
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

// Abre a folha de etiquetas em nova aba (a API aceita o cookie de sessão).
function abrirEtiquetas(ids) {
    if (!ids.length) return;
    window.open(`/api/v1/etiquetas/lote?ids=${ids.map(encodeURIComponent).join(',')}`, '_blank', 'noopener');
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

async function verDetalhes(id) {
    const container = $("#conteudoDetalhes");
    container.innerHTML = `<div class="text-center py-4"><div class="spinner-border text-primary" role="status"></div></div>`;
    
    const myModal = bootstrap.Modal.getOrCreateInstance($("#modalDetalhesBem"));
    myModal.show();

    try {
        const bem = await api.get(`/api/v1/bem/${id}/detalhes`);
        const historico = await api.get(`/api/v1/movimentacao/bem/${encodeURIComponent(bem.codigo_tombamento)}`);
        
        const dataFormatada = bem.data_ultima_movimentacao ? new Date(bem.data_ultima_movimentacao).toLocaleString('pt-BR') : "Sem registro";
        
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
                    <div class="col-6"><strong>Entrada:</strong> ${bem.data_entrada ? new Date(`${esc(bem.data_entrada)}T00:00:00`).toLocaleDateString('pt-BR') : '—'}</div>
                </div>
            </div>

            <div class="border-top pt-4">
                <h6 class="fw-bold mb-3"><i class="bi bi-clock-history me-2 text-primary"></i>Linha do Tempo de Movimentações</h6>
                ${renderizarTimeline(historico)}
            </div>
        `;
    } catch (error) {
        container.innerHTML = `<div class="alert alert-danger">Erro ao carregar detalhes do equipamento.</div>`;
    }
}

function renderizarTimeline(historico) {
    if (!historico || historico.length === 0) {
        return `<p class="text-muted fst-italic small">Nenhuma movimentação registrada para este bem.</p>`;
    }

    return `
        <div class="timeline">
            ${historico.map(m => `
                <div class="timeline-item">
                    <div class="timeline-marker"></div>
                    <div class="timeline-content">
                        <span class="timeline-date">${new Date(m.data_movimentacao).toLocaleString('pt-BR')}</span>
                        <div class="fw-bold text-dark small">${esc(m.setor_destino_nome)}</div>
                        <div class="text-muted smaller mt-1" style="font-size: 0.8rem;">
                            <i class="bi bi-arrow-right me-1 text-primary"></i> Origem: ${esc(m.setor_origem_nome || 'Cadastro Inicial')}
                        </div>
                        <p class="mb-0 mt-2 text-muted fst-italic" style="font-size: 0.85rem;">"${esc(m.justificativa || 'Sem justificativa')}"</p>
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

function filtrarBens() {
    const termo = $("#inputBusca").value.toLowerCase();
    const statusFiltro = $("#filtroStatus").value.toLowerCase();

    filtrados = todosBens.filter(bem => {
        const matchesBusca = bem.nome.toLowerCase().includes(termo) || 
                             bem.codigo_tombamento.toLowerCase().includes(termo);
        
        if (statusFiltro === "") return matchesBusca;

        const sFiltroNorm = normalizarString(statusFiltro);
        let sBemNorm = normalizarString(bem.status);
        
        if (!bem.ativo) sBemNorm = "baixado";

        return matchesBusca && sBemNorm === sFiltroNorm;
    });

    paginaAtual = 1;
    renderizarTabela();
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
