import { $, api, ui, esc } from './utils.js';

document.addEventListener('DOMContentLoaded', async () => {
    await carregarDadosFiltros();
    carregarEstatisticas();
    configurarEventos();
});

async function carregarDadosFiltros() {
    try {
        const [categorias, setores] = await Promise.all([
            api.get('/api/v1/categoria/'),
            api.get('/api/v1/setores/')
        ]);

        const selCat = $('#filtroCategoria');
        const selSet = $('#filtroSetor');

        if (selCat) {
            selCat.innerHTML += categorias
                .filter(c => c.ativo)
                .map(c => `<option value="${esc(c.id)}">${esc(c.nome)}</option>`)
                .join('');
        }

        if (selSet) {
            selSet.innerHTML += setores
                .filter(s => s.ativo)
                .map(s => `<option value="${esc(s.id)}">${esc(s.nome)}</option>`)
                .join('');
        }
    } catch (error) {
        ui.showNotification('Erro ao carregar filtros', 'error');
    }
}

async function carregarEstatisticas() {
    try {
        const bens = await api.get('/api/v1/bem/');
        $('#totalBens').innerText = bens.length;
    } catch (error) {}
}

function configurarEventos() {
    $('#formRelatorio')?.addEventListener('submit', async (e) => {
        e.preventDefault();
        await gerarRelatorio();
    });
}

async function gerarRelatorio() {
    const btn = $('#btnGerar');
    const originalContent = btn.innerHTML;
    
    const filtros = {
        categoria_id: $('#filtroCategoria').value,
        setor_id: $('#filtroSetor').value,
        status: $('#filtroStatus').value,
        formato: document.querySelector('input[name="formato"]:checked').value
    };

    ui.setLoading('btnGerar', true);

    try {
        // Construindo a URL com query params
        const params = new URLSearchParams();
        if (filtros.categoria_id) params.append('categoria_id', filtros.categoria_id);
        if (filtros.setor_id) params.append('setor_id', filtros.setor_id);
        if (filtros.status) params.append('status', filtros.status);
        params.append('formato', filtros.formato);

        // Como é um download de arquivo, não usamos o helper api.request comum que espera JSON
        const url = `/api/v1/relatorio/exportar?${params.toString()}`;
        
        // Simulação de download via link temporário
        const response = await fetch(url);
        if (!response.ok) throw new Error('Erro ao gerar arquivo no servidor.');

        const blob = await response.blob();
        const downloadUrl = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = downloadUrl;
        
        const timestamp = new Date().toISOString().split('T')[0];
        a.download = `inventario_patriflow_${timestamp}.${filtros.formato}`;
        
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(downloadUrl);
        a.remove();

        ui.showNotification('Relatório gerado com sucesso!');
    } catch (error) {
        ui.showNotification(error.message, 'error');
    } finally {
        ui.setLoading('btnGerar', false);
        btn.innerHTML = originalContent;
    }
}
