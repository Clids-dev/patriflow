import { $, api, ui, esc } from '/static/js/utils.js';

// Inventários: abertura (lista congelada), conferência por leitura da etiqueta, faltantes e fechamento.
// A API valida todas as regras e permissões; a tela só organiza o trabalho.

const SITUACAO = {
    localizado: ['Localizado', 'bg-success-subtle text-success'],
    outro_setor: ['Em outro setor', 'bg-warning-subtle text-warning-emphasis'],
    nao_localizado: ['Não localizado', 'bg-danger-subtle text-danger'],
    nao_cadastrado: ['Não cadastrado', 'bg-secondary-subtle text-secondary'],
};
const JUSTIFICATIVA = { emprestado: 'emprestado', manutencao: 'em manutenção' };

const dataBR = (valor) => new Date(`${valor}T00:00:00`).toLocaleDateString('pt-BR');
const dataHoraBR = (valor) => new Date(valor).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
const hojeISO = () => new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 10);

let eu = null;
let atual = null;  // inventário aberto no modal

const souPatrimonio = () => eu?.perfil === 'setor_patrimonio';

// ----- Lista e indicadores ---------------------------------------------------------------------

async function carregarLista() {
    const filtro = $('#filtroInventarios').value;
    const corpo = $('#listaInventarios');
    try {
        const inventarios = await api.get(`/api/v1/inventarios/?situacao=${filtro}`);
        corpo.innerHTML = inventarios.length ? inventarios.map(linhaInventario).join('')
            : '<tr><td colspan="6" class="text-center text-muted py-4">Nenhum inventário nesta situação.</td></tr>';
    } catch (erro) {
        corpo.innerHTML = '<tr><td colspan="6" class="text-center text-danger py-4">Não foi possível carregar os inventários.</td></tr>';
    }
}

function linhaInventario(inv) {
    const conferidos = inv.total_itens - inv.pendentes;
    const pct = inv.total_itens ? Math.round((conferidos / inv.total_itens) * 100) : 100;
    const badge = inv.status === 'aberto'
        ? '<span class="badge bg-primary-subtle text-primary rounded-pill">Aberto</span>'
        : '<span class="badge bg-secondary-subtle text-secondary rounded-pill">Fechado</span>';
    return `
        <tr>
            <td class="ps-4">#${inv.id}</td>
            <td class="fw-semibold">${esc(inv.descricao)}</td>
            <td class="small">${dataBR(inv.inicio)} a ${dataBR(inv.fim)}</td>
            <td style="min-width: 160px;">
                <div class="progress" style="height: 6px;" role="progressbar" aria-label="Andamento"
                     aria-valuenow="${pct}" aria-valuemin="0" aria-valuemax="100">
                    <div class="progress-bar" style="width: ${pct}%"></div>
                </div>
                <small class="text-muted">${conferidos} de ${inv.total_itens} conferidos</small>
            </td>
            <td>${badge}</td>
            <td class="text-end pe-4">
                <button class="btn btn-sm btn-outline-primary btn-abrir-inventario" data-id="${inv.id}">
                    ${inv.status === 'aberto' ? 'Conferir' : 'Ver resultado'}
                </button>
            </td>
        </tr>`;
}

async function carregarIndicadores() {
    const [abertos, pendencias] = await Promise.allSettled([
        api.get('/api/v1/inventarios/?situacao=abertos'),
        api.get('/api/v1/pendencias/?situacao=abertas'),
    ]);
    $('#kpiAbertos').textContent = abertos.status === 'fulfilled' ? abertos.value.length : '--';
    $('#kpiAConferir').textContent = abertos.status === 'fulfilled'
        ? abertos.value.reduce((soma, inv) => soma + inv.pendentes, 0) : '--';
    // Pendências são do patrimônio e do auditor; para os demais perfis a API responde 403.
    $('#kpiPendencias').textContent = pendencias.status === 'fulfilled' ? pendencias.value.length : '--';
}

// ----- Abertura --------------------------------------------------------------------------------

