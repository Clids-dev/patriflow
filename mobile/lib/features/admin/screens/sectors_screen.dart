import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_helpers.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_states.dart';

class SectorsScreen extends StatefulWidget {
  const SectorsScreen({super.key});

  @override
  State<SectorsScreen> createState() => _SectorsScreenState();
}

class _SectorsScreenState extends State<SectorsScreen> {
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
          scrollable: true,
          title: Text('Editar ${row['nome']}'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                formTextField(name, 'Nome', required: true),
                _responsibleDropdown(
                  responsibles,
                  responsibleId,
                  (v) => refresh(() => responsibleId = v),
                ),
                _roomDropdown(rooms, roomId, (v) => refresh(() => roomId = v)),
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
                  showAppMessage(ctx, 'Informe nome, responsável e sala.');
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
                  if (ctx.mounted) showAppMessage(ctx, '$e');
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
        scrollable: true,
        title: Text(title),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (body.containsKey('predio_id'))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: DropdownButtonFormField<int>(
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
                ),
              if (body.containsKey('andar_id'))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: DropdownButtonFormField<int>(
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
                ),
              formTextField(name, 'Nome / identificação', required: true),
              if (endpoint.endsWith('predios'))
                formTextField(extra, 'Endereço (opcional)'),
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
                showAppMessage(ctx, 'Selecione a localização superior.');
                return;
              }
              final payload = <String, dynamic>{...body}
                ..remove('predios')
                ..remove('andares');
              payload[endpoint.endsWith('predios') ? 'nome' : 'identificacao'] =
                  name.text.trim();
              if (endpoint.endsWith('predios')) {
                payload['endereco'] = blankOrNull(extra.text);
              }
              try {
                await ApiClient.post(endpoint, payload);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) showAppMessage(ctx, '$e');
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
          scrollable: true,
          title: const Text('Novo setor'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                formTextField(name, 'Nome', required: true),
                _responsibleDropdown(
                  responsibles,
                  responsibleId,
                  (v) => refresh(() => responsibleId = v),
                ),
                _roomDropdown(rooms, roomId, (v) => refresh(() => roomId = v)),
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
                  showAppMessage(ctx, 'Informe nome, responsável e sala.');
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
                  if (ctx.mounted) showAppMessage(ctx, '$e');
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
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const AppLoading(label: 'Carregando setores e locais...');
      }
      if (snapshot.hasError) {
        return AppErrorState(
          description: '${snapshot.error}',
          onRetry: () => setState(() => _refresh++),
        );
      }
      final sectors = snapshot.data![0];
      final responsibles = snapshot.data![1];
      final buildings = snapshot.data![2];
      final floors = snapshot.data![3];
      final rooms = snapshot.data![4];
      return ListView(
        padding: AppSpacing.screen,
        children: [
          const AppSectionHeader(title: 'Localização física'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
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
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Setores',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton.filled(
                tooltip: 'Novo setor',
                onPressed: responsibles.isEmpty || rooms.isEmpty
                    ? null
                    : () => _createSector(responsibles, rooms),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final raw in sectors)
            AppListCard(
              leading: const AppIconBadge(icon: Icons.business_outlined),
              title: '${raw['nome']}',
              subtitle:
                  '${raw['predio_nome']} • ${raw['andar_identificacao']} • ${raw['sala_nome']}\nResponsável: ${raw['responsavel_nome'] ?? '—'}',
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  final row = Map<String, dynamic>.from(raw);
                  if (action == 'edit') {
                    await _editSector(row, responsibles, rooms);
                    return;
                  }
                  if (!mounted ||
                      !await confirmAction(
                        context,
                        'Desativar setor ${row['nome']}?',
                      )) {
                    return;
                  }
                  try {
                    await ApiClient.delete(
                      '/setores/',
                      queryParameters: {'id': '${row['id']}'},
                    );
                    if (mounted) setState(() => _refresh++);
                  } catch (e) {
                    if (mounted) showAppMessage(context, '$e');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'disable', child: Text('Desativar')),
                ],
              ),
            ),
        ],
      );
    },
  );
}

Widget _responsibleDropdown(
  List<dynamic> responsibles,
  int? value,
  ValueChanged<int?> onChanged,
) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.md),
  child: DropdownButtonFormField<int>(
    initialValue: value,
    decoration: const InputDecoration(labelText: 'Responsável'),
    items: responsibles
        .map(
          (r) => DropdownMenuItem<int>(
            value: r['id'] as int,
            child: Text('${r['nome']}'),
          ),
        )
        .toList(),
    onChanged: onChanged,
  ),
);

Widget _roomDropdown(
  List<dynamic> rooms,
  int? value,
  ValueChanged<int?> onChanged,
) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.md),
  child: DropdownButtonFormField<int>(
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Sala'),
    items: rooms
        .map(
          (r) => DropdownMenuItem<int>(
            value: r['id'] as int,
            child: Text(
              '${r['predio_nome']} • ${r['andar_identificacao']} • ${r['identificacao']}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(),
    onChanged: onChanged,
  ),
);
