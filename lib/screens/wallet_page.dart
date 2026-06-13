import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final wallet = Provider.of<WalletProvider>(context, listen: false);
      if (auth.token != null) {
        wallet.fetchProfile(auth.token!);
        wallet.fetchBetHistory(auth.token!);
      }
    });
  }

  void _submitDeposit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);

    if (auth.isGuest) {
      _showUpgradePrompt();
      return;
    }

    final double? amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showMessage("يرجى إدخال مبلغ صحيح.");
      return;
    }

    final success = await wallet.requestDeposit(auth.token!, amount);
    if (success && mounted) {
      _amountController.clear();
      _showMessage("تم إرسال طلب الشحن بنجاح! بانتظار موافقة الإدارة.");
    } else {
      _showMessage("فشل إرسال طلب الشحن.");
    }
  }

  void _submitWithdrawal() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);

    if (auth.isGuest) {
      _showUpgradePrompt();
      return;
    }

    final double? amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showMessage("يرجى إدخال مبلغ صحيح.");
      return;
    }

    if (wallet.cashBalance < amount) {
      _showMessage("رصيد الشحن غير كافٍ لإجراء السحب.");
      return;
    }

    final success = await wallet.requestWithdrawal(auth.token!, amount);
    if (success && mounted) {
      _amountController.clear();
      _showMessage(
          "تم إرسال طلب السحب بنجاح! سيتم فحص العملية من قبل المشرفين.");
      wallet.fetchBetHistory(auth.token!);
    } else {
      _showMessage("فشل إرسال طلب السحب.");
    }
  }

  void _showUpgradePrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حساب زائر"),
        content: const Text(
            "يرجى ترقية حسابك وربط بريدك الإلكتروني لتتمكن من الشحن والسحب."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("حسناً"),
          ),
        ],
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = Provider.of<WalletProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("محفظتي وعملياتي",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wallets Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text("عملات مجانية",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            wallet.freeBalance.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFB703)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 40,
                      child: VerticalDivider(color: Colors.black12),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text("عملات شحن",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            wallet.cashBalance.toStringAsFixed(2),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF06D6A0)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Funding Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("تقديم طلب مالي",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "قيمة المبلغ (عملة شحن)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitDeposit,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF06D6A0),
                                foregroundColor: Colors.black),
                            child: const Text("شحن رصيد"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitWithdrawal,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5E62),
                                foregroundColor: Colors.white),
                            child: const Text("سحب رصيد"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // My history logs list
            const Text("سجل المراهنات السابقة",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            ...wallet.betHistory.map((bet) {
              final isWin = bet['status'] == "WON";
              return Card(
                child: ListTile(
                  title: Text(
                      "رهان صندوق ${bet['boxIndex']} (x${bet['winningMultiplier'] ?? '0'})"),
                  subtitle: Text(
                    "${bet['amount']} ${bet['currency'] == 'FREE' ? 'مجاني' : 'شحن'} • ${isWin ? 'ربح' : 'خسارة'}",
                    style: TextStyle(
                        color: isWin ? Colors.green : Colors.grey,
                        fontSize: 13),
                  ),
                  trailing: Text(
                    isWin ? "+${bet['winAmount']}" : "0.0",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isWin ? Colors.green : Colors.redAccent,
                        fontSize: 16),
                  ),
                ),
              );
            }),

            if (wallet.betHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Text("لا توجد جولات سابقة مسجلة.",
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}