async function abrirNovo() {
    const form = $('#formNovoInventario');
    form.reset();
    form.classList.remove('was-validated');
    $('#invInicio').value = hojeISO();
    $('#invFim').value = hojeISO();
    const setores = (await api.get('/api/v1/setores/')).filter(s => s.ativo !== false);
    $('#listaSetoresInventario').innerHTML = setores.map(s => `
        <div class="col-12 col-md-6">
            <div class="form-check">
                <input class="form-check-input setor-inventario" type="checkbox" value="${s.id}" id="setorInv${s.id}">
                <label class="form-check-label" for="setorInv${s.id}">${esc(s.nome)}</label>
            </div>
        </div>`).join('');
    bootstrap.Modal.getOrCreateInstance($('#modalNovoInventario')).show();
}

async function confirmarNovo(evento) {
    evento.preventDefault();
    const form = evento.target;
    const setores = [...document.querySelectorAll('.setor-inventario:checked')].map(c => Number(c.value));
    if (!form.checkValidity() || !setores.length) {
        form.classList.add('was-validated');
        if (!setores.length) ui.showNotification('Escolha ao menos um setor.', 'error');
        return;
    }
    try {
        const inv = await api.post('/api/v1/inventarios/', {
            descricao: $('#invDescricao').value.trim(), inicio: $('#invInicio').value, fim: $('#invFim').value,
            setor_ids: setores,
        });
        bootstrap.Modal.getInstance($('#modalNovoInventario')).hide();
        ui.showNotification(`Inventário #${inv.id} aberto com ${inv.total_itens} bens esperados.`, 'success');
        await Promise.all([carregarLista(), carregarIndicadores()]);
        abrirInventario(inv.id);
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    }
}

// ----- Andamento e conferência -----------------------------------------------------------------

async function abrirInventario(id) {
    $('#resumoFechamento').classList.add('d-none');
    $('#confRetorno').textContent = '';
    $('#filtroItens').value = 'todos';
    bootstrap.Modal.getOrCreateInstance($('#modalInventario')).show();
    await recarregarInventario(id);
    focarLeitura();
}

// Pronto para o leitor de etiquetas. Chamado também quando o modal termina de abrir, porque o
// Bootstrap move o foco para a janela nesse momento.
function focarLeitura() {
    if (atual?.status === 'aberto' && $('#modalInventario').classList.contains('show')) $('#confTombo').focus();
}

async function recarregarInventario(id = atual?.id) {
    atual = await api.get(`/api/v1/inventarios/${id}`);
    const aberto = atual.status === 'aberto';
    $('#tituloInventario').textContent = `#${atual.id} · ${atual.descricao}`;
    $('#resumoSetores').innerHTML = atual.setores.map(cartaoSetor).join('');
    $('#areaConferencia').classList.toggle('d-none', !aberto);
    $('#btnFecharInventario')?.classList.toggle('d-none', !aberto);

    // Colaboradores conferem só no próprio setor; o patrimônio escolhe.
    const setores = souPatrimonio() ? atual.setores : atual.setores.filter(s => s.setor_id === eu.setor_id);
    const escolhido = $('#confSetor').value;
    $('#confSetor').innerHTML = setores.map(s => `<option value="${s.setor_id}">${esc(s.setor_nome)}</option>`).join('');
    if (setores.some(s => String(s.setor_id) === escolhido)) $('#confSetor').value = escolhido;
    await carregarItens();
}

