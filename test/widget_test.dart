import 'package:flutter_test/flutter_test.dart';
import 'package:alara/services/auth_service.dart';

void main() {
  testWidgets('App startup test', (WidgetTester tester) async {
    // Create auth service instance
    final authService = AuthService();

    // Basic test to ensure auth service can be instantiated
    expect(authService, isNotNull);
  });
}
