import 'package:flutter/material.dart';
import 'api_client.dart';
import 'screens/login_screen.dart';
import 'screens/vendors_screen.dart';
import 'theme.dart';

void main() {
  runApp(const HollaAdminApp());
}

class HollaAdminApp extends StatelessWidget {
  const HollaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Holla Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      home: const _SessionGate(),
    );
  }
}

/// Restores a still-valid login from a previous visit (if any) before
/// deciding whether to show the login screen or jump straight in - this is
/// what makes a page refresh not log you out.
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.restoreSession().then((_) {
      if (mounted) setState(() => _checking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ApiClient.instance.isLoggedIn ? const VendorsScreen() : const LoginScreen();
  }
}
