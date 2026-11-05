import { $, api, ui, esc } from '/static/js/utils.js';

// Solicitações de transferência (W06): quem decide, quem pediu e o resultado com o motivo.
const ROTULO = {
    pendente: ['Aguardando autorização', 'bg-warning-subtle text-warning-emphasis'],
    aprovada: ['Autorizada', 'bg-success-subtle text-success'],
    recusada: ['Recusada', 'bg-danger-subtle text-danger'],
};
const data = (valor) => (valor ? new Date(valor).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : '—');

async function podeDecidir() {
    const eu = await api.get('/api/v1/auth/me');
    if (eu.perfil === 'setor_patrimonio') return true;
    if (eu.perfil !== 'responsavel_setor') return false;
    const setores = await api.get('/api/v1/setores/');
    const almox = setores.find(s => s.flag_almoxarifado);
    return Boolean(almox && eu.setor_id === almox.id);
}

function cartaoDecisao(m) {
    return `
        <div class="solicitacao border rounded-3 p-3 mb-3">
            <div class="d-flex justify-content-between flex-wrap gap-2">
                <div>
                    <div class="fw-semibold">${esc(m.bem_nome)} <code class="ms-1">${esc(m.codigo_tombamento)}</code>
                        ${m.escalada ? '<span class="badge rounded-pill bg-danger-subtle text-danger ms-2">Escalada</span>' : ''}</div>
                    <div class="small text-muted">${esc(m.setor_origem_nome || 'Almoxarifado')} → <strong>${esc(m.setor_destino_nome)}</strong></div>
                    <div class="small text-muted">Solicitado por ${esc(m.solicitante_nome || '—')} em ${esc(data(m.data_movimentacao))}</div>
                </div>
            </div>
            <div class="mt-2 p-2 rounded-2" style="background: var(--bg-main);">
                <small class="text-muted d-block">Motivo da solicitação</small>
                <span>${esc(m.justificativa || '—')}</span>
            </div>
            <div class="d-flex gap-2 mt-3">
                <button class="btn btn-primary btn-sm pill-btn btn-autorizar" data-id="${esc(m.id)}" data-resumo="${esc(`${m.bem_nome} → ${m.setor_destino_nome}`)}"><i class="bi bi-camera me-1"></i>Autorizar com foto</button>
                <button class="btn btn-outline-danger btn-sm pill-btn btn-recusar" data-id="${esc(m.id)}"
                    data-resumo="${esc(`${m.bem_nome} → ${m.setor_destino_nome}`)}"><i class="bi bi-x-lg me-1"></i>Recusar</button>
            </div>
        </div>`;
}

function cartaoMinha(m) {
    const [texto, classe] = ROTULO[m.status] || [m.status, 'bg-secondary-subtle'];
    let resultado = '';
    if (m.status === 'recusada') {
        resultado = `<div class="mt-2 p-2 rounded-2 small" style="background: var(--danger-bg); color: var(--danger-text);">
            <strong>Motivo da recusa:</strong> ${esc(m.motivo_decisao || '—')}
            <div class="text-muted">por ${esc(m.decisor_nome || '—')} em ${esc(data(m.data_decisao))}</div></div>`;
    } else if (m.status === 'aprovada') {
        resultado = `<div class="small text-muted mt-2">Autorizada por ${esc(m.decisor_nome || '—')} em ${esc(data(m.data_decisao))}</div>`;
    }
    return `
        <div class="solicitacao border rounded-3 p-3 mb-3">
            <div class="d-flex justify-content-between flex-wrap gap-2">
                <div>
                    <div class="fw-semibold">${esc(m.bem_nome)} <code class="ms-1">${esc(m.codigo_tombamento)}</code></div>
                    <div class="small text-muted">${esc(m.setor_origem_nome || 'Almoxarifado')} → ${esc(m.setor_destino_nome)} · ${esc(data(m.data_movimentacao))}</div>
                </div>
                <span class="badge rounded-pill align-self-start ${classe}">${esc(texto)}</span>
            </div>
            ${resultado}
        </div>`;
}

