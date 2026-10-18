import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/api_client.dart';
import '../../core/services/session_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../server_config/server_config_page.dart';

enum AdminSection {
  dashboard('Dashboard', Icons.dashboard_outlined),
  bens('Bens', Icons.inventory_2_outlined),
  categorias('Categorias', Icons.category_outlined),
  setores('Setores e localização', Icons.business_outlined),
  responsaveis('Responsáveis', Icons.people_outline),
  movimentacoes('Movimentações', Icons.swap_horiz_outlined),
  relatorios('Relatórios', Icons.analytics_outlined);

  const AdminSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.profile});
  final Map<String, dynamic> profile;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  AdminSection _section = AdminSection.dashboard;
  int _refresh = 0;

  void _reload() => setState(() => _refresh++);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_section.label),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    drawer: Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(AppIcons.brand, color: AppColors.primary, size: 36),
            ),
            accountName: Text(
              widget.profile['nome']?.toString() ??
                  widget.profile['username']?.toString() ??
                  'Administrador',
            ),
            accountEmail: const Text('Setor de Patrimônio'),
          ),
          Expanded(
            child: ListView(
              children: [
                ...AdminSection.values.map(
                  (item) => ListTile(
                    leading: Icon(
                      item.icon,
                      color: _section == item ? AppColors.primary : null,
                    ),
                    title: Text(item.label),
                    selected: _section == item,
                    onTap: () {
                      setState(() => _section = item);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(AppIcons.settings),
                  title: const Text('Configurar servidor'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, ServerConfigPage.routeName);
                  },
                ),
                ListTile(
                  leading: const Icon(AppIcons.logout, color: AppColors.error),
                  title: const Text(
                    'Sair',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () async {
                    await SessionManager.logout();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    body: KeyedSubtree(
      key: ValueKey('${_section.name}-$_refresh'),
      child: switch (_section) {
        AdminSection.dashboard => const _DashboardScreen(),
        AdminSection.bens => const _AssetsScreen(),
        AdminSection.categorias => const _CategoriesScreen(),
        AdminSection.setores => const _SectorsScreen(),
        AdminSection.responsaveis => const _ResponsibleScreen(),
        AdminSection.movimentacoes => const _MovementsScreen(),
        AdminSection.relatorios => const _ReportsScreen(),
      },
    ),
  );
}

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: Future.wait([ApiClient.get('/bem/'), ApiClient.get('/categoria/')]),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const AppLoading(label: 'Carregando painel...');
      if (snapshot.hasError)
        return AppErrorState(
          title: 'Erro ao carregar painel',
          description: '${snapshot.error}',
        );
      final assets = snapshot.data![0];
      final categoryNames = {
        for (final item in snapshot.data![1])
          '${item['id']}': '${item['nome']}',
      };
      final active = assets.where((item) => item['ativo'] == true).length;
      final inactive = assets.length - active;
      final categories = <String, int>{};
      final statuses = <String, int>{};
      for (final item in assets) {
        final key = categoryNames['${item['id_categoria']}'] ?? 'Sem categoria';
        categories.update(key, (n) => n + 1, ifAbsent: () => 1);
        final status = '${item['status'] ?? 'Sem status'}';
        statuses.update(status, (n) => n + 1, ifAbsent: () => 1);
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Visão geral do patrimônio',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                label: 'Total de itens',
                value: '${assets.length}',
                icon: Icons.inventory_2_outlined,
              ),
              _MetricCard(
                label: 'Itens ativos',
                value: '$active',
                icon: Icons.check_circle_outline,
              ),
              _MetricCard(
                label: 'Itens inativos',
                value: '$inactive',
                icon: Icons.archive_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _CountList(title: 'Distribuição por categoria', counts: categories),
          const SizedBox(height: 12),
          _CountList(title: 'Distribuição por status', counts: statuses),
          const SizedBox(height: 12),
          Text(
            'Últimos registros',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...assets.reversed
              .take(5)
              .map(
                (asset) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text('${asset['nome'] ?? 'Bem'}'),
                  subtitle: Text(
                    '${asset['codigo_tombamento'] ?? ''} • ${asset['status'] ?? ''}',
                  ),
                ),
              ),
        ],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 42) / 2,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _CountList extends StatelessWidget {
  const _CountList({required this.title, required this.counts});
  final String title;
  final Map<String, int> counts;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (counts.isEmpty)
            const Text('Sem dados')
          else
            ...counts.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(entry.key), Text('${entry.value}')],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _AssetsScreen extends StatefulWidget {
  const _AssetsScreen();
  @override
  State<_AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<_AssetsScreen> {
  String _query = '';
  String? _statusFilter;
  int _refresh = 0;

  Future<void> _editAsset(
    List<dynamic> categories, [
    Map<String, dynamic>? asset,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AssetDialog(categories: categories, asset: asset),
    );
    if (saved == true && mounted) setState(() => _refresh++);
  }

  Future<void> _toggleActive(Map<String, dynamic> asset) async {
    final active = asset['ativo'] == true;
    final confirmed = await _confirm(
      context,
      active ? 'Dar baixa neste bem?' : 'Reativar este bem?',
    );
    if (!mounted || !confirmed) return;
    try {
      await ApiClient.post(
        '/bem/${asset['id']}/${active ? 'desativar' : 'reativar'}',
        {},
      );
      if (mounted) setState(() => _refresh++);
    } catch (e) {
      if (mounted) _message(context, '$e');
    }
  }

  Future<void> _showDetails(Map<String, dynamic> asset) async {
    try {
      final details = await ApiClient.getMap('/bem/${asset['id']}/detalhes');
      final history = await ApiClient.get(
        '/movimentacao/bem/${Uri.encodeComponent('${asset['codigo_tombamento']}')}',
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .78,
            builder: (ctx, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${details['nome']}',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                Text(
                  'Tombo ${details['codigo_tombamento']} • ${details['status']}',
                ),
                const Divider(),
                _detailLine('Categoria', details['categoria_nome']),
                _detailLine(
                  'Marca / modelo',
                  '${details['marca'] ?? '—'} ${details['modelo'] ?? ''}',
                ),
                _detailLine('Número de série', details['numero_serie']),
                _detailLine(
                  'Valor de aquisição',
                  'R\$ ${details['valor_aquisicao'] ?? details['valor'] ?? '—'}',
                ),
                _detailLine('Nota fiscal', details['nota_fiscal']),
                _detailLine(
                  'Data de entrada',
                  _shortDate(details['data_entrada']),
                ),
                _detailLine('Conservação', details['estado_conservacao']),
                _detailLine(
                  'Local atual',
                  '${details['predio_nome'] ?? '—'} • ${details['andar_identificacao'] ?? '—'} • ${details['sala_nome'] ?? '—'}',
                ),
                const Divider(),
                Text(
                  'Histórico de movimentações',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                if (history.isEmpty)
                  const Text('Sem movimentações registradas.'),
                ...history.map((raw) {
                  final item = Map<String, dynamic>.from(raw);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(
                      '${item['setor_origem_nome'] ?? 'Origem inicial'} → ${item['setor_destino_nome'] ?? ''}',
                    ),
                    subtitle: Text(
                      '${_shortDate(item['data_movimentacao'])} • ${item['justificativa'] ?? ''}',
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) _message(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    key: ValueKey(_refresh),
    future: Future.wait([ApiClient.get('/bem/'), ApiClient.get('/categoria/')])
        .then((value) => value),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const AppLoading(label: 'Carregando bens...');
      if (snapshot.hasError)
        return AppErrorState(
          title: 'Erro ao carregar bens',
          description: '${snapshot.error}',
          onRetry: () => setState(() => _refresh++),
        );
      final assets = snapshot.data![0];
      final categories = snapshot.data![1];
      final filtered = assets
          .where(
            (item) =>
                '${item['nome']} ${item['codigo_tombamento']} ${item['marca'] ?? ''}'
                    .toLowerCase()
                    .contains(_query.toLowerCase()) &&
                (_statusFilter == null || item['status'] == _statusFilter),
          )
          .toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar nome ou tombo',
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Novo bem',
                  onPressed: () => _editAsset(categories),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Filtrar por status',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todos os status'),
                ),
                ...['Disponível', 'Em Uso', 'Manutenção', 'Baixado'].map(
                  (v) => DropdownMenuItem<String>(value: v, child: Text(v)),
                ),
              ],
              onChanged: (v) => setState(() => _statusFilter = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const AppEmptyState(title: 'Nenhum bem encontrado')
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final asset = Map<String, dynamic>.from(filtered[index]);
                      final value =
                          asset['valor_aquisicao'] ?? asset['valor'] ?? 0;
                      return Card(
                        child: ListTile(
                          isThreeLine: true,
                          title: Text(
                            '${asset['nome'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${asset['codigo_tombamento']} • ${asset['status']}\n${asset['marca'] ?? ''} ${asset['modelo'] ?? ''} • R\$ ${value}',
                          ),
                          onTap: () => _showDetails(asset),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'edit')
                                _editAsset(categories, asset);
                              if (action == 'toggle') _toggleActive(asset);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  asset['ativo'] == true
                                      ? 'Dar baixa'
                                      : 'Reativar',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );
}

class _AssetDialog extends StatefulWidget {
  const _AssetDialog({required this.categories, this.asset});
  final List<dynamic> categories;
  final Map<String, dynamic>? asset;
  @override
  State<_AssetDialog> createState() => _AssetDialogState();
}

class _AssetDialogState extends State<_AssetDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: '${widget.asset?['nome'] ?? ''}',
  );
  late final _type = TextEditingController(
    text: '${widget.asset?['tipo'] ?? 'Equipamento'}',
  );
  late final _value = TextEditingController(
    text: '${widget.asset?['valor_aquisicao'] ?? widget.asset?['valor'] ?? ''}',
  );
  late final _brand = TextEditingController(
    text: '${widget.asset?['marca'] ?? ''}',
  );
  late final _model = TextEditingController(
    text: '${widget.asset?['modelo'] ?? ''}',
  );
  late final _serial = TextEditingController(
    text: '${widget.asset?['numero_serie'] ?? ''}',
  );
  late final _invoice = TextEditingController(
    text: '${widget.asset?['nota_fiscal'] ?? ''}',
  );
  late final _date = TextEditingController(
    text: '${widget.asset?['data_entrada'] ?? ''}'.split('T').first,
  );
  late final _tombo = TextEditingController(
    text: '${widget.asset?['codigo_tombamento'] ?? ''}',
  );
  late int? _category = widget.asset?['id_categoria'] as int?;
  late String _status = '${widget.asset?['status'] ?? 'Disponível'}';
  late String _condition = '${widget.asset?['estado_conservacao'] ?? 'novo'}';
  bool _saving = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _category == null) return;
    setState(() => _saving = true);
    try {
      final isNew = widget.asset == null;
      var code = _tombo.text.trim();
      if (isNew) {
        final next = await ApiClient.getMap('/bem/proximo-codigo/$_category');
        code = '${next['codigo']}';
      }
      final amount = double.parse(_value.text.replaceAll(',', '.'));
      final payload = <String, dynamic>{
        'nome': _name.text.trim(),
        'tipo': _type.text.trim(),
        'valor': amount,
        'status': _status,
        'id_categoria': _category,
        'marca': _blank(_brand.text),
        'modelo': _blank(_model.text),
        'numero_serie': _blank(_serial.text),
        'valor_aquisicao': amount,
        'nota_fiscal': _blank(_invoice.text),
        'data_entrada': _blank(_date.text),
        'estado_conservacao': _condition,
      };
      if (isNew) {
        payload['codigo_tombamento'] = code;
        await ApiClient.post('/bem/', payload);
      } else {
        payload.remove('tipo');
        payload.remove('id_categoria');
        await ApiClient.put('/bem/${widget.asset!['id']}', body: payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _message(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.asset == null ? 'Cadastrar bem' : 'Editar bem'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_name, 'Nome', required: true),
              if (widget.asset == null) ...[
                _field(_type, 'Tipo', required: true),
                DropdownButtonFormField<int>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: widget.categories
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text('${c['nome']} (${c['sigla']})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _category = v),
                ),
              ],
              _field(
                _value,
                'Valor de aquisição',
                required: true,
                number: true,
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const ['Disponível', 'Em Uso', 'Manutenção', 'Baixado']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              _field(_brand, 'Marca'),
              _field(_model, 'Modelo'),
              _field(_serial, 'Número de série'),
              _field(_invoice, 'Nota fiscal'),
              _field(_date, 'Data de entrada (AAAA-MM-DD)'),
              DropdownButtonFormField<String>(
                value: _condition,
                decoration: const InputDecoration(labelText: 'Conservação'),
                items: const ['novo', 'bom', 'regular', 'ruim', 'inservivel']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _condition = v ?? _condition),
              ),
              if (widget.asset == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'O tombo será gerado automaticamente com dígito verificador.',
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Salvando...' : 'Salvar'),
      ),
    ],
  );
}

class _CategoriesScreen extends StatefulWidget {
  const _CategoriesScreen();
  @override
  State<_CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<_CategoriesScreen> {
  int _refresh = 0;
  Future<void> _edit([Map<String, dynamic>? category]) async {
    final name = TextEditingController(text: '${category?['nome'] ?? ''}');
    final acronym = TextEditingController(text: '${category?['sigla'] ?? ''}');
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? 'Nova categoria' : 'Editar categoria'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: _required,
              ),
              if (category == null)
                TextFormField(
                  controller: acronym,
                  maxLength: 3,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Sigla (3 caracteres)',
                  ),
                  validator: _required,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                if (category == null) {
                  await ApiClient.post('/categoria/', {
                    'nome': name.text.trim(),
                    'sigla': acronym.text.trim().toUpperCase(),
                  });
                } else {
                  await ApiClient.put(
                    '/categoria/',
                    queryParameters: {
                      'id': '${category['id']}',
                      'novo_nome': name.text.trim(),
                    },
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) _message(ctx, '$e');
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    name.dispose();
    acronym.dispose();
    if (saved == true && mounted) setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    key: ValueKey(_refresh),
    future: ApiClient.get('/categoria/'),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const AppLoading();
      if (snapshot.hasError)
        return AppErrorState(
          description: '${snapshot.error}',
          onRetry: () => setState(() => _refresh++),
        );
      final rows = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Nova categoria'),
            ),
          ),
          ...rows.map((raw) {
            final row = Map<String, dynamic>.from(raw);
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${row['sigla'] ?? ''}')),
                title: Text('${row['nome'] ?? ''}'),
                subtitle: Text('ID ${row['id']}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') await _edit(row);
                    if (v == 'disable' &&
                        await _confirm(
                          context,
                          'Desativar categoria ${row['nome']}?',
                        )) {
                      try {
                        await ApiClient.delete(
                          '/categoria/',
                          queryParameters: {'id': '${row['id']}'},
                        );
                        if (mounted) setState(() => _refresh++);
                      } catch (e) {
                        if (mounted) _message(context, '$e');
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar nome')),
                    PopupMenuItem(value: 'disable', child: Text('Desativar')),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    },
  );
}

class _ResponsibleScreen extends StatefulWidget {
  const _ResponsibleScreen();
  @override
  State<_ResponsibleScreen> createState() => _ResponsibleScreenState();
}

class _ResponsibleScreenState extends State<_ResponsibleScreen> {
  int _refresh = 0;
  Future<void> _edit([Map<String, dynamic>? row]) async {
    final name = TextEditingController(text: '${row?['nome'] ?? ''}');
    final job = TextEditingController(text: '${row?['cargo'] ?? ''}');
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(row == null ? 'Novo responsável' : 'Editar responsável'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: _required,
              ),
              TextFormField(
                controller: job,
                decoration: const InputDecoration(labelText: 'Cargo'),
                validator: _required,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                if (row == null)
                  await ApiClient.post('/responsavel/', {
                    'nome': name.text.trim(),
                    'cargo': job.text.trim(),
                  });
                else
                  await ApiClient.put(
                    '/responsavel/',
                    body: {'nome': name.text.trim(), 'cargo': job.text.trim()},
                    queryParameters: {'id': '${row['id']}'},
                  );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) _message(ctx, '$e');
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    name.dispose();
    job.dispose();
    if (result == true && mounted) setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    key: ValueKey(_refresh),
    future: ApiClient.get('/responsavel/'),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const AppLoading();
      if (snapshot.hasError)
        return AppErrorState(
          description: '${snapshot.error}',
          onRetry: () => setState(() => _refresh++),
        );
      final rows = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Novo responsável'),
            ),
          ),
          ...rows.map((raw) {
            final row = Map<String, dynamic>.from(raw);
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('${row['nome']}'),
                subtitle: Text('${row['cargo']}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') await _edit(row);
                    if (v == 'disable' &&
                        await _confirm(context, 'Desativar ${row['nome']}?')) {
                      try {
                        await ApiClient.delete(
                          '/responsavel/',
                          queryParameters: {'id': '${row['id']}'},
                        );
                        if (mounted) setState(() => _refresh++);
                      } catch (e) {
                        if (mounted) _message(context, '$e');
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'disable', child: Text('Desativar')),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    },
  );
}

class _SectorsScreen extends StatefulWidget {
  const _SectorsScreen();
  @override
  State<_SectorsScreen> createState() => _SectorsScreenState();
}

class _SectorsScreenState extends State<_SectorsScreen> {
  int _refresh = 0;

  Future<void> _editSector(
    Map<String, dynamic> row,
    List<dynamic> responsibles,
    List<dynamic> rooms,
  ) async {
    final name = TextEditingController(text: '${row['nome']}');
    final form = GlobalKey<FormState>();
    int? responsibleId = row['responsavel_id'] as int?;
    int? roomId = row['sala_id'] as int?;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text('Editar ${row['nome']}'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: _required,
                ),
                DropdownButtonFormField<int>(
                  value: responsibleId,
                  decoration: const InputDecoration(labelText: 'Responsável'),
                  items: responsibles
                      .map(
                        (r) => DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child: Text('${r['nome']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => refresh(() => responsibleId = v),
                ),
                DropdownButtonFormField<int>(
                  value: roomId,
                  decoration: const InputDecoration(labelText: 'Sala'),
                  items: rooms
                      .map(
                        (r) => DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child: Text(
                            '${r['predio_nome']} • ${r['andar_identificacao']} • ${r['identificacao']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => refresh(() => roomId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate() ||
                    responsibleId == null ||
                    roomId == null) {
                  _message(ctx, 'Informe nome, responsável e sala.');
                  return;
                }
                try {
                  await ApiClient.put(
                    '/setores/${row['id']}',
                    queryParameters: {
                      'novo_nome': name.text.trim(),
                      'novo_responsavel_id': '$responsibleId',
                      'novo_sala_id': '$roomId',
                    },
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) _message(ctx, '$e');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (result == true && mounted) setState(() => _refresh++);
  }

  Future<void> _simpleLocation(
    String title,
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final name = TextEditingController();
    final extra = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (body.containsKey('predio_id'))
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Prédio'),
                  items: (body['predios'] as List)
                      .map(
                        (r) => DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child: Text('${r['nome']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => body['predio_id'] = v,
                ),
              if (body.containsKey('andar_id'))
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Andar'),
                  items: (body['andares'] as List)
                      .map(
                        (r) => DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child: Text(
                            '${r['predio_nome']} • ${r['identificacao']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => body['andar_id'] = v,
                ),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nome / identificação',
                ),
                validator: _required,
              ),
              if (endpoint.endsWith('predios'))
                TextField(
                  controller: extra,
                  decoration: const InputDecoration(
                    labelText: 'Endereço (opcional)',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              if ((body.containsKey('predio_id') &&
                      body['predio_id'] == null) ||
                  (body.containsKey('andar_id') && body['andar_id'] == null)) {
                _message(ctx, 'Selecione a localização superior.');
                return;
              }
              final payload = <String, dynamic>{...body}
                ..remove('predios')
                ..remove('andares');
              payload[endpoint.endsWith('predios') ? 'nome' : 'identificacao'] =
                  name.text.trim();
              if (endpoint.endsWith('predios'))
                payload['endereco'] = _blank(extra.text);
              try {
                await ApiClient.post(endpoint, payload);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) _message(ctx, '$e');
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    name.dispose();
    extra.dispose();
    if (result == true && mounted) setState(() => _refresh++);
  }

  Future<void> _createSector(
    List<dynamic> responsibles,
    List<dynamic> rooms,
  ) async {
    final name = TextEditingController();
    final form = GlobalKey<FormState>();
    int? responsibleId;
    int? roomId;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: const Text('Novo setor'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: _required,
                ),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Responsável'),
                  items: responsibles
                      .map(
                        (r) => DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child: Text('${r['nome']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => refresh(() => responsibleId = v),
                ),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Sala'),
                  items: rooms
                      .map(
                        (r) => DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child: Text(
                            '${r['predio_nome']} • ${r['andar_identificacao']} • ${r['identificacao']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => refresh(() => roomId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate() ||
                    responsibleId == null ||
                    roomId == null) {
                  _message(ctx, 'Informe nome, responsável e sala.');
                  return;
                }
                try {
                  await ApiClient.post('/setores/', {
                    'nome': name.text.trim(),
                    'responsavel_id': responsibleId,
                    'sala_id': roomId,
                    'flag_almoxarifado': false,
                  });
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) _message(ctx, '$e');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (result == true && mounted) setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    key: ValueKey(_refresh),
    future: Future.wait([
      ApiClient.get('/setores/'),
      ApiClient.get('/responsavel/'),
      ApiClient.get('/localizacao/predios'),
      ApiClient.get('/localizacao/andares'),
      ApiClient.get('/localizacao/salas'),
    ]),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const AppLoading(label: 'Carregando setores e locais...');
      if (snapshot.hasError)
        return AppErrorState(
          description: '${snapshot.error}',
          onRetry: () => setState(() => _refresh++),
        );
      final sectors = snapshot.data![0];
      final responsibles = snapshot.data![1];
      final buildings = snapshot.data![2];
      final floors = snapshot.data![3];
      final rooms = snapshot.data![4];
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Localização física',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () =>
                    _simpleLocation('Novo prédio', '/localizacao/predios', {}),
                child: const Text('Prédio'),
              ),
              OutlinedButton(
                onPressed: buildings.isEmpty
                    ? null
                    : () => _simpleLocation(
                        'Novo andar',
                        '/localizacao/andares',
                        {'predio_id': null, 'predios': buildings},
                      ),
                child: const Text('Andar'),
              ),
              OutlinedButton(
                onPressed: floors.isEmpty
                    ? null
                    : () => _simpleLocation('Nova sala', '/localizacao/salas', {
                        'andar_id': null,
                        'andares': floors,
                      }),
                child: const Text('Sala'),
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Setores', style: Theme.of(context).textTheme.titleLarge),
              IconButton.filled(
                tooltip: 'Novo setor',
                onPressed: responsibles.isEmpty || rooms.isEmpty
                    ? null
                    : () => _createSector(responsibles, rooms),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          ...sectors.map((raw) {
            final row = Map<String, dynamic>.from(raw);
            return Card(
              child: ListTile(
                leading: const Icon(Icons.business),
                title: Text('${row['nome']}'),
                subtitle: Text(
                  '${row['predio_nome']} • ${row['andar_identificacao']} • ${row['sala_nome']}\nResponsável: ${row['responsavel_nome'] ?? '—'}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _editSector(row, responsibles, rooms);
                      return;
                    }
                    if (!mounted ||
                        !await _confirm(
                          context,
                          'Desativar setor ${row['nome']}?',
                        ))
                      return;
                    try {
                      await ApiClient.delete(
                        '/setores/',
                        queryParameters: {'id': '${row['id']}'},
                      );
                      if (mounted) setState(() => _refresh++);
                    } catch (e) {
                      if (mounted) _message(context, '$e');
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'disable', child: Text('Desativar')),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    },
  );
}

class _MovementsScreen extends StatefulWidget {
  const _MovementsScreen();
  @override
  State<_MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<_MovementsScreen> {
  int _refresh = 0;
  String _query = '';
  Future<void> _create(List<dynamic> assets, List<dynamic> sectors) async {
    final code = TextEditingController();
    final reason = TextEditingController();
    int? selectedAsset;
    int? destination;
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: const Text('Nova transferência'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Bem'),
                  items: assets
                      .where((r) => r['ativo'] == true)
                      .map(
                        (r) => DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child: Text(
                            '${r['codigo_tombamento']} • ${r['nome']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => refresh(() => selectedAsset = v),
                ),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Setor de destino',
                  ),
                  items: sectors
                      .map(
                        (r) => DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child: Text('${r['nome']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => refresh(() => destination = v),
                ),
                TextFormField(
                  controller: reason,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Justificativa'),
                  validator: _required,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate() ||
                    selectedAsset == null ||
                    destination == null) {
                  _message(ctx, 'Selecione o bem e o setor de destino.');
                  return;
                }
                try {
                  await ApiClient.post('/movimentacao/', {
                    'bem_id': selectedAsset,
                    'setor_destino_id': destination,
                    'justificativa': reason.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) _message(ctx, '$e');
                }
              },
              child: const Text('Transferir'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    reason.dispose();
    if (result == true && mounted) setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    key: ValueKey(_refresh),
    future: Future.wait([
      ApiClient.get('/movimentacao/detailed/'),
      ApiClient.get('/bem/'),
      ApiClient.get('/setores/'),
    ]),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const AppLoading(label: 'Carregando movimentações...');
      if (snapshot.hasError)
        return AppErrorState(
          description: '${snapshot.error}',
          onRetry: () => setState(() => _refresh++),
        );
      final allMovements = snapshot.data![0];
      final assets = snapshot.data![1];
      final sectors = snapshot.data![2];
      final movements = allMovements
          .where(
            (m) =>
                '${m['bem_nome']} ${m['codigo_tombamento']} ${m['setor_origem_nome'] ?? ''} ${m['setor_destino_nome']}'
                    .toLowerCase()
                    .contains(_query.toLowerCase()),
          )
          .toList();
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _create(assets, sectors),
              icon: const Icon(Icons.add),
              label: const Text('Nova transferência'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por tombo, bem ou setor',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (movements.isEmpty)
            const AppEmptyState(title: 'Sem movimentações')
          else
            ...movements.map((raw) {
              final row = Map<String, dynamic>.from(raw);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: Text('${row['bem_nome']}'),
                  subtitle: Text(
                    '${row['codigo_tombamento']}\n${row['setor_origem_nome'] ?? 'Origem não informada'} → ${row['setor_destino_nome']} • ${_shortDate(row['data_movimentacao'])}\n${row['justificativa'] ?? ''}',
                  ),
                  isThreeLine: true,
                ),
              );
            }),
        ],
      );
    },
  );
}

class _ReportsScreen extends StatefulWidget {
  const _ReportsScreen();
  @override
  State<_ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<_ReportsScreen> {
  String _format = 'xlsx';
  int? _category;
  int? _sector;
  String? _status;
  bool _loading = false;

  Future<void> _export() async {
    setState(() => _loading = true);
    try {
      final query = <String, String>{'formato': _format};
      if (_category != null) query['categoria_id'] = '$_category';
      if (_sector != null) query['setor_id'] = '$_sector';
      if (_status != null) query['status'] = _status!;
      final uri = Uri(queryParameters: query).query;
      final response = await ApiClient.getResponse('/relatorio/exportar?$uri');
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw Exception('Falha ao gerar relatório (${response.statusCode}).');
      final name = 'inventario_patriflow.$_format';
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(response.bodyBytes),
            name: name,
            mimeType: _format == 'pdf' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        text: 'Relatório do patrimônio PatriFlow',
        fileNameOverrides: [name],
      );
    } catch (e) {
      if (mounted) _message(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: Future.wait([
      ApiClient.get('/categoria/'),
      ApiClient.get('/setores/'),
      ApiClient.get('/bem/'),
    ]),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const AppLoading(label: 'Carregando filtros...');
      if (snapshot.hasError)
        return AppErrorState(description: '${snapshot.error}');
      final categories = snapshot.data![0];
      final sectors = snapshot.data![1];
      final assets = snapshot.data![2];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 54,
            color: Theme.of(context).colorScheme.primary,
          ),
          Text(
            'Exportar inventário',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _format,
            decoration: const InputDecoration(labelText: 'Formato'),
            items: const [
              DropdownMenuItem(value: 'xlsx', child: Text('Excel (.xlsx)')),
              DropdownMenuItem(value: 'pdf', child: Text('PDF')),
            ],
            onChanged: (v) => setState(() => _format = v ?? 'xlsx'),
          ),
          DropdownButtonFormField<int>(
            value: _category,
            decoration: const InputDecoration(
              labelText: 'Categoria (opcional)',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas')),
              ...categories.map(
                (r) => DropdownMenuItem<int>(
                  value: r['id'] as int,
                  child: Text('${r['nome']}'),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          DropdownButtonFormField<int>(
            value: _sector,
            decoration: const InputDecoration(labelText: 'Setor (opcional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              ...sectors.map(
                (r) => DropdownMenuItem<int>(
                  value: r['id'] as int,
                  child: Text('${r['nome']}'),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _sector = v),
          ),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status (opcional)'),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('Todos')),
              ...[
                'Disponível',
                'Em Uso',
                'Manutenção',
                'Baixado',
              ].map((v) => DropdownMenuItem<String>(value: v, child: Text(v))),
            ],
            onChanged: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _export,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_loading ? 'Gerando...' : 'Gerar e compartilhar'),
          ),
          const SizedBox(height: 12),
          Text(
            'Itens no inventário: ${assets.length}',
            textAlign: TextAlign.center,
          ),
        ],
      );
    },
  );
}

Future<bool> _confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Campo obrigatório' : null;
String? _blank(String value) => value.trim().isEmpty ? null : value.trim();
String _shortDate(dynamic value) =>
    value == null ? '—' : value.toString().split('T').first;
Widget _detailLine(String label, dynamic value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 138,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      Expanded(child: Text(value == null || '$value'.isEmpty ? '—' : '$value')),
    ],
  ),
);

Widget _field(
  TextEditingController controller,
  String label, {
  bool required = false,
  bool number = false,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: TextFormField(
    controller: controller,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      if (required && (value == null || value.trim().isEmpty))
        return 'Campo obrigatório';
      if (number &&
          value != null &&
          value.trim().isNotEmpty &&
          double.tryParse(value.replaceAll(',', '.')) == null)
        return 'Informe um valor numérico';
      return null;
    },
  ),
);

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
  );
}
