import 'package:flutter/material.dart';

import '../navigation/app_navigation.dart';
import '../storage/secure_token_storage.dart';
import '../../features/auth/login_page.dart';

class SessionManager {
  static bool _handlingUnauthorized = false;

  static Future<void> handleUnauthorized() async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    try {
      // Remove apenas a credencial. A fila offline pertence ao armazenamento
      // de sincronização e nunca deve ser apagada durante uma expiração de sessão.
      await SecureTokenStorage().clearToken();
      scaffoldMessengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('Sua sessão expirou. Entre novamente.'),
        ));
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        LoginPage.routeName,
        (_) => false,
      );
    } finally {
      _handlingUnauthorized = false;
    }
  }

  static Future<void> logout() => SecureTokenStorage().clearToken();
}
