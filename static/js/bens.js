import { $, api, ui } from '/static/js/utils.js';

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
}

async function carregarCategorias() {
    try {
        categorias = await api.get("/api/v1/categoria/");
        console.log("Categorias carregadas:", categorias); // Debug
        const select = $("#id_categoria");
        if (select) {
            select.innerHTML = '<option value="">Selecione uma categoria...</option>' +
                categorias.map(c => `<option value="${c.id}">${c.nome} (${c.sigla})</option>`).join('');
        }
    } catch (error) {
        console.error("Erro ao carregar categorias:", error);
    }
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
            <td class="ps-4"><span class="text-muted">#${bem.id}</span></td>
            <td><span class="fw-bold text-dark">${bem.nome}</span></td>
            <td><code>${bem.codigo_tombamento}</code></td>
            <td>R$ ${parseFloat(bem.valor_aquisicao ?? bem.valor).toLocaleString('pt-BR', {minimumFractionDigits: 2})}</td>
            <td>${getStatusBadge(bem.status, bem.ativo)}</td>
            <td class="text-end pe-4">
                <div class="btn-group">
                    <button class="btn btn-sm btn-light text-primary btn-detalhes" data-id="${bem.id}" title="Ver Detalhes"><i class="fas fa-eye"></i></button>
                    ${bem.ativo ? `<button class="btn btn-sm btn-light text-warning btn-editar" data-id="${bem.id}" title="Editar"><i class="fas fa-edit"></i></button>` : ''}
                    ${bem.ativo ? 
                        `<button class="btn btn-sm btn-light text-danger btn-deletar" data-id="${bem.id}" title="Desativar"><i class="fas fa-trash"></i></button>` :
                        `<button class="btn btn-sm btn-light text-success btn-reativar" data-id="${bem.id}" title="Reativar"><i class="fas fa-redo"></i></button>`
                    }
                </div>
            </td>
        </tr>
    `).join('');

    tabela.querySelectorAll('.btn-editar').forEach(btn => {
        btn.addEventListener('click', () => editarBem(btn.dataset.id));
    });

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
        <li class="page-item ${paginaAtual === 1 ? 'disabled' : ''}">
            <a class="page-link" href="#" data-page="${paginaAtual - 1}"><i class="fas fa-chevron-left"></i></a>
        </li>
    `;

    for (let i = 1; i <= totalPaginas; i++) {
        html += `
            <li class="page-item ${paginaAtual === i ? 'active' : ''}">
                <a class="page-link" href="#" data-page="${i}">${i}</a>
            </li>
        `;
    }

    html += `
        <li class="page-item ${paginaAtual === totalPaginas ? 'disabled' : ''}">
            <a class="page-link" href="#" data-page="${paginaAtual + 1}"><i class="fas fa-chevron-right"></i></a>
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
        const historico = await api.get(`/api/v1/movimentacao/bem/${bem.codigo_tombamento}`);
        
        const dataFormatada = bem.data_ultima_movimentacao ? new Date(bem.data_ultima_movimentacao).toLocaleString('pt-BR') : "Sem registro";
        
        container.innerHTML = `
            <div class="mb-4">
                <small class="text-muted text-uppercase fw-bold d-block mb-1">Informações Básicas</small>
                <h4 class="fw-bold text-primary mb-0">${bem.nome}</h4>
                <p class="text-muted mb-0">Código: <code>${bem.codigo_tombamento}</code> | Categoria: <span class="badge bg-secondary">${bem.categoria_nome || 'N/A'}</span></p>
            </div>
            
            <div class="row g-3 mb-4">
                <div class="col-6">
                    <div class="p-3 bg-light rounded-3">
                        <small class="text-muted d-block mb-1">Setor Atual</small>
                        <span class="fw-bold text-dark"><i class="fas fa-map-marker-alt text-primary me-2"></i>${bem.setor_atual || "Não alocado"}</span>
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
                    <div class="col-6"><strong>Marca:</strong> ${bem.marca || '—'}</div>
                    <div class="col-6"><strong>Modelo:</strong> ${bem.modelo || '—'}</div>
                    <div class="col-6"><strong>Nº de série:</strong> ${bem.numero_serie || '—'}</div>
                    <div class="col-6"><strong>Conservação:</strong> ${bem.estado_conservacao || '—'}</div>
                    <div class="col-12"><strong>Localização física:</strong> ${bem.predio_nome ? `${bem.predio_nome} — ${bem.andar_identificacao} — ${bem.sala_nome}` : '—'}</div>
                    <div class="col-6"><strong>Aquisição:</strong> R$ ${Number(bem.valor_aquisicao ?? bem.valor).toLocaleString('pt-BR', {minimumFractionDigits: 2})}</div>
                    <div class="col-6"><strong>Nota fiscal:</strong> ${bem.nota_fiscal || '—'}</div>
                    <div class="col-6"><strong>Entrada:</strong> ${bem.data_entrada ? new Date(`${bem.data_entrada}T00:00:00`).toLocaleDateString('pt-BR') : '—'}</div>
                </div>
            </div>

            <div class="border-top pt-4">
                <h6 class="fw-bold mb-3"><i class="fas fa-history me-2 text-primary"></i>Linha do Tempo de Movimentações</h6>
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
                        <div class="fw-bold text-dark small">${m.setor_destino_nome}</div>
                        <div class="text-muted smaller mt-1" style="font-size: 0.8rem;">
                            <i class="fas fa-long-arrow-alt-right me-1 text-primary"></i> Origem: ${m.setor_origem_nome || 'Cadastro Inicial'}
                        </div>
                        <p class="mb-0 mt-2 text-muted fst-italic" style="font-size: 0.85rem;">"${m.justificativa || 'Sem justificativa'}"</p>
                    </div>
                </div>
            `).join('')}
        </div>
    `;
}

function getStatusBadge(status, ativo = true) {
    if (!ativo) return '<span class="badge bg-danger-subtle text-danger rounded-pill px-3"><i class="fas fa-ban me-1"></i>Inativo / Baixado</span>';
    
    const s = status.toLowerCase();
    if (s.includes('disponivel')) 
        return '<span class="badge bg-success text-white rounded-pill px-3 shadow-sm"><i class="fas fa-check-circle me-1"></i>Disponível</span>';
    
    if (s === 'em uso' || s === 'em_uso') 
        return '<span class="badge bg-primary-subtle text-primary rounded-pill px-3"><i class="fas fa-user-check me-1"></i>Em Uso</span>';
    
    if (s.includes('manutencao')) 
        return '<span class="badge bg-warning-subtle text-warning-emphasis rounded-pill px-3"><i class="fas fa-tools me-1"></i>Manutenção</span>';

    return `<span class="badge bg-secondary-subtle text-secondary rounded-pill px-3">${status}</span>`;
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
    });

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

async function deletar(id) {
    if (!confirm("Tem certeza que deseja desativar este equipamento?")) return;
    try {
        await api.post(`/api/v1/bem/${id}/desativar`);
        ui.showNotification("Equipamento desativado.");
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

window.limparFiltros = () => {
    $("#inputBusca").value = "";
    $("#filtroStatus").value = "";
    filtrarBens();
};

init();
