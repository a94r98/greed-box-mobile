import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF06D6A0),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openProfileEditor() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ProfileEditPage(),
    ));
  }

  Widget _buildAvatarIcon(String? avatarId, String displayNickname) {
    switch (avatarId) {
      case 'avatar_1':
        return const Icon(Icons.verified_rounded,
            color: Colors.white, size: 32);
      case 'avatar_2':
        return const Icon(Icons.auto_awesome_rounded,
            color: Colors.white, size: 32);
      case 'avatar_3':
        return const Icon(Icons.sports_esports_rounded,
            color: Colors.white, size: 32);
      case 'avatar_4':
        return const Icon(Icons.flash_on_rounded,
            color: Colors.white, size: 32);
      default:
        return Text(
          displayNickname.isNotEmpty ? displayNickname[0].toUpperCase() : "؟",
          style: const TextStyle(
              fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
        );
    }
  }

  String _getCountryFlag(String countryCode) {
    if (countryCode.length != 2) return "🇸🇦";
    final int firstChar = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondChar = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstChar) + String.fromCharCode(secondChar);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final wallet = Provider.of<WalletProvider>(context);
    final stats = wallet.profileStats;
    final displayNickname =
        auth.user?['displayNickname'] ?? auth.user?['username'] ?? "لاعب";
    final publicId = auth.user?['publicId'] ?? auth.user?['id'] ?? "----";
    final genderValue =
        (auth.user?['gender'] ?? "MALE").toString().toUpperCase();
    final isFemale = genderValue == "FEMALE";
    final accentColor =
        isFemale ? const Color(0xFFE91E63) : const Color(0xFF7C4DFF);
    final accentGradient = LinearGradient(
      colors: isFemale
          ? const [Color(0xFF8E24AA), Color(0xFFD81B60), Color(0xFFFF6EA1)]
          : const [Color(0xFF512DA8), Color(0xFF5E35B1), Color(0xFF42A5F5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final userAge = (auth.user?['age']?.toString() ?? "18").replaceAll('+', '');
    final countryCode = auth.user?['countryCode']?.toString().toUpperCase() ??
        auth.user?['country']?['code']?.toString().toUpperCase() ??
        "SA";
    final userBio =
        auth.user?['bio']?.toString() ?? "مرحبا بك في حسابي على Greedy Box!";
    final inviteCode = auth.user?['referralCode']?.toString() ?? "----";
    final invitedCount =
        auth.user?['inviteCount'] ?? stats?['inviteCount'] ?? 0;
    final inviteReward =
        auth.user?['inviteReward'] ?? stats?['inviteReward'] ?? 0;
    final mostPlayed =
        stats?['favoriteGame'] ?? stats?['mostPlayedGame'] ?? "غير محددة";
    final totalProfitFree =
        (stats?['stats']?['totalProfitFree'] as num?)?.toDouble() ?? 0.0;
    final totalProfitCash =
        (stats?['stats']?['totalProfitCash'] as num?)?.toDouble() ?? 0.0;
    final played = stats?['roundsPlayed'] ?? 0;
    final won = stats?['roundsWon'] ?? 0;
    final lost = stats?['roundsLost'] ??
        (played is int && won is int ? (played - won) : 0);
    final topUpsHistory =
        wallet.betHistory.where((item) => item['currency'] == 'CASH').toList();
    final coinsHistory =
        wallet.betHistory.where((item) => item['currency'] == 'FREE').toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF110424),
                  Color(0xFF250C4A),
                  Color(0xFF430A6F)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xFF7C4DFF), Colors.transparent],
                    radius: 0.8,
                    center: Alignment(-0.8, -0.6),
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 90, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _glassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Details Column (now first on the right in RTL, start in LTR context)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name, Age/Gender icon, Flag Row
                              Row(
                                children: [
                                  Text(
                                    displayNickname,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(width: 8),
                                  // Age Chip (Without gender icon and without + sign)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: accentGradient,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      userAge,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Flag Emoji
                                  Text(
                                    _getCountryFlag(countryCode),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Player ID (above the bio, under the name, without container box)
                              InkWell(
                                onTap: () => _copyToClipboard(
                                    publicId, "تم نسخ معرف اللاعب!"),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "ID: $publicId",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 12,
                                      color: Colors.white.withValues(alpha: 0.4),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Bio Section
                              Text(
                                userBio,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    height: 1.4),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 2. Avatar (now second)
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Lottie.asset(
                                isFemale
                                    ? 'assets/frames/New female account.json'
                                    : 'assets/frames/New male account.json',
                                width: 80,
                                height: 80,
                                fit: BoxFit.contain,
                                repeat: true,
                              ),
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: accentColor.withValues(alpha: 0.2),
                                child: _buildAvatarIcon(
                                    auth.user?['avatar']?.toString(),
                                    displayNickname),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildSectionTitle("خيارات سريعة"),
                const SizedBox(height: 10),
                _glassCard(
                  child: Column(
                    children: [
                      _buildSettingsTile(Icons.edit_rounded,
                          "تعديل الملف الشخصي", _openProfileEditor),
                      _buildSettingsTile(Icons.photo_camera_rounded,
                          "تغيير الصورة", _openProfileEditor),
                      _buildSettingsTile(Icons.note_alt_rounded, "تعديل البايو",
                          _openProfileEditor),
                      _buildSettingsTile(
                          Icons.notifications_active_rounded, "الإشعارات", () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('إعدادات الإشعارات')));
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _glassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: accentGradient,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.card_giftcard_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "دعوات ومكافآت",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildStatRow("كود الدعوة", inviteCode, true, () {
                          _copyToClipboard(
                              inviteCode, "تم نسخ كود الدعوة الخاص بك!");
                        }),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildMiniStat("المدعوون", invitedCount.toString(),
                                Icons.group_rounded, const Color(0xFF8E24AA)),
                            const SizedBox(width: 12),
                            _buildMiniStat(
                                "مكافآت",
                                inviteReward.toString(),
                                Icons.card_giftcard_rounded,
                                const Color(0xFFFF4081)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildSectionTitle("إحصائيات الألعاب"),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildSmallStatCard("اللعب", played.toString(),
                        Icons.sports_esports_rounded, const Color(0xFF7C4DFF)),
                    _buildSmallStatCard("فوز", won.toString(),
                        Icons.emoji_events_rounded, Colors.greenAccent),
                    _buildSmallStatCard("خسارة", lost.toString(),
                        Icons.sports_mma_rounded, Colors.redAccent),
                    _buildSmallStatCard(
                        "أرباح",
                        "+${(totalProfitCash + totalProfitFree).toStringAsFixed(1)}",
                        Icons.trending_up_rounded,
                        const Color(0xFFFFB703)),
                  ],
                ),
                const SizedBox(height: 14),
                _glassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("أكثر لعبة لعبت",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(mostPlayed,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.auto_graph_rounded,
                                color: accentColor, size: 20),
                            const SizedBox(width: 6),
                            Text("أرباح $totalProfitCash",
                                style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildSectionTitle("السجل"),
                const SizedBox(height: 10),
                DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: accentColor,
                        ),
                        tabs: const [
                          Tab(text: "الشحن"),
                          Tab(text: "الكونزات"),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 320,
                        child: TabBarView(
                          children: [
                            _buildHistoryList(topUpsHistory,
                                "سجل شحنات المستخدم", Colors.orangeAccent),
                            _buildHistoryList(coinsHistory, "سجل الكونزات",
                                Colors.purpleAccent),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildSectionTitle("الدعم الفني"),
                const SizedBox(height: 10),
                _glassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("تواصل مباشر مع الدعم",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 10),
                        const Text(
                            "اختر الطريقة الأنسب لك للحصول على مساعدة سريعة.",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                        content: Text('فتح دردشة الدعم'))),
                                icon: const Icon(
                                    Icons.chat_bubble_outline_rounded),
                                label: const Text("دردشة الدعم"),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C4DFF)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                        content: Text('إرسال مشكلة'))),
                                icon: const Icon(Icons.report_problem_rounded,
                                    color: Colors.white),
                                label: const Text("أبلغ عن مشكلة",
                                    style: TextStyle(color: Colors.white)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildSupportInfo(
                            "رفع ملف أو صورة", "رابط رفع ملف قيد التطوير"),
                        if (auth.user?['whatsapp'] != null)
                          _buildSupportInfo(
                              "واتساب", auth.user!['whatsapp'].toString()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildSectionTitle("حول التطبيق"),
                const SizedBox(height: 10),
                _glassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            "Greedy Box هي وجهتك الممتازة لألعاب الحظ والإثارة مع تصميم أنيق ووظائف سريعة.",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5)),
                        const SizedBox(height: 14),
                        _buildAboutRow("الإصدار الحالي", "2.5.0"),
                        _buildAboutRow("سياسة الاستخدام", "عرض السياسة"),
                        _buildAboutRow("شروط الخدمة", "عرض الشروط"),
                        const SizedBox(height: 14),
                        const Text("حقوق النشر © 2026 Greedy Box",
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildSectionTitle("الإعدادات"),
                const SizedBox(height: 10),
                _glassCard(
                  child: Column(
                    children: [
                      _buildSettingsTile(
                          Icons.lock_outline_rounded, "الخصوصية والأمان", () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('فتح إعدادات الخصوصية')));
                      }),
                      _buildSettingsTile(
                          Icons.keyboard_double_arrow_left_rounded,
                          "تغيير اللغة", () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('تغيير اللغة قيد التطوير')));
                      }),
                      _buildSettingsTile(
                          Icons.notifications_rounded, "إعدادات الإشعارات", () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('إعدادات الإشعارات')));
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.12), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget _buildMiniStat(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatRow(
      String title, String value, bool hasCopy, VoidCallback onCopy) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        if (hasCopy)
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, color: Colors.white70),
          ),
      ],
    );
  }

  Widget _buildHistoryList(
      List<Map<String, dynamic>> items, String emptyLabel, Color accent) {
    if (items.isEmpty) {
      return Center(
        child: Text(emptyLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(right: 2),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final record = items[index];
        final status = record['status'] == 'WON' ? 'ناجح' : 'فشل';
        final amount = record['amount']?.toString() ?? '-';
        final type = record['currency'] == 'FREE' ? 'كونزات' : 'شحن';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.history_rounded, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record['description']?.toString() ??
                          '$type ${record['boxIndex'] ?? ''}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatHistoryDate(record),
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$amount ${record['currency'] == 'FREE' ? 'كونز' : 'ر.س'}",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(status,
                      style: TextStyle(
                          color: status == 'ناجح'
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatHistoryDate(Map<String, dynamic> record) {
    final dateValue =
        record['createdAt'] ?? record['timestamp'] ?? record['date'] ?? '';
    if (dateValue == null) return '-';
    final dateString = dateValue.toString();
    if (dateString.length >= 10) {
      return dateString.substring(0, 10);
    }
    return dateString;
  }

  Widget _buildSupportInfo(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.white70),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          color: Colors.white54, size: 18),
      onTap: onTap,
    );
  }
}

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _displayController = TextEditingController();
  final _bioController = TextEditingController();
  final _ageController = TextEditingController();
  final _whatsappController = TextEditingController();
  String _selectedGender = "MALE";
  String _selectedAvatar = "avatar_1";
  bool _isSaving = false;

  static const _avatarOptions = [
    {'id': 'avatar_1', 'icon': Icons.verified_rounded},
    {'id': 'avatar_2', 'icon': Icons.auto_awesome_rounded},
    {'id': 'avatar_3', 'icon': Icons.sports_esports_rounded},
    {'id': 'avatar_4', 'icon': Icons.flash_on_rounded},
  ];

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _displayController.text = auth.user?['displayNickname']?.toString() ??
        auth.user?['username']?.toString() ??
        "";
    _bioController.text = auth.user?['bio']?.toString() ?? "";
    _ageController.text = auth.user?['age']?.toString() ?? "";
    _whatsappController.text = auth.user?['whatsapp']?.toString() ?? "";
    _selectedGender = (auth.user?['gender'] ?? "MALE").toString().toUpperCase();
    _selectedAvatar = auth.user?['avatar']?.toString() ?? "avatar_1";
  }

  @override
  void dispose() {
    _displayController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _isSaving = true;
    });

    final avatarChanged = auth.user?['avatar']?.toString() != _selectedAvatar;
    if (avatarChanged) {
      final success = await auth.updateAvatar(_selectedAvatar);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(auth.errorMessage ?? 'فشل تحديث الصورة.'),
          backgroundColor: Colors.red,
        ));
        setState(() {
          _isSaving = false;
        });
        return;
      }
    }

    await auth.updateLocalProfile(
      displayNickname: _displayController.text.trim().isEmpty
          ? null
          : _displayController.text.trim(),
      bio: _bioController.text.trim(),
      whatsapp: _whatsappController.text.trim(),
      age: int.tryParse(_ageController.text.trim()),
      gender: _selectedGender,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم حفظ معلومات الملف الشخصي بنجاح.'),
        backgroundColor: Color(0xFF06D6A0),
      ));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFemale = _selectedGender == "FEMALE";
    final accentColor =
        isFemale ? const Color(0xFFE91E63) : const Color(0xFF7C4DFF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF110424),
                  Color(0xFF250C4A),
                  Color(0xFF430A6F)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 110, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _glassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('اختر الصورة الشخصية',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _avatarOptions.map((option) {
                            final id = option['id'] as String;
                            final icon = option['icon'] as IconData;
                            final selected = id == _selectedAvatar;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedAvatar = id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? accentColor.withValues(alpha: 0.9)
                                      : Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: selected
                                          ? accentColor
                                          : Colors.white12,
                                      width: 2),
                                ),
                                child: Icon(icon,
                                    color: selected
                                        ? Colors.white
                                        : Colors.white70,
                                    size: 34),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),
                        const Text('بيانات المستخدم',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _displayController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'الاسم الظاهر',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _bioController,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'البايو',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'العمر',
                                  labelStyle:
                                      const TextStyle(color: Colors.white70),
                                  filled: true,
                                  fillColor:
                                      Colors.white.withValues(alpha: 0.08),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedGender,
                                    dropdownColor: const Color(0xFF190F2D),
                                    style: const TextStyle(color: Colors.white),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _selectedGender = value);
                                      }
                                    },
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'MALE', child: Text('ذكر ♂')),
                                      DropdownMenuItem(
                                          value: 'FEMALE',
                                          child: Text('أنثى ♀')),
                                      DropdownMenuItem(
                                          value: 'OTHER', child: Text('آخر')),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _whatsappController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'واتساب (اختياري)',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('حفظ التعديلات',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.12), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
