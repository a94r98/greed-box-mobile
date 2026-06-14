import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'socket_provider.dart';
import '../config.dart';

class BoxBet {
  final double free;
  final double cash;
  BoxBet({required this.free, required this.cash});
}

class UserBet {
  final String id;
  final int boxIndex;
  final double amount;
  final String currency;
  UserBet(
      {required this.id,
      required this.boxIndex,
      required this.amount,
      required this.currency});
}

class GameProvider extends ChangeNotifier {
  String get apiBase => AppConfig.apiBase;

  String _roundId = "";
  String _status = "ENDED";
  String _currencyMode = "FREE_ONLY";
  int _remainingMs = 0;
  int _sequenceNumber = 0;

  int? _winningBox;
  double? _winningMultiplier;

  double _totalFreeBets = 0.0;
  double _totalCashBets = 0.0;
  final Map<int, BoxBet> _boxBets = {};

  List<UserBet> _myActiveBets = [];
  List<Map<String, dynamic>> _recentOutcomes = [];
  List<dynamic> _roundWinners = [];
  String? _maintenanceMessage;

  // Getters
  String get roundId => _roundId;
  String get status => _status;
  String get currencyMode => _currencyMode;
  int get remainingMs => _remainingMs;
  int get sequenceNumber => _sequenceNumber;
  int? get winningBox => _winningBox;
  double? get winningMultiplier => _winningMultiplier;
  double get totalFreeBets => _totalFreeBets;
  double get totalCashBets => _totalCashBets;
  Map<int, BoxBet> get boxBets => _boxBets;
  List<UserBet> get myActiveBets => _myActiveBets;
  List<Map<String, dynamic>> get recentOutcomes => _recentOutcomes;
  List<dynamic> get roundWinners => _roundWinners;
  String? get maintenanceMessage => _maintenanceMessage;

  bool get isLocked =>
      _status == "LOCKED" ||
      _status == "CALCULATING" ||
      _status == "REVEALING" ||
      _status == "FINALIZING";
  bool get isBettingOpen => _status == "BETTING";

  GameProvider() {
    _initBoxBets();
  }

  void _initBoxBets() {
    for (int i = 0; i < 8; i++) {
      _boxBets[i] = BoxBet(free: 0.0, cash: 0.0);
    }
  }

  // Subscribe to websocket events
  void subscribeToSocketEvents(SocketProvider socketProvider) {
    final socket = socketProvider.socket;
    if (socket == null) return;

    socket.off("round_state_change");
    socket.off("timer_tick");
    socket.off("bets_update");
    socket.off("round_reveal");
    socket.off("maintenance_alert");

    socket.on("round_state_change", (data) {
      _roundId = data['roundId'] ?? "";
      _status = data['status'] ?? "ENDED";
      _currencyMode = data['currencyMode'] ?? "FREE_ONLY";
      _remainingMs = data['remainingMs'] ?? 0;
      _sequenceNumber = data['sequenceNumber'] ?? 0;

      if (_status == "BETTING") {
        _winningBox = null;
        _winningMultiplier = null;
        _myActiveBets = [];
        _initBoxBets();
        _totalFreeBets = 0.0;
        _totalCashBets = 0.0;
        _roundWinners = [];
      }
      notifyListeners();
    });

    socket.on("timer_tick", (data) {
      _remainingMs = data['remainingMs'] ?? 0;
      notifyListeners();
    });

    socket.on("bets_update", (data) {
      _totalFreeBets = (data['totalFree'] as num?)?.toDouble() ?? 0.0;
      _totalCashBets = (data['totalCash'] as num?)?.toDouble() ?? 0.0;

      final Map<String, dynamic> boxBetsData = data['boxBets'] ?? {};
      boxBetsData.forEach((boxIdxStr, value) {
        final boxIdx = int.parse(boxIdxStr);
        _boxBets[boxIdx] = BoxBet(
            free: (value['free'] as num?)?.toDouble() ?? 0.0,
            cash: (value['cash'] as num?)?.toDouble() ?? 0.0);
      });
      notifyListeners();
    });

    socket.on("round_reveal", (data) {
      _winningBox = data['winningBox'];
      _winningMultiplier = (data['winningMultiplier'] as num?)?.toDouble();
      _roundWinners = data['topWinners'] ?? [];

      if (_winningBox != null && _winningBox! >= 0) {
        _recentOutcomes.insert(0, {
          "id": _roundId,
          "winningBox": _winningBox,
          "winningMultiplier": _winningMultiplier,
          "sequenceNumber": _sequenceNumber
        });
        if (_recentOutcomes.length > 20) {
          _recentOutcomes = _recentOutcomes.sublist(0, 20);
        }
      }
      notifyListeners();
    });

    socket.on("maintenance_alert", (data) {
      _maintenanceMessage = data['message'];
      notifyListeners();
    });
  }

