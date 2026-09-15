import 'package:flutter_test/flutter_test.dart';
import 'package:patriflow_app/app.dart';

void main() {
  testWidgets('exibe a abertura do PatriFlow', (tester) async {
    await tester.pumpWidget(const PatriFlowApp());

    expect(find.text('PatriFlow'), findsOneWidget);
    expect(find.text('Gestão patrimonial simplificada'), findsOneWidget);
  });
}
