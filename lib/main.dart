import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/building_detail_screen.dart';
import 'services/auth_service.dart';
import 'services/baserow_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const MainNavigationScreen(),
    ),
    GoRoute(
      path: '/projects',
      builder: (context, state) => const MainNavigationScreen(),
    ),
    GoRoute(
      path: '/building/:projectId',
      builder: (context, state) {
        final projectId = int.parse(state.pathParameters['projectId']!);
        return BuildingDetailScreen(projectId: projectId);
      },
    ),
  ],
);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App kapanırken otomatik logout
        if (AuthService.isLoggedIn) {
          AuthService.logout();
          print('🔄 App closed - user logged out automatically');
        }
        break;
      case AppLifecycleState.resumed:
        // App açılırken session kontrolü
        _checkSession();
        break;
      default:
        break;
    }
  }

  Future<void> _checkSession() async {
    try {
      if (AuthService.isLoggedIn) {
        final user = AuthService.currentUser;
        if (user != null) {
          // Session'ın hala aktif olup olmadığını kontrol et
          final baserowUser = await BaserowService.getUser(user.id);
          if (baserowUser == null || baserowUser['field_7343'] != 'true') {
            // Session expired, logout
            AuthService.logout();
            print('🔄 Session expired - user logged out');
          }
        }
      }
    } catch (e) {
      print('❌ Session check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Field Pro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C2C2E),
          brightness: Brightness.light,
        ),
      ),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}