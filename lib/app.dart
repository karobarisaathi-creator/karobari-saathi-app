import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// L10n
import 'l10n/app_localizations.dart';

// Models
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/models/shared_account_model.dart';
import 'package:account_app/core/models/chat_model.dart';

// Services
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/theme_service.dart';
import 'package:account_app/core/services/auto_sync_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/services/firebase_service.dart';
import 'package:account_app/core/services/balance_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/services/backup_service.dart';
import 'package:account_app/core/services/chat_service.dart';
import 'package:account_app/core/services/sharing_service.dart';
import 'package:account_app/core/services/security_service.dart';

// Screens
import 'package:account_app/features/settings/login_screen.dart';
import 'package:account_app/features/dashboard/dashboard_screen.dart';
import 'package:account_app/features/settings/profile_setup_screen.dart';
import 'package:account_app/features/settings/app_lock_screen.dart' as real_lock;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register Hive adapters
  Hive.registerAdapter(AccountAdapter());
  Hive.registerAdapter(TransactionAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(CategoryTypeAdapter());
  Hive.registerAdapter(ProfessionAdapter());
  Hive.registerAdapter(AppNotificationAdapter());
  Hive.registerAdapter(NotificationTypeAdapter());
  Hive.registerAdapter(SharedAccountAdapter());
  Hive.registerAdapter(ChatAdapter());
  Hive.registerAdapter(ChatMessageAdapter());

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => AutoSyncService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => FirebaseService()),
        ChangeNotifierProvider(create: (_) => BalanceService()),
        ChangeNotifierProvider(create: (_) => PdfService()),
        ChangeNotifierProvider(create: (_) => BackupService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => SharingService()),
        ChangeNotifierProvider(create: (_) => SecurityService()),
      ],
      child: Consumer2<LanguageService, ThemeService>(
        builder: (context, languageService, themeService, child) {
          return MaterialApp(
            title: 'Karobari Saathi',
            debugShowCheckedModeBanner: false,
            navigatorKey: GlobalKey<NavigatorState>(), // Add this if not already present and needed by NotificationService

            // Theme Configuration
            theme: themeService.currentThemeData,
            darkTheme: themeService.currentThemeData,
            themeMode: themeService.themeMode,

            // Localization Configuration
            locale: languageService.currentLocale,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [
              Locale('en', ''),
              Locale('ur', ''),
            ],

            // RTL/LTR Support
            builder: (context, child) {
              // Pass navigator key to notification service if needed
              final navigatorKey = (context as Element).findAncestorWidgetOfExactType<MaterialApp>()?.navigatorKey;
              if (navigatorKey != null) {
                 Provider.of<NotificationService>(context, listen: false).setNavigatorKey(navigatorKey);
              }
              
              return Directionality(
                textDirection: languageService.textDirection,
                child: child!,
              );
            },

            home: AppWrapper(),

            routes: {
              '/dashboard': (context) => DashboardScreen(),
              '/login': (context) => LoginScreen(),
              '/profileSetup': (context) => ProfileSetupScreen(),
            },
          );
        },
      ),
    );
  }
}

class AppWrapper extends StatefulWidget {
  @override
  _AppWrapperState createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _needsProfileSetup = false;
  bool _isLoggedIn = false;
  bool _isAppUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Re-lock app when it goes to background
      setState(() {
        _isAppUnlocked = false;
      });
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Check Login Status
      final user = FirebaseAuth.instance.currentUser;
      _isLoggedIn = user != null;

      if (_isLoggedIn) {
        // Check if user needs profile setup
        final securityService = Provider.of<SecurityService>(
          context,
          listen: false,
        );

        // Check if profile data exists
        final hasProfileData = await securityService.getSensitiveData('user_profile') != null;
        final hasDisplayName = user!.displayName != null && user.displayName!.isNotEmpty;

        _needsProfileSetup = !hasDisplayName && !hasProfileData;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('App initialization error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('ایپ لوڈ ہو رہی ہے...'),
            ],
          ),
        ),
      );
    }

    // 1. Check Login
    if (!_isLoggedIn) {
      return LoginScreen();
    }

    // 2. Check App Lock (Only if logged in)
    return Consumer<SecurityService>(
      builder: (context, securityService, child) {
        final isAppLockEnabled = securityService.isLockEnabled;

        if (isAppLockEnabled && !_isAppUnlocked) {
          return real_lock.AppLockScreen(
            onUnlock: () {
              setState(() {
                _isAppUnlocked = true;
              });
            },
          );
        }

        // 3. Check Profile Setup
        if (_needsProfileSetup) {
          return ProfileSetupScreen();
        } else {
          return DashboardScreen();
        }
      },
    );
  }
}
