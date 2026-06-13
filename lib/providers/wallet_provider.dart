import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class WalletProvider extends ChangeNotifier {
  String get apiBase => AppConfig.apiBase;

  double _freeBalance = 0.0;
  double _cashBalance = 0.0;
  List<Map<String, dynamic>> _betHistory = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _rankings = [];
  Map<String, dynamic>? _myRankInfo;
  
  Map<String, dynamic>? _profileStats;
  bool _isLoading = false;

  double get freeBalance => _freeBalance;
  double get cashBalance => _cashBalance;
  List<Map<String, dynamic>> get betHistory => _betHistory;
  List<Map<String, dynamic>> get tasks => _tasks;
  List<Map<String, dynamic>> get rankings => _rankings;
  Map<String, dynamic>? get myRankInfo => _myRankInfo;
  Map<String, dynamic>? get profileStats => _profileStats;
  bool get isLoading => _isLoading;

  // Sync balances and stats from server
  Future<void> fetchProfile(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await http.get(
        Uri.parse("$apiBase/player/profile"),
        headers: {"Authorization": "Bearer $token"}
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['profile'];
        _freeBalance = (data['wallet']['freeBalance'] as num).toDouble();
        _cashBalance = (data['wallet']['cashBalance'] as num).toDouble();
        _profileStats = data;
      }
    } catch (e) {
      debugPrint("[WalletProvider] Profile sync error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  // Fetch paginated personal bet history
  Future<void> fetchBetHistory(String token) async {
    try {
      final res = await http.get(
        Uri.parse("$apiBase/player/history?limit=20"),
        headers: {"Authorization": "Bearer $token"}
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _betHistory = List<Map<String, dynamic>>.from(data['history']);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("[WalletProvider] History error: $e");
    }
  }

  // Request Cash Deposit
  Future<bool> requestDeposit(String token, double amount) async {
    try {
      final res = await http.post(
        Uri.parse("$apiBase/player/deposit"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({"amount": amount})
      );
      return res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // Request Cash Withdrawal
  Future<bool> requestWithdrawal(String token, double amount) async {
    try {
      final res = await http.post(
        Uri.parse("$apiBase/player/withdrawal"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({"amount": amount})
      );
      if (res.statusCode == 201) {
        // Fetch profile immediately to update wallet balance since amount was holding-deducted
        await fetchProfile(token);
        return true;
      }
    } catch (e) {
      debugPrint("[WalletProvider] Withdrawal error: $e");
    }
    return false;
  }

  // Fetch Daily Tasks Progress
  Future<void> fetchTasks(String token) async {
    try {
      final res = await http.get(
        Uri.parse("$apiBase/player/tasks"),
        headers: {"Authorization": "Bearer $token"}
      );
      if (res.statusCode == 200) {
        _tasks = List<Map<String, dynamic>>.from(jsonDecode(res.body)['tasks']);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("[WalletProvider] Tasks load error: $e");
    }
  }

  // Claim Daily Task Reward
  Future<bool> claimTaskReward(String token, String taskId) async {
    try {
      final res = await http.post(
        Uri.parse("$apiBase/player/tasks/$taskId/claim"),
        headers: {"Authorization": "Bearer $token"}
      );
      if (res.statusCode == 200) {
        await fetchProfile(token);
        await fetchTasks(token);
        return true;
      }
    } catch (e) {
      debugPrint("[WalletProvider] Claim reward error: $e");
    }
    return false;
  }

  // Report custom task action (e.g. social clicks, reviews)
  Future<bool> reportAction(String token, String actionType) async {
    try {
      final res = await http.post(
        Uri.parse("$apiBase/player/tasks/action"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({"actionType": actionType})
      );
      if (res.statusCode == 200) {
        await fetchTasks(token);
        return true;
      }
    } catch (e) {
      debugPrint("[WalletProvider] Report action error: $e");
    }
    return false;
  }

  // Send periodic online minutes heartbeat tick
  Future<void> sendHeartbeat(String token) async {
    try {
      final res = await http.post(
        Uri.parse("$apiBase/player/tasks/heartbeat"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        }
      );
      if (res.statusCode == 200) {
        await fetchTasks(token);
      }
    } catch (e) {
      debugPrint("[WalletProvider] Heartbeat tick error: $e");
    }
  }

  // Fetch Leaderboard rankings
  Future<void> fetchRankings(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await http.get(
        Uri.parse("$apiBase/player/rankings"),
        headers: {"Authorization": "Bearer $token"}
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _rankings = List<Map<String, dynamic>>.from(data['rankings']);
        _myRankInfo = data['myRank'] != null ? Map<String, dynamic>.from(data['myRank']) : null;
      }
    } catch (e) {
      debugPrint("[WalletProvider] Rankings error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Request Test Refill
  Future<bool> requestTestRefill(String token, double amount, String currency) async {
    try {
      final res = await http.post(
        Uri.parse("$apiBase/player/testing/add-coins"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({"amount": amount, "currency": currency})
      );
      if (res.statusCode == 200) {
        await fetchProfile(token);
        return true;
      }
    } catch (e) {
      debugPrint("[WalletProvider] Test refill error: $e");
    }
    return false;
  }
}