async function carregarDecidir() {
    const lista = $('#listaDecidir');
    const pendentes = await api.get('/api/v1/movimentacao/pendentes');
    $('#qtdDecidir').textContent = pendentes.length;
    lista.innerHTML = pendentes.length
        ? pendentes.map(cartaoDecisao).join('')
        : '<p class="text-muted mb-0">Nenhuma solicitação aguardando sua decisão.</p>';
}

async function carregarMinhas() {
    const lista = $('#listaMinhas');
    const minhas = await api.get('/api/v1/movimentacao/minhas');
    lista.innerHTML = minhas.length
        ? minhas.map(cartaoMinha).join('')
        : '<p class="text-muted mb-0">Você ainda não fez solicitações de transferência.</p>';
}

async function atualizar() {
    await Promise.allSettled([carregarMinhas(), $('#itemAbaDecidir').classList.contains('d-none') ? null : carregarDecidir()]);
}

// Autorizar exige a foto do recebimento: envia a foto primeiro e só então autoriza.
async function autorizar(evento) {
    evento.preventDefault();
    const id = $('#autorizarId').value;
    const arquivo = $('#fotoRecebimento').files[0];
    if (!arquivo) return;
    const botao = $('#btnConfirmarAutorizacao');
    botao.disabled = true;
    try {
        const form = new FormData();
        form.append('arquivo', arquivo);
        form.append('registro_tipo', 'aceite_transferencia');
        form.append('registro_id', id);
        const envio = await fetch('/api/v1/fotos/', { method: 'POST', body: form, credentials: 'same-origin' });
        if (!envio.ok) {
            const erro = await envio.json().catch(() => ({}));
            throw new Error(erro.detail || 'Não foi possível enviar a foto.');
        }
        await api.post(`/api/v1/movimentacao/${id}/aprovar`, {});
        bootstrap.Modal.getInstance($('#modalAutorizar'))?.hide();
        $('#formAutorizar').reset();
        ui.showNotification('Transferência autorizada com a foto do recebimento.');
        await atualizar();
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    } finally {
        botao.disabled = false;
    }
}

async function confirmarRecusa(evento) {
    evento.preventDefault();
    const motivo = $('#motivoRecusa').value.trim();
    if (motivo.length < 3) return;
    try {
        await api.post(`/api/v1/movimentacao/${$('#recusaId').value}/recusar`, { motivo });
        bootstrap.Modal.getInstance($('#modalRecusa'))?.hide();
        $('#formRecusa').reset();
        ui.showNotification('Solicitação recusada. Quem pediu vai ver o motivo.');
        await atualizar();
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    }
}

document.addEventListener('DOMContentLoaded', async () => {
    try {
        const decide = await podeDecidir();
        $('#itemAbaDecidir').classList.toggle('d-none', !decide);
        if (!decide) {
            $('#btnAbaMinhas').click();
        }
        $('#cardSolicitacoes').addEventListener('click', (e) => {
            const autorizarBotao = e.target.closest('.btn-autorizar');
            if (autorizarBotao) {
                $('#autorizarId').value = autorizarBotao.dataset.id;
                $('#autorizarResumo').textContent = autorizarBotao.dataset.resumo;
                bootstrap.Modal.getOrCreateInstance($('#modalAutorizar')).show();
            }
            const recusarBotao = e.target.closest('.btn-recusar');
            if (recusarBotao) {
                $('#recusaId').value = recusarBotao.dataset.id;
                $('#recusaResumo').textContent = recusarBotao.dataset.resumo;
                bootstrap.Modal.getOrCreateInstance($('#modalRecusa')).show();
            }
        });
        $('#formRecusa').addEventListener('submit', confirmarRecusa);
        $('#formAutorizar').addEventListener('submit', autorizar);
        await atualizar();
    } catch (erro) {
        console.warn('Solicitações indisponíveis:', erro);
    }
});
