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
      // Premium Light Theme definition
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0518), // Deep Dark Purple
        primaryColor: const Color(0xFFFFB703),            // Neon Gold
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB703),      // Gold
          secondary: Color(0xFF06D6A0),    // Mint Green
          error: Color(0xFFFF5E62),        // Bright Crimson
          surface: Color(0xFF190F2D),      // Luxury Purple Card Surface
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF190F2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha:0.4),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0C0518),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: auth.isAuthenticated ? const MainNavigationPage() : const AuthLandingPage(),
    );
  }
}

