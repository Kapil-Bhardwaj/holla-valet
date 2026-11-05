import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:redvalet_admin/main.dart';

void main() {
  testWidgets('Login screen shows email and password fields', (WidgetTester tester) async {
    // No persisted session - the app should settle on the login screen,
    // not the brief loading spinner _SessionGate shows while checking.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const RedValetAdminApp());
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
