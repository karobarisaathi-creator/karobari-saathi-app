import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Added for background handler
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart'; // Import generated options

// Models
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart'; // Added import for TransactionItemAdapter
import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/models/shared_account_model.dart';
import 'package:account_app/core/models/chat_model.dart';
import 'package:account_app/core/models/inventory_item_model.dart';

// Services
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/auth_service.dart'; // Added AuthService
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/theme_service.dart';
import 'package:account_app/core/services/auto_sync_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/services/firebase_service.dart';
import 'package:account_app/core/services/balance_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/services/excel_service.dart'; // Added ExcelService
import 'package:account_app/core/services/backup_service.dart';
import 'package:account_app/core/services/chat_service.dart';
import 'package:account_app/core/services/sharing_service.dart';
import 'package:account_app/core/services/security_service.dart';
import 'package:account_app/core/services/price_database_service.dart';
import 'package:account_app/core/services/verification_service.dart';
import 'package:account_app/core/widgets/simple_spinning_ring.dart';
import './helpers/migration_helper.dart';  // ✅ یہ import کریں


// Screens
import 'package:account_app/features/settings/login_screen.dart';
import 'package:account_app/features/dashboard/dashboard_screen.dart';
import 'package:account_app/features/settings/profile_setup_screen.dart';
import 'package:account_app/features/accounts/add_party_screen.dart';
import 'package:account_app/features/settings/settings_screen.dart';
import 'package:account_app/features/accounts/reports_screen.dart';
import 'package:account_app/features/notifications/notifications_screen.dart';
import 'package:account_app/features/professions/professions_screen.dart';
import 'package:account_app/features/accounts/add_transaction_screen.dart';
import 'package:account_app/features/settings/app_lock_screen.dart' as real_lock; // Import the real screen
import 'package:account_app/features/dashboard/main_navigation_screen.dart'; 
import 'package:account_app/core/theme/app_theme.dart'; // نئی تھیم فائل شامل کی

// Localization
import 'l10n/app_localizations.dart';

