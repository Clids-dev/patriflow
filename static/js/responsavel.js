import { $, $$, api, ui, esc } from './utils.js';

let todosResponsaveis = [];

document.addEventListener('DOMContentLoaded', async () => {
    if (new URLSearchParams(window.location.search).get('novo') === '1') {
        bootstrap.Modal.getOrCreateInstance($('#modalResponsavel')).show();
    }
    await carregarResponsaveis();
    configurarEventos();
});

// Indicadores do topo da página: total e ativos/inativos da base completa (não da busca).
function atualizarIndicadores(lista) {
    const ativos = lista.filter(item => item.ativo).length;
    $('#kpiTotal').textContent = lista.length;
    $('#kpiAtivas').textContent = ativos;
    $('#kpiInativas').textContent = lista.length - ativos;
}

async function carregarResponsaveis() {
    try {
        todosResponsaveis = await api.get('/api/v1/responsavel/');
        atualizarIndicadores(todosResponsaveis);
        renderizarResponsaveis(todosResponsaveis);
    } catch (error) {
        ui.showNotification('Erro ao carregar responsáveis', 'error');
    }
}

function renderizarResponsaveis(responsaveis) {
    const lista = $('#listaResponsaveis');
    if (!lista) return;

    if (responsaveis.length === 0) {
        lista.innerHTML = `<tr><td colspan="5" class="text-center py-5 text-muted">Nenhum responsável encontrado.</td></tr>`;
        return;
    }

    lista.innerHTML = responsaveis.map(resp => `
        <tr>
            <td class="px-4 fw-bold text-muted">#${esc(resp.id)}</td>
            <td><a href="/responsaveis/${esc(resp.id)}" class="fw-bold text-dark text-decoration-none">${esc(resp.nome)}</a></td>
            <td><span class="text-muted small">${esc(resp.cargo)}</span></td>
            <td>
                <span class="badge ${esc(resp.ativo ? 'bg-success-subtle text-success' : 'bg-danger-subtle text-danger')} rounded-pill px-3">
                    ${esc(resp.ativo ? 'Ativo' : 'Inativo')}
                </span>
            </td>
            <td class="px-4 text-end">
                <button class="btn btn-sm btn-light btn-termo me-1" data-id="${esc(resp.id)}" title="Termo de responsabilidade"><i class="bi bi-file-earmark-text text-dark"></i></button>
                <button class="btn btn-sm btn-light btn-edit me-1" data-id="${esc(resp.id)}"><i class="bi bi-pencil-square text-primary"></i></button>
                <button class="btn btn-sm btn-light btn-delete" data-id="${esc(resp.id)}"><i class="bi bi-trash text-danger"></i></button>
            </td>
        </tr>
    `).join('');

    vincularAcoesTabela();
}

function configurarEventos() {
    $('#formResponsavel')?.addEventListener('submit', async (e) => {
        e.preventDefault();
        await salvarResponsavel();
    });

    $('#modalResponsavel')?.addEventListener('hidden.bs.modal', () => {
        $('#formResponsavel').reset();
        $('#responsavelId').value = '';
        $('#tituloModal').innerText = 'Novo Responsável';
    });
}

async function salvarResponsavel() {
    const id = $('#responsavelId').value;
    const dados = {
        nome: $('#nome').value,
        cargo: $('#cargo').value
    };

    ui.setLoading('btnSalvar', true);

    try {
        if (id) {
            await api.put(`/api/v1/responsavel/?id=${id}`, dados);
            ui.showNotification('Responsável atualizado!');
        } else {
            await api.post('/api/v1/responsavel/', dados);
            ui.showNotification('Responsável cadastrado!');
        }

        bootstrap.Modal.getInstance($('#modalResponsavel')).hide();
        await carregarResponsaveis();
    } catch (error) {
        ui.showNotification(error.message, 'error');
    } finally {
        ui.setLoading('btnSalvar', false);
    }
}

function vincularAcoesTabela() {
    $$('.btn-termo').forEach(btn => {
        btn.addEventListener('click', () => window.open(`/api/v1/termos/responsavel/${btn.dataset.id}`, '_blank', 'noopener'));
    });

    $$('.btn-edit').forEach(btn => {
        btn.addEventListener('click', () => {
            const resp = todosResponsaveis.find(r => r.id == btn.dataset.id);
            if (resp) {
                $('#responsavelId').value = resp.id;
                $('#nome').value = resp.nome;
                $('#cargo').value = resp.cargo;
                $('#tituloModal').innerText = 'Editar Responsável';
                new bootstrap.Modal($('#modalResponsavel')).show();
            }
        });
    });

    $$('.btn-delete').forEach(btn => {
        btn.addEventListener('click', async () => {
            if (confirm('Deseja inativar este responsável?')) {
                try {
                    await api.delete(`/api/v1/responsavel/?id=${btn.dataset.id}`);
                    ui.showNotification('Responsável inativado!');
                    await carregarResponsaveis();
                } catch (error) {
                    ui.showNotification(error.message, 'error');
                }
            }
        });
    });
}
