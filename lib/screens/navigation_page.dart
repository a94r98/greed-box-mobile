import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'game_screen.dart';
import 'rankings_page.dart';
import 'tasks_page.dart';
import 'wallet_page.dart';
import 'profile_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 4;

  final List<Widget> _pages = [
    const ProfilePage(),
    const WalletPage(),
    const TasksPage(),
    const RankingsPage(),
    const GameScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final game = Provider.of<GameProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          
          // Maintenance Mode overlay blocking interactions
          if (game.maintenanceMessage != null)
            Container(
              color: Colors.black.withValues(alpha:0.92),
              width: double.infinity,
              height: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.construction_rounded,
                      size: 80,
                      color: Color(0xFFFFB703),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "أشغال صيانة - صيانة السيرفر",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      game.maintenanceMessage!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: game.maintenanceMessage != null
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFFFFB703),
              unselectedItemColor: Colors.grey,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "حسابي"),
                BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: "المحفظة"),
                BottomNavigationBarItem(icon: Icon(Icons.task_alt_rounded), label: "المهام"),
                BottomNavigationBarItem(icon: Icon(Icons.leaderboard_rounded), label: "المتصدرين"),
                BottomNavigationBarItem(icon: Icon(Icons.videogame_asset_rounded), label: "اللعبة"),
              ],
            ),
    );
  }
}