// Global Navigator Key for notification handling
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background Handler must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    print("Environment variables loaded successfully");
  } catch (e) {
    print("Error loading .env file: $e");
  }

  try {
    // Initialize Hive
    await Hive.initFlutter();

    // Register Hive adapters
    Hive.registerAdapter(AccountAdapter());
    Hive.registerAdapter(TransactionAdapter());
    Hive.registerAdapter(TransactionItemAdapter()); // ✅ Register TransactionItemAdapter (TypeId 20)
    Hive.registerAdapter(InventoryItemAdapter()); // ✅ Register InventoryItemAdapter (TypeId 21)
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(CategoryTypeAdapter());
    Hive.registerAdapter(ProfessionAdapter());
    Hive.registerAdapter(ProfessionCategoryAdapter()); // ✅ Register the new adapter
    Hive.registerAdapter(AppNotificationAdapter());
    Hive.registerAdapter(NotificationTypeAdapter());
    Hive.registerAdapter(SharedAccountAdapter());
    Hive.registerAdapter(ChatAdapter());
    Hive.registerAdapter(ChatMessageAdapter());

    // Initialize Firebase using DefaultFirebaseOptions
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      print("Firebase Initialized Successfully with DefaultOptions");
    } catch (e) {
      print("Firebase Initialization Failed: $e");
    }

    // Open Hive boxes
    final accountsBox = await Hive.openBox<Account>('accounts');
    final transactionsBox = await Hive.openBox<Transaction>('transactions');
    await Hive.openBox<Category>('categories');
    final professionsBox = await Hive.openBox<Profession>('professions');
    await Hive.openBox('settings');

    try {
      // 🔥 Run migrations before app starts
      print("🚀 App starting - Running migrations...");
      await MigrationHelper.runAllMigrations(
        accountsBox: accountsBox,
        transactionsBox: transactionsBox,
        professionsBox: professionsBox,
      );
      print("✅ Migrations completed");

      // Optional: Check database health
      final health = await MigrationHelper.checkDatabaseHealth(
        professionsBox: professionsBox,
      );
      print("📊 Database Health: ${health['status']}");

      if (health['issues'].isNotEmpty) {
        print("⚠️ Issues found: ${health['issues']}");
      }

    } catch (e) {
      print("❌ Migration/Health check failed: $e");
      // Continue anyway - app should still work
    }

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  } catch (e) {
    print("Critical Initialization Error: $e");
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => AuthService()), // Added AuthService provider
        ChangeNotifierProvider(create: (_) => LanguageService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => AutoSyncService()),
        ChangeNotifierProvider(create: (_) {
           // Pass navigator key to NotificationService
           final service = NotificationService();
           service.setNavigatorKey(navigatorKey);
           return service;
        }),
        ChangeNotifierProvider(create: (_) => FirebaseService()),
        ChangeNotifierProvider(create: (_) => BalanceService()),
        ChangeNotifierProvider(create: (_) => PdfService()),
        ChangeNotifierProvider(create: (_) => ExcelService()), // Added ExcelService provider
        ChangeNotifierProvider(create: (_) => BackupService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => SharingService()),
        ChangeNotifierProvider(create: (_) => SecurityService()),
        ChangeNotifierProvider(create: (_) => VerificationService()),
        Provider(create: (_) => PriceDatabaseService()),
      ],
      child: Consumer2<LanguageService, ThemeService>(
        builder: (context, languageService, themeService, child) {
          return MaterialApp(
            title: 'کاروباری ساتھی',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey, // Assign the key here

            // Theme Configuration
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeService.themeMode,

            // Localization Configuration
            locale: languageService.currentLocale,
            supportedLocales: const [
              Locale('en', ''),
              Locale('ur', ''),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // RTL/LTR Support
            builder: (context, child) {
              final mediaQueryData = MediaQuery.of(context);
              
              return MediaQuery(
                data: mediaQueryData.copyWith(
                  // Lock text scale to exactly 1.0 to prevent "Zoom" issues
                  textScaler: const TextScaler.linear(1.0),
                ),
                child: Directionality(
                  textDirection: languageService.textDirection,
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    left: false,
                    right: false,
                    child: child!,
                  ),
                ),
              );
            },

            home: AppWrapper(),

            routes: {
              '/dashboard': (context) => DashboardScreen(),
              '/login': (context) => LoginScreen(),
              '/profileSetup': (context) => const ProfileSetupScreen(),
              '/addParty': (context) => AddPartyScreen(),
              '/settings': (context) => SettingsScreen(),
              '/reports': (context) => ReportsScreen(),
              '/notifications': (context) => NotificationsScreen(),
              '/professions': (context) => ProfessionsScreen(),
              '/addTransaction': (context) => AddTransactionScreen(),
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

class _AppWrapperState extends State<AppWrapper> {
  bool _isLoading = true;
  bool _needsLogin = true;
  bool _isUnlocked = false; // Tracks session unlock status

  // Colors for loading screen (Matches AppTheme)
  final Color _themeColor = const Color(0xFF123248); // AppTheme.darkColor
  final Color _greyColor = const Color(0xFF607D8B); // AppTheme.goldColor (Grey)

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Set a maximum timeout for initialization to prevent hanging on loading screen
    bool isTimedOut = false;
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        print("Initialization timed out, proceeding anyway...");
        setState(() {
          isTimedOut = true;
          _isLoading = false;
        });
      }
    });

    try {
      // Listen to Auth State Changes
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (mounted) {
          setState(() {
            _needsLogin = user == null;
          });
        }
      });

      // 0. Trigger Notification Permission immediately
      Provider.of<NotificationService>(context, listen: false);

      // 1. Initialize Database Service fully
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      if (!databaseService.isInitialized) {
        await databaseService.init().timeout(const Duration(seconds: 15));
      }

      // 2. Check Login Status
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        _needsLogin = false;
        // 3. Auto Restore from Cloud (with timeout)
        try {
          await databaseService.fetchFromFirebase().timeout(const Duration(seconds: 10));
        } catch (e) {
          print("Auto restore failed or timed out: $e");
        }
      } else {
        _needsLogin = true;
      }
    } catch (e) {
      print("Initialization Error: $e");
    }

    if (mounted && !isTimedOut) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    // 1. Check Login
    if (_needsLogin) {
      return LoginScreen();
    }

    // 2. Check App Lock
    return FutureBuilder<bool>(
      future: Provider.of<SecurityService>(context, listen: false).isAppLockEnabled(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        final isAppLockEnabled = snapshot.data ?? false;

        // If lock is enabled and not yet unlocked in this session
        // REMOVED BYPASS - LOCK IS NOW ACTIVE
        if (isAppLockEnabled && !_isUnlocked) {
          return real_lock.AppLockScreen(
            onUnlock: () {
              setState(() {
                _isUnlocked = true;
              });
            },
          );
        }

        // 3. Main Navigation
        return MainNavigationScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    return Scaffold(
      backgroundColor: _themeColor,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icons/zalooq.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.account_balance_wallet, size: 80, color: Colors.white70);
                },
              ),
              const SizedBox(height: 40),
              Text(
                isUrdu ? 'کاروباری ساتھی' : 'Karobari Sathi',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: fontFamily,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                isUrdu ? 'ڈیٹا لوڈ ہو رہا ہے...' : 'Loading Data...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.5),
                  fontFamily: fontFamily,
                ),
              ),
              const SizedBox(height: 30),
              const SimpleSpinningRing(
                size: 60,
                duration: Duration(seconds: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
