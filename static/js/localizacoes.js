import { $, api, ui, esc } from '/static/js/utils.js';

// Árvore de localizações: prédio → andar → sala → setores. Cadastro de prédio, andar ou sala no mesmo formulário.
let dados = { predios: [], andares: [], salas: [], setores: [] };

async function carregar() {
    try {
        const [predios, andares, salas, setores] = await Promise.all([
            api.get('/api/v1/localizacao/predios'),
            api.get('/api/v1/localizacao/andares'),
            api.get('/api/v1/localizacao/salas'),
            api.get('/api/v1/setores/'),
        ]);
        dados = { predios, andares, salas, setores };
        atualizarIndicadores();
        desenharArvore();
        preencherSeletores();
    } catch (erro) {
        ui.showNotification('Erro ao carregar localizações', 'error');
    }
}

function atualizarIndicadores() {
    const salasComSetor = dados.salas.filter(s => dados.setores.some(st => st.sala_id === s.id)).length;
    $('#kpiPredios').textContent = dados.predios.length;
    $('#kpiAndares').textContent = dados.andares.length;
    $('#kpiSalas').textContent = `${salasComSetor}/${dados.salas.length}`;
}

function desenharArvore() {
    const area = $('#arvoreLocais');
    if (!dados.predios.length) {
        area.innerHTML = '<p class="text-muted mb-0">Nenhum prédio cadastrado ainda. Use "Cadastrar local" para começar.</p>';
        return;
    }
    area.innerHTML = dados.predios
        .slice()
        .sort((a, b) => a.nome.localeCompare(b.nome, 'pt-BR'))
        .map(predio => {
            const andares = dados.andares.filter(a => a.predio_id === predio.id);
            const corpo = andares.length
                ? andares.map(andar => {
                    const salas = dados.salas.filter(s => s.andar_id === andar.id);
                    const itens = salas.length
                        ? salas.map(sala => {
                            const setores = dados.setores.filter(st => st.sala_id === sala.id);
                            const nomes = setores.map(st => `<a href="/setores/${esc(st.id)}" class="badge bg-primary-subtle text-primary text-decoration-none me-1">${esc(st.nome)}</a>`).join('');
                            return `<li class="arvore-item"><i class="bi bi-door-open me-2 text-muted"></i>
                                        <span class="fw-semibold">${esc(sala.identificacao)}</span>
                                        <span class="ms-2">${nomes || '<span class="text-muted small">sem setor</span>'}</span></li>`;
                        }).join('')
                        : '<li class="arvore-item text-muted small">Nenhuma sala</li>';
                    return `<li class="arvore-nivel"><div class="arvore-titulo"><i class="bi bi-layers me-2 text-muted"></i>${esc(andar.identificacao)}</div>
                                <ul class="arvore-lista">${itens}</ul></li>`;
                }).join('')
                : '<li class="arvore-item text-muted small">Nenhum andar</li>';
            const endereco = predio.endereco ? `<span class="text-muted small ms-2">${esc(predio.endereco)}</span>` : '';
            return `<details class="arvore-predio" open>
                        <summary><i class="bi bi-buildings me-2"></i><span class="fw-bold">${esc(predio.nome)}</span>${endereco}</summary>
                        <ul class="arvore-lista">${corpo}</ul>
                    </details>`;
        }).join('');
}

function preencherSeletores() {
    $('#predioPai').innerHTML = dados.predios.map(p => `<option value="${esc(p.id)}">${esc(p.nome)}</option>`).join('');
    $('#andarPai').innerHTML = dados.andares.map(a => `<option value="${esc(a.id)}">${esc(a.predio_nome)} — ${esc(a.identificacao)}</option>`).join('');
}

// Mostra só os campos do tipo escolhido.
function ajustarFormulario() {
    const tipo = $('#tipoLocal').value;
    $('#campoPredioPai').classList.toggle('d-none', tipo !== 'andar');
    $('#campoAndarPai').classList.toggle('d-none', tipo !== 'sala');
    $('#campoEndereco').classList.toggle('d-none', tipo !== 'predio');
    $('#rotuloNomeLocal').textContent = { predio: 'Nome do prédio', andar: 'Identificação do andar', sala: 'Identificação da sala' }[tipo];
    $('#nomeLocal').placeholder = { predio: 'Ex.: Sede Central', andar: 'Ex.: Térreo, 1º andar', sala: 'Ex.: Sala 12' }[tipo];
}

async function salvar(evento) {
    evento.preventDefault();
    const tipo = $('#tipoLocal').value;
    const nome = $('#nomeLocal').value.trim();
    const botao = $('#btnSalvarLocal');
    botao.disabled = true;
    try {
        if (tipo === 'predio') {
            await api.post('/api/v1/localizacao/predios', { nome, endereco: $('#enderecoLocal').value.trim() || null });
        } else if (tipo === 'andar') {
            await api.post('/api/v1/localizacao/andares', { predio_id: Number($('#predioPai').value), identificacao: nome });
        } else {
            await api.post('/api/v1/localizacao/salas', { andar_id: Number($('#andarPai').value), identificacao: nome });
        }
        ui.showNotification('Local cadastrado!');
        $('#formLocal').reset();
        bootstrap.Modal.getInstance($('#modalLocal'))?.hide();
        await carregar();
    } catch (erro) {
        ui.showNotification(erro.message || 'Não foi possível cadastrar.', 'error');
    } finally {
        botao.disabled = false;
    }
}

document.addEventListener('DOMContentLoaded', () => {
    carregar();
    $('#tipoLocal').addEventListener('change', ajustarFormulario);
    $('#formLocal').addEventListener('submit', salvar);
    ajustarFormulario();
    if (new URLSearchParams(window.location.search).get('novo') === '1') {
        bootstrap.Modal.getOrCreateInstance($('#modalLocal')).show();
    }
});
