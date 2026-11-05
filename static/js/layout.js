/**
 * layout.js - Comportamento do layout (barra lateral, menu responsivo e avisos).
 * Baseado no componente de sidebar do Mazer (MIT), reduzido ao necessário.
 */
import { ui } from '/static/js/utils.js';

const sidebar = document.getElementById('sidebar');
const isDesktop = () => window.innerWidth > 1200;

const createBackdrop = () => {
    if (isDesktop() || document.querySelector('.sidebar-backdrop')) return;
    const backdrop = document.createElement('div');
    backdrop.className = 'sidebar-backdrop';
    backdrop.addEventListener('click', hideSidebar);
    document.body.appendChild(backdrop);
};

const deleteBackdrop = () => document.querySelector('.sidebar-backdrop')?.remove();

const setBodyScroll = (sidebarOpen) => {
    if (isDesktop()) return;
    document.body.style.overflowY = sidebarOpen ? 'hidden' : 'auto';
};

function showSidebar() {
    sidebar.classList.add('active');
    sidebar.classList.remove('inactive');
    createBackdrop();
    setBodyScroll(true);
}

function hideSidebar() {
    sidebar.classList.remove('active');
    sidebar.classList.add('inactive');
    deleteBackdrop();
    setBodyScroll(false);
}

function toggleSidebar(event) {
    event.preventDefault();
    sidebar.classList.contains('active') ? hideSidebar() : showSidebar();
}

function onResize() {
    if (isDesktop()) {
        sidebar.classList.add('active', 'sidebar-desktop');
        sidebar.classList.remove('inactive');
    } else {
        sidebar.classList.remove('active', 'sidebar-desktop');
    }
    deleteBackdrop();
    document.body.style.overflowY = '';
}

if (sidebar) {
    if (isDesktop()) sidebar.classList.add('active', 'sidebar-desktop');

    document.querySelectorAll('.burger-btn').forEach((el) => el.addEventListener('click', toggleSidebar));
    document.querySelectorAll('.sidebar-hide').forEach((el) => el.addEventListener('click', toggleSidebar));
    window.addEventListener('resize', onResize);

    // Ao escolher um item no celular, o menu fecha.
    sidebar.querySelectorAll('.sidebar-link').forEach((link) => {
        link.addEventListener('click', () => { if (!isDesktop()) hideSidebar(); });
    });

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !isDesktop()) hideSidebar();
    });

    // Barra de rolagem fina, como no Mazer.
    if (typeof PerfectScrollbar === 'function') {
        new PerfectScrollbar(sidebar.querySelector('.sidebar-wrapper'), { wheelPropagation: true });
    }

    // Mantém o item ativo visível dentro do menu.
    setTimeout(() => {
        sidebar.querySelector('.sidebar-item.active')?.scrollIntoView({ block: 'nearest' });
    }, 300);
}

// Avisos usados pelas telas.
window.showNotification = ui.showNotification;
