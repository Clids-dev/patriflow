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
                throw new Error(errorData.detail || `Erro na requisição: ${response.status}`);
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
            success: { bg: 'bg-success', icon: 'fa-check-circle' },
            error: { bg: 'bg-danger', icon: 'fa-exclamation-circle' },
            warning: { bg: 'bg-warning text-dark', icon: 'fa-exclamation-triangle' }
        };

        const { bg, icon } = config[type] || config.success;

        toastEl.className = `toast align-items-center text-white border-0 ${bg}`;
        toastIcon.className = `fas ${icon} me-2`;
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
