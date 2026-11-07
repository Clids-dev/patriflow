/**
 * Utils.js - Helpers Globais do PatriFlow
 */

// Escapa texto vindo do servidor antes de inserir em innerHTML.
// Use em todo dado que não seja HTML montado pelo próprio código.
export const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (ch) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
})[ch]);

// Atalhos para manipulação do DOM
export const $ = (selector) => {
    const el = document.querySelector(selector);
    if (!el && selector.startsWith('#')) {
        console.warn(`Elemento não encontrado: ${selector}`);
    }
    return el;
};
export const $$ = (selector) => document.querySelectorAll(selector);

// Helper para chamadas de API
export const api = {
    async request(url, options = {}) {
        const defaultHeaders = { 'Content-Type': 'application/json' };
        
        try {
            console.log(`[API Request] ${options.method || 'GET'} ${url}`);
            const response = await fetch(url, {
                ...options,
                headers: { ...defaultHeaders, ...options.headers }
            });

            if (!response.ok) {
                let errorData;
                try {
                    errorData = await response.json();
                } catch (e) {
                    errorData = { detail: `Erro HTTP ${response.status}` };
                }
                // Validação do FastAPI (422) devolve uma lista de erros; mostra as mensagens, não "[object Object]".
                const detalhe = Array.isArray(errorData.detail)
                    ? errorData.detail.map(e => String(e.msg || '').replace(/^Value error, /, '')).join(' ')
                    : errorData.detail;
                const erro = new Error(detalhe || `Erro na requisição: ${response.status}`);
                erro.status = response.status;
                throw erro;
            }

            return await response.json();
        } catch (error) {
            console.error(`[API Error] ${url}:`, error);
            throw error;
        }
    },

    get(url) { return this.request(url); },
    post(url, body) { return this.request(url, { method: 'POST', body: JSON.stringify(body) }); },
    put(url, body) { return this.request(url, { method: 'PUT', body: JSON.stringify(body) }); },
    patch(url, body) { return this.request(url, { method: 'PATCH', body: JSON.stringify(body) }); },
    delete(url) { return this.request(url, { method: 'DELETE' }); }
};

// Gerenciamento de Notificações (Toast)
export const ui = {
    showNotification(message, type = 'success') {
        const toastEl = document.getElementById('liveToast');
        if (!toastEl) {
            console.error("Elemento 'liveToast' não encontrado no DOM.");
            alert(message); // Fallback
            return;
        }

        const toastIcon = document.getElementById('toastIcon');
        const toastMessage = document.getElementById('toastMessage');
        
        const config = {
            success: { bg: 'bg-success', icon: 'bi-check-circle-fill' },
            error: { bg: 'bg-danger', icon: 'bi-exclamation-circle' },
            warning: { bg: 'bg-warning text-dark', icon: 'bi-exclamation-triangle' }
        };

        const { bg, icon } = config[type] || config.success;

        toastEl.className = `toast align-items-center text-white border-0 ${bg}`;
        toastIcon.className = `bi ${icon} me-2`;
        toastMessage.innerText = message;

        const toast = bootstrap.Toast.getOrCreateInstance(toastEl);
        toast.show();
    },

    setLoading(id, isLoading) {
        const el = document.getElementById(id);
        if (!el) return;
        if (isLoading) {
            el.disabled = true;
            el.dataset.oldContent = el.innerHTML;
            el.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Carregando...';
        } else {
            el.disabled = false;
            el.innerHTML = el.dataset.oldContent || el.innerHTML;
        }
    }
};

// Formatadores
export const format = {
    date(dateString) {
        if (!dateString) return '--';
        try {
            const date = new Date(dateString);
            return date.toLocaleDateString('pt-BR', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        } catch (e) { return '--'; }
    }
};

// Botões de ação das tabelas: a mesma ação tem o mesmo ícone, cor e descrição em todas as telas.
// `classe` mantém o gancho que cada tela usa para tratar o clique (ex.: 'btn-edit').
const ACOES = {
    ver: { icone: 'bi-eye', titulo: 'Ver detalhes', tom: 'neutro' },
    etiqueta: { icone: 'bi-qr-code', titulo: 'Gerar etiqueta', tom: 'neutro' },
    termo: { icone: 'bi-file-earmark-text', titulo: 'Termo de responsabilidade', tom: 'neutro' },
    abrir: { icone: 'bi-arrow-right', titulo: 'Abrir', tom: 'neutro' },
    agentes: { icone: 'bi-person-badge', titulo: 'Agentes designados', tom: 'neutro' },
    editar: { icone: 'bi-pencil-square', titulo: 'Editar', tom: 'primario' },
    inativar: { icone: 'bi-slash-circle', titulo: 'Inativar', tom: 'perigo' },
    baixa: { icone: 'bi-box-arrow-down', titulo: 'Dar baixa', tom: 'perigo' },
    reativar: { icone: 'bi-arrow-counterclockwise', titulo: 'Reativar', tom: 'sucesso' },
};

export function botaoAcao(acao, { id = '', classe = '', titulo, href } = {}) {
    const a = ACOES[acao];
    const rotulo = esc(titulo || a.titulo);
    const conteudo = `<i class="bi ${a.icone}" aria-hidden="true"></i>`;
    const classes = `btn-acao btn-acao--${a.tom} ${classe}`.trim();
    return href
        ? `<a href="${esc(href)}" class="${classes}" title="${rotulo}" aria-label="${rotulo}">${conteudo}</a>`
        : `<button type="button" class="${classes}" data-id="${esc(id)}" title="${rotulo}" aria-label="${rotulo}">${conteudo}</button>`;
}
