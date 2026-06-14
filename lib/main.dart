import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'providers/auth_provider.dart';
import 'providers/socket_provider.dart';
import 'providers/game_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/landing_page.dart';
import 'screens/navigation_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();
  runApp(

    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SocketProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
      ],
      child: const GreedBoxesApp(),
    ),
  );
}

class GreedBoxesApp extends StatefulWidget {
  const GreedBoxesApp({super.key});

  @override
  State<GreedBoxesApp> createState() => _GreedBoxesAppState();
}

class _GreedBoxesAppState extends State<GreedBoxesApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupSocketBindings());
  }

  void _setupSocketBindings() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final socketProv = Provider.of<SocketProvider>(context, listen: false);
    final gameProv = Provider.of<GameProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);

    // Register persistent callbacks on SocketProvider
    // These are called directly by the socket listener regardless of isConnected state
    socketProv.onWalletUpdate = (data) {
      if (data != null && data['freeBalance'] != null && data['cashBalance'] != null) {
        wallet.updateBalancesLocally(
          (data['freeBalance'] as num).toDouble(),
          (data['cashBalance'] as num).toDouble()
        );
      } else if (auth.token != null) {
        wallet.fetchProfile(auth.token!);
      }
    };

    socketProv.onKickOut = (data) {
      // Force disconnect and logout immediately
      socketProv.disconnect();
      auth.logout();
    };

    // Watch auth status changes to connect/disconnect socket
    auth.addListener(() {
      if (auth.isAuthenticated) {
        socketProv.connect(auth.token!);
      } else {
        socketProv.disconnect();
      }
    });

    // When socket connects, hook up GameProvider listeners and sync state
    socketProv.addListener(() {
      if (socketProv.isConnected) {
        gameProv.subscribeToSocketEvents(socketProv);
        if (auth.token != null) {
          gameProv.rehydrateState(auth.token!);
        }
      }
    });

    // If already authenticated on startup
    if (auth.isAuthenticated) {
      socketProv.connect(auth.token!);
    } else {
      // Auto-trigger Guest Login immediately to go straight to the game
      auth.loginGuest();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return MaterialApp(
      title: 'صناديق الطمع - Greed Boxes',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      // Premium Light Theme definition
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFFCFAFF), // Light Lavender White
        primaryColor: const Color(0xFF8E24AA),            // Luxury Purple
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF8E24AA),      // Purple
          secondary: Color(0xFFE91E63),    // Pink
          error: Color(0xFFFF2E93),        // Vivid Red
          surface: Color(0xFFFFFFFF),      // Pure White Card Surface
          onSurface: Color(0xFF1A0933),    // Deep Purple Text
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
          shadowColor: const Color(0xFF8E24AA).withValues(alpha: 0.08),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFCFAFF),
          foregroundColor: Color(0xFF1A0933),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF1A0933)),
        ),
      ),
      home: auth.isAuthenticated ? const MainNavigationPage() : const AuthLandingPage(),
    );
  }
}
