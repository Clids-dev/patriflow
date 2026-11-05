import { $, api } from '/static/js/utils.js';

// Contagens do painel de cadastros. Cada uma é independente: uma falha não esconde as outras.
async function contar(url, alvo) {
    try {
        const itens = await api.get(url);
        const el = $(alvo);
        if (el) el.textContent = itens.length;
    } catch (erro) {
        console.warn(`Contagem indisponível (${url}):`, erro);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    contar('/api/v1/categoria/', '#totalCategorias');
    contar('/api/v1/setores/', '#totalSetores');
    contar('/api/v1/responsavel/', '#totalResponsaveis');
});
