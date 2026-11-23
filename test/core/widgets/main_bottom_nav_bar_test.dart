import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/main_bottom_nav_bar.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestConnectivityPlatform extends ConnectivityPlatform {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream<List<ConnectivityResult>>.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'bottom navigation can be swiped repeatedly without layout errors',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final previousPlatform = ConnectivityPlatform.instance;
    ConnectivityPlatform.instance = _TestConnectivityPlatform();
    addTearDown(() => ConnectivityPlatform.instance = previousPlatform);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageService(),
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MainBottomNavBar(
              selectedIndex: 0,
              onItemTapped: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageView = find.byType(PageView);
    expect(pageView, findsOneWidget);
    for (var swipe = 0; swipe < 20; swipe++) {
      await tester.drag(pageView, const Offset(-160, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
