import { $, api, ui, esc } from '/static/js/utils.js';

// Transferências com dupla confirmação: origem libera, destino confirma com foto,
// almoxarifado acompanha e pode intervir. A API valida cada permissão.
const ROTULO = {
    pendente: ['Aguarda liberação', 'bg-warning-subtle text-warning-emphasis'],
    liberada: ['Aguarda recebimento', 'bg-primary-subtle text-primary'],
    aprovada: ['Concluída', 'bg-success-subtle text-success'],
    recusada: ['Recusada', 'bg-danger-subtle text-danger'],
    cancelada: ['Cancelada', 'bg-secondary-subtle text-secondary'],
};
const data = (valor) => (valor ? new Date(valor).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : '—');

let eu = null;
let almoxId = null;

async function carregarPerfil() {
    eu = await api.get('/api/v1/auth/me');
    const setores = await api.get('/api/v1/setores/');
    almoxId = setores.find(s => s.flag_almoxarifado)?.id ?? null;
}

const souResponsavel = () => eu.perfil === 'responsavel_setor';
const souPatrimonio = () => eu.perfil === 'setor_patrimonio';
// Almoxarifado (responsável) e setor de patrimônio acompanham e intervêm.
const podeIntervir = () => souPatrimonio() || (souResponsavel() && eu.setor_id === almoxId);

function cartaoDecisao(m, { decidir = false, intervir = false } = {}) {
    const [texto, classe] = ROTULO[m.status] || [m.status, 'bg-secondary-subtle'];
    const aberta = m.status === 'pendente' || m.status === 'liberada';
    const liberar = m.etapa === 'liberar' && m.fluxo !== 'simples';
    const alvo = `data-id="${esc(m.id)}" data-resumo="${esc(`${m.bem_nome} → ${m.setor_destino_nome}`)}"`;
    const botoes = [];
    if (aberta && decidir) {
        if (liberar) {
            botoes.push(`<button class="btn btn-primary btn-sm pill-btn btn-liberar" ${alvo}><i class="bi bi-unlock me-1"></i>Liberar bem</button>`);
        } else {
            botoes.push(`<button class="btn btn-primary btn-sm pill-btn btn-autorizar" ${alvo}><i class="bi bi-camera me-1"></i>Confirmar com foto</button>`);
        }
        botoes.push(`<button class="btn btn-outline-danger btn-sm pill-btn btn-recusar" ${alvo}><i class="bi bi-x-lg me-1"></i>Recusar</button>`);
    }
    if (aberta && intervir) {
        botoes.push(`<button class="btn btn-outline-warning btn-sm pill-btn btn-intervir" ${alvo}><i class="bi bi-shield-exclamation me-1"></i>Intervir</button>`);
    }
    const etapa = liberar
        ? 'Aguarda a liberação do setor de origem'
        : m.status === 'liberada' ? 'Liberada. Aguarda a confirmação do destino' : '';
    return `
        <div class="solicitacao border rounded-3 p-3 mb-3">
            <div class="d-flex justify-content-between flex-wrap gap-2">
                <div>
                    <div class="fw-semibold">${esc(m.bem_nome)} <code class="ms-1">${esc(m.codigo_tombamento)}</code>
                        ${m.escalada ? '<span class="badge rounded-pill bg-danger-subtle text-danger ms-2">Escalada</span>' : ''}</div>
                    <div class="small text-muted">${esc(m.setor_origem_nome || '—')} → <strong>${esc(m.setor_destino_nome)}</strong></div>
                    <div class="small text-muted">Solicitado por ${esc(m.solicitante_nome || '—')} em ${esc(data(m.data_movimentacao))}</div>
                    ${etapa ? `<div class="small fw-semibold mt-1">${esc(etapa)}</div>` : ''}
                </div>
                <span class="badge rounded-pill align-self-start ${classe}">${esc(texto)}</span>
            </div>
            <div class="mt-2 p-2 rounded-2" style="background: var(--bg-main);">
                <small class="text-muted d-block">Motivo da solicitação</small>
                <span>${esc(m.justificativa || '—')}</span>
            </div>
            ${botoes.length ? `<div class="d-flex flex-wrap gap-2 mt-3">${botoes.join('')}</div>` : ''}
        </div>`;
}

