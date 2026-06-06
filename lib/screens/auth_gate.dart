import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth_screen.dart';
import 'main_navigation.dart';

// ✨ EL BÚNKER OFFLINE
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Verificamos si ya hay una sesión guardada localmente (Funciona sin internet)
    final currentSession = Supabase.instance.client.auth.currentSession;

    // Si la sesión existe en el teléfono, entra directo a la app
    if (currentSession != null) {
      return const MainNavigation();
    }

    // 2. Si no hay sesión, escuchamos los cambios (por si el usuario inicia sesión ahora)
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF09090B),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;
        if (session != null) {
          return const MainNavigation();
        } else {
          return const AuthScreen(); // Si no hay nada, muestra el login
        }
      },
    );
  }
}
