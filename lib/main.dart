import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'services/shared_prefs_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/driver/driver_dashboard.dart';
import 'screens/passenger/passenger_dashboard.dart';
import 'screens/onboarding/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SharedPrefsService.init();

  // Initialize Google Mobile Ads only on mobile platforms
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color primaryBlueLight = Color(0xFF4C51BF);
  static const Color primaryBlueDark = Color(0xFF818CF8);
  static const Color backgroundLight = Color(0xFFF7F9FC);
  static const Color surfaceLight = Colors.white;
  static const Color errorRed = Color(0xFFD32F2F);

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  static const TextStyle inputHintLabelStyle = TextStyle(
    fontSize: 15,
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Carpool',
        debugShowCheckedModeBanner: false,

        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryBlueLight,
            primary: primaryBlueLight,
            secondary: const Color(0xFF805AD5),
            surface: surfaceLight,
            background: backgroundLight,
            error: errorRed,
          ),

          scaffoldBackgroundColor: backgroundLight,

          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.transparent,
            foregroundColor: Color(0xFF1E293B),
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
            ),
          ),

          cardTheme: CardThemeData(
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: surfaceLight,
            margin: EdgeInsets.zero,
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: primaryBlueLight,
              foregroundColor: Colors.white,
              textStyle: buttonTextStyle,
            ),
          ),

          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: primaryBlueLight,
              textStyle: buttonTextStyle.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),

          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFEFEFF4),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              borderSide: const BorderSide(
                color: primaryBlueLight,
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: errorRed,
                width: 2.0,
              ),
            ),
            labelStyle: inputHintLabelStyle.copyWith(
              color: const Color(0xFF64748B),
            ),
            hintStyle: inputHintLabelStyle.copyWith(
              color: const Color(0xFF94A3B8),
            ),
          ),

          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            elevation: 8,
            backgroundColor: surfaceLight,
            selectedItemColor: primaryBlueLight,
            unselectedItemColor: const Color(0xFF94A3B8),
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),

          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            headlineMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            headlineSmall: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
            titleLarge: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF334155),
            ),
            titleSmall: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              color: Color(0xFF475569),
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
            bodySmall: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),

        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryBlueDark,
            brightness: Brightness.dark,
            primary: primaryBlueDark,
            secondary: const Color(0xFFA78BFA),
            surface: const Color(0xFF1E293B),
            background: const Color(0xFF0F172A),
            error: const Color(0xFFF87171),
          ),

          scaffoldBackgroundColor: const Color(0xFF0F172A),

          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.transparent,
            foregroundColor: Color(0xFFF1F5F9),
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            ),
          ),

          cardTheme: CardThemeData(
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: const Color(0xFF1E293B),
            margin: EdgeInsets.zero,
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: primaryBlueDark,
              foregroundColor: Colors.white,
              textStyle: buttonTextStyle,
            ),
          ),

          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: primaryBlueDark,
              textStyle: buttonTextStyle.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),

          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF334155),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF334155),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: primaryBlueDark,
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFF87171),
                width: 2.0,
              ),
            ),
            labelStyle: inputHintLabelStyle.copyWith(
              color: const Color(0xFF94A3B8),
            ),
            hintStyle: inputHintLabelStyle.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),

          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            elevation: 8,
            backgroundColor: const Color(0xFF1E293B),
            selectedItemColor: primaryBlueDark,
            unselectedItemColor: const Color(0xFF64748B),
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),

          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF1F5F9),
            ),
            headlineMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF1F5F9),
            ),
            headlineSmall: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE2E8F0),
            ),
            titleLarge: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE2E8F0),
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFFCBD5E1),
            ),
            titleSmall: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFFA1A3B8),
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              color: Color(0xFFCBD5E1),
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
            ),
            bodySmall: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
        ),

        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
        routes: {
          '/passenger': (ctx) => const PassengerDashboard(),
          '/driver': (ctx) => const DriverDashboard(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _checkingFirstTime = true;
  bool _showWelcome = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeUser();
  }

  Future<void> _checkFirstTimeUser() async {
    final isFirstTime = SharedPrefsService.isFirstTimeUser();
    setState(() {
      _showWelcome = isFirstTime;
      _checkingFirstTime = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingFirstTime) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }
    if (_showWelcome) {
      return const WelcomeScreen();
    }
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.hasInitialized) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Loading your Carpool session...',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (authProvider.isAuthenticated && authProvider.currentUser != null) {
          final userRole = (authProvider.currentUser!.role ?? 'passenger').toLowerCase();
          final dashboardKey = ValueKey('${authProvider.currentUser!.uid}_$userRole');

          if (userRole == 'driver') {
            return DriverDashboard(key: dashboardKey);
          } else {
            return PassengerDashboard(key: dashboardKey);
          }
        }
        return const LoginScreen(key: ValueKey('LoginScreen'));
      },
    );
  }
}