function cartaoMinha(m) {
    const [texto, classe] = ROTULO[m.status] || [m.status, 'bg-secondary-subtle'];
    let resultado = '';
    if (m.status === 'recusada' || m.status === 'cancelada') {
        const quem = m.status === 'cancelada' ? 'Cancelada' : 'Motivo da recusa';
        resultado = `<div class="mt-2 p-2 rounded-2 small" style="background: var(--danger-bg); color: var(--danger-text);">
            <strong>${quem}:</strong> ${esc(m.motivo_decisao || '—')}
            <div class="text-muted">por ${esc(m.decisor_nome || '—')} em ${esc(data(m.data_decisao))}</div></div>`;
    } else if (m.status === 'liberada') {
        resultado = `<div class="small text-muted mt-2">Liberada pelo setor de origem. Aguarda o recebimento no seu setor.</div>`;
    } else if (m.status === 'aprovada') {
        resultado = `<div class="small text-muted mt-2">Recebida e confirmada por ${esc(m.decisor_nome || '—')} em ${esc(data(m.data_decisao))}</div>`;
    }
    return `
        <div class="solicitacao border rounded-3 p-3 mb-3">
            <div class="d-flex justify-content-between flex-wrap gap-2">
                <div>
                    <div class="fw-semibold">${esc(m.bem_nome)} <code class="ms-1">${esc(m.codigo_tombamento)}</code></div>
                    <div class="small text-muted">${esc(m.setor_origem_nome || '—')} → ${esc(m.setor_destino_nome)} · ${esc(data(m.data_movimentacao))}</div>
                </div>
                <span class="badge rounded-pill align-self-start ${classe}">${esc(texto)}</span>
            </div>
            ${resultado}
        </div>`;
}

async function carregarDecidir() {
    const pendentes = await api.get('/api/v1/movimentacao/pendentes');
    $('#qtdDecidir').textContent = pendentes.length;
    $('#listaDecidir').innerHTML = pendentes.length
        ? pendentes.map(m => cartaoDecisao(m, { decidir: true, intervir: podeIntervir() })).join('')
        : '<p class="text-muted mb-0">Nenhuma transferência aguardando sua decisão.</p>';
}

async function carregarAcompanhamento() {
    const abertas = await api.get('/api/v1/movimentacao/acompanhamento');
    $('#qtdAcompanhamento').textContent = abertas.length;
    $('#listaAcompanhamento').innerHTML = abertas.length
        ? abertas.map(m => cartaoDecisao(m, { intervir: true })).join('')
        : '<p class="text-muted mb-0">Nenhuma transferência em andamento.</p>';
}

async function carregarEscaladas() {
    const escaladas = await api.get('/api/v1/movimentacao/escaladas');
    $('#qtdEscaladas').textContent = escaladas.length;
    $('#listaEscaladas').innerHTML = escaladas.length
        ? escaladas.map(m => cartaoDecisao(m, { decidir: true, intervir: true })).join('')
        : '<p class="text-muted mb-0">Nenhuma transferência escalada no momento.</p>';
}

async function carregarMinhas() {
    const minhas = await api.get('/api/v1/movimentacao/minhas');
    $('#listaMinhas').innerHTML = minhas.length
        ? minhas.map(cartaoMinha).join('')
        : '<p class="text-muted mb-0">Você ainda não fez solicitações de transferência.</p>';
}

async function atualizar() {
    const tarefas = [carregarMinhas()];
    if (!$('#itemAbaDecidir').classList.contains('d-none')) tarefas.push(carregarDecidir());
    if (!$('#itemAbaAcompanhamento').classList.contains('d-none')) tarefas.push(carregarAcompanhamento());
    if (!$('#itemAbaEscaladas').classList.contains('d-none')) tarefas.push(carregarEscaladas());
    await Promise.allSettled(tarefas);
    aplicarFiltroDaUrl();
}

