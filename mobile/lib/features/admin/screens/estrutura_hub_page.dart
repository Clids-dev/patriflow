import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_components.dart';
import '../../home/inicio_page.dart';
import 'categories_screen.dart';
import 'responsibles_screen.dart';
import 'sectors_screen.dart';
import 'users_screen.dart';

/// Hub "Estrutura", igual ao da web: reúne categorias, setores e localização,
/// responsáveis e a aprovação de usuários.
class EstruturaHubPage extends StatelessWidget {
  const EstruturaHubPage({super.key, required this.adminId});

  final int adminId;

  void _abrir(BuildContext context, String titulo, Widget tela) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaginaSimples(titulo: titulo, child: tela),
        ),
      );

  @override
  Widget build(BuildContext context) => ListView(
    padding: AppSpacing.screen,
    children: [
      Text(
        'Cadastros que organizam o patrimônio: categorias, setores, responsáveis e acessos.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      AppListCard(
        leading: const AppIconBadge(icon: Icons.category_outlined),
        title: 'Categorias',
        subtitle: 'Siglas usadas no tombamento',
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () => _abrir(context, 'Categorias', const CategoriesScreen()),
      ),
      AppListCard(
        leading: const AppIconBadge(icon: Icons.business_outlined),
        title: 'Setores e localização',
        subtitle: 'Prédio, andar, sala e setor',
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () => _abrir(context, 'Setores e localização', const SectorsScreen()),
      ),
      AppListCard(
        leading: const AppIconBadge(icon: Icons.people_outline),
        title: 'Responsáveis',
        subtitle: 'Pessoas que respondem pelos bens',
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () => _abrir(context, 'Responsáveis', const ResponsibleScreen()),
      ),
      AppListCard(
        leading: const AppIconBadge(icon: Icons.manage_accounts_outlined),
        title: 'Usuários',
        subtitle: 'Aprovação de contas e perfis de acesso',
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () => _abrir(
          context,
          'Usuários',
          UsersScreen(adminId: adminId),
        ),
      ),
    ],
  );
}
