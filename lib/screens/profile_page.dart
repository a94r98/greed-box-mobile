import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isReferralActive = true;
  double _inviteReward = 500.0;
  List<dynamic> _myReferrals = [];
  bool _isLoadingReferrals = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final wallet = Provider.of<WalletProvider>(context, listen: false);
      if (auth.token != null) {
        wallet.fetchProfile(auth.token!);
        _fetchReferralConfig();
      }
    });
  }

  Future<void> _fetchReferralConfig() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;
    if (mounted) setState(() { _isLoadingReferrals = true; });
    try {
      final res = await http.get(
        Uri.parse("${auth.apiBase}/player/referrals"),
        headers: {"Authorization": "Bearer ${auth.token}"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _isReferralActive = data['isReferralActive'] ?? true;
            _inviteReward = (data['inviteReward'] as num?)?.toDouble() ?? 500.0;
            _myReferrals = data['referrals'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching referrals config: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoadingReferrals = false; });
      }
    }
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

  Widget _buildAvatarIcon(String? avatarId, String displayNickname, {double size = 56}) {
    if (avatarId != null && (avatarId.startsWith('data:image/') || avatarId.length > 100)) {
      try {
        final cleanBase64 = avatarId.contains(',') ? avatarId.split(',')[1] : avatarId;
        return CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.transparent,
          backgroundImage: MemoryImage(base64Decode(cleanBase64)),
        );
      } catch (e) {
        // fallback
      }
    }

    switch (avatarId) {
      case 'avatar_1':
        return Icon(Icons.verified_rounded, color: Colors.white, size: size * 0.5);
      case 'avatar_2':
        return Icon(Icons.auto_awesome_rounded, color: Colors.white, size: size * 0.5);
      case 'avatar_3':
        return Icon(Icons.sports_esports_rounded, color: Colors.white, size: size * 0.5);
      case 'avatar_4':
        return Icon(Icons.flash_on_rounded, color: Colors.white, size: size * 0.5);
      default:
        return Text(
          displayNickname.isNotEmpty ? displayNickname[0].toUpperCase() : "؟",
          style: TextStyle(
              fontSize: size * 0.45, fontWeight: FontWeight.w800, color: Colors.white),
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

    final played = stats?['roundsPlayed'] ?? 0;
    final won = stats?['roundsWon'] ?? 0;
    final lost = stats?['roundsLost'] ??
        (played is int && won is int ? (played - won) : 0);
    final totalProfitFree =
        (stats?['stats']?['totalProfitFree'] as num?)?.toDouble() ?? 0.0;
    final totalProfitCash =
        (stats?['stats']?['totalProfitCash'] as num?)?.toDouble() ?? 0.0;
    final mostPlayed = "الصندوق الأسود"; // One game only

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          "حسابي",
          style: TextStyle(
            color: Color(0xFF1A0933),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFFFCFAFF)),

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _glassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar (first, on the left)
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: accentColor.withOpacity(0.2),
                                child: _buildAvatarIcon(
                                    auth.user?['avatar']?.toString(),
                                    displayNickname,
                                    size: 56),
                              ),
                              IgnorePointer(
                                child: Lottie.asset(
                                  isFemale
                                      ? 'assets/frames/New female account.json'
                                      : 'assets/frames/New male account.json',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                  repeat: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Details Column
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
                                        color: Color(0xFF1A0933)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(width: 8),
                                  // Age Chip with Gender Icon inside
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: accentGradient,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isFemale
                                              ? Icons.female_rounded
                                              : (genderValue == "MALE"
                                                  ? Icons.male_rounded
                                                  : Icons.person_rounded),
                                          color: Colors.white,
                                          size: 11,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          userAge,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10),
                                        ),
                                      ],
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
                              // Player ID
                              InkWell(
                                onTap: () => _copyToClipboard(
                                    publicId, "تم نسخ معرف اللاعب!"),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "ID: $publicId",
                                      style: const TextStyle(
                                        color: Color(0xFF9E9E9E),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.copy_rounded,
                                      size: 12,
                                      color: Color(0xFFBDBDBD),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Main Options List (No headers, clean modern design)
                _glassCard(
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        Icons.person_outline_rounded,
                        "تعديل الملف الشخصي",
                        () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const ProfileEditChoicesPage(),
                          ));
                        },
                      ),
                      if (_isReferralActive)
                        _buildSettingsTile(
                          Icons.card_giftcard_rounded,
                          "دعوات ومكافآت",
                          () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => InvitationsPage(
                                inviteCode: inviteCode,
                                invitedCount: _myReferrals.length,
                                inviteReward: _inviteReward,
                                referralsList: _myReferrals,
                                accentGradient: accentGradient,
                                onRefresh: _fetchReferralConfig,
                              ),
                            ));
                          },
                        ),
                      _buildSettingsTile(
                        Icons.bar_chart_rounded,
                        "إحصائيات اللعبة",
                        () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => GameStatsPage(
                              played: played,
                              won: won,
                              lost: lost,
                              totalProfitCash: totalProfitCash,
                              totalProfitFree: totalProfitFree,
                              mostPlayed: mostPlayed,
                              accentColor: accentColor,
                            ),
                          ));
                        },
                      ),
                      _buildSettingsTile(
                        Icons.history_rounded,
                        "سجل العمليات واللعب",
                        () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => HistoryPage(
                              accentColor: accentColor,
                            ),
                          ));
                        },
                      ),
                      _buildSettingsTile(
                        Icons.chat_bubble_outline_rounded,
                        "الدعم الفني",
                        () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SupportChatPage(
                              accentGradient: accentGradient,
                            ),
                          ));
                        },
                      ),
                      _buildSettingsTile(
                        Icons.settings_outlined,
                        "الإعدادات",
                        () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ));
                        },
                      ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: const Color(0xFF8E24AA).withValues(alpha: 0.08), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E24AA).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: const Color(0xFF8E24AA)),
      title: Text(title,
          style: const TextStyle(
              color: Color(0xFF1A0933), fontWeight: FontWeight.w600)),
      trailing: Icon(
          isRtl ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded,
          color: const Color(0xFF9E9E9E),
          size: 18),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Profile Edit Choice Screen
