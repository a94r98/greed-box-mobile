import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/auth_provider.dart';
import '../providers/socket_provider.dart';
import '../providers/game_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/chest_widget.dart';

class GameAudio {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play(String fileName) async {
    try {
      await rootBundle.load("assets/sounds/$fileName");
      await _player.play(AssetSource("sounds/$fileName"));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Selection states
  int _selectedKeyValue = 50; // Active betting key value
  String _betCurrency = "FREE"; // FREE or CASH
  
  // Custom animations controllers
  late AnimationController _revealController;
  
  // Local state copy to detect round transition and run animations
  String? _lastRoundId;
  int? _revealedWinningBox;
  bool _isAnimatingReveal = false;
  
  // Local win notice state
  double? _lastWinAmount;
  bool _showWinNotice = false;

  // Scanning animation states
  Timer? _scanTimer;
  int _scanHighlightIdx = -1;
  bool _isAnimatingScan = false;
  bool _closedResultsManually = false;

  // History popup states
  Map<String, dynamic>? _historyRoundDetails;
  bool _isLoadingHistoryDetails = false;

  final List<int> _betKeys = [50, 500, 5000, 10000, 50000, 100000];

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final wallet = Provider.of<WalletProvider>(context, listen: false);
      if (auth.token != null) {
        wallet.fetchProfile(auth.token!);
        wallet.fetchRankings(auth.token!);
      }
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _revealController.dispose();
    super.dispose();
  }

  // Auto bet submit on clicking a box
  void _placeDirectBet(int boxIndex) async {
    final game = Provider.of<GameProvider>(context, listen: false);
    final socketProv = Provider.of<SocketProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (game.isLocked) {
      _showError("الرهانات مغلقة للجولة الحالية!");
      return;
    }

    final double betAmount = _selectedKeyValue.toDouble();
    final balance = _betCurrency == "FREE" ? wallet.freeBalance : wallet.cashBalance;
    if (balance < betAmount) {
      _showError("عذراً، رصيدك غير كافي.");
      return;
    }

    GameAudio.play("coins.mp3");
    HapticFeedback.selectionClick();

    final clientBetId = UniqueKey().toString();
    try {
      await game.placeBet(socketProv, boxIndex, betAmount, clientBetId);
      if (auth.token != null) {
        wallet.fetchProfile(auth.token!);
      }
    } catch (e) {
      _showError("خطأ في وضع الرهان: $e");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent)
    );
  }

  // Handle server outcome transitions and play animations
  void _checkForRevealTransitions(GameProvider game, WalletProvider wallet, AuthProvider auth) {
    if (game.roundId != _lastRoundId) {
      _lastRoundId = game.roundId;
      _revealedWinningBox = null;
      _isAnimatingReveal = false;
      setState(() {
        _showWinNotice = false;
        _closedResultsManually = false;
      });
    }

    _updateScanAnimation(game.status);

    if (game.status == "REVEALING" && game.winningBox != null && !_isAnimatingReveal) {
      _isAnimatingReveal = true;
      _revealedWinningBox = game.winningBox;
      _runRevealSequence(game, wallet, auth);
    }
  }