// Links do painel inicial: ?aba=decidir|escaladas abre a aba; ?busca=<código> mostra só o bem pedido.
function parametrosDaUrl() {
    const params = new URLSearchParams(window.location.search);
    return { aba: params.get('aba'), busca: (params.get('busca') || '').trim().toUpperCase() };
}

function aplicarFiltroDaUrl() {
    const { busca } = parametrosDaUrl();
    document.querySelectorAll('#listaDecidir .solicitacao, #listaEscaladas .solicitacao, #listaAcompanhamento .solicitacao')
        .forEach(cartao => cartao.classList.toggle('d-none', !!busca && !cartao.textContent.toUpperCase().includes(busca)));
    const aviso = $('#contextoFiltro');
    if (busca) {
        aviso.innerHTML = `<i class="bi bi-funnel me-2"></i>Filtro do painel: bem ${esc(busca)} <a href="/movimentacao" class="ms-2 fw-semibold">Limpar</a>`;
        aviso.classList.remove('d-none');
    } else {
        aviso.classList.add('d-none');
    }
}

// Abre o mesmo modal para liberar (sem foto) ou confirmar recebimento (com foto).
function abrirLiberacao(id, resumo, etapa) {
    const liberar = etapa === 'liberar';
    $('#autorizarId').value = id;
    $('#autorizarEtapa').value = etapa;
    $('#autorizarResumo').textContent = resumo;
    $('#tituloAutorizar').textContent = liberar ? 'Liberar bem' : 'Confirmar recebimento';
    $('#grupoFoto').classList.toggle('d-none', liberar);
    $('#fotoRecebimento').required = !liberar;
    $('#fotoRecebimento').value = '';
    $('#btnConfirmarAutorizacao').textContent = liberar ? 'Liberar bem' : 'Enviar foto e confirmar';
    bootstrap.Modal.getOrCreateInstance($('#modalAutorizar')).show();
}

// Mesmo modal de motivo para recusar e para intervir.
function abrirMotivo(id, resumo, acao) {
    const intervir = acao === 'intervir';
    $('#recusaId').value = id;
    $('#recusaAcao').value = acao;
    $('#recusaResumo').textContent = resumo;
    $('#tituloRecusa').textContent = intervir ? 'Intervir na transferência' : 'Recusar transferência';
    $('#btnConfirmarRecusa').textContent = intervir ? 'Cancelar transferência' : 'Confirmar recusa';
    $('#motivoRecusa').placeholder = intervir
        ? 'Ex.: o bem não estava disponível para transferência'
        : 'Ex.: o bem está em uso no laboratório';
    bootstrap.Modal.getOrCreateInstance($('#modalRecusa')).show();
}

// Liberar ou confirmar recebimento. A foto é enviada antes da confirmação.
async function confirmarAutorizacao(evento) {
    evento.preventDefault();
    const id = $('#autorizarId').value;
    const etapa = $('#autorizarEtapa').value;
    const botao = $('#btnConfirmarAutorizacao');
    botao.disabled = true;
    try {
        if (etapa === 'receber') {
            const arquivo = $('#fotoRecebimento').files[0];
            if (!arquivo) throw new Error('A foto do recebimento é obrigatória.');
            const form = new FormData();
            form.append('arquivo', arquivo);
            form.append('registro_tipo', 'aceite_transferencia');
            form.append('registro_id', id);
            const envio = await fetch('/api/v1/fotos/', { method: 'POST', body: form, credentials: 'same-origin' });
            if (!envio.ok) {
                const erro = await envio.json().catch(() => ({}));
                throw new Error(erro.detail || 'Não foi possível enviar a foto.');
            }
        }
        await api.post(`/api/v1/movimentacao/${id}/aprovar`, {});
        bootstrap.Modal.getInstance($('#modalAutorizar'))?.hide();
        $('#formAutorizar').reset();
        ui.showNotification(etapa === 'liberar'
            ? 'Bem liberado. Aguarda a confirmação do destino.'
            : 'Recebimento confirmado com a foto.');
        await atualizar();
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    } finally {
        botao.disabled = false;
    }
}

