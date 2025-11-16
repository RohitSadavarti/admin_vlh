// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- 1. IMPORT THE NEW FILE YOU GENERATED ---
import 'firebase_options.dart';
import 'models/order_details.dart';
import 'providers/cart_provider.dart';
import 'screens/admin_analytics_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_order_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/invoice_screen.dart';
import 'screens/login_screen.dart';
import 'screens/menu_management_screen.dart';
import 'screens/printer_setup_screen.dart';
import 'screens/take_order_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/printer_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- 2. USE THE OPTIONS FROM THE NEW FILE ---
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // --- END OF FIX ---

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => PrinterService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(navigatorKey: navigatorKey);
    _notificationService.initialize();
  }

  @override
  void dispose() {
    ApiService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vanita Lunch Home',
      navigatorKey: navigatorKey, // Set the navigatorKey
      debugShowCheckedModeBanner: false,
      theme: buildTheme(isDark: false),
      darkTheme: buildTheme(isDark: true),
      themeMode: ThemeMode.system,
      home: const AuthWrapper(), // Use AuthWrapper as home
      routes: {
        '/login': (context) => const LoginScreen(),
        '/take-order': (context) => const TakeOrderScreen(),
        '/cart': (context) => const CartScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        '/admin-orders': (context) => const AdminOrderScreen(),
        '/admin-analytics': (context) => const AdminAnalyticsScreen(),
        '/printer-setup': (context) => const PrinterSetupScreen(),
        '/menu-management': (context) => const MenuManagementScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == InvoiceScreen.routeName) {
          final orderDetails = settings.arguments as OrderDetails;
          return MaterialPageRoute(
            builder: (context) {
              return InvoiceScreen(orderDetails: orderDetails);
            },
          );
        }
        return null;
      },
    );
  }
}

ThemeData buildTheme({required bool isDark}) {
  final primaryColor =
      isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
  final secondaryColor =
      isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
  final backgroundColor =
      isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
  final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
  final onBackgroundColor =
      isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1A1A1A);
  final onSurfaceColor =
      isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1A1A1A);
  final errorColor = isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444);

  final colorScheme = ColorScheme.fromSeed(
    brightness: isDark ? Brightness.dark : Brightness.light,
    seedColor: primaryColor,
    primary: primaryColor,
    secondary: secondaryColor,
    background: backgroundColor,
    surface: surfaceColor,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onBackground: onBackgroundColor,
    onSurface: onSurfaceColor,
    error: errorColor,
  );

  return ThemeData.from(colorScheme: colorScheme, useMaterial3: true).copyWith(
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: surfaceColor,
      foregroundColor: onSurfaceColor,
      iconTheme: IconThemeData(color: onSurfaceColor),
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: onSurfaceColor,
        fontSize: 18,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: surfaceColor,
      shadowColor: isDark
          ? Colors.black.withOpacity(0.4)
          : Colors.black.withOpacity(0.05),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        elevation: 1,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F2F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      hintStyle: TextStyle(
        color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
        fontWeight: FontWeight.w400,
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: MaterialStateProperty.all(
          isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50),
      headingTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: isDark ? Colors.white : Colors.grey.shade800,
      ),
      dataTextStyle: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white70 : Colors.grey.shade700,
      ),
      dataRowHeight: 64,
      columnSpacing: 40,
      horizontalMargin: 24,
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      color: surfaceColor,
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      borderRadius: BorderRadius.circular(12),
      selectedColor: primaryColor,
      color: isDark ? Colors.white70 : Colors.black87,
      fillColor: primaryColor.withOpacity(0.1),
      constraints: const BoxConstraints(minHeight: 40, minWidth: 80),
    ),
  );
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    Future<bool> checkLogin() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('isLoggedIn') ?? false;
    }

    return FutureBuilder<bool>(
        future: checkLogin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data == true) {
            return const AdminDashboardScreen();
          }
          return const LoginScreen();
        });
  }
}
