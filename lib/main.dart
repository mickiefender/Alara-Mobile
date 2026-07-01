import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:alara/theme.dart';
import 'package:alara/nav.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/core/offline/sync/sync_state_provider.dart';
import 'package:alara/core/services/app_bootstrap_service.dart';
import 'package:alara/core/offline/sync/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 STEP 1: Firebase MUST initialize first (fixes APNS delay issues)
  await Firebase.initializeApp();

  // 🔥 STEP 2: Create core providers BEFORE UI
  final authProvider = AuthProvider();

  // 🔥 STEP 3: Run bootstrap BEFORE runApp (no FutureBuilder race)
  final bootstrapService = const AppBootstrapService();
  final bootstrapResult =
      await bootstrapService.bootstrap(authProvider: authProvider);

  runApp(MyApp(
    authProvider: authProvider,
    bootstrapResult: bootstrapResult,
  ));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  final AppBootstrapResult bootstrapResult;

  const MyApp({
    super.key,
    required this.authProvider,
    required this.bootstrapResult,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(
          value: bootstrapResult.connectivityMonitor,
        ),
        ChangeNotifierProvider(
          create: (_) => SyncStateProvider(
            connectivityMonitor: bootstrapResult.connectivityMonitor,
            syncEngine: SyncEngine.instance,
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'Alara - School Management',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.light,
        routerConfig: AppRouter.createRouter(authProvider),
      ),
    );
  }
}