import { $, api, esc } from '/static/js/utils.js';

/**
 * Dashboard.js - Lógica da página inicial com visualização de dados
 */

// Cores vêm dos tokens de style.css, para os gráficos seguirem a paleta do sistema.
const cor = (token) => getComputedStyle(document.documentElement).getPropertyValue(token).trim();

async function init() {
    console.log("Iniciando Dashboard...");
    mostrarDataDeHoje();
    configurarChartsGlobal();
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

// "O que pede atenção": situações que exigem decisão, da mais urgente para a menos urgente.
// Cada fonte é independente. Quem não tem permissão para uma fonte (403) só não a vê;
// falha de verdade é sinalizada, para não parecer que "tudo está em ordem" quando não está.
const PRIORIDADE_ATENCAO = { escalada: 0, emprestimoAtrasado: 1, baixa: 2, transferencia: 3, garantiaVencida: 4, garantiaAVencer: 5 };
const LIMITE_ATENCAO = 6;

async function renderizarAtencao() {
    const lista = $('#atencaoLista');
    const total = $('#atencaoTotal');

    const [escaladas, atrasados, baixas, pendentes, garantias] = await Promise.allSettled([
        api.get('/api/v1/movimentacao/escaladas'),
        api.get('/api/v1/emprestimos/?situacao=atrasados'),
        api.get('/api/v1/bem/baixas/pendentes'),
        api.get('/api/v1/movimentacao/pendentes'),
        api.get('/api/v1/bem/alertas/garantias?dias=60'),
    ]);

    const resultados = [escaladas, atrasados, baixas, pendentes, garantias];
    const falhou = resultados.some(r => r.status === 'rejected' && r.reason?.status !== 403);
    resultados.filter(r => r.status === 'rejected').forEach(r => console.warn('Fonte de atenção indisponível:', r.reason));
    const dados = r => (r.status === 'fulfilled' ? r.value : []);

    const itens = [];
    const idsEscaladas = new Set();

    dados(escaladas).forEach(m => {
        idsEscaladas.add(m.id);
        itens.push({
            prioridade: PRIORIDADE_ATENCAO.escalada,
            icone: 'bi-exclamation-octagon',
            titulo: `Transferência escalada: ${m.bem_nome}`,
            detalhe: `${m.codigo_tombamento} → ${m.setor_destino_nome} · sem resposta no prazo`,
            link: `/movimentacao?aba=escaladas&busca=${encodeURIComponent(m.codigo_tombamento)}`,
        });
    });

    dados(atrasados).forEach(e => itens.push({
        prioridade: PRIORIDADE_ATENCAO.emprestimoAtrasado,
        icone: 'bi-alarm',
        titulo: `Empréstimo atrasado: ${e.bem_nome}`,
        detalhe: `${e.codigo_tombamento} · com ${e.tomador} · ${e.dias_atraso} dia(s) de atraso`,
        link: `/bens?busca=${encodeURIComponent(e.codigo_tombamento)}`,
    }));

    dados(baixas).forEach(b => itens.push({
        prioridade: PRIORIDADE_ATENCAO.baixa,
        icone: 'bi-box-arrow-down',
        titulo: `Baixa aguardando aprovação: ${b.bem_nome}`,
        detalhe: `${b.codigo_tombamento} · ${b.motivo} · solicitada por ${b.solicitante}`,
        link: `/bens?busca=${encodeURIComponent(b.codigo_tombamento)}`,
    }));

    dados(pendentes).filter(m => !idsEscaladas.has(m.id)).forEach(m => itens.push({
        prioridade: PRIORIDADE_ATENCAO.transferencia,
        icone: 'bi-arrow-left-right',
        titulo: `Transferência aguardando autorização: ${m.bem_nome}`,
        detalhe: `${m.codigo_tombamento} → ${m.setor_destino_nome}`,
        link: `/movimentacao?aba=decidir&busca=${encodeURIComponent(m.codigo_tombamento)}`,
    }));

    const listaGarantias = dados(garantias);
    listaGarantias.forEach(g => {
        const data = new Date(g.garantia_fim + 'T00:00:00').toLocaleDateString('pt-BR');
        const link = `/bens?busca=${encodeURIComponent(g.codigo_tombamento)}`;
        if (g.vencida) {
            itens.push({ prioridade: PRIORIDADE_ATENCAO.garantiaVencida, icone: 'bi-shield-exclamation',
                titulo: `Garantia vencida: ${g.nome}`, detalhe: `${g.codigo_tombamento} · venceu em ${data}`, link });
        } else {
            itens.push({ prioridade: PRIORIDADE_ATENCAO.garantiaAVencer, icone: 'bi-shield-check',
                titulo: `Garantia a vencer: ${g.nome}`, detalhe: `${g.codigo_tombamento} · vence em ${data}`, link });
        }
    });

    const kpi = $('#kpiGarantias');
    if (kpi) kpi.textContent = garantias.status === 'fulfilled' ? listaGarantias.length : '--';

    itens.sort((a, b) => a.prioridade - b.prioridade);
    total.textContent = `${itens.length} ${itens.length === 1 ? 'ponto' : 'pontos'}`;

    if (itens.length === 0) {
        lista.innerHTML = falhou
            ? '<li class="atencao-vazio">Não foi possível carregar esta seção agora. Atualize a página.</li>'
            : '<li class="atencao-vazio">Nada pendente agora. Tudo em ordem.</li>';
        return;
    }

    const visiveis = itens.slice(0, LIMITE_ATENCAO);
    const ocultos = itens.length - visiveis.length;
    const html = visiveis.map(item => `
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
    const rodape = ocultos > 0
        ? `<li class="atencao-vazio"><small>+ ${ocultos} ${ocultos === 1 ? 'item' : 'itens'} não exibido${ocultos === 1 ? "" : "s"}</small></li>`
        : '';
    lista.innerHTML = html + rodape;
}

// ----- Estilo dos gráficos: paleta e tipografia do projeto -----
function configurarChartsGlobal() {
    if (typeof Chart === 'undefined') return;
    Chart.defaults.font.family = "Inter, -apple-system, BlinkMacSystemFont, sans-serif";
    Chart.defaults.font.size = 12;
    Chart.defaults.color = cor('--text-secondary');
    Chart.defaults.borderColor = cor('--border-color');
    const tip = Chart.defaults.plugins.tooltip;
    tip.backgroundColor = cor('--primary-dark');
    tip.padding = 12;
    tip.cornerRadius = 12;
    tip.boxPadding = 6;
    tip.titleFont = { weight: '700', size: 13 };
}

// Degradê vertical entre dois tokens, aplicado na área real do gráfico.
function degrade(chart, de, para) {
    const area = chart.chartArea;
    if (!area) return cor(de);
    const g = chart.ctx.createLinearGradient(0, area.bottom, 0, area.top);
    g.addColorStop(0, cor(de));
    g.addColorStop(1, cor(para));
    return g;
}

async function renderizarGraficoCategorias() {
    try {
        const stats = await api.get('/api/v1/bem/stats/categoria');
        if (!stats || stats.length === 0) return;

        const labels = stats.map(s => s[0]);
        const data = stats.map(s => s[1]);
        const ctx = document.getElementById('chartCategorias');
        if (!ctx) return;

        if (window.chartCat) window.chartCat.destroy();
        window.chartCat = new Chart(ctx, {
            type: 'bar',
            data: {
                labels,
                datasets: [{
                    label: 'Bens',
                    data,
                    backgroundColor: (c) => degrade(c.chart, '--primary-accent', '--primary-color'),
                    borderRadius: 10,
                    borderSkipped: false,
                    maxBarThickness: 44,
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                animation: { duration: 700, easing: 'easeOutQuart' },
                plugins: {
                    legend: { display: false },
                    tooltip: { callbacks: { label: (c) => ` ${c.parsed.y} bem(ns)` } }
                },
                scales: {
                    x: { grid: { display: false }, border: { display: false }, ticks: { font: { weight: '600' } } },
                    y: {
                        beginAtZero: true,
                        border: { display: false },
                        grid: { color: cor('--border-color'), drawTicks: false },
                        ticks: { precision: 0, padding: 8 }
                    }
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
        if (!stats || stats.length === 0) return;

        const labels = stats.map(s => s[0]);
        const data = stats.map(s => s[1]);
        const total = data.reduce((soma, v) => soma + v, 0);
        const ctx = document.getElementById('chartStatus');
        if (!ctx) return;

        if (window.chartStat) window.chartStat.destroy();

        const normalizarStatus = (str) => (str || '').toLowerCase()
            .normalize("NFD").replace(/[̀-ͯ]/g, "")
            .replace(/\s+/g, '').replace(/_/g, '');

        // Cores dos status pelos tokens do projeto.
        const colorMap = {
            'disponivel': '--success',
            'emuso': '--primary-accent',
            'manutencao': '--warning',
            'baixado': '--danger',
            'inativo': '--text-secondary'
        };
        const backgroundColors = labels.map(label => cor(colorMap[normalizarStatus(label)] || '--text-secondary'));

        // Número total no centro da rosca.
        const centroTotal = {
            id: 'centroTotal',
            afterDraw(chart) {
                const { ctx: g, chartArea } = chart;
                if (!chartArea) return;
                const x = (chartArea.left + chartArea.right) / 2;
                const y = (chartArea.top + chartArea.bottom) / 2;
                g.save();
                g.textAlign = 'center';
                g.textBaseline = 'middle';
                g.fillStyle = cor('--text-primary');
                g.font = '800 28px Inter, sans-serif';
                g.fillText(String(total), x, y - 8);
                g.fillStyle = cor('--text-secondary');
                g.font = '600 12px Inter, sans-serif';
                g.fillText('itens', x, y + 18);
                g.restore();
            }
        };

        window.chartStat = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels,
                datasets: [{
                    data,
                    backgroundColor: backgroundColors,
                    borderColor: cor('--surface-color'),
                    borderWidth: 4,
                    borderRadius: 6,
                    hoverOffset: 8,
                }]
            },
            plugins: [centroTotal],
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '74%',
                animation: { animateRotate: true, duration: 800 },
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: { usePointStyle: true, pointStyle: 'circle', boxWidth: 8, padding: 18, font: { weight: '600' } }
                    },
                    tooltip: {
                        callbacks: {
                            label: (c) => ` ${c.label}: ${c.parsed} (${Math.round(c.parsed * 100 / total)}%)`
                        }
                    }
                }
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