  void _updateScanAnimation(String status) {
    if (status == "CALCULATING") {
      if (!_isAnimatingScan) {
        _isAnimatingScan = true;
        _scanTimer?.cancel();
        _scanTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
          if (mounted) {
            setState(() {
              _scanHighlightIdx = (_scanHighlightIdx + 1) % 8;
            });
          }
        });
      }
    } else {
      if (_isAnimatingScan) {
        _isAnimatingScan = false;
        _scanTimer?.cancel();
        _scanTimer = null;
        setState(() {
          _scanHighlightIdx = -1;
        });
      }
    }
  }

  void _showPastRoundDetails(String roundId) async {
    final game = Provider.of<GameProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    setState(() {
      _isLoadingHistoryDetails = true;
    });

    final details = await game.fetchRoundDetails(auth.token!, roundId);
    
    setState(() {
      _isLoadingHistoryDetails = false;
      _historyRoundDetails = details;
    });
  }

  void _runRevealSequence(GameProvider game, WalletProvider wallet, AuthProvider auth) async {
    HapticFeedback.mediumImpact();
    GameAudio.play("reveal.mp3");

    _revealController.forward(from: 0.0);

    // Trigger BIG WIN effect if multiplier is 45x
    final isBigWin = _revealedWinningBox == 4; // 45x is index 4 (Royal Red)
    if (isBigWin) {
      Timer(const Duration(milliseconds: 500), () {
        HapticFeedback.vibrate();
        GameAudio.play("win.mp3");
      });
    }

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Check if player won
    final myWinningBet = game.myActiveBets.firstWhere(
      (b) => b.boxIndex == _revealedWinningBox,
      orElse: () => UserBet(id: "", boxIndex: -1, amount: 0, currency: "")
    );

    final won = myWinningBet.boxIndex != -1;
    final double mult = _revealedWinningBox! <= 3 ? 5.0 : (_revealedWinningBox == 4 ? 45.0 : (_revealedWinningBox == 5 ? 25.0 : (_revealedWinningBox == 6 ? 15.0 : 10.0)));

    if (auth.token != null) {
      wallet.fetchProfile(auth.token!);
    }

    if (won) {
      setState(() {
        _lastWinAmount = myWinningBet.amount * mult;
        _showWinNotice = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final game = Provider.of<GameProvider>(context);
    final wallet = Provider.of<WalletProvider>(context);

    // Watch for server outcome changes
    _checkForRevealTransitions(game, wallet, auth);

    // Apply currency mode restrictions
    if (game.currencyMode == "FREE_ONLY" && _betCurrency != "FREE") {
      _betCurrency = "FREE";
    } else if (game.currencyMode == "CASH_ONLY" && _betCurrency != "CASH") {
      _betCurrency = "CASH";
    }

    // Dynamic state countdown colors
    Color timerColor = const Color(0xFF00E676);
    if (game.status == "LOCKED" || game.status == "CALCULATING") {
      timerColor = Colors.orange;
    } else if (game.status == "REVEALING" || game.status == "FINALIZING") {
      timerColor = Colors.amber;
    }

    final remainingSecs = (game.remainingMs / 1000).ceil();

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF130A30), // Deep Purple Background matching the image
        cardColor: const Color(0xFF241554),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
            onPressed: () {},
          ),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text("جولة: ${game.sequenceNumber}", style: const TextStyle(fontSize: 14, color: Colors.amber)),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.emoji_events_rounded, color: Colors.amber),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
        ),
        endDrawer: _buildWinnersDrawer(wallet),
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF130A30), Color(0xFF200F4E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Header Banner
                          const Center(
                            child: Text(
                              "Greedy Box",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Color(0xFF00E5FF), blurRadius: 15),
                                  Shadow(color: Color(0xFFE040FB), blurRadius: 15),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 2. Timeline Outcomes bar
                          _buildOutcomesTimeline(game),
                          const SizedBox(height: 10),

                          // 3. Countdown display bar
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: timerColor.withValues(alpha:0.3)),
                              ),
                              child: Text(
                                "العد التنازلي: ${remainingSecs}s",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: timerColor),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 4. Grid layout for chests
                          AnimatedBuilder(
                            animation: _revealController,
                            builder: (context, _) => _buildChestsGrid(game),
                          ),
                          const SizedBox(height: 12),

                          // 5. Currency tab switcher
                          _buildCurrencySwitcher(game),
                          const SizedBox(height: 8),

                          // 6. Keys values selection
                          const Center(
                            child: Text(
                              "حدد المفتاح",
                              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildKeysSelector(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // 7. Bottom static bar
                  _buildBottomLedger(wallet),
                ],
              ),
            ),
            if (game.status == "FINALIZING")
              _buildResultsPopup(context, game, wallet),
            _buildHistoryResultsPopup(),
            if (_isLoadingHistoryDetails)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBoxColor(int boxIndex) {
    if (boxIndex == 0) return const Color(0xFFFF7B00); // Orange
    if (boxIndex == 1) return const Color(0xFFE040FB); // Pink
    if (boxIndex == 2) return const Color(0xFF8A2BE2); // Purple
    if (boxIndex == 3) return const Color(0xFF00E5FF); // Sky Blue
    if (boxIndex == 4) return const Color(0xFFFF1744); // Royal Red
    if (boxIndex == 5) return const Color(0xFF2979FF); // Blue Crystal
    if (boxIndex == 6) return const Color(0xFFD500F9); // Star Purple
    return const Color(0xFF00E676); // Icy Green
  }

  // Timeline strip
  Widget _buildOutcomesTimeline(GameProvider game) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text("النتيجة:", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: game.recentOutcomes.length,
                itemBuilder: (ctx, idx) {
                  final outcome = game.recentOutcomes[idx];
                  final isNew = idx == 0;
                  final int winBox = outcome['winningBox'] ?? 0;
                  final Color chestColor = _getBoxColor(winBox);

                  return GestureDetector(
                    onTap: () => _showPastRoundDetails(outcome['id']),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isNew ? Colors.amber : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_rounded, size: 20, color: chestColor),
                          if (isNew) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(color: Colors.pink, borderRadius: BorderRadius.circular(4)),
                              child: const Text("New", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                            )
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Visual custom chests grid
  Widget _buildChestsGrid(GameProvider game) {
    int hotBoxIdx = -1;
    double maxBets = 0;
    for (int i = 0; i < 8; i++) {
      final totals = game.boxBets[i];
      final currentTotal = game.currencyMode == "FREE_ONLY" ? (totals?.free ?? 0) : (totals?.cash ?? 0);
      if (currentTotal > maxBets) {
        maxBets = currentTotal;
        hotBoxIdx = i;
      }
    }

    return Column(
      children: [
        // Row 1: 4 standard chests (5x)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (idx) {
            Color boxColor = const Color(0xFFFF7B00); // Orange
            if (idx == 1) boxColor = const Color(0xFFE040FB); // Pink
            if (idx == 2) boxColor = const Color(0xFF8A2BE2); // Purple
            if (idx == 3) boxColor = const Color(0xFF00E5FF); // Sky Blue

            final activeUserBets = game.myActiveBets.where((b) => b.boxIndex == idx);
            final double userBetAmount = activeUserBets.fold(0.0, (prev, val) => prev + val.amount);
            final isWinner = _revealedWinningBox == idx;
            final isHighlight = _scanHighlightIdx == idx;

            final totals = game.boxBets[idx];
            final double totalFree = totals?.free ?? 0.0;
            final double totalCash = totals?.cash ?? 0.0;
            final String totalBetsStr = _betCurrency == "FREE"
                ? (totalFree > 0 ? "🪙 ${totalFree.toStringAsFixed(0)}" : "")
                : (totalCash > 0 ? "💵 ${totalCash.toStringAsFixed(0)}" : "");

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isHighlight ? const Color(0xFF00E5FF) : Colors.transparent,
                      width: 2.0,
                    ),
                    boxShadow: isHighlight ? [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha:0.6),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ] : null,
                  ),
                  child: GestureDetector(
                    onTap: () => _placeDirectBet(idx),
                    child: ChestWidget(
                      color: boxColor,
                      multiplierLabel: "5x مرة",
                      multiplierValue: 5,
                      isSelected: userBetAmount > 0,
                      isWinner: isWinner,
                      userBetAmount: userBetAmount,
                      totalBets: totalBetsStr,
                      isHot: idx == hotBoxIdx,
                      gameStatus: game.status,
                      openProgress: _revealedWinningBox == idx ? _revealController.value : 0.0,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        
        const SizedBox(height: 12), // Visible clear space between rows

        // Row 2: 4 premium chests
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (i) {
            final idx = i + 4;
            Color boxColor = const Color(0xFFFF1744); // Red Royal
            String label = "45x مرة";
            int mult = 45;

            if (idx == 5) {
              boxColor = const Color(0xFF2979FF); // Blue Crystal
              label = "25x مرة";
              mult = 25;
            } else if (idx == 6) {
              boxColor = const Color(0xFFD500F9); // Star Purple
              label = "15x مرة";
              mult = 15;
            } else if (idx == 7) {
              boxColor = const Color(0xFF00E676); // Icy Green
              label = "10x مرة";
              mult = 10;
            }

            final activeUserBets = game.myActiveBets.where((b) => b.boxIndex == idx);
            final double userBetAmount = activeUserBets.fold(0.0, (prev, val) => prev + val.amount);
            final isWinner = _revealedWinningBox == idx;
            final isHighlight = _scanHighlightIdx == idx;

            final totals = game.boxBets[idx];
            final double totalFree = totals?.free ?? 0.0;
            final double totalCash = totals?.cash ?? 0.0;
            final String totalBetsStr = _betCurrency == "FREE"
                ? (totalFree > 0 ? "🪙 ${totalFree.toStringAsFixed(0)}" : "")
                : (totalCash > 0 ? "💵 ${totalCash.toStringAsFixed(0)}" : "");

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isHighlight ? const Color(0xFF00E5FF) : Colors.transparent,
                      width: 2.0,
                    ),
                    boxShadow: isHighlight ? [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha:0.6),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ] : null,
                  ),
                  child: GestureDetector(
                    onTap: () => _placeDirectBet(idx),
                    child: ChestWidget(
                      color: boxColor,
                      multiplierLabel: label,
                      multiplierValue: mult,
                      isSelected: userBetAmount > 0,
                      isWinner: isWinner,
                      userBetAmount: userBetAmount,
                      totalBets: totalBetsStr,
                      isHot: idx == hotBoxIdx,
                      gameStatus: game.status,
                      openProgress: _revealedWinningBox == idx ? _revealController.value : 0.0,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCurrencySwitcher(GameProvider game) {
    // Disable selection if locked to a specific mode by the server
    final isFreeLocked = game.currencyMode == "FREE_ONLY";
    final isCashLocked = game.currencyMode == "CASH_ONLY";

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCurrencyTab(
          label: "العملات المجانية",
          isActive: _betCurrency == "FREE",
          disabled: isCashLocked,
          onTap: () {
            GameAudio.play("click.mp3");
            setState(() => _betCurrency = "FREE");
          },
        ),
        const SizedBox(width: 12),
        _buildCurrencyTab(
          label: "الكونز المدفوع",
          isActive: _betCurrency == "CASH",
          disabled: isFreeLocked,
          onTap: () {
            GameAudio.play("click.mp3");
            setState(() => _betCurrency = "CASH");
          },
        ),
      ],
    );
  }

  Widget _buildCurrencyTab({required String label, required bool isActive, required bool disabled, required VoidCallback onTap}) {
    return IgnorePointer(
      ignoring: disabled,
      child: Opacity(
        opacity: disabled ? 0.3 : 1.0,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? Colors.amber : Colors.black26,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isActive ? Colors.amber : Colors.white24),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isActive ? Colors.black : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Key Selection matching image
  Widget _buildKeysSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _betKeys.map((keyVal) {
        final isSelected = _selectedKeyValue == keyVal;
        
        // Custom keys colors/designs based on value
        Color keyColor = Colors.amber;
        if (keyVal == 500) keyColor = const Color(0xFF00E5FF);
        if (keyVal == 5000) keyColor = const Color(0xFFFF1744);
        if (keyVal == 10000) keyColor = const Color(0xFFE040FB);
        if (keyVal == 50000) keyColor = const Color(0xFF00E676);
        if (keyVal >= 100000) keyColor = Colors.orange;

        return GestureDetector(
          onTap: () {
            GameAudio.play("click.mp3");
            setState(() {
              _selectedKeyValue = keyVal;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha:0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? Colors.amber : Colors.transparent, width: 1.5),
            ),
            child: Column(
              children: [
                Icon(Icons.vpn_key_rounded, color: keyColor, size: 28),
                const SizedBox(height: 6),
                Text(
                  keyVal.toString(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Bottom static bar showing balances
  Widget _buildBottomLedger(WalletProvider wallet) {
    final double balance = _betCurrency == "FREE" ? wallet.freeBalance : wallet.cashBalance;
    final currencySymbol = _betCurrency == "FREE" ? "🪙" : "💵";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF130A30),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Current user balance
            Row(
              children: [
                Text("رصيدك: ${balance.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                const SizedBox(width: 4),
                Text(currencySymbol, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    if (auth.token != null) {
                      final amount = _betCurrency == "FREE" ? 100000.0 : 10000.0;
                      final success = await wallet.requestTestRefill(auth.token!, amount, _betCurrency);
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("تم إضافة +${amount.toStringAsFixed(0)} عملة بنجاح للاختبار!"),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline, size: 14, color: Colors.amber),
                        SizedBox(width: 2),
                        Text(
                          "شحن تجريبي",
                          style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Dynamic win alert display
            if (_showWinNotice && _lastWinAmount != null)
              AnimatedOpacity(
                opacity: _showWinNotice ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  "ربحت: +${_lastWinAmount!.toStringAsFixed(0)}",
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              )
            else
              const Text(
                "ربحت: 0",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }

  // Side Drawer for top winners
  Widget _buildWinnersDrawer(WalletProvider wallet) {
    return Drawer(
      backgroundColor: const Color(0xFF130A30),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "أفضل الفائزين (آخر 24 ساعة)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: wallet.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: min(3, wallet.rankings.length),
                        itemBuilder: (ctx, idx) {
                          final user = wallet.rankings[idx];
                          return Card(
                            color: const Color(0xFF241554),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.amber.withValues(alpha:0.2),
                                child: Text("#${idx + 1}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(user['username'] ?? "لاعب", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              trailing: Text("+${user['value']} شحن", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsPopup(BuildContext context, GameProvider game, WalletProvider wallet) {
    if (_closedResultsManually) return const SizedBox.shrink();

    final winBox = game.winningBox ?? 0;
    
    // Chest details
    Color boxColor = const Color(0xFFFF7B00); // Orange
    String label = "5x مرة";
    int multVal = 5;
    if (winBox == 1) boxColor = const Color(0xFFE040FB);
    if (winBox == 2) boxColor = const Color(0xFF8A2BE2);
    if (winBox == 3) boxColor = const Color(0xFF00E5FF);
    if (winBox == 4) { boxColor = const Color(0xFFFF1744); label = "45x مرة"; multVal = 45; }
    if (winBox == 5) { boxColor = const Color(0xFF2979FF); label = "25x مرة"; multVal = 25; }
    if (winBox == 6) { boxColor = const Color(0xFFD500F9); label = "15x مرة"; multVal = 15; }
    if (winBox == 7) { boxColor = const Color(0xFF00E676); label = "10x مرة"; multVal = 10; }

    // Calc personal stats
    final myBetsOnWinningBox = game.myActiveBets.where((b) => b.boxIndex == winBox);
    final totalBetOnWinningBox = myBetsOnWinningBox.fold(0.0, (sum, b) => sum + b.amount);
    final totalMyBets = game.myActiveBets.fold(0.0, (sum, b) => sum + b.amount);
    final double winReward = totalBetOnWinningBox * multVal;

    final currencySymbol = _betCurrency == "FREE" ? "🪙" : "💵";

    // Winners list (with mock fallbacks)
    final List<dynamic> winners = game.roundWinners.isNotEmpty 
      ? game.roundWinners 
      : [
          {"username": "سلطان", "avatar": "avatar_1", "winAmount": 150000.0},
          {"username": "أبو فهد", "avatar": "avatar_2", "winAmount": 21000.0},
          {"username": "صقر العرب", "avatar": "avatar_3", "winAmount": 15000.0},
        ];

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha:0.7),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B0F42),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00E5FF), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha:0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with wings and title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () {
                        setState(() {
                          _closedResultsManually = true;
                        });
                      },
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                        SizedBox(width: 4),
                        Text(
                          "نتائج الجولة",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      ],
                    ),
                    const SizedBox(width: 48), // Spacer to balance close button
                  ],
                ),
                const SizedBox(height: 16),

                // Winning Box Representation
                Center(
                  child: Column(
                    children: [
                      ChestWidget(
                        color: boxColor,
                        multiplierLabel: label,
                        multiplierValue: multVal,
                        isSelected: false,
                        isWinner: true,
                        userBetAmount: 0,
                        totalBets: "",
                        isHot: false,
                        gameStatus: game.status,
                        openProgress: 1.0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Player Bet & Win stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Bet Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF241554),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            const Text("راهنت", style: TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              "${totalMyBets.toStringAsFixed(0)} $currencySymbol",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Win Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF241554),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha:0.3)),
                        ),
                        child: Column(
                          children: [
                            const Text("فزت", style: TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              "${winReward.toStringAsFixed(0)} $currencySymbol",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.greenAccent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Top Winners section
                const Text(
                  "أكبر الفائزين في هذه الجولة",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // 3 Winners row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(winners.length, (idx) {
                    final winner = winners[idx];
                    final String name = winner['username'] ?? "لاعب";
                    final double amount = (winner['winAmount'] as num).toDouble();
                    
                    // Crown and medal coloring
                    Color medalColor = Colors.amber;
                    if (idx == 1) medalColor = Colors.grey;
                    if (idx == 2) medalColor = Colors.brown;

                    return Expanded(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: medalColor, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white12,
                                  child: Icon(Icons.person, color: medalColor, size: 20),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                child: Icon(Icons.emoji_events_rounded, color: medalColor, size: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${amount.toStringAsFixed(0)} $currencySymbol",
                            style: const TextStyle(fontSize: 10, color: Colors.amberAccent),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryResultsPopup() {
    if (_historyRoundDetails == null) return const SizedBox.shrink();

    final round = _historyRoundDetails!['round'];
    final List<dynamic> winners = _historyRoundDetails!['topWinners'] ?? [];
    final int winBox = round['winningBox'] ?? 0;
    final int sequenceNumber = round['sequenceNumber'] ?? 0;

    // Chest details
    Color boxColor = const Color(0xFFFF7B00); // Orange
    String label = "5x مرة";
    int multVal = 5;
    if (winBox == 1) boxColor = const Color(0xFFE040FB);
    if (winBox == 2) boxColor = const Color(0xFF8A2BE2);
    if (winBox == 3) boxColor = const Color(0xFF00E5FF);
    if (winBox == 4) { boxColor = const Color(0xFFFF1744); label = "45x مرة"; multVal = 45; }
    if (winBox == 5) { boxColor = const Color(0xFF2979FF); label = "25x مرة"; multVal = 25; }
    if (winBox == 6) { boxColor = const Color(0xFFD500F9); label = "15x مرة"; multVal = 15; }
    if (winBox == 7) { boxColor = const Color(0xFF00E676); label = "10x مرة"; multVal = 10; }

    final currencySymbol = _betCurrency == "FREE" ? "🪙" : "💵";

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha:0.7),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B0F42),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE040FB), width: 2), // Pink border for history details
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE040FB).withValues(alpha:0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with wings and title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () {
                        setState(() {
                          _historyRoundDetails = null;
                        });
                      },
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          "نتائج الجولة $sequenceNumber",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 16),

                // Winning Box Representation
                Center(
                  child: Column(
                    children: [
                      ChestWidget(
                        color: boxColor,
                        multiplierLabel: label,
                        multiplierValue: multVal,
                        isSelected: false,
                        isWinner: true,
                        userBetAmount: 0,
                        totalBets: "",
                        isHot: false,
                        openProgress: 1.0,
                        gameStatus: "REVEALING",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Top Winners section
                const Text(
                  "أكبر الفائزين في هذه الجولة",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // 3 Winners row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: winners.isEmpty
                    ? [
                        const Text("لا يوجد فائزين في هذه الجولة", style: TextStyle(color: Colors.white38, fontSize: 13))
                      ]
                    : List.generate(winners.length, (idx) {
                        final winner = winners[idx];
                        final String name = winner['username'] ?? "لاعب";
                        final double amount = (winner['winAmount'] as num).toDouble();
                        
                        Color medalColor = Colors.amber;
                        if (idx == 1) medalColor = Colors.grey;
                        if (idx == 2) medalColor = Colors.brown;

                        return Expanded(
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: medalColor, width: 2),
                                    ),
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white12,
                                      child: Icon(Icons.person, color: medalColor, size: 20),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    child: Icon(Icons.emoji_events_rounded, color: medalColor, size: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                name,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${amount.toStringAsFixed(0)} $currencySymbol",
                                style: const TextStyle(fontSize: 10, color: Colors.amberAccent),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        );
                      }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

