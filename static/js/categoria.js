import { $, $$, api, ui, esc } from './utils.js';

let todasCategorias = [];

/**
 * Inicialização da página
 */
document.addEventListener('DOMContentLoaded', async () => {
    await carregarCategorias();
    configurarEventos();
});

/**
 * Carrega a lista de categorias da API
 */
async function carregarCategorias() {
    try {
        todasCategorias = await api.get('/api/v1/categoria/');
        renderizarCategorias(todasCategorias);
        atualizarContadores(todasCategorias.length);
    } catch (error) {
        ui.showNotification('Erro ao carregar categorias', 'error');
    }
}

/**
 * Renderiza os itens na tabela
 */
function renderizarCategorias(categorias) {
    const lista = $('#listaCategorias');
    if (!lista) return;

    if (categorias.length === 0) {
        lista.innerHTML = `
            <tr>
                <td colspan="5" class="text-center py-5 text-muted">
                    <i class="fas fa-folder-open fa-3x mb-3 d-block opacity-25"></i>
                    Nenhuma categoria encontrada.
                </td>
            </tr>
        `;
        return;
    }

    lista.innerHTML = categorias.map(cat => `
        <tr>
            <td class="px-4 fw-bold text-muted">#${esc(cat.id)}</td>
            <td>
                <div class="fw-bold text-dark">${esc(cat.nome)}</div>
            </td>
            <td class="text-center">
                <span class="badge bg-light text-primary border border-primary border-opacity-25 px-3 py-2">
                    ${esc(cat.sigla)}
                </span>
            </td>
            <td>
                <span class="badge ${esc(cat.ativo ? 'bg-success-subtle text-success' : 'bg-danger-subtle text-danger')} rounded-pill px-3">
                    ${esc(cat.ativo ? 'Ativo' : 'Inativo')}
                </span>
            </td>
            <td class="px-4 text-end">
                <button class="btn btn-sm btn-light btn-edit me-1" data-id="${esc(cat.id)}" title="Editar">
                    <i class="fas fa-edit text-primary"></i>
                </button>
                <button class="btn btn-sm btn-light btn-delete" data-id="${esc(cat.id)}" title="Inativar">
                    <i class="fas fa-trash-alt text-danger"></i>
                </button>
            </td>
        </tr>
    `).join('');

    vincularAcoesTabela();
}

/**
 * Configura os eventos de busca e formulário
 */
function configurarEventos() {
    // Busca dinâmica
    $('#buscaCategoria')?.addEventListener('input', (e) => {
        const termo = e.target.value.toLowerCase();
        const filtradas = todasCategorias.filter(cat => 
            cat.nome.toLowerCase().includes(termo) || 
            cat.sigla.toLowerCase().includes(termo)
        );
        renderizarCategorias(filtradas);
    });

    // Submissão do formulário
    $('#formCategoria')?.addEventListener('submit', async (e) => {
        e.preventDefault();
        await salvarCategoria();
    });

    // Reset do modal ao fechar
    $('#modalCategoria')?.addEventListener('hidden.bs.modal', () => {
        $('#formCategoria').reset();
        $('#categoriaId').value = '';
        $('#tituloModal').innerText = 'Nova Categoria';
        $('#sigla').disabled = false;
    });
}

/**
 * Salva ou Atualiza uma categoria
 */
async function salvarCategoria() {
    const id = $('#categoriaId').value;
    const dados = {
        nome: $('#nome').value,
        sigla: $('#sigla').value.toUpperCase()
    };

    ui.setLoading('btnSalvar', true);

    try {
        if (id) {
            // A API atual usa query params para PUT conforme roteiro, mas vamos seguir o padrão REST se possível
            // Revisando o modules/categoria/router.py: update_categoria(id: int, novo_nome: str)
            await api.put(`/api/v1/categoria/?id=${id}&novo_nome=${encodeURIComponent(dados.nome)}`);
            ui.showNotification('Categoria atualizada com sucesso!');
        } else {
            await api.post('/api/v1/categoria/', dados);
            ui.showNotification('Categoria cadastrada com sucesso!');
        }

        const modal = bootstrap.Modal.getInstance($('#modalCategoria'));
        modal.hide();
        await carregarCategorias();
    } catch (error) {
        ui.showNotification(error.message, 'error');
    } finally {
        ui.setLoading('btnSalvar', false);
    }
}

/**
 * Vincula cliques nos botões de editar e deletar
 */
function vincularAcoesTabela() {
    $$('.btn-edit').forEach(btn => {
        btn.addEventListener('click', () => {
            const id = btn.dataset.id;
            const cat = todasCategorias.find(c => c.id == id);
            if (cat) prepararEdicao(cat);
        });
    });

    $$('.btn-delete').forEach(btn => {
        btn.addEventListener('click', async () => {
            const id = btn.dataset.id;
            if (confirm('Deseja realmente inativar esta categoria?')) {
                await deletarCategoria(id);
            }
        });
    });
}

/**
 * Prepara o modal para edição
 */
function prepararEdicao(cat) {
    $('#categoriaId').value = cat.id;
    $('#nome').value = cat.nome;
    $('#sigla').value = cat.sigla;
    $('#sigla').disabled = true; // Sigla não deve ser alterada pois afeta tombamentos existentes
    $('#tituloModal').innerText = 'Editar Categoria';
    
    const modal = new bootstrap.Modal($('#modalCategoria'));
    modal.show();
}

/**
 * Inativa uma categoria (Soft Delete)
 */
async function deletarCategoria(id) {
    try {
        await api.delete(`/api/v1/categoria/?id=${id}`);
        ui.showNotification('Categoria inativada!');
        await carregarCategorias();
    } catch (error) {
        ui.showNotification(error.message, 'error');
    }
}

function atualizarContadores(total) {
    const el = $('#totalCategorias');
    if (el) el.innerText = `${total} categoria(s) encontrada(s)`;
}
