import { $, api, esc } from '/static/js/utils.js';

/**
 * Dashboard.js - Lógica da página inicial com visualização de dados
 */

// Cores vêm dos tokens de style.css, para os gráficos seguirem a paleta do sistema.
const cor = (token) => getComputedStyle(document.documentElement).getPropertyValue(token).trim();

async function init() {
    console.log("Iniciando Dashboard...");
    mostrarDataDeHoje();
    await Promise.all([
        renderizarGraficoCategorias(),
        renderizarGraficoStatus(),
        renderizarUltimosRegistros(),
        renderizarAtencao()
    ]);
}

function mostrarDataDeHoje() {
    const el = $('#dataHoje');
    if (!el) return;
    const texto = new Date().toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long', year: 'numeric' });
    el.textContent = texto.charAt(0).toUpperCase() + texto.slice(1);
}

// "O que pede atenção": transferências aguardando aceite e garantias vencidas ou a vencer.
// Cada consulta é independente: quem não tem permissão para uma delas só não vê aquele item.
async function renderizarAtencao() {
    const lista = $('#atencaoLista');
    const total = $('#atencaoTotal');
    const itens = [];

    let garantias = [];
    try {
        garantias = await api.get('/api/v1/bem/alertas/garantias?dias=60');
        const kpi = $('#kpiGarantias');
        if (kpi) kpi.textContent = garantias.length;
        garantias.filter(g => g.vencida).forEach(g => itens.push({
            icone: 'bi-shield-exclamation',
            titulo: `Garantia vencida: ${g.nome}`,
            detalhe: `${g.codigo_tombamento} · venceu em ${new Date(g.garantia_fim + 'T00:00:00').toLocaleDateString('pt-BR')}`,
            link: '/bens'
        }));
        garantias.filter(g => !g.vencida).forEach(g => itens.push({
            icone: 'bi-shield-check',
            titulo: `Garantia a vencer: ${g.nome}`,
            detalhe: `${g.codigo_tombamento} · vence em ${new Date(g.garantia_fim + 'T00:00:00').toLocaleDateString('pt-BR')}`,
            link: '/bens'
        }));
    } catch (erro) {
        console.warn("Garantias indisponíveis:", erro);
        const kpi = $('#kpiGarantias');
        if (kpi) kpi.textContent = '--';
    }

    try {
        const pendentes = await api.get('/api/v1/movimentacao/pendentes');
        pendentes.forEach(m => itens.push({
            icone: 'bi-arrow-left-right',
            titulo: `Transferência aguardando aceite: ${m.bem_nome}`,
            detalhe: `${m.codigo_tombamento} → ${m.setor_destino_nome}`,
            link: '/movimentacao'
        }));
    } catch (erro) {
        console.warn("Pendências indisponíveis:", erro);
    }

    total.textContent = `${itens.length} ${itens.length === 1 ? 'ponto' : 'pontos'}`;
    if (itens.length === 0) {
        lista.innerHTML = '<li class="atencao-vazio">Nada pendente agora. Tudo em ordem.</li>';
        return;
    }
    lista.innerHTML = itens.slice(0, 6).map(item => `
        <li>
            <a href="${esc(item.link)}" class="atencao-item">
                <span class="atencao-icone"><i class="bi ${esc(item.icone)}"></i></span>
                <span class="atencao-texto">
                    <strong>${esc(item.titulo)}</strong>
                    <small>${esc(item.detalhe)}</small>
                </span>
                <i class="bi bi-chevron-right atencao-seta"></i>
            </a>
        </li>`).join('');
}

