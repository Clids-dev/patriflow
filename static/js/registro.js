import { $, api, ui, esc } from '/static/js/utils.js';

// Registro de um cadastro com abas: dados (editáveis), bens ligados e uma aba de ação específica.
// Cada entidade declara seus campos e suas ações; o restante é comum.
const area = $('#registro');
const entidade = area?.dataset.entidade;
const id = area?.dataset.id;
const moeda = (v) => Number(v || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });

const ENTIDADES = {
    responsavel: {
        rotulo: 'Responsável',
        lista: '/responsaveis',
        subtitulo: (r) => r.cargo,
        titulo: (r) => r.nome,
        status: (r) => (r.ativo ? ['Ativo', 'bg-success-subtle text-success'] : ['Inativo', 'bg-danger-subtle text-danger']),
        carregar: () => api.get(`/api/v1/responsavel/${id}/`),
        bens: () => api.get(`/api/v1/responsavel/${id}/bens`),
        campos: () => [
            { nome: 'nome', rotulo: 'Nome completo', obrigatorio: true },
            { nome: 'cargo', rotulo: 'Cargo', obrigatorio: true },
        ],
        salvar: (dados) => api.put(`/api/v1/responsavel/?id=${id}`, { nome: dados.nome, cargo: dados.cargo }),
        acao: {
            titulo: 'Termo de responsabilidade',
            html: () => `
                <p class="text-muted">O termo lista os bens sob a guarda deste responsável, com campos para assinatura.</p>
                <button class="btn btn-primary" id="btnAcao"><i class="bi bi-file-earmark-text me-1"></i> Gerar termo</button>`,
            evento: () => window.open(`/api/v1/termos/responsavel/${id}`, '_blank', 'noopener'),
        },
    },

    setor: {
        rotulo: 'Setor',
        lista: '/setores',
        subtitulo: (r) => [r.predio_nome, r.andar_identificacao, r.sala_nome].filter(Boolean).join(' — ') || 'Sem sala',
        titulo: (r) => r.nome,
        status: (r) => (r.ativo ? ['Ativo', 'bg-success-subtle text-success'] : ['Inativo', 'bg-danger-subtle text-danger']),
        carregar: () => api.get(`/api/v1/setores/${id}/`),
        bens: () => api.get(`/api/v1/bem/setor/${id}`),
        campos: async (registro) => {
            const [responsaveis, salas] = await Promise.all([api.get('/api/v1/responsavel/'), api.get('/api/v1/localizacao/salas')]);
            return [
                { nome: 'nome', rotulo: 'Nome do setor', obrigatorio: true },
                {
                    nome: 'responsavel_id', rotulo: 'Responsável', tipo: 'select', obrigatorio: true,
                    opcoes: responsaveis.filter(r => r.ativo).map(r => ({ valor: r.id, texto: r.nome })),
                    valor: registro.responsavel_id,
                },
                {
                    nome: 'sala_id', rotulo: 'Sala', tipo: 'select', obrigatorio: true,
                    opcoes: salas.map(s => ({ valor: s.id, texto: `${s.predio_nome} — ${s.andar_identificacao} — ${s.identificacao}` })),
                    valor: registro.sala_id,
                },
            ];
        },
        salvar: (dados) => api.put(
            `/api/v1/setores/${id}?novo_nome=${encodeURIComponent(dados.nome)}&novo_responsavel_id=${dados.responsavel_id}&novo_sala_id=${dados.sala_id}`),
        acao: {
            titulo: 'Etiquetas',
            html: (bens) => `
                <p class="text-muted">Gera uma folha com as etiquetas de todos os ${bens.length} bens ativos deste setor.</p>
                <button class="btn btn-primary" id="btnAcao" ${bens.length ? '' : 'disabled'}><i class="bi bi-qr-code me-1"></i> Gerar etiquetas do setor</button>`,
            evento: (bens) => window.open(`/api/v1/etiquetas/lote?ids=${bens.map(b => encodeURIComponent(b.id)).join(',')}`, '_blank', 'noopener'),
        },
    },

    categoria: {
        rotulo: 'Categoria',
        lista: '/categoria',
        subtitulo: (r) => `Sigla ${r.sigla}`,
        titulo: (r) => r.nome,
        status: (r) => (r.ativo ? ['Ativa', 'bg-success-subtle text-success'] : ['Inativa', 'bg-danger-subtle text-danger']),
        carregar: () => api.get(`/api/v1/categoria/${id}/`),
        bens: () => api.get(`/api/v1/categoria/${id}/bens`),
        campos: () => [
            { nome: 'nome', rotulo: 'Nome da categoria', obrigatorio: true },
            { nome: 'sigla', rotulo: 'Sigla (não pode ser alterada)', somenteLeitura: true, ajuda: 'A sigla já foi usada nos tombos existentes.' },
        ],
        salvar: (dados) => api.put(`/api/v1/categoria/?id=${id}&novo_nome=${encodeURIComponent(dados.nome)}`),
        acao: {
            titulo: 'Tombamento',
            html: (bens, extra) => `
                <p class="text-muted">Próximo número de tombo para esta categoria:</p>
                <p class="fs-4 fw-bold"><code>${esc(extra.proximo || '--')}</code></p>
                <p class="text-muted small">Os números são sequenciais por sigla e nunca são reaproveitados, mesmo de bens baixados.</p>`,
            evento: () => {},
            carregarExtra: async (registro) => ({ proximo: await api.get(`/api/v1/bem/proximo-codigo/${id}`) }),
        },
    },
};

