import { $, api, ui, esc, botaoAcao } from './utils.js';

// Categorias: a tela de gestão traz também as inativas (a API devolve as ativas primeiro).
// A sigla é o prefixo dos tombos (ex.: INF-001-0) e não muda depois de criada.

let todasCategorias = [];

const modal = () => bootstrap.Modal.getOrCreateInstance($('#modalCategoria'));

document.addEventListener('DOMContentLoaded', async () => {
    configurarEventos();
    await carregarCategorias();
    if (new URLSearchParams(window.location.search).get('novo') === '1') abrirNova();
});

// Indicadores do topo: sempre da base completa, não do resultado da busca.
function atualizarIndicadores(lista) {
    const ativas = lista.filter(item => item.ativo).length;
    $('#kpiTotal').textContent = lista.length;
    $('#kpiAtivas').textContent = ativas;
    $('#kpiInativas').textContent = lista.length - ativas;
}

async function carregarCategorias() {
    try {
        todasCategorias = await api.get('/api/v1/categoria/?incluir_inativas=true');
        atualizarIndicadores(todasCategorias);
        aplicarBusca();
    } catch (erro) {
        ui.showNotification('Erro ao carregar categorias.', 'error');
    }
}

function aplicarBusca() {
    const termo = $('#buscaCategoria').value.trim().toLowerCase();
    const filtradas = termo
        ? todasCategorias.filter(cat => cat.nome.toLowerCase().includes(termo) || (cat.sigla || '').toLowerCase().includes(termo))
        : todasCategorias;
    renderizarCategorias(filtradas, termo);
    $('#totalCategorias').textContent = termo
        ? `${filtradas.length} de ${todasCategorias.length} categoria(s)`
        : `${todasCategorias.length} categoria(s)`;
}

function renderizarCategorias(categorias, termo) {
    const lista = $('#listaCategorias');
    if (categorias.length === 0) {
        lista.innerHTML = `
            <tr>
                <td colspan="5" class="text-center py-5 text-muted">
                    <i class="bi bi-folder2-open fs-1 mb-3 d-block opacity-25" aria-hidden="true"></i>
                    ${termo ? 'Nenhuma categoria corresponde à busca.' : 'Nenhuma categoria cadastrada.'}
                </td>
            </tr>`;
        return;
    }
    lista.innerHTML = categorias.map(cat => `
        <tr class="${cat.ativo ? '' : 'text-muted'}">
            <td class="ps-4 fw-bold text-muted">#${esc(cat.id)}</td>
            <td><a href="/categoria/${esc(cat.id)}" class="fw-bold text-dark text-decoration-none">${esc(cat.nome)}</a></td>
            <td class="text-center">
                <span class="badge bg-light text-primary border border-primary border-opacity-25 px-3 py-2">${esc(cat.sigla)}</span>
            </td>
            <td>
                <span class="badge ${cat.ativo ? 'bg-success-subtle text-success' : 'bg-danger-subtle text-danger'} rounded-pill px-3">
                    ${cat.ativo ? 'Ativa' : 'Inativa'}
                </span>
            </td>
            <td class="pe-4 acoes-tabela">
                ${botaoAcao('editar', { id: cat.id, classe: 'btn-edit' })}${cat.ativo
                    ? botaoAcao('inativar', { id: cat.id, classe: 'btn-delete' })
                    : botaoAcao('reativar', { id: cat.id, classe: 'btn-reativar' })}
            </td>
        </tr>`).join('');
}

function configurarEventos() {
    $('#buscaCategoria').addEventListener('input', aplicarBusca);
    $('#btnNovaCategoria').addEventListener('click', abrirNova);
    $('#formCategoria').addEventListener('submit', salvarCategoria);
    $('#sigla').addEventListener('input', (e) => {
        // Só letras, em maiúsculas, enquanto digita (a API também normaliza e valida).
        e.target.value = e.target.value.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^A-Za-z]/g, '').toUpperCase();
    });
    // Um único ouvinte para a tabela inteira (a lista é redesenhada a cada busca).
    $('#listaCategorias').addEventListener('click', async (e) => {
        const botao = e.target.closest('button[data-id]');
        if (!botao) return;
        const cat = todasCategorias.find(c => String(c.id) === botao.dataset.id);
        if (!cat) return;
        if (botao.classList.contains('btn-edit')) abrirEdicao(cat);
        if (botao.classList.contains('btn-delete')) await inativar(cat);
        if (botao.classList.contains('btn-reativar')) await reativar(cat);
    });
}

function prepararFormulario({ titulo, nome = '', sigla = '', id = '', siglaFixa = false }) {
    const form = $('#formCategoria');
    form.reset();
    form.classList.remove('was-validated');
    $('#categoriaId').value = id;
    $('#nome').value = nome;
    $('#sigla').value = sigla;
    $('#sigla').disabled = siglaFixa;
    $('#ajudaSigla').textContent = siglaFixa
        ? 'A sigla não pode ser alterada: ela é o prefixo dos tombos já emitidos.'
        : 'Três letras, usadas como prefixo dos tombos (ex.: INF-001-0). Não pode ser alterada depois.';
    $('#tituloModal').textContent = titulo;
}

function abrirNova() {
    prepararFormulario({ titulo: 'Nova categoria' });
    modal().show();
}

function abrirEdicao(cat) {
    prepararFormulario({ titulo: 'Editar categoria', nome: cat.nome, sigla: cat.sigla, id: cat.id, siglaFixa: true });
    modal().show();
}

async function salvarCategoria(evento) {
    evento.preventDefault();
    const form = evento.target;
    if (!form.checkValidity()) {
        form.classList.add('was-validated');
        return;
    }
    const id = $('#categoriaId').value;
    const nome = $('#nome').value.trim();
    ui.setLoading('btnSalvar', true);
    try {
        if (id) {
            await api.put(`/api/v1/categoria/?id=${encodeURIComponent(id)}&novo_nome=${encodeURIComponent(nome)}`);
            ui.showNotification('Categoria atualizada.');
        } else {
            await api.post('/api/v1/categoria/', { nome, sigla: $('#sigla').value });
            ui.showNotification('Categoria cadastrada.');
        }
        modal().hide();
        await carregarCategorias();
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    } finally {
        ui.setLoading('btnSalvar', false);
    }
}

async function inativar(cat) {
    const ok = confirm(`Inativar a categoria "${cat.nome}"?\n\nOs bens já cadastrados continuam nela, mas não será possível `
        + 'cadastrar bens novos nesta categoria até ela ser reativada.');
    if (!ok) return;
    try {
        await api.delete(`/api/v1/categoria/?id=${encodeURIComponent(cat.id)}`);
        ui.showNotification(`Categoria "${cat.nome}" inativada.`);
        await carregarCategorias();
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    }
}

async function reativar(cat) {
    try {
        await api.post(`/api/v1/categoria/${encodeURIComponent(cat.id)}/reativar`, {});
        ui.showNotification(`Categoria "${cat.nome}" reativada.`);
        await carregarCategorias();
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
    }
}