function cartaoSetor(s) {
    const pct = s.esperados ? Math.round((s.conferidos / s.esperados) * 100) : 100;
    const podeMarcar = atual.status === 'aberto' && s.pendentes > 0 && (souPatrimonio() || eu.setor_id === s.setor_id);
    return `
        <div class="col-12 col-md-6 col-xl-4">
            <div class="p-3 border rounded-3 h-100">
                <div class="d-flex justify-content-between align-items-start gap-2">
                    <strong>${esc(s.setor_nome)}</strong>
                    <span class="small text-muted">${s.conferidos}/${s.esperados}</span>
                </div>
                <div class="progress my-2" style="height: 6px;" role="progressbar" aria-label="Conferidos em ${esc(s.setor_nome)}"
                     aria-valuenow="${pct}" aria-valuemin="0" aria-valuemax="100">
                    <div class="progress-bar" style="width: ${pct}%"></div>
                </div>
                <div class="small text-muted">
                    ${s.localizados} localizados · ${s.outro_setor} em outro setor · ${s.nao_localizados} não localizados
                    ${s.nao_cadastrados ? ` · ${s.nao_cadastrados} sem cadastro` : ''}
                </div>
                ${podeMarcar ? `<button class="btn btn-link btn-sm px-0 mt-1 btn-faltantes" data-setor="${s.setor_id}"
                    data-nome="${esc(s.setor_nome)}" data-qtd="${s.pendentes}">Encerrar contagem do setor</button>` : ''}
            </div>
        </div>`;
}

async function carregarItens() {
    const itens = await api.get(`/api/v1/inventarios/${atual.id}/itens?filtro=${$('#filtroItens').value}`);
    const aberto = atual.status === 'aberto';
    $('#listaItens').innerHTML = itens.length ? itens.map(item => {
        const [rotulo, classe] = SITUACAO[item.situacao] || ['A conferir', 'bg-light text-dark border'];
        const onde = item.situacao === 'outro_setor' ? ` → ${esc(item.setor_encontrado)}` : '';
        const justificativa = item.ausencia_justificada
            ? `<div class="small text-muted">${JUSTIFICATIVA[item.ausencia_justificada]}</div>` : '';
        const podeMarcar = aberto && !item.situacao && (souPatrimonio() || eu.setor_id === item.setor_esperado_id);
        return `
            <tr>
                <td class="text-nowrap"><code>${esc(item.codigo_tombamento || '—')}</code></td>
                <td>${esc(item.nome)}${justificativa}</td>
                <td class="small">${esc(item.setor_esperado || '—')}</td>
                <td><span class="badge rounded-pill ${classe}">${rotulo}</span><span class="small">${onde}</span></td>
                <td class="small text-muted">${item.conferido_em ? `${dataHoraBR(item.conferido_em)} · ${esc(item.conferido_por || '')}` : '—'}</td>
                <td class="text-end">${podeMarcar
                    ? `<button class="btn btn-sm btn-light btn-nao-localizado" data-id="${item.id}">Não localizado</button>` : ''}</td>
            </tr>`;
    }).join('') : '<tr><td colspan="6" class="text-center text-muted py-3">Nenhum item neste filtro.</td></tr>';
}

async function conferir(evento) {
    evento.preventDefault();
    const campo = $('#confTombo');
    const codigo = campo.value.trim();
    if (!codigo) return;
    const retorno = $('#confRetorno');
    try {
        const item = await api.post(`/api/v1/inventarios/${atual.id}/conferencias`, {
            setor_id: Number($('#confSetor').value), codigo_tombamento: codigo,
            estado_encontrado: $('#confEstado').value || null,
        });
        retorno.className = item.situacao === 'localizado' ? 'small mt-2 text-success' : 'small mt-2 text-warning-emphasis';
        retorno.innerHTML = item.situacao === 'localizado'
            ? `<i class="bi bi-check-circle-fill me-1"></i>${esc(item.nome)}: localizado.`
            : `<i class="bi bi-signpost-split me-1"></i>${esc(item.nome)}: era esperado em ${esc(item.setor_esperado || 'outro local')}.`;
        await recarregarInventario();
    } catch (erro) {
        retorno.className = 'small mt-2 text-danger';
        retorno.innerHTML = `<i class="bi bi-exclamation-circle me-1"></i>${esc(codigo)}: ${esc(erro.message)}`;
        if (erro.status === 404) {
            $('#formNaoCadastrado').classList.remove('d-none');
            $('#ncCodigo').value = '';
        }
    }
    // Pronto para a próxima leitura (leitores de etiqueta digitam o código e teclam Enter).
    campo.value = '';
    campo.focus();
}