// Recusa de quem decide, ou intervenção do almoxarifado. Ambas exigem motivo.
async function confirmarMotivo(evento) {
    evento.preventDefault();
    const motivo = $('#motivoRecusa').value.trim();
    if (motivo.length < 3) return;
    const intervir = $('#recusaAcao').value === 'intervir';
    try {
        await api.post(`/api/v1/movimentacao/${$('#recusaId').value}/${intervir ? 'intervir' : 'recusar'}`, { motivo });
        bootstrap.Modal.getInstance($('#modalRecusa'))?.hide();
        $('#formRecusa').reset();
        ui.showNotification(intervir
            ? 'Transferência cancelada. Os setores vão ver o motivo.'
            : 'Solicitação recusada. Quem pediu vai ver o motivo.');
        await atualizar();
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    }
}

// Solicitação de um bem de qualquer setor para o próprio setor.
async function confirmarSolicitacao(evento) {
    evento.preventDefault();
    const codigo = $('#solicitarCodigo').value.trim().toUpperCase();
    const motivo = $('#solicitarMotivo').value.trim();
    if (motivo.length < 3) return;
    const botao = $('#btnConfirmarSolicitacao');
    botao.disabled = true;
    try {
        const bem = await api.get(`/api/v1/bem/buscar?codigo_tombamento=${encodeURIComponent(codigo)}`);
        await api.post('/api/v1/movimentacao/', {
            bem_id: bem.id,
            setor_destino_id: eu.setor_id,
            justificativa: motivo,
        });
        bootstrap.Modal.getInstance($('#modalSolicitarBem'))?.hide();
        $('#formSolicitarBem').reset();
        ui.showNotification('Solicitação enviada ao responsável do setor onde o bem está.');
        await atualizar();
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    } finally {
        botao.disabled = false;
    }
}

document.addEventListener('DOMContentLoaded', async () => {
    try {
        await carregarPerfil();
        const decide = souResponsavel() || souPatrimonio();
        $('#itemAbaDecidir').classList.toggle('d-none', !decide);
        $('#itemAbaAcompanhamento').classList.toggle('d-none', !podeIntervir());
        $('#itemAbaEscaladas').classList.toggle('d-none', !souPatrimonio());
        $('#btnSolicitarBem').classList.toggle('d-none', !(eu.setor_id && !souPatrimonio()));
        if (!decide) $('#btnAbaMinhas').click();
        const { aba } = parametrosDaUrl();
        const botaoAba = aba ? document.querySelector(`[data-bs-target="#aba-${aba}"]`) : null;
        if (botaoAba && !botaoAba.parentElement.classList.contains('d-none')) {
            bootstrap.Tab.getOrCreateInstance(botaoAba).show();
        }

        $('#cardSolicitacoes').addEventListener('click', (e) => {
            const liberar = e.target.closest('.btn-liberar');
            const autorizar = e.target.closest('.btn-autorizar');
            const recusar = e.target.closest('.btn-recusar');
            const intervir = e.target.closest('.btn-intervir');
            if (liberar) abrirLiberacao(liberar.dataset.id, liberar.dataset.resumo, 'liberar');
            if (autorizar) abrirLiberacao(autorizar.dataset.id, autorizar.dataset.resumo, 'receber');
            if (recusar) abrirMotivo(recusar.dataset.id, recusar.dataset.resumo, 'recusar');
            if (intervir) abrirMotivo(intervir.dataset.id, intervir.dataset.resumo, 'intervir');
        });
        $('#formAutorizar').addEventListener('submit', confirmarAutorizacao);
        $('#formRecusa').addEventListener('submit', confirmarMotivo);
        $('#formSolicitarBem').addEventListener('submit', confirmarSolicitacao);
        await atualizar();
    } catch (erro) {
        console.warn('Solicitações indisponíveis:', erro);
    }
});
