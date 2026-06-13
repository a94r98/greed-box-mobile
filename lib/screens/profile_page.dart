import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  
  bool _showUpgradeForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final wallet = Provider.of<WalletProvider>(context, listen: false);
      if (auth.token != null) {
        wallet.fetchProfile(auth.token!);
      }
    });
  }

  void _upgradeAccount() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);

    final success = await auth.upgradeGuestAccount(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _usernameController.text.trim(),
    );

    if (success && mounted) {
      setState(() {
        _showUpgradeForm = false;
      });
      wallet.fetchProfile(auth.token!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم ترقية الحساب بنجاح! 🎉"), backgroundColor: Colors.green)
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? "فشلت عملية الترقية."), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final wallet = Provider.of<WalletProvider>(context);
    final stats = wallet.profileStats;

    return Scaffold(
      appBar: AppBar(
        title: const Text("ملفي الشخصي", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () {
              auth.logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Meta Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                      child: Text(
                        auth.user?['username']?[0]?.toUpperCase() ?? "P",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      auth.user?['username'] ?? "لاعب",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      auth.isGuest ? "حساب زائر مؤقت" : "حساب مسجل رسمي",
                      style: TextStyle(color: auth.isGuest ? Colors.orange : Colors.green, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "ID: ${auth.user?['id']}",
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: "monospace"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Upgrade account form for Guests
            if (auth.isGuest && !_showUpgradeForm)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showUpgradeForm = true;
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.black),
                child: const Text("اربط حسابك لتأمين أرصدتك 🔒"),
              ),

            if (_showUpgradeForm)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text("ربط وترقية الحساب", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(labelText: "اسم المستخدم", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: "البريد الإلكتروني", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: "كلمة المرور", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _upgradeAccount,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        child: const Text("ترقية الحساب الآن"),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showUpgradeForm = false;
                          });
                        },
                        child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Referral card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("كود الدعوة الخاص بك", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              auth.user?['referralCode'] ?? "",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2, color: Color(0xFFFFB703)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Colors.grey),
                          onPressed: () {
                            // Copy to clipboard action placeholder
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("تم نسخ كود الدعوة!"))
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Statistics Card
            if (stats != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("إحصائيات اللعب", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("إجمالي الجولات الملعوبة:"),
                          Text("${stats['roundsPlayed']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("الجولات الفائزة:"),
                          Text("${stats['roundsWon']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("إجمالي أرباح الذهب (FREE):"),
                          Text("+${stats['stats']['totalProfitFree'].toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB703))),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("إجمالي أرباح الشحن (CASH):"),
                          Text("+${stats['stats']['totalProfitCash'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
