import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/socket_provider.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRankings();
      _setupSocketListener();
    });
  }

  void _loadRankings() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    if (auth.token != null) {
      wallet.fetchRankings(auth.token!);
    }
  }

  void _setupSocketListener() {
    final socketProv = Provider.of<SocketProvider>(context, listen: false);
    socketProv.socket?.on("round_state_change", _onSocketUpdate);
  }

  void _removeSocketListener() {
    final socketProv = Provider.of<SocketProvider>(context, listen: false);
    socketProv.socket?.off("round_state_change", _onSocketUpdate);
  }

  void _onSocketUpdate(dynamic data) {
    if (mounted) {
      _loadRankings();
    }
  }

  @override
  void dispose() {
    _removeSocketListener();
    super.dispose();
  }

  String _formatCoins(double value) {
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String mathFunc(Match match) => '${match[1]},';
    String formatted = value.toInt().toString().replaceAllMapped(reg, mathFunc);
    return "$formatted Coins";
  }

  @override
  Widget build(BuildContext context) {
    final wallet = Provider.of<WalletProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final rankings = wallet.rankings;
    final myRank = wallet.myRankInfo;

    // Determine if user is in top 100
    final int myRankNumber =
        myRank != null ? (myRank['rank'] as num).toInt() : -1;
    final bool showStickyBottom = myRankNumber > 100 || myRankNumber == -1;

    // Separate Top 3 from remaining players
    final List<Map<String, dynamic>> topThree = rankings.take(3).toList();
    final List<Map<String, dynamic>> remainingList = rankings.skip(3).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "لوحة الصدارة",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0E021F), // Dark Purple
              Color(0xFF23073E), // Purple
              Color(0xFF4A0A3D), // Pink-Plum
              Color(0xFF0E021F), // Dark Purple
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: wallet.isLoading && rankings.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDA22FF)),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => _loadRankings(),
                        color: const Color(0xFFDA22FF),
                        backgroundColor: const Color(0xFF0F0826),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          children: [

                        // Top 3 Podium
                        if (topThree.isNotEmpty) ...[
                          TopThreeWidget(topPlayers: topThree),
                          const SizedBox(height: 24),
                        ],

                        // Rest of the general players list (Rank 4 to 100)
                        if (remainingList.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "الترتيب العام (${rankings.length})",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  Icons.star_border_rounded,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                          ...remainingList.map((player) {
                            final int rank = (player['rank'] as num).toInt();
                            final String nickname = player['displayNickname'] ??
                                player['username'] ??
                                "لاعب";
                            final String publicId = player['publicId'] ?? "";
                            final double value =
                                (player['value'] as num?)?.toDouble() ?? 0.0;
                            final String gender = player['gender'] ?? "MALE";

                            return Card(
                              color: const Color(0xFF0F0826)
                                  .withValues(alpha: 0.7),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: auth.user?['publicId'] == publicId
                                      ? const Color(0xFFDA22FF)
                                      : Colors.purple.withValues(alpha: 0.1),
                                  width: auth.user?['publicId'] == publicId
                                      ? 1.5
                                      : 1.0,
                                ),
                              ),
                              elevation: 0,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 38,
                                      alignment: Alignment.center,
                                      child: Text(
                                        "#$rank",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color:
                                              auth.user?['publicId'] == publicId
                                                  ? const Color(0xFFDA22FF)
                                                  : Colors.white70,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildListAvatar(nickname, gender),
                                  ],
                                ),
                                title: Text(
                                  nickname,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  "ID: $publicId",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: Text(
                                  _formatCoins(value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFFB703),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ] else if (!wallet.isLoading) ...[
                          const SizedBox(height: 48),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.emoji_events_outlined,
                                  size: 64,
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "لا يوجد متصدرين حالياً",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Sticky Bottom Bar for user ranking outside top 100
                if (showStickyBottom && myRank != null) ...[
                  Container(
                    padding: const EdgeInsets.only(
                        left: 20, right: 20, top: 16, bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0826),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              _buildListAvatar(
                                  myRank['displayNickname'] ?? "أنت",
                                  myRank['gender'] ?? "MALE"),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      myRank['displayNickname'] ?? "أنت",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      "ترتيبك الحالي: #${myRankNumber == -1 ? 'غير مصنف' : myRankNumber}",
                                      style: const TextStyle(
                                        color: Color(0xFFDA22FF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatCoins(
                                        (myRank['value'] as num?)?.toDouble() ??
                                            0.0),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFFB703),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (myRank['coinsToRank99'] != null &&
                              (myRank['coinsToRank99'] as num) > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "باقي لك ${_formatCoins((myRank['coinsToRank99'] as num).toDouble())} للوصول إلى المركز 99",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  ],
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildListAvatar(String nickname, String gender) {
    final String framePath = gender == "FEMALE"
        ? "assets/frames/New female account.json"
        : "assets/frames/New male account.json";

    return AnimatedFrameAvatar(
      nickname: nickname,
      frameAssetPath: framePath,
      size: 32,
    );
  }
}

class TopThreeWidget extends StatelessWidget {
  final List<Map<String, dynamic>> topPlayers;

  const TopThreeWidget({super.key, required this.topPlayers});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? first =
        topPlayers.isNotEmpty ? topPlayers[0] : null;
    final Map<String, dynamic>? second =
        topPlayers.length > 1 ? topPlayers[1] : null;
    final Map<String, dynamic>? third =
        topPlayers.length > 2 ? topPlayers[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0826).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 3rd Place (Left)
          Expanded(
            child: third != null
                ? _buildPodiumMember(
                    context,
                    player: third,
                    rank: 3,
                    avatarSize: 52,
                    badge: "🥉",
                    framePath: "assets/frames/Third place.json",
                    heightOffset: 0.0,
                  )
                : const SizedBox(),
          ),

          // 1st Place (Center)
          Expanded(
            child: first != null
                ? _buildPodiumMember(
                    context,
                    player: first,
                    rank: 1,
                    avatarSize: 72,
                    badge: "🥇",
                    framePath: "assets/frames/First place.json",
                    heightOffset: 25.0,
                  )
                : const SizedBox(),
          ),

          // 2nd Place (Right)
          Expanded(
            child: second != null
                ? _buildPodiumMember(
                    context,
                    player: second,
                    rank: 2,
                    avatarSize: 62,
                    badge: "🥈",
                    framePath: "assets/frames/Second place.json",
                    heightOffset: 10.0,
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumMember(
    BuildContext context, {
    required Map<String, dynamic> player,
    required int rank,
    required double avatarSize,
    required String badge,
    required String framePath,
    required double heightOffset,
  }) {
    final nickname = player['displayNickname'] ?? player['username'] ?? "لاعب";
    final publicId = player['publicId'] ?? "";
    final double value = (player['value'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: heightOffset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedFrameAvatar(
            nickname: nickname,
            frameAssetPath: framePath,
            size: avatarSize,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              badge,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          Text(
            "ID: $publicId",
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCoins(value),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFB703),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCoins(double value) {
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String mathFunc(Match match) => '${match[1]},';
    String formatted = value.toInt().toString().replaceAllMapped(reg, mathFunc);
    return "$formatted Coins";
  }
}

class AnimatedFrameAvatar extends StatelessWidget {
  final String nickname;
  final String frameAssetPath;
  final double size;

  const AnimatedFrameAvatar({
    super.key,
    required this.nickname,
    required this.frameAssetPath,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.5,
      height: size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildRawAvatar(),
          IgnorePointer(
            child: Lottie.asset(
              frameAssetPath,
              width: size * 1.5,
              height: size * 1.5,
              fit: BoxFit.fill,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawAvatar() {
    final initials = nickname.isNotEmpty ? nickname[0].toUpperCase() : "?";
    final hash = nickname.hashCode;
    final List<Color> colors = [
      [const Color(0xFFDA22FF), const Color(0xFF9733EE)],
      [const Color(0xFF00F2FE), const Color(0xFF4FACFE)],
      [const Color(0xFFF21B3F), const Color(0xFFAB001C)],
      [const Color(0xFFFF8C00), const Color(0xFFFF0080)],
    ][hash % 4];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
