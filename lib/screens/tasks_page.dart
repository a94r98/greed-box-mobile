import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final wallet = Provider.of<WalletProvider>(context, listen: false);
      if (auth.token != null) {
        wallet.fetchTasks(auth.token!);
        // Send initial heartbeat tick
        wallet.sendHeartbeat(auth.token!);
      }
    });

    // Heartbeat timer (sends online minute ticks to the server every 1 minute)
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final wallet = Provider.of<WalletProvider>(context, listen: false);
      if (auth.token != null) {
        wallet.sendHeartbeat(auth.token!);
      }
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  void _claimReward(String taskId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);

    if (auth.token != null) {
      final success = await wallet.claimTaskReward(auth.token!, taskId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم استلام المكافأة بنجاح! 🎉"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleSocialAction(Map<String, dynamic> task) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    if (auth.token == null) return;

    final urlStr = task['linkUrl'];
    if (urlStr != null && urlStr.isNotEmpty) {
      final Uri url = Uri.parse(urlStr);
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          // Fallback launch
          await launchUrl(url);
        }
      } catch (e) {
        debugPrint("Could not launch URL: $e");
      }
    }

    // Call action trigger on backend immediately to mark task completed
    if (task['actionType'] != null) {
      await wallet.reportAction(auth.token!, task['actionType']);
    }
  }

  Widget _buildTaskItem(Map<String, dynamic> task, bool isSocial) {
    final double progress = task['goalCount'] > 0 ? (task['count'] / task['goalCount']) : 0.0;
    final bool isCompleted = task['isCompleted'] == true;
    final bool isClaimed = task['isClaimed'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task['description'] ?? "",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB703).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/diamond.png', width: 14, height: 14),
                      const SizedBox(width: 4),
                      Text(
                        "+${task['rewardAmount']}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB703), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress > 1.0 ? 1.0 : progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      color: const Color(0xFF7C4DFF),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "${task['count']} / ${task['goalCount']}",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isCompleted && !isClaimed)
              ElevatedButton(
                onPressed: () => _claimReward(task['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06D6A0),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text("استلم المكافأة", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            else if (isClaimed)
              OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text("تم الاستلام", style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
              )
            else if (isSocial)
              ElevatedButton(
                onPressed: () => _handleSocialAction(task),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  task['key'].toString().contains("video") ? "مشاهدة الفيديو" : "انتقال للمتابعة",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            else
              OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text("جاري العمل", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = Provider.of<WalletProvider>(context);

    // Group tasks
    final dailyTasks = wallet.tasks.where((t) => t['type'] == 'DAILY' && t['key'] != 'complete_all_daily').toList();
    final achievements = wallet.tasks.where((t) => t['type'] == 'ONETIME').toList();
    final socialTasks = wallet.tasks.where((t) => t['type'] == 'SOCIAL').toList();

    Map<String, dynamic>? completeAllTask;
    for (var t in wallet.tasks) {
      if (t['key'] == 'complete_all_daily') {
        completeAllTask = t;
        break;
      }
    }

    // Calculate daily tasks completion for cumulative chest progress
    int completedDailyCount = dailyTasks.where((t) => t['isCompleted'] == true).length;
    int totalDailyCount = dailyTasks.length;
    double chestProgress = totalDailyCount > 0 ? (completedDailyCount / totalDailyCount) : 0.0;
    bool allDailyCompleted = totalDailyCount > 0 && completedDailyCount >= totalDailyCount;
    bool chestClaimed = completeAllTask?['isClaimed'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text("قسم المهام والمكافآت", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D021F),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7C4DFF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
          tabs: const [
            Tab(text: "📅 اليومية"),
            Tab(text: "🎯 الإنجازات"),
            Tab(text: "📱 السوشيال"),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D021F), Color(0xFF1E0638), Color(0xFF330954)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Daily Tasks
            RefreshIndicator(
              onRefresh: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                if (auth.token != null) {
                  await wallet.fetchTasks(auth.token!);
                }
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Cumulative Chest Card
                  if (completeAllTask != null && completeAllTask['isEnabled'] == true) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF330954), Color(0xFF5E17EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFB703).withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB703).withValues(alpha: 0.1),
                            blurRadius: 15,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB703).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  chestClaimed ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                                  color: const Color(0xFFFFB703),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      completeAllTask['title'] ?? "صندوق المكافأة اليومي",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      completeAllTask['description'] ?? "أكمل جميع المهام اليومية لفتح الصندوق.",
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    "المكافأة: ",
                                    style: TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    "${completeAllTask['rewardAmount']}",
                                    style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 4),
                                  Image.asset('assets/diamond.png', width: 14, height: 14),
                                ],
                              ),
                              Text(
                                "$completedDailyCount / $totalDailyCount مهام منجزة",
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: chestProgress,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              color: const Color(0xFFFFB703),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (allDailyCompleted && !chestClaimed)
                            ElevatedButton(
                              onPressed: () => _claimReward(completeAllTask!['id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB703),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("افتح الصندوق واستلم 5,000 ماسة! ", style: TextStyle(fontWeight: FontWeight.bold)),
                                  Image.asset('assets/diamond.png', width: 16, height: 16),
                                ],
                              ),
                            )
                          else if (chestClaimed)
                            OutlinedButton(
                              onPressed: null,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text("تم فتح الصندوق واستلام الجائزة اليوم", style: TextStyle(color: Colors.white38)),
                            )
                          else
                            OutlinedButton(
                              onPressed: null,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text("أكمل بقية المهام لفتح الصندوق", style: TextStyle(color: Colors.white54)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text(
                    "قائمة المهام اليومية",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  ...dailyTasks.map((t) => _buildTaskItem(t, false)),
                  if (dailyTasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Text("لا توجد مهام يومية حالياً.", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),

            // Tab 2: Achievements
            RefreshIndicator(
              onRefresh: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                if (auth.token != null) {
                  await wallet.fetchTasks(auth.token!);
                }
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: achievements.length,
                itemBuilder: (ctx, idx) {
                  return _buildTaskItem(achievements[idx], false);
                },
              ),
            ),

            // Tab 3: Social Tasks
            RefreshIndicator(
              onRefresh: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                if (auth.token != null) {
                  await wallet.fetchTasks(auth.token!);
                }
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: socialTasks.length,
                itemBuilder: (ctx, idx) {
                  return _buildTaskItem(socialTasks[idx], true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