async function registrarNaoCadastrado(evento) {
    evento.preventDefault();
    const form = evento.target;
    if (!form.checkValidity()) {
        form.classList.add('was-validated');
        return;
    }
    try {
        await api.post(`/api/v1/inventarios/${atual.id}/nao-cadastrados`, {
            setor_id: Number($('#confSetor').value), descricao: $('#ncDescricao').value.trim(),
            codigo_lido: $('#ncCodigo').value.trim() || null,
        });
        form.reset();
        form.classList.remove('was-validated');
        form.classList.add('d-none');
        ui.showNotification('Bem sem cadastro registrado.', 'success');
        await recarregarInventario();
        $('#confTombo').focus();
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    }
}

async function marcarFaltantes({ setor, nome, qtd }) {
    if (!confirm(`Encerrar a contagem de ${nome}? Os ${qtd} bem(ns) ainda não lidos serão marcados como não localizados.`)) return;
    try {
        const { marcados } = await api.post(`/api/v1/inventarios/${atual.id}/setores/${setor}/faltantes`, {});
        ui.showNotification(`${marcados} bem(ns) marcados como não localizados.`, 'success');
        await recarregarInventario();
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    }
}

async function marcarNaoLocalizado(itemId) {
    try {
        await api.post(`/api/v1/inventarios/${atual.id}/itens/${itemId}/nao-localizado`, {});
        await recarregarInventario();
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    }
}

async function fecharInventario() {
    if (!confirm('Fechar o inventário? Bens em outro setor abrem transferências e os não localizados viram pendências. '
        + 'Depois de fechado, nada pode ser alterado.')) return;
    try {
        const r = await api.post(`/api/v1/inventarios/${atual.id}/fechar`, {});
        const ignoradas = r.transferencias_ignoradas.length
            ? `<ul class="mb-0 mt-2">${r.transferencias_ignoradas.map(t =>
                `<li><code>${esc(t.codigo_tombamento)}</code>: ${esc(t.motivo)}</li>`).join('')}</ul>` : '';
        const resumo = $('#resumoFechamento');
        resumo.className = 'alert alert-success mb-3';
        resumo.innerHTML = `
            <strong>Inventário fechado.</strong>
            ${r.localizados} localizados · ${r.outro_setor} em outro setor (${r.transferencias_abertas} transferências abertas)
            · ${r.nao_localizados} não localizados (${r.ausencias_justificadas} justificados) · ${r.nao_cadastrados} sem cadastro
            · ${r.pendencias_criadas} pendência(s) criada(s). ${ignoradas}`;
        await Promise.all([recarregarInventario(), carregarLista(), carregarIndicadores()]);
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    }
}

// ----- Início ----------------------------------------------------------------------------------

document.addEventListener('DOMContentLoaded', async () => {
    eu = await api.get('/api/v1/auth/me');
    $('#filtroInventarios').addEventListener('change', carregarLista);
    $('#btnNovoInventario')?.addEventListener('click', abrirNovo);
    $('#formNovoInventario').addEventListener('submit', confirmarNovo);
    $('#listaInventarios').addEventListener('click', (e) => {
        const botao = e.target.closest('.btn-abrir-inventario');
        if (botao) abrirInventario(botao.dataset.id);
    });
    $('#formConferencia').addEventListener('submit', conferir);
    $('#formNaoCadastrado').addEventListener('submit', registrarNaoCadastrado);
    $('#btnMostrarNaoCadastrado').addEventListener('click', () => {
        $('#formNaoCadastrado').classList.toggle('d-none');
        $('#ncDescricao').focus();
    });
    $('#filtroItens').addEventListener('change', carregarItens);
    $('#resumoSetores').addEventListener('click', (e) => {
        const botao = e.target.closest('.btn-faltantes');
        if (botao) marcarFaltantes(botao.dataset);
    });
    $('#listaItens').addEventListener('click', (e) => {
        const botao = e.target.closest('.btn-nao-localizado');
        if (botao) marcarNaoLocalizado(botao.dataset.id);
    });
    $('#btnFecharInventario')?.addEventListener('click', fecharInventario);
    $('#modalInventario').addEventListener('shown.bs.modal', focarLeitura);
    await Promise.all([carregarLista(), carregarIndicadores()]);
});
