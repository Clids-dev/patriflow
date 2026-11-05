import { $, $$, api, ui, format, esc } from '/static/js/utils.js';

let bemSelecionadoParaMov = null;
let todosSetores = [];

/**
 * Inicialização
 */
async function init() {
    try {
        todosSetores = await api.get("/api/v1/setores/");
        const movimentacoes = await api.get("/api/v1/movimentacao/detailed/");
        renderRecentList(movimentacoes);
    } catch (error) {
        ui.showNotification("Erro ao carregar dados iniciais.", "error");
    }
}

/**
 * Renderização de Componentes
 */
function renderRecentList(dados) {
    const container = $("#lista-acesso-rapido");
    if (!container) return;

    // Filtra únicos e limita a 8
    const unicos = [...new Map(dados.map(m => [m.codigo_tombamento, m])).values()].slice(0, 8);

    container.innerHTML = unicos.map(m => `
        <div class="list-group-item recent-item p-3 border-0 border-bottom" 
             data-codigo="${esc(m.codigo_tombamento)}">
            <div class="d-flex justify-content-between align-items-center mb-1">
                <span class="fw-bold text-dark small">${esc(m.codigo_tombamento)}</span>
                <i class="fas fa-chevron-right text-muted x-small"></i>
            </div>
            <div class="text-muted text-truncate x-small">${esc(m.bem_nome)}</div>
        </div>
    `).join('');

    // Event Delegation para cliques na lista
    container.addEventListener('click', (e) => {
        const item = e.target.closest('.recent-item');
        if (item) loadHistory(item.dataset.codigo);
    });
}

function renderTimeline(historico) {
    const timeline = $("#timeline-movimentacoes");
    timeline.innerHTML = historico.map(m => `
        <div class="timeline-item">
            <div class="timeline-icon shadow-sm">
                <i class="fas fa-exchange-alt text-primary small"></i>
            </div>
            <div class="card border-0 bg-light rounded-4">
                <div class="card-body p-3">
                    <div class="d-flex justify-content-between mb-2">
                        <span class="fw-bold small">${format.date(m.data_movimentacao)}</span>
                        <span class="badge bg-white text-primary border x-small">TRANSFERÊNCIA</span>
                    </div>
                    <div class="d-flex align-items-center gap-2 mb-2">
                        <span class="text-muted small">${esc(m.setor_origem_nome || 'Aquisição')}</span>
                        <i class="fas fa-arrow-right text-muted x-small"></i>
                        <span class="fw-bold text-primary small">${esc(m.setor_destino_nome)}</span>
                    </div>
                    <div class="p-2 bg-white rounded-3 x-small text-muted italic">
                        "${esc(m.justificativa || 'Sem observações.')}"
                    </div>
                </div>
            </div>
        </div>
    `).join('');
}

/**
 * Lógica de Negócio
 */
async function loadHistory(codigo) {
    if (!codigo) return;
    
    toggleState('carregando');
    
    try {
        const bem = await api.get(`/api/v1/bem/buscar?codigo_tombamento=${encodeURIComponent(codigo)}`);
        const [detalhes, historico] = await Promise.all([
            api.get(`/api/v1/bem/${bem.id}/detalhes`),
            api.get(`/api/v1/movimentacao/bem/${encodeURIComponent(codigo)}`)
        ]);

        toggleState('resultado');
        updateDetailsUI(bem, detalhes, historico);
        
        if (historico.length === 0) {
            $("#timeline-container").classList.add("d-none");
            $("#bem-novo-state").classList.remove("d-none");
        } else {
            $("#timeline-container").classList.remove("d-none");
            $("#bem-novo-state").classList.add("d-none");
            renderTimeline(historico);
        }
    } catch (error) {
        toggleState('vazio');
    }
}

function updateDetailsUI(bem, detalhes, historico) {
    $("#detalheNome").innerText = bem.nome;
    $("#detalheCodigo").innerText = bem.codigo_tombamento;
    $("#detalheSetor").innerText = detalhes.setor_atual || "Não alocado";
    $("#detalheQtdMov").innerText = historico.length;
    $("#detalheStatus").innerHTML = getStatusBadge(bem.status, bem.ativo);
}