const cfg = ENTIDADES[entidade];
let registro = null;
let bens = [];

function mostrarMensagem(texto, tipo = 'success') {
    $('#msgRegistro').innerHTML = `<div class="alert alert-${tipo}">${esc(texto)}</div>`;
}

function preencherCabecalho() {
    $('#registroRotulo').textContent = cfg.rotulo;
    $('#btnVerLista').href = cfg.lista;
    $('#btnCadastrarNovo').href = `${cfg.lista}?novo=1`;
    $('#registroTitulo').textContent = cfg.titulo(registro);
    $('#registroSubtitulo').textContent = cfg.subtitulo(registro);
    const [texto, classes] = cfg.status(registro);
    const badge = $('#registroStatus');
    badge.textContent = texto;
    badge.className = `badge rounded-pill ${classes}`;
    $('#kpiSituacao').textContent = texto;
    document.title = `PatriFlow - ${cfg.titulo(registro)}`;
}

function desenharCampos(campos) {
    const form = $('#formRegistro');
    form.innerHTML = campos.map(c => {
        const valorAtual = c.valor ?? registro[c.nome] ?? '';
        const rotulo = `<label class="form-label fw-semibold" for="campo-${c.nome}">${esc(c.rotulo)}</label>`;
        if (c.tipo === 'select') {
            const opcoes = c.opcoes.map(o => `<option value="${esc(o.valor)}" ${String(o.valor) === String(valorAtual) ? 'selected' : ''}>${esc(o.texto)}</option>`).join('');
            return `<div class="col-12 col-md-6">${rotulo}<select class="form-select" id="campo-${c.nome}" name="${c.nome}" ${c.obrigatorio ? 'required' : ''}>
                        <option value="">Selecione…</option>${opcoes}</select></div>`;
        }
        const ajuda = c.ajuda ? `<div class="form-text">${esc(c.ajuda)}</div>` : '';
        return `<div class="col-12 col-md-6">${rotulo}<input class="form-control" id="campo-${c.nome}" name="${c.nome}"
                    value="${esc(valorAtual)}" ${c.obrigatorio ? 'required' : ''} ${c.somenteLeitura ? 'readonly' : ''}>${ajuda}</div>`;
    }).join('') + `
        <div class="col-12 d-flex justify-content-end">
            <button type="submit" class="btn btn-primary px-4" id="btnSalvarRegistro">Salvar alterações</button>
        </div>`;
}

function desenharBens() {
    $('#qtdBensAba').textContent = bens.length;
    $('#kpiBens').textContent = bens.length;
    const valor = bens.reduce((soma, b) => soma + Number(b.valor_aquisicao || 0), 0);
    $('#kpiValor').textContent = moeda(valor);
    const corpo = $('#tbodyBens');
    if (!bens.length) {
        corpo.innerHTML = '<tr><td colspan="5" class="text-center text-muted py-4">Nenhum bem ligado a este cadastro.</td></tr>';
        return;
    }
    corpo.innerHTML = bens.map(b => `
        <tr>
            <td><code>${esc(b.codigo_tombamento)}</code></td>
            <td class="fw-semibold">${esc(b.nome)}</td>
            <td>${esc(b.status)}</td>
            <td>${esc(b.setor || '—')}</td>
            <td class="text-end">${moeda(b.valor_aquisicao)}</td>
        </tr>`).join('');
}

async function desenharAcao() {
    $('#tituloAbaAcao').textContent = cfg.acao.titulo;
    let extra = {};
    if (cfg.acao.carregarExtra) {
        try { extra = await cfg.acao.carregarExtra(registro); } catch (e) { console.warn(e); }
    }
    $('#conteudoAcao').innerHTML = cfg.acao.html(bens, extra);
    $('#btnAcao')?.addEventListener('click', () => cfg.acao.evento(bens));
}

async function iniciar() {
    if (!cfg) {
        $('#registroTitulo').textContent = 'Cadastro não encontrado';
        return;
    }
    try {
        registro = await cfg.carregar();
    } catch (erro) {
        ui.showNotification(`Não foi possível abrir este cadastro: ${erro.message}`, 'error');
        $('#registroTitulo').textContent = 'Cadastro não encontrado';
        return;
    }
    preencherCabecalho();

    const campos = await cfg.campos(registro);
    desenharCampos(campos);

    try {
        bens = await cfg.bens();
    } catch (erro) {
        bens = [];
        console.warn('Bens ligados indisponíveis:', erro);
    }
    desenharBens();
    await desenharAcao();

    $('#formRegistro').addEventListener('submit', async (evento) => {
        evento.preventDefault();
        const form = evento.target;
        if (!form.reportValidity()) return;
        const dados = Object.fromEntries(new FormData(form).entries());
        const botao = $('#btnSalvarRegistro');
        botao.disabled = true;
        try {
            await cfg.salvar(dados);
            registro = await cfg.carregar();
            preencherCabecalho();
            mostrarMensagem('Alterações salvas.');
        } catch (erro) {
            mostrarMensagem(erro.message || 'Não foi possível salvar.', 'danger');
        } finally {
            botao.disabled = false;
        }
    });
}

document.addEventListener('DOMContentLoaded', iniciar);
