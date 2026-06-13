import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final wallet = Provider.of<WalletProvider>(context, listen: false);
      if (auth.token != null) {
        wallet.fetchTasks(auth.token!);
      }
    });
  }

  void _claimReward(String taskId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);

    if (auth.token != null) {
      final success = await wallet.claimTaskReward(auth.token!, taskId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم استلام المكافأة بنجاح! 🎉"), backgroundColor: Colors.green)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = Provider.of<WalletProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("المهام اليومية", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: wallet.tasks.length,
        itemBuilder: (ctx, idx) {
          final task = wallet.tasks[idx];
          final double progress = task['goalCount'] > 0 ? (task['count'] / task['goalCount']) : 0.0;
          
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['title'] ?? "",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              task['description'] ?? "",
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "+${task['rewardAmount']} ${task['rewardCurrency'] == "FREE" ? "عملة مجانية" : "عملة شحن"}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB703)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress > 1.0 ? 1.0 : progress,
                          backgroundColor: Colors.black.withOpacity(0.05),
                          color: Theme.of(context).primaryColor,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text("${task['count']} / ${task['goalCount']}"),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Claim reward action
                  if (task['isCompleted'] && !task['isClaimed'])
                    ElevatedButton(
                      onPressed: () => _claimReward(task['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("استلم المكافأة"),
                    )
                  else if (task['isClaimed'])
                    const OutlinedButton(
                      onPressed: null,
                      child: Text("تم الاستلام", style: TextStyle(color: Colors.grey)),
                    )
                  else
                    const OutlinedButton(
                      onPressed: null,
                      child: Text("جاري العمل"),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