function toggleState(state) {
    ['inicial', 'carregando', 'resultado', 'vazio'].forEach(s => {
        $(`#estado-${s}`)?.classList.add('d-none');
    });
    $(`#estado-${state}`)?.classList.remove('d-none');
}

function getStatusBadge(status, ativo = true) {
    if (!ativo) return '<span class="badge bg-danger text-white rounded-pill px-3 shadow-sm"><i class="fas fa-ban me-1"></i>Baixado</span>';
    const s = status.toLowerCase();
    let bg = 'bg-warning text-dark';
    let icon = 'fa-info-circle';

    if (s.includes('disponivel')) { bg = 'bg-success text-white'; icon = 'fa-check-circle'; }
    else if (s.includes('uso')) { bg = 'bg-primary text-white'; icon = 'fa-user-check'; }

    return `<span class="badge ${esc(bg)} rounded-pill px-3 shadow-sm"><i class="fas ${esc(icon)} me-1"></i>${esc(status)}</span>`;
}

/**
 * Eventos
 */
$("#btnBuscarHist").onclick = () => loadHistory($("#inputCodigoBusca").value.trim().toUpperCase());
$("#inputCodigoBusca").onkeypress = (e) => { if(e.key === 'Enter') loadHistory(e.target.value.trim().toUpperCase()); };

// Validação do Bem no Modal
$("#mov_codigo_bem").onchange = async (e) => {
    const codigo = e.target.value.trim().toUpperCase();
    if (!codigo) return;

    const statusIcon = $("#statusValidacaoBem");
    statusIcon.innerHTML = `<div class="spinner-border spinner-border-sm text-primary"></div>`;

    try {
        const bem = await api.get(`/api/v1/bem/buscar?codigo_tombamento=${encodeURIComponent(codigo)}`);
        if (!bem.ativo) throw new Error("Bem inativo");

        const detalhes = await api.get(`/api/v1/bem/${bem.id}/detalhes`);
        bemSelecionadoParaMov = { ...bem, ...detalhes };

        statusIcon.innerHTML = `<i class="fas fa-check-circle text-success"></i>`;
        $("#infoBemMov").classList.remove("d-none");
        $("#infoBemMovNome").innerText = bem.nome;
        $("#infoBemMovSetor").innerText = detalhes.setor_atual || "Almoxarifado";

        // Preenche destinos (excluindo o atual)
        const select = $("#mov_setor_destino");
        select.disabled = false;
        $("#btnSalvarMov").disabled = false;
        select.innerHTML = '<option value="">Selecione o destino</option>' + 
            todosSetores
                .filter(s => s.nome !== detalhes.setor_atual)
                .map(s => `<option value="${esc(s.id)}">${esc(s.nome)}</option>`)
                .join('');

    } catch (error) {
        statusIcon.innerHTML = `<i class="fas fa-times-circle text-danger"></i>`;
        $("#infoBemMov").classList.add("d-none");
        $("#mov_setor_destino").disabled = true;
        $("#btnSalvarMov").disabled = true;
        ui.showNotification(error.message, "error");
    }
};

// Submissão da Movimentação
$("#formNovaMovimentacao").onsubmit = async (e) => {
    e.preventDefault();
    ui.setLoading("btnSalvarMov", true);

    const dados = {
        bem_id: bemSelecionadoParaMov.id,
        setor_origem_id: bemSelecionadoParaMov.id_setor_atual || null,
        setor_destino_id: parseInt($("#mov_setor_destino").value),
        justificativa: $("#mov_justificativa").value
    };

    try {
        await api.post("/api/v1/movimentacao/", dados);
        ui.showNotification("Movimentação concluída!");
        
        bootstrap.Modal.getInstance($("#modalNovaMovimentacao")).hide();
        e.target.reset();
        $("#infoBemMov").classList.add("d-none");
        
        init(); // Recarrega lista lateral
        loadHistory(bemSelecionadoParaMov.codigo_tombamento); // Recarrega histórico visual
    } catch (error) {
        ui.showNotification(error.message, "error");
    } finally {
        ui.setLoading("btnSalvarMov", false);
    }
};

// Reset da busca
window.resetarVista = () => {
    $("#inputCodigoBusca").value = "";
    toggleState('inicial');
};

init();
