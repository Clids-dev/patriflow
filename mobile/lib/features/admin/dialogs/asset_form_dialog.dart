import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_helpers.dart';

/// Cadastro e edição de bem. Na criação o tombo é gerado pela API.
class AssetFormDialog extends StatefulWidget {
  const AssetFormDialog({super.key, required this.categories, this.asset});

  final List<dynamic> categories;
  final Map<String, dynamic>? asset;

  @override
  State<AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<AssetFormDialog> {
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

  @override
  void dispose() {
    for (final c in [
      _name,
      _type,
      _value,
      _brand,
      _model,
      _serial,
      _invoice,
      _date,
      _tombo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

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
        'marca': blankOrNull(_brand.text),
        'modelo': blankOrNull(_model.text),
        'numero_serie': blankOrNull(_serial.text),
        'valor_aquisicao': amount,
        'nota_fiscal': blankOrNull(_invoice.text),
        'data_entrada': blankOrNull(_date.text),
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
      if (mounted) showAppMessage(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.asset == null ? 'Cadastrar bem' : 'Editar bem'),
    content: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 520,
        maxHeight: MediaQuery.sizeOf(context).height * .68,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            formTextField(_name, 'Nome', required: true),
            if (widget.asset == null) ...[
              formTextField(_type, 'Tipo', required: true),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: DropdownButtonFormField<int>(
                  initialValue: _category,
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
              ),
            ],
            formTextField(
              _value,
              'Valor de aquisição',
              required: true,
              number: true,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: assetStatuses
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ),
            formTextField(_brand, 'Marca'),
            formTextField(_model, 'Modelo'),
            formTextField(_serial, 'Número de série'),
            formTextField(_invoice, 'Nota fiscal'),
            formTextField(_date, 'Data de entrada (AAAA-MM-DD)'),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: DropdownButtonFormField<String>(
                initialValue: _condition,
                decoration: const InputDecoration(labelText: 'Conservação'),
                items: const ['novo', 'bom', 'regular', 'ruim', 'inservivel']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _condition = v ?? _condition),
              ),
            ),
            if (widget.asset == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'O tombo será gerado automaticamente com dígito verificador.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
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
