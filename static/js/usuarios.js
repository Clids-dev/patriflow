import { $, api, ui, esc } from '/static/js/utils.js';

// Usuários (D3): o cadastro tem situação própria. Quem aguarda aprovação aparece primeiro;
// recusados ficam registrados. Responsável de setor só é ativado com setor (D2).

const PERFIS = { setor_patrimonio: 'Setor de patrimônio', agente_campo: 'Agente de campo',
                 responsavel_setor: 'Responsável de setor', auditor: 'Auditor' };
const SITUACOES = {
    aguardando: ['Aguardando aprovação', 'bg-warning-subtle text-warning-emphasis'],
    ativo: ['Ativo', 'bg-success-subtle text-success'],
    desativado: ['Desativado', 'bg-secondary-subtle text-secondary'],
    recusado: ['Recusado', 'bg-danger-subtle text-danger'],
};

let eu = null;
let usuarios = [];
let setores = [];
let editando = null;

async function carregar() {
    const filtro = $('#filtroSituacao').value;
    const corpo = $('#listaUsuarios');
    try {
        usuarios = await api.get(`/api/v1/usuarios/${filtro ? `?situacao=${filtro}` : ''}`);
        corpo.innerHTML = usuarios.length ? usuarios.map(linha).join('')
            : '<tr><td colspan="6" class="text-center text-muted py-4">Nenhum usuário nesta situação.</td></tr>';
    } catch (erro) {
        corpo.innerHTML = `<tr><td colspan="6" class="text-center text-danger py-4">${esc(erro.message)}</td></tr>`;
    }
}

function linha(u) {
    const [rotulo, classe] = SITUACOES[u.situacao] || [u.situacao, 'bg-light text-dark'];
    const decisao = u.decidido_em
        ? `<div class="small text-muted">${esc(u.decidido_por || '')}, ${new Date(u.decidido_em).toLocaleDateString('pt-BR')}</div>` : '';
    const proprio = eu && u.id === eu.id;
    const botoes = {
        aguardando: `<button class="btn btn-sm btn-primary me-1" data-acao="aprovar" data-id="${u.id}">Aprovar</button>
                     <button class="btn btn-sm btn-outline-danger" data-acao="recusar" data-id="${u.id}">Recusar</button>`,
        ativo: proprio ? '' : `<button class="btn btn-sm btn-outline-secondary me-1" data-acao="editar" data-id="${u.id}">Editar</button>
                     <button class="btn btn-sm btn-outline-danger" data-acao="desativar" data-id="${u.id}">Desativar</button>`,
        desativado: `<button class="btn btn-sm btn-outline-primary" data-acao="reativar" data-id="${u.id}">Reativar</button>`,
        recusado: '',
    }[u.situacao] || '';
    return `
        <tr>
            <td class="ps-4 fw-semibold">${esc(u.nome || u.username)}</td>
            <td class="small text-muted">${esc(u.username)}</td>
            <td class="small">${esc(PERFIS[u.perfil] || u.perfil)}</td>
            <td class="small">${esc(u.setor_nome || '—')}</td>
            <td><span class="badge rounded-pill ${classe}">${rotulo}</span>${decisao}</td>
            <td class="pe-4 acoes-tabela">${botoes}</td>
        </tr>`;
}

function abrirModal(u, titulo) {
    editando = u;
    $('#tituloUsuario').textContent = titulo;
    $('#resumoUsuario').textContent = `${u.nome || u.username} (${u.username})`;
    $('#usuarioPerfil').value = u.perfil;
    $('#usuarioSetor').innerHTML = '<option value="">Sem setor</option>'
        + setores.map(s => `<option value="${esc(s.id)}">${esc(s.nome)}</option>`).join('');
    $('#usuarioSetor').value = u.setor_id ?? '';
    bootstrap.Modal.getOrCreateInstance($('#modalUsuario')).show();
}

async function enviar(u, situacao, perfil = u.perfil, setor = u.setor_id) {
    try {
        await api.patch(`/api/v1/usuarios/${u.id}`, { perfil, setor_id: setor ?? null, situacao });
        ui.showNotification({ ativo: 'Usuário ativo.', desativado: 'Usuário desativado.', recusado: 'Cadastro recusado.' }[situacao]);
        await carregar();
        return true;
    } catch (erro) {
        ui.showNotification(erro.message, 'error');
        return false;
    }
}

async function aoClicar(e) {
    const botao = e.target.closest('button[data-acao]');
    if (!botao) return;
    const u = usuarios.find(x => String(x.id) === botao.dataset.id);
    const acao = botao.dataset.acao;
    if (acao === 'aprovar') abrirModal(u, 'Aprovar cadastro');
    if (acao === 'editar') abrirModal(u, 'Editar usuário');
    if (acao === 'reativar') abrirModal(u, 'Reativar usuário');
    if (acao === 'recusar' && confirm(`Recusar o cadastro de ${u.nome || u.username}? O registro fica guardado.`)) await enviar(u, 'recusado');
    if (acao === 'desativar' && confirm(`Desativar ${u.nome || u.username}? A pessoa deixa de entrar no sistema.`)) await enviar(u, 'desativado');
}

async function salvar(evento) {
    evento.preventDefault();
    const setor = $('#usuarioSetor').value ? Number($('#usuarioSetor').value) : null;
    if (await enviar(editando, 'ativo', $('#usuarioPerfil').value, setor)) {
        bootstrap.Modal.getInstance($('#modalUsuario')).hide();
    }
}

document.addEventListener('DOMContentLoaded', async () => {
    const filtro = new URLSearchParams(window.location.search).get('situacao');
    if (filtro) $('#filtroSituacao').value = filtro;
    [eu, setores] = await Promise.all([
        api.get('/api/v1/auth/me'),
        api.get('/api/v1/setores/').then(l => l.filter(s => s.ativo !== false)).catch(() => []),
    ]);
    $('#filtroSituacao').addEventListener('change', carregar);
    $('#listaUsuarios').addEventListener('click', aoClicar);
    $('#formUsuario').addEventListener('submit', salvar);
    await carregar();
});