// ─────────────────────────────────────────────────────────────────────────────
class ProfileEditChoicesPage extends StatefulWidget {
  const ProfileEditChoicesPage({super.key});

  @override
  State<ProfileEditChoicesPage> createState() => _ProfileEditChoicesPageState();
}

class _ProfileEditChoicesPageState extends State<ProfileEditChoicesPage> {
  bool _isSaving = false;

  void _showEditDialog({
    required String title,
    required String initialValue,
    required String labelText,
    required Future<bool> Function(String) onSave,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Color(0xFF1A0933), fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: title.contains("البايو") ? 3 : 1,
          style: const TextStyle(color: Color(0xFF1A0933)),
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: const TextStyle(color: Color(0xFF6B5885)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8DBFA))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8E24AA))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: Color(0xFF6B5885))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() { _isSaving = true; });
              final success = await onSave(controller.text.trim());
              if (mounted) {
                setState(() { _isSaving = false; });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success ? "تم التحديث بنجاح." : "فشل التحديث."),
                  backgroundColor: success ? const Color(0xFF06D6A0) : Colors.redAccent,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E24AA)),
            child: const Text("حفظ", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 400,
      maxHeight: 400,
    );
    if (image != null) {
      setState(() { _isSaving = true; });
      try {
        final bytes = await image.readAsBytes();
        // Detect mime type from header bytes
        String mime = 'image/jpeg';
        if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) mime = 'image/png';
        final base64Image = "data:$mime;base64,${base64Encode(bytes)}";
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final success = await auth.updateServerProfile(avatar: base64Image);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(success ? "تم تحديث الصورة الشخصية بنجاح. \u2705" : (auth.errorMessage ?? "فشل تحميل الصورة.")),
            backgroundColor: success ? const Color(0xFF4CAF50) : Colors.redAccent,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("حدث خطأ أثناء قراءة الملف."),
            backgroundColor: Colors.redAccent,
          ));
        }
      } finally {
        if (mounted) setState(() { _isSaving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final displayNickname = auth.user?['displayNickname'] ?? auth.user?['username'] ?? "";
    final userBio = auth.user?['bio'] ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFF),
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي',
            style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF8E24AA)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(
                  color: Color(0xFF8E24AA),
                  backgroundColor: Color(0xFFEDE7F6),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF8E24AA).withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8E24AA).withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFF8E24AA)),
                    title: const Text("تغيير الصورة الشخصية",
                        style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.w600)),
                    subtitle: const Text("تحميل صورة من الهاتف",
                        style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
                    trailing: const Icon(Icons.arrow_back_ios_rounded,
                        color: Color(0xFF9E9E9E), size: 16),
                    onTap: _isSaving ? null : _pickAndUploadImage,
                  ),
                  const Divider(color: Color(0xFFF3EEF9), height: 1),
                  ListTile(
                    leading: const Icon(Icons.edit_rounded, color: Color(0xFF8E24AA)),
                    title: const Text("تغيير الاسم الظاهر",
                        style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.w600)),
                    subtitle: Text(displayNickname,
                        style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
                    trailing: const Icon(Icons.arrow_back_ios_rounded,
                        color: Color(0xFF9E9E9E), size: 16),
                    onTap: _isSaving
                        ? null
                        : () => _showEditDialog(
                              title: "تعديل الاسم الظاهر",
                              initialValue: displayNickname,
                              labelText: "الاسم الظاهر الجديد",
                              onSave: (val) => auth.updateServerProfile(displayNickname: val),
                            ),
                  ),
                  const Divider(color: Color(0xFFF3EEF9), height: 1),
                  ListTile(
                    leading: const Icon(Icons.note_alt_rounded, color: Color(0xFF8E24AA)),
                    title: const Text("تغيير البايو (الوصف)",
                        style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        userBio.isEmpty ? "لا يوجد وصف حالياً" : userBio,
                        style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.arrow_back_ios_rounded,
                        color: Color(0xFF9E9E9E), size: 16),
                    onTap: _isSaving
                        ? null
                        : () => _showEditDialog(
                              title: "تعديل البايو",
                              initialValue: userBio,
                              labelText: "اكتب شيئاً عن نفسك...",
                              onSave: (val) => auth.updateServerProfile(bio: val),
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Invitations Screen (Fully online & Database-connected)
// ─────────────────────────────────────────────────────────────────────────────
class InvitationsPage extends StatefulWidget {
  final String inviteCode;
  final int invitedCount;
  final double inviteReward;
  final List<dynamic> referralsList;
  final LinearGradient accentGradient;
  final Future<void> Function() onRefresh;

  const InvitationsPage({
    super.key,
    required this.inviteCode,
    required this.invitedCount,
    required this.inviteReward,
    required this.referralsList,
    required this.accentGradient,
    required this.onRefresh,
  });

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  final _codeController = TextEditingController();
  bool _isApplying = false;

  Future<void> _applyInviteCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);

    setState(() { _isApplying = true; });

    try {
      final res = await http.post(
        Uri.parse("${auth.apiBase}/player/referrals/apply"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${auth.token}"
        },
        body: jsonEncode({"code": code}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['message'] ?? "تم تطبيق كود الدعوة بنجاح!"),
          backgroundColor: const Color(0xFF06D6A0),
        ));
        _codeController.clear();
        await auth.updateServerProfile(); // pull latest referredByCode
        await wallet.fetchProfile(auth.token!); // update balance
        await widget.onRefresh(); // refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['error'] ?? "كود الدعوة غير صالح."),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("خطأ في الاتصال بالخادم."),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      setState(() { _isApplying = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final alreadyReferred = auth.user?['referredByCode'] != null && auth.user?['referredByCode'].toString().isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text("دعوات ومكافآت", style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF8E24AA)),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFFCFAFF), Color(0xFFF0EBF7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: const Color(0xFF8E24AA),
              onRefresh: widget.onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Code & Stats Card
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
                                    gradient: widget.accentGradient,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.card_giftcard_rounded,
                                      color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "اربح ${widget.inviteReward.toInt()} كنز لكل مستخدم!",
                                    style: const TextStyle(
                                        color: Color(0xFF1A0933),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            // Referral code display
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("كود الدعوة الخاص بك",
                                        style: TextStyle(color: Color(0xFF6B5885), fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(widget.inviteCode,
                                        style: const TextStyle(
                                            color: Color(0xFF8E24AA),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            letterSpacing: 1.5)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: widget.inviteCode));
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                          content: Text("تم نسخ كود الدعوة الخاص بك!"),
                                          backgroundColor: Color(0xFF06D6A0),
                                        ));
                                      },
                                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF8E24AA)),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        // Share code
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                          content: Text("يمكنك الآن نسخ ومشاركة الكود مع أصدقائك!"),
                                        ));
                                      },
                                      icon: const Icon(Icons.share_rounded, color: Color(0xFF8E24AA)),
                                    ),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildMiniStat("إجمالي المدعوين", widget.invitedCount.toString(),
                                      Icons.group_rounded, const Color(0xFF8E24AA)),
                                const SizedBox(width: 12),
                                _buildMiniStat(
                                    "المكافأة (لكل مستخدم)",
                                    "${widget.inviteReward.toInt()} كنز",
                                    Icons.monetization_on_rounded,
                                    const Color(0xFFFF4081)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Enter Code Card
                    _glassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("أدخل كود دعوة صديق",
                                style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 10),
                            if (alreadyReferred)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      "لقد قمت بإدخال كود الدعوة سابقاً: ${auth.user?['referredByCode']}",
                                      style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _codeController,
                                      style: const TextStyle(color: Color(0xFF1A0933)),
                                      decoration: InputDecoration(
                                        hintText: "مثال: INVITE123",
                                        hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
                                        filled: true,
                                        fillColor: const Color(0xFFF5EEFD),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: _isApplying ? null : _applyInviteCode,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8E24AA),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: _isApplying
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Text("تطبيق", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Invited list title
                    const Text("الأصدقاء المسجلين من خلالك",
                        style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    // Referrals List
                    if (widget.referralsList.isEmpty)
                      _glassCard(
                        child: const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(Icons.people_outline_rounded, color: Color(0xFFBDBDBD), size: 48),
                              SizedBox(height: 12),
                              Text("لا يوجد أصدقاء مسجلين حالياً.",
                                  style: TextStyle(color: Color(0xFF6B5885), fontSize: 13),
                                  textAlign: TextAlign.center),
                              SizedBox(height: 4),
                              Text("شارك الكود الخاص بك لتبدأ بربح الكونزات!",
                                  style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 11),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.referralsList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final ref = widget.referralsList[idx];
                          final dateStr = ref['date'] != null && ref['date'].toString().length >= 10
                              ? ref['date'].toString().substring(0, 10)
                              : ref['date'] ?? '';
                          return _glassCard(
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF5EEFD),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person, color: Color(0xFF8E24AA)),
                              ),
                              title: Text(ref['username'] ?? "لاعب", style: const TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold)),
                              subtitle: Text("انضم في: $dateStr", style: const TextStyle(color: Color(0xFF6B5885), fontSize: 11)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                ),
                                child: const Text("تم الدفع", style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF8E24AA).withValues(alpha: 0.08), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E24AA).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5EEFD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8DBFA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Color(0xFF1A0933),
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(color: Color(0xFF6B5885), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Game Stats Screen (Refactored to edit out multiple games check & add note)
// ─────────────────────────────────────────────────────────────────────────────
class GameStatsPage extends StatelessWidget {
  final int played;
  final int won;
  final int lost;
  final double totalProfitFree;
  final double totalProfitCash;
  final String mostPlayed;
  final Color accentColor;

  const GameStatsPage({
    super.key,
    required this.played,
    required this.won,
    required this.lost,
    required this.totalProfitFree,
    required this.totalProfitCash,
    required this.mostPlayed,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إحصائيات اللعبة", style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF8E24AA)),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFFCFAFF), Color(0xFFF0EBF7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildSmallStatCard("الجولات الملعوبة", played.toString(),
                          Icons.sports_esports_rounded, const Color(0xFF8E24AA)),
                      _buildSmallStatCard("جولات الفوز", won.toString(),
                          Icons.emoji_events_rounded, const Color(0xFF2E7D32)),
                      _buildSmallStatCard("جولات الخسارة", lost.toString(),
                          Icons.sports_mma_rounded, Colors.redAccent),
                      _buildSmallStatCard(
                          "أرباح الكونزات والماس",
                          "+${(totalProfitCash + totalProfitFree).toStringAsFixed(1)}",
                          Icons.trending_up_rounded,
                          const Color(0xFFFFB703)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Disclaimer note (Real game disclaimer)
                  _glassCard(
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF8E24AA), size: 24),
                          SizedBox(height: 8),
                          Text(
                            "تنويه: الإحصائيات معروضة في الوقت الفعلي وهي تشمل نشاطك في اللعبة الرئيسية لـ Greedy Box (الصندوق الأسود).",
                            style: TextStyle(color: Color(0xFF6B5885), fontSize: 12, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF8E24AA).withValues(alpha: 0.08), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E24AA).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSmallStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EEFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DBFA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF1A0933),
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(color: Color(0xFF6B5885), fontSize: 12)),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// 4. History Screen (Luxurious design with dropdown Year/Month filtering)
// ─────────────────────────────────────────────────────────────────────────────
class HistoryPage extends StatefulWidget {
  final Color accentColor;

  const HistoryPage({
    super.key,
    required this.accentColor,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _selectedYear = "الكل";
  String _selectedMonth = "الكل";
  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = false;

  final List<String> _years = ["الكل", "2026", "2025", "2024"];
  final List<String> _monthNames = [
    "الكل", "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
    "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
  ];

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  Future<void> _fetchHistoryData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;
    setState(() { _isLoading = true; });

    try {
      String url = "${auth.apiBase}/player/history?limit=100";
      if (_selectedYear != "الكل") {
        url += "&year=$_selectedYear";
      }
      if (_selectedMonth != "الكل") {
        final monthIdx = _monthNames.indexOf(_selectedMonth);
        url += "&month=$monthIdx";
      }

      final res = await http.get(Uri.parse(url), headers: {"Authorization": "Bearer ${auth.token}"});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _historyItems = List<Map<String, dynamic>>.from(data['history']);
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  String _formatHistoryDate(Map<String, dynamic> record) {
    final dateValue = record['createdAt'] ?? record['timestamp'] ?? record['date'] ?? '';
    if (dateValue == null) return '-';
    final dateString = dateValue.toString();
    if (dateString.length >= 10) {
      return dateString.substring(0, 10);
    }
    return dateString;
  }

  @override
  Widget build(BuildContext context) {
    final cashHistory = _historyItems.where((item) => item['currency'] == 'CASH').toList();
    final freeHistory = _historyItems.where((item) => item['currency'] == 'FREE').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("سجل العمليات واللعب", style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF8E24AA)),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFFCFAFF), Color(0xFFF0EBF7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Dropdown filters
                  _glassCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<String>(
                                value: _selectedYear,
                                decoration: const InputDecoration(
                                  labelText: "السنة",
                                  labelStyle: TextStyle(color: Color(0xFF6B5885), fontSize: 12),
                                  border: InputBorder.none,
                                ),
                                dropdownColor: Colors.white,
                                style: const TextStyle(color: Color(0xFF1A0933)),
                                items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() { _selectedYear = val; });
                                    _fetchHistoryData();
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<String>(
                                value: _selectedMonth,
                                decoration: const InputDecoration(
                                  labelText: "الشهر",
                                  labelStyle: TextStyle(color: Color(0xFF6B5885), fontSize: 12),
                                  border: InputBorder.none,
                                ),
                                dropdownColor: Colors.white,
                                style: const TextStyle(color: Color(0xFF1A0933)),
                                items: _monthNames.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() { _selectedMonth = val; });
                                    _fetchHistoryData();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // List content
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: Colors.white,
                            unselectedLabelColor: const Color(0xFF6B5885),
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: widget.accentColor,
                            ),
                            tabs: const [
                              Tab(text: "الشحن والكونزات"),
                              Tab(text: "الماسات (مجاني)"),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8E24AA)))
                                : TabBarView(
                                    children: [
                                      _buildHistoryList(cashHistory, "لا توجد عمليات شحن في الفلتر المحدد", Colors.orange),
                                      _buildHistoryList(freeHistory, "لا توجد ألعاب ماسات في الفلتر المحدد", const Color(0xFF8E24AA)),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF8E24AA).withValues(alpha: 0.08), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E24AA).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> items, String emptyLabel, Color accent) {
    if (items.isEmpty) {
      return Center(
        child: Text(emptyLabel,
            style: const TextStyle(color: Color(0xFF6B5885), fontSize: 13),
            textAlign: TextAlign.center),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, right: 2),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final record = items[index];
        final status = record['status'] == 'WON' ? 'ناجح' : 'خسارة';
        final amount = record['amount']?.toString() ?? '-';
        final isCash = record['currency'] == 'CASH';
        return _glassCard(
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
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
                        record['description']?.toString() ?? "لعب جولة",
                        style: const TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatHistoryDate(record),
                        style: const TextStyle(color: Color(0xFF6B5885), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "$amount ${isCash ? 'كونز' : 'ماسة'}",
                      style: const TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(status,
                        style: TextStyle(
                            color: status == 'ناجح' ? const Color(0xFF2E7D32) : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Support Chat Screen (Live Support Chat + Image Upload + social FAB links)
// ─────────────────────────────────────────────────────────────────────────────
class SupportChatPage extends StatefulWidget {
  final LinearGradient accentGradient;

  const SupportChatPage({
    super.key,
    required this.accentGradient,
  });

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  Timer? _pollingTimer;

  // Selected Image for uploading to support
  XFile? _selectedImage;
  String? _whatsappUrl;
  String? _telegramUrl;
  bool _showFabMenu = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadSocialConfigs();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSocialConfigs() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse("${auth.apiBase}/player/support/config"),
        headers: {"Authorization": "Bearer ${auth.token}"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _whatsappUrl = data['supportWhatsApp']?.toString().trim();
          _telegramUrl = data['supportTelegram']?.toString().trim();
        });
      }
    } catch (e) {
      debugPrint("Error fetching support config: $e");
    }
  }

  Future<void> _loadMessages() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    try {
      final res = await http.get(
        Uri.parse("${auth.apiBase}/player/support/messages"),
        headers: {"Authorization": "Bearer ${auth.token}"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _messages = data['messages'] ?? [];
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("Error fetching support messages: $e");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (img != null) {
      setState(() {
        _selectedImage = img;
      });
    }
  }

  Future<void> _sendMessage() async {
    final msg = _msgController.text.trim();
    if (msg.isEmpty && _selectedImage == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() { _isSending = true; });

    String? base64Img;
    if (_selectedImage != null) {
      try {
        final bytes = await _selectedImage!.readAsBytes();
        base64Img = "data:image/png;base64,${base64Encode(bytes)}";
      } catch (e) {
        debugPrint("Error base64 image: $e");
      }
    }

    try {
      final res = await http.post(
        Uri.parse("${auth.apiBase}/player/support/messages"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${auth.token}"
        },
        body: jsonEncode({
          "message": msg.isNotEmpty ? msg : null,
          "imageUrl": base64Img,
        }),
      );

      if (res.statusCode == 200) {
        _msgController.clear();
        setState(() {
          _selectedImage = null;
        });
        await _loadMessages();
      }
    } catch (e) {
      debugPrint("Send message error: $e");
    } finally {
      setState(() { _isSending = false; });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _launchUrlHelper(String? urlStr) async {
    if (urlStr == null || urlStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("رابط التواصل غير متوفر حالياً."),
        backgroundColor: Colors.orangeAccent,
      ));
      return;
    }
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("تعذر فتح التطبيق الخارجي."),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("تعذر الانتقال إلى الرابط."),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الدعم الفني المباشر", style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF8E24AA)),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFFCFAFF), Color(0xFFF0EBF7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Messages List
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.support_agent_rounded, size: 64, color: Color(0xFFBDBDBD)),
                              SizedBox(height: 12),
                              Text("مرحباً بك! تواصل معنا مباشرة هنا", style: TextStyle(color: Color(0xFF6B5885), fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text("فريق الدعم متاح لمساعدتك على مدار الساعة.", style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, idx) {
                            final m = _messages[idx];
                            final isUser = m['sender'] == 'USER';
                            final msgText = m['message']?.toString();
                            final imgUrl = m['imageUrl']?.toString();
                            return Align(
                              alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isUser ? const Color(0xFF8E24AA) : const Color(0xFFF5EEFD),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: isUser ? Radius.zero : const Radius.circular(16),
                                    bottomRight: isUser ? const Radius.circular(16) : Radius.zero,
                                  ),
                                  border: isUser ? null : Border.all(color: const Color(0xFFE8DBFA)),
                                ),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (imgUrl != null && imgUrl.isNotEmpty) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: imgUrl.startsWith("data:image/")
                                            ? Image.memory(base64Decode(imgUrl.contains(',') ? imgUrl.split(',')[1] : imgUrl))
                                            : Image.network(imgUrl),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    if (msgText != null && msgText.isNotEmpty)
                                      Text(msgText, style: TextStyle(color: isUser ? Colors.white : const Color(0xFF1A0933), fontSize: 13, height: 1.4)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Preview picked image
                if (_selectedImage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFFF5EEFD),
                    child: Row(
                      children: [
                        const Icon(Icons.image_rounded, color: Color(0xFF8E24AA)),
                        const SizedBox(width: 10),
                        const Expanded(child: Text("تم إرفاق صورة", style: TextStyle(color: Color(0xFF6B5885), fontSize: 12))),
                        IconButton(
                          onPressed: () => setState(() { _selectedImage = null; }),
                          icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                        )
                      ],
                    ),
                  ),
                // Input controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE8DBFA))),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_rounded, color: Color(0xFF8E24AA)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          style: const TextStyle(color: Color(0xFF1A0933), fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "اكتب رسالة للدعم...",
                            hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isSending ? null : _sendMessage,
                        icon: _isSending
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF8E24AA), strokeWidth: 2))
                            : const Icon(Icons.send_rounded, color: Color(0xFF8E24AA)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 80,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_showFabMenu) ...[
                  FloatingActionButton.extended(
                    heroTag: "tg_support",
                    onPressed: () {
                      setState(() { _showFabMenu = false; });
                      _launchUrlHelper(_telegramUrl);
                    },
                    backgroundColor: const Color(0xFF0088CC),
                    icon: const Icon(Icons.telegram, color: Colors.white),
                    label: const Text("تليجرام الدعم", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.extended(
                    heroTag: "wa_support",
                    onPressed: () {
                      setState(() { _showFabMenu = false; });
                      _launchUrlHelper(_whatsappUrl);
                    },
                    backgroundColor: const Color(0xFF25D366),
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: const Text("واتساب الدعم", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                ],
                FloatingActionButton(
                  heroTag: "menu_trigger",
                  onPressed: () => setState(() { _showFabMenu = !_showFabMenu; }),
                  backgroundColor: const Color(0xFF7C4DFF),
                  child: Icon(_showFabMenu ? Icons.close : Icons.headset_mic_rounded, color: Colors.white),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Settings Screen
// ─────────────────────────────────────────────────────────────────────────────
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifyPush = true;
  bool _notifyInApp = true;

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("الخصوصية والأمان", style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold, fontSize: 16)),
        content: const SingleChildScrollView(
          child: Text(
            "تلتزم إدارة Greedy Box بحماية خصوصية كافة اللاعبين بشكل كامل. يتم تشفير كلمات المرور وتخزين الحسابات باستخدام أحدث أساليب الأمان الرقمي.\n\nنهتم بخصوصيتك ولا نشارك أي بيانات تابعة لك مع جهات خارجية.",
            style: TextStyle(color: Color(0xFF6B5885), fontSize: 12, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("حسناً", style: TextStyle(color: Color(0xFF8E24AA), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _changeLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تغيير اللغة", style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text("اللغة الحالية هي العربية. هل ترغب في التبديل؟", style: TextStyle(color: Color(0xFF6B5885), fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("العربية", style: TextStyle(color: Color(0xFF6B5885))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("English mode is currently under dev config."),
              ));
            },
            child: const Text("English", style: TextStyle(color: Color(0xFF8E24AA), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("الإعدادات", style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF8E24AA)),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFFCFAFF), Color(0xFFF0EBF7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF8E24AA).withValues(alpha: 0.08), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8E24AA).withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8E24AA)),
                          title: const Text("الخصوصية والأمان", style: TextStyle(color: Color(0xFF1A0933))),
                          trailing: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF9E9E9E), size: 16),
                          onTap: _showPrivacyDialog,
                        ),
                        const Divider(color: Color(0xFFF3EEF9), height: 1),
                        ListTile(
                          leading: const Icon(Icons.language_rounded, color: Color(0xFF8E24AA)),
                          title: const Text("تغيير اللغة", style: TextStyle(color: Color(0xFF1A0933))),
                          trailing: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF9E9E9E), size: 16),
                          onTap: _changeLanguageDialog,
                        ),
                        const Divider(color: Color(0xFFF3EEF9), height: 1),
                        SwitchListTile(
                          value: _notifyPush,
                          activeColor: const Color(0xFF8E24AA),
                          secondary: const Icon(Icons.notifications_active_rounded, color: Color(0xFF8E24AA)),
                          title: const Text("تنبيهات الإشعارات الخارجية", style: TextStyle(color: Color(0xFF1A0933), fontSize: 14)),
                          onChanged: (val) => setState(() { _notifyPush = val; }),
                        ),
                        const Divider(color: Color(0xFFF3EEF9), height: 1),
                        SwitchListTile(
                          value: _notifyInApp,
                          activeColor: const Color(0xFF8E24AA),
                          secondary: const Icon(Icons.app_registration_rounded, color: Color(0xFF8E24AA)),
                          title: const Text("الإشعارات والرسائل داخل التطبيق", style: TextStyle(color: Color(0xFF1A0933), fontSize: 14)),
                          onChanged: (val) => setState(() { _notifyInApp = val; }),
                        ),
                        const Divider(color: Color(0xFFF3EEF9), height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                          title: const Text("تسجيل الخروج", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text("تسجيل الخروج", style: TextStyle(color: Color(0xFF1A0933), fontWeight: FontWeight.bold)),
                                content: const Text("هل أنت متأكد من رغبتك في تسجيل الخروج؟", style: TextStyle(color: Color(0xFF6B5885))),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء", style: TextStyle(color: Color(0xFF6B5885)))),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                    child: const Text("تأكيد", style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && mounted) {
                              auth.logout();
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
