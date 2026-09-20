import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../auth/login_page.dart';

enum AppRole { admin, common }

class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key, required this.role});

  static const adminRoute = '/area-admin';
  static const commonRoute = '/area-comum';
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == AppRole.admin;
    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Área administrativa' : 'Área de consulta'),
        actions: [
          IconButton(
            tooltip: 'Voltar ao login',
            onPressed: () =>
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(LoginPage.routeName, (_) => false),
            icon: const Icon(AppIcons.logout),
          ),
        ],
      ),
      body: AppEmptyState(
        title: isAdmin ? 'Painel administrativo' : 'Consulta de patrimônio',
        description:
            'Esta área receberá as telas liberadas após a autenticação.',
      ),
    );
  }
}
