import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _timeframe = "daily"; // daily, weekly, monthly

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRankings());
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    _loadRankings();
  }

  void _loadRankings() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    
    if (auth.token != null) {
      String category = "winners";
      if (_tabController.index == 1) category = "depositors";
      if (_tabController.index == 2) category = "withdrawers";

      wallet.fetchRankings(auth.token!, category, _timeframe);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = Provider.of<WalletProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة المتصدرين", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          DropdownButton<String>(
            value: _timeframe,
            underline: Container(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _timeframe = val;
                });
                _loadRankings();
              }
            },
            items: const [
              DropdownMenuItem(value: "daily", child: Text("اليوم")),
              DropdownMenuItem(value: "weekly", child: Text("الأسبوع")),
              DropdownMenuItem(value: "monthly", child: Text("الشهر")),
            ],
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: "الأكثر ربحاً"),
            Tab(text: "الأكثر شحناً"),
            Tab(text: "الأكثر سحباً"),
          ],
        ),
      ),
      body: wallet.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: wallet.rankings.length,
              itemBuilder: (ctx, idx) {
                final rank = wallet.rankings[idx];
                
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.black.withOpacity(0.05),
                      child: Text("#${rank['rank']}"),
                    ),
                    title: Text(rank['username'] ?? "لاعب"),
                    trailing: Text(
                      "${rank['value']} عملة شحن",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
