import { $, api, ui, esc } from '/static/js/utils.js';

// Caixa de pendências: o que precisa de decisão do patrimônio. Resolver exige descrever o que foi feito.

const TIPO = {
    bem_nao_localizado: ['Não localizado', 'bi-question-circle', 'bg-danger-subtle text-danger'],
    bem_nao_cadastrado: ['Sem cadastro', 'bi-box-seam', 'bg-secondary-subtle text-secondary'],
    conflito_sincronizacao: ['Conflito de sincronização', 'bi-arrow-repeat', 'bg-warning-subtle text-warning-emphasis'],
    operacao_imprevista: ['Operação imprevista', 'bi-lightning', 'bg-warning-subtle text-warning-emphasis'],
    bem_baixado_encontrado: ['Baixado encontrado', 'bi-exclamation-diamond', 'bg-danger-subtle text-danger'],
};
const dataHoraBR = (valor) => new Date(valor).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });

let eu = null;
let selecionada = null;
let pendencias = [];
let acoesPorTipo = {};
let setoresAtivos = [];

async function carregar() {
    const corpo = $('#listaPendencias');
    try {
        pendencias = await api.get(`/api/v1/pendencias/?situacao=${$('#filtroPendencias').value}`);
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
        ? `<button class="btn btn-sm btn-outline-primary btn-resolver" data-id="${p.id}">Resolver</button>` : '';
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

// Ações guiadas por tipo (D6): cada ação pede só o que precisa para ser executada.
const CAMPOS_DA_ACAO = {
    encontrado: () => `<div class="mb-3"><label class="form-label fw-semibold" for="resolverSetor">Onde foi encontrado</label>
        <select class="form-select" id="resolverSetor" required><option value="">Escolha o setor</option>
        ${setoresAtivos.map(s => `<option value="${esc(s.id)}">${esc(s.nome)}</option>`).join('')}</select></div>`,
    baixa_extravio: () => `<div class="mb-3"><label class="form-label fw-semibold" for="resolverDocumento">Boletim de ocorrência</label>
        <input class="form-control" id="resolverDocumento" required minlength="3" maxlength="120" placeholder="Número do BO">
        <div class="form-text">A baixa segue a regra da alçada: acima do valor limite, aguarda outro servidor.</div></div>`,
    cadastrado: (p) => `<div class="alert alert-info small">Cadastre o bem na tela de Equipamentos; ao salvar, esta pendência é
        resolvida sozinha. <a class="fw-semibold" href="/bens?novo=1&pendencia=${p.id}&nome=${encodeURIComponent(p.descricao.split(':')[0].split(' (etiqueta')[0])}">Cadastrar agora</a></div>`,
};

async function abrirResolver(id) {
    const p = pendencias.find(x => String(x.id) === String(id));
    if (!p) return;
    selecionada = p;
    $('#resolverResumo').textContent = p.descricao;
    $('#formResolver').reset();
    $('#formResolver').classList.remove('was-validated');
    const acoes = acoesPorTipo[p.tipo] || {};
    $('#resolverAcoes').innerHTML = Object.entries(acoes).map(([chave, rotulo], i) => `
        <div class="form-check">
            <input class="form-check-input" type="radio" name="resolverAcao" id="acao-${chave}" value="${chave}" ${i === 0 ? 'checked' : ''}>
            <label class="form-check-label" for="acao-${chave}">${esc(rotulo)}</label>
        </div>`).join('');
    if ('encontrado' in acoes && !setoresAtivos.length) {
        try { setoresAtivos = (await api.get('/api/v1/setores/')).filter(s => s.ativo !== false); } catch (e) { /* lista vazia */ }
    }
    mostrarCamposDaAcao();
    bootstrap.Modal.getOrCreateInstance($('#modalResolver')).show();
}

function acaoEscolhida() {
    return document.querySelector('input[name="resolverAcao"]:checked')?.value;
}

function mostrarCamposDaAcao() {
    const acao = acaoEscolhida();
    $('#resolverExtra').innerHTML = CAMPOS_DA_ACAO[acao] ? CAMPOS_DA_ACAO[acao](selecionada) : '';
    // "Cadastrado" se resolve ao salvar o bem: aqui não há o que enviar.
    $('#formResolver button[type="submit"]').disabled = acao === 'cadastrado';
}

async function resolver(evento) {
    evento.preventDefault();
    const form = evento.target;
    if (!form.checkValidity()) {
        form.classList.add('was-validated');
        return;
    }
    const corpo = { acao: acaoEscolhida(), resolucao: $('#resolverTexto').value.trim() };
    if ($('#resolverSetor')) corpo.setor_id = Number($('#resolverSetor').value);
    if ($('#resolverDocumento')) corpo.documento = $('#resolverDocumento').value.trim();
    try {
        await api.post(`/api/v1/pendencias/${selecionada.id}/resolver`, corpo);
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
        if (botao) abrirResolver(botao.dataset.id);
    });
    $('#formResolver').addEventListener('submit', resolver);
    $('#resolverAcoes').addEventListener('change', mostrarCamposDaAcao);
    try { acoesPorTipo = await api.get('/api/v1/pendencias/acoes'); } catch (erro) { /* sem ações, sem resolução */ }
    await carregar();
});