  // REST API rehydration when connection drops and recovers
  Future<void> rehydrateState(String token) async {
    try {
      final res = await http.get(Uri.parse("$apiBase/rounds/current"),
          headers: {"Authorization": "Bearer $token"});

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final roundData = data['round'];
        _roundId = roundData['roundId'] ?? "";
        _status = roundData['status'] ?? "ENDED";
        _currencyMode = roundData['currencyMode'] ?? "FREE_ONLY";
        _remainingMs = roundData['remainingMs'] ?? 0;
        _sequenceNumber = roundData['sequenceNumber'] ?? 0;

        final List<dynamic> betsData = data['myBets'] ?? [];
        _myActiveBets = betsData
            .map((b) => UserBet(
                id: b['clientBetId'],
                boxIndex: b['boxIndex'],
                amount: (b['amount'] as num).toDouble(),
                currency: b['currency']))
            .toList();

        _maintenanceMessage = null;
      }

      // Fetch recent rounds list
      final recentRes = await http.get(
          Uri.parse("$apiBase/player/rounds/recent"),
          headers: {"Authorization": "Bearer $token"});
      if (recentRes.statusCode == 200) {
        final recentData = jsonDecode(recentRes.body);
        final List<dynamic> rounds = recentData['rounds'] ?? [];
        _recentOutcomes = rounds
            .map((r) => {
                  "id": r['id'],
                  "winningBox": r['winningBox'],
                  "winningMultiplier":
                      (r['winningMultiplier'] as num?)?.toDouble(),
                  "sequenceNumber": r['sequenceNumber']
                })
            .toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("[GameProvider] Rehydration error: $e");
    }
  }

  // Fetch specific round details from DB
  Future<Map<String, dynamic>?> fetchRoundDetails(
      String token, String roundId) async {
    try {
      final res = await http.get(Uri.parse("$apiBase/player/rounds/$roundId"),
          headers: {"Authorization": "Bearer $token"});
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("[GameProvider] Fetch round details error: $e");
    }
    return null;
  }

  // Socket request to place bet
  Future<void> placeBet(SocketProvider socketProvider, int boxIndex,
      double amount, String clientBetId, String currency) async {
    final socket = socketProvider.socket;
    if (socket == null || !socketProvider.isConnected) {
      throw Exception("Game connection is offline.");
    }

    final completer = Completer<void>();

    socket.emitWithAck("place_bet", {
      "boxIndex": boxIndex,
      "amount": amount,
      "clientBetId": clientBetId,
      "currency": currency
    }, ack: (response) {
      final res = response as Map;
      if (res.containsKey("error")) {
        completer.completeError(res['error']);
      } else {
        final b = res['bet'];
        _myActiveBets.add(UserBet(
            id: b['clientBetId'],
            boxIndex: b['boxIndex'],
            amount: (b['amount'] as num).toDouble(),
            currency: b['currency']));
        notifyListeners();
        completer.complete();
      }
    });

    return completer.future;
  }
}