async function renderizarGraficoCategorias() {
    try {
        const stats = await api.get('/api/v1/bem/stats/categoria');
        console.log("Stats Categorias:", stats);

        if (!stats || stats.length === 0) {
            console.warn("Nenhum dado de categoria encontrado.");
            return;
        }

        const labels = stats.map(s => s[0]);
        const data = stats.map(s => s[1]);

        const ctx = document.getElementById('chartCategorias');
        if (!ctx) return;

        if (window.chartCat) window.chartCat.destroy();

        window.chartCat = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Quantidade de Bens',
                    data: data,
                    backgroundColor: cor('--primary-color'),
                    borderColor: cor('--primary-color'),
                    borderWidth: 1,
                    borderRadius: 8
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false }
                },
                scales: {
                    y: { beginAtZero: true, grid: { display: false } },
                    x: { grid: { display: false } }
                }
            }
        });
    } catch (error) {
        console.error("Erro ao carregar gráfico de categorias:", error);
    }
}

async function renderizarGraficoStatus() {
    try {
        const stats = await api.get('/api/v1/bem/stats/status');
        console.log("Stats Status:", stats);

        if (!stats || stats.length === 0) {
            console.warn("Nenhum dado de status encontrado.");
            return;
        }

        const labels = stats.map(s => s[0]);
        const data = stats.map(s => s[1]);

        const ctx = document.getElementById('chartStatus');
        if (!ctx) return;

        if (window.chartStat) window.chartStat.destroy();

        // Função para normalizar strings de status (remove acentos, espaços e caracteres especiais)
        const normalizarStatus = (str) => {
            if (!str) return '';
            return str.toLowerCase()
                .normalize("NFD")
                .replace(/[\u0300-\u036f]/g, "")
                .replace(/\s+/g, '')
                .replace(/_/g, '');
        };

        // Mapeamento semântico de cores intuitivas
        const colorMap = {
            'disponivel': cor('--success'),        // Disponível
            'emuso': cor('--primary-accent'),      // Em uso
            'manutencao': cor('--warning'),        // Manutenção
            'baixado': cor('--danger'),            // Baixado
            'inativo': cor('--text-secondary')     // Inativo
        };

        const backgroundColors = labels.map(label => {
            const key = normalizarStatus(label);
            return colorMap[key] || cor('--text-secondary');
        });

        window.chartStat = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: backgroundColors,
                    hoverOffset: 4,
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { position: 'bottom' }
                },
                cutout: '70%'
            }
        });
    } catch (error) {
        console.error("Erro ao carregar gráfico de status:", error);
    }
}

async function renderizarUltimosRegistros() {
    try {
        const bens = await api.get('/api/v1/bem/');
        console.log("Bens carregados para tabela:", bens?.length);

        const tbody = $('#listaRecentes');
        if (!tbody) return;

        if (!bens || bens.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4" class="text-center py-4 text-muted">Nenhum registro encontrado.</td></tr>';
            return;
        }

        // Ordena por ID desc e pega os 5 primeiros
        const recentes = [...bens].sort((a, b) => (b.id || 0) - (a.id || 0)).slice(0, 5);
        
        tbody.innerHTML = recentes.map(bem => `
            <tr>
                <td class="ps-4"><span class="text-muted">#${esc(bem.id)}</span></td>
                <td><span class="fw-bold text-dark">${esc(bem.nome || 'Sem nome')}</span></td>
                <td><span class="badge ${esc(bem.ativo ? 'bg-success-subtle text-success' : 'bg-danger-subtle text-danger')} rounded-pill px-3">${esc(bem.ativo ? 'Ativo' : 'Inativo')}</span></td>
                <td class="text-end pe-4">
                    <a href="/bens" class="btn btn-sm btn-light"><i class="bi bi-arrow-right"></i></a>
                </td>
            </tr>
        `).join('');
    } catch (error) {
        console.error("Erro ao carregar últimos registros:", error);
        const tbody = $('#listaRecentes');
        if (tbody) {
            tbody.innerHTML = '<tr><td colspan="4" class="text-center py-4 text-danger">Erro ao carregar dados.</td></tr>';
        }
    }
}

// Inicializa quando o DOM estiver pronto
document.addEventListener('DOMContentLoaded', init);
