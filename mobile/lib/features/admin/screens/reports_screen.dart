import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_helpers.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_states.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
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
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Falha ao gerar relatório (${response.statusCode}).');
      }
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
      if (mounted) showAppMessage(context, '$e');
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
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const AppLoading(label: 'Carregando filtros...');
      }
      if (snapshot.hasError) {
        return AppErrorState(description: '${snapshot.error}');
      }
      final categories = snapshot.data![0];
      final sectors = snapshot.data![1];
      final assets = snapshot.data![2];
      return ListView(
        padding: AppSpacing.screen,
        children: [
          const SizedBox(height: AppSpacing.md),
          const Align(
            child: AppIconBadge(icon: Icons.analytics_outlined, size: 64),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Exportar inventário',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Itens no inventário: ${assets.length}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppPanel(
            child: Column(
              children: [
                _filter(
                  DropdownButtonFormField<String>(
                    initialValue: _format,
                    decoration: const InputDecoration(labelText: 'Formato'),
                    items: const [
                      DropdownMenuItem(
                        value: 'xlsx',
                        child: Text('Excel (.xlsx)'),
                      ),
                      DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                    ],
                    onChanged: (v) => setState(() => _format = v ?? 'xlsx'),
                  ),
                ),
                _filter(
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _category,
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
                ),
                _filter(
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _sector,
                    decoration: const InputDecoration(
                      labelText: 'Setor (opcional)',
                    ),
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
                ),
                _filter(
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      for (final status in assetStatuses)
                        DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        ),
                    ],
                    onChanged: (v) => setState(() => _status = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _loading ? null : _export,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(_loading ? 'Gerando...' : 'Gerar e compartilhar'),
          ),
        ],
      );
    },
  );

  Widget _filter(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: child,
  );
}
