import { $, api, ui, esc } from '/static/js/utils.js';

// Caixa de pendências: o que precisa de decisão do patrimônio. Resolver exige descrever o que foi feito.

const TIPO = {
    bem_nao_localizado: ['Não localizado', 'bi-question-circle', 'bg-danger-subtle text-danger'],
    bem_nao_cadastrado: ['Sem cadastro', 'bi-box-seam', 'bg-secondary-subtle text-secondary'],
    conflito_sincronizacao: ['Conflito de sincronização', 'bi-arrow-repeat', 'bg-warning-subtle text-warning-emphasis'],
};
const dataHoraBR = (valor) => new Date(valor).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });

let eu = null;
let selecionada = null;

async function carregar() {
    const corpo = $('#listaPendencias');
    try {
        const pendencias = await api.get(`/api/v1/pendencias/?situacao=${$('#filtroPendencias').value}`);
        corpo.innerHTML = pendencias.length ? pendencias.map(linha).join('')
            : '<tr><td colspan="6" class="text-center text-muted py-4">Nada pendente aqui.</td></tr>';
    } catch (erro) {
        corpo.innerHTML = `<tr><td colspan="6" class="text-center text-danger py-4">${esc(erro.message)}</td></tr>`;
    }
}

const origem = (p) => p.inventario_id ? `Inventário #${p.inventario_id}`
    : p.sync_operacao_id ? 'Sincronização do aplicativo' : '—';

function linha(p) {
    const [rotulo, icone, classe] = TIPO[p.tipo] || [p.tipo, 'bi-dot', 'bg-light text-dark'];
    const fotos = p.fotos.map((id, i) =>
        `<a href="/api/v1/fotos/${id}" target="_blank" rel="noopener" class="small me-2"><i class="bi bi-image me-1"></i>Foto ${i + 1}</a>`).join('');
    const situacao = p.resolvida_em
        ? `<span class="badge bg-success-subtle text-success rounded-pill">Resolvida</span>
           <div class="small text-muted">${esc(p.resolucao)} · ${esc(p.resolvida_por || '')}, ${dataHoraBR(p.resolvida_em)}</div>`
        : '<span class="badge bg-warning-subtle text-warning-emphasis rounded-pill">Aberta</span>';
    const acao = !p.resolvida_em && eu.perfil === 'setor_patrimonio'
        ? `<button class="btn btn-sm btn-outline-primary btn-resolver" data-id="${p.id}" data-resumo="${esc(p.descricao)}">Resolver</button>` : '';
    return `
        <tr>
            <td class="ps-4"><span class="badge rounded-pill ${classe}"><i class="bi ${icone} me-1"></i>${rotulo}</span></td>
            <td>${esc(p.descricao)}${fotos ? `<div>${fotos}</div>` : ''}</td>
            <td class="small">${esc(p.setor_nome || '—')}</td>
            <td class="small">${origem(p)}<div class="text-muted">${esc(p.criada_por || '')} · ${dataHoraBR(p.criada_em)}</div></td>
            <td>${situacao}</td>
            <td class="pe-4 acoes-tabela">${acao}</td>
        </tr>`;
}

function abrirResolver({ id, resumo }) {
    selecionada = id;
    $('#resolverResumo').textContent = resumo;
    $('#formResolver').reset();
    $('#formResolver').classList.remove('was-validated');
    bootstrap.Modal.getOrCreateInstance($('#modalResolver')).show();
}

async function resolver(evento) {
    evento.preventDefault();
    const form = evento.target;
    if (!form.checkValidity()) {
        form.classList.add('was-validated');
        return;
    }
    try {
        await api.post(`/api/v1/pendencias/${selecionada}/resolver`, { resolucao: $('#resolverTexto').value.trim() });
        bootstrap.Modal.getInstance($('#modalResolver')).hide();
        ui.showNotification('Pendência resolvida.', 'success');
        await carregar();
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    }
}

document.addEventListener('DOMContentLoaded', async () => {
    eu = await api.get('/api/v1/auth/me');
    $('#filtroPendencias').addEventListener('change', carregar);
    $('#listaPendencias').addEventListener('click', (e) => {
        const botao = e.target.closest('.btn-resolver');
        if (botao) abrirResolver(botao.dataset);
    });
    $('#formResolver').addEventListener('submit', resolver);
    await carregar();
});
