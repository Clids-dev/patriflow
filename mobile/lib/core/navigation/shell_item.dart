import 'package:flutter/widgets.dart';

/// Um item do menu do aplicativo. Cada perfil recebe a sua lista; o menu lateral
/// segue a mesma ordem e os mesmos nomes da web.
class ShellItem {
  const ShellItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
    this.bottomBar = false,
    this.badge,
    this.subitens = const [],
  });

  /// Nome exibido no menu e na barra inferior (igual à web).
  final String label;
  final IconData icon;

  /// Versão preenchida do ícone, usada quando o item está selecionado.
  final IconData selectedIcon;

  /// Tela do item. Recebe apenas o corpo; a barra superior é da shell.
  final Widget page;

  /// Aparece na barra inferior. A barra tem no máximo 4 itens; a última vaga é "Mais".
  final bool bottomBar;

  /// Contagem exibida como bolinha no ícone (ex.: transferências pendentes).
  final Future<int> Function()? badge;

  /// Atalhos que aparecem ao expandir o item no menu lateral (ex.: categorias,
  /// setores e responsáveis dentro de "Estrutura"). Abrem a tela direto.
  final List<ShellItem> subitens;
}
