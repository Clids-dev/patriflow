import 'package:flutter/material.dart';

/// Escala de espaçamento única do PatriFlow mobile.
/// Espelha a escala visual usada no painel web (`static/css/style.css`).
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Margem horizontal padrão das telas.
  static const screen = EdgeInsets.fromLTRB(lg, md, lg, xxl);
}

/// Raios de borda: cards 16, controles 12, folhas e diálogos maiores.
abstract final class AppRadius {
  static const sm = 8.0;
  static const control = 12.0;
  static const card = 16.0;
  static const dialog = 24.0;
  static const sheet = 28.0;

  static const controlBorder = BorderRadius.all(Radius.circular(control));
  static const cardBorder = BorderRadius.all(Radius.circular(card));
}

/// Sombras discretas, no estilo iOS (quase imperceptíveis).
abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const brand = [
    BoxShadow(color: Color(0x2E19002B), blurRadius: 16, offset: Offset(0, 5)),
  ];
}

/// Duração e curva padrão de transições e feedbacks.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 200);
  static const curve = Curves.easeInOutCubic;
}
