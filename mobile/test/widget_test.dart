import 'package:flutter_test/flutter_test.dart';
import 'package:patriflow_app/app.dart';

void main() {
  testWidgets('exibe a abertura do PatriFlow', (tester) async {
    await tester.pumpWidget(const PatriFlowApp());

    // A logo é imagem (o nome já vem nela); o texto da abertura é o slogan.
    expect(find.text('Gestão patrimonial simplificada'), findsOneWidget);
  });
}
