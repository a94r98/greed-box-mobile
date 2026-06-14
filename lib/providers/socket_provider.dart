import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config.dart';

class SocketProvider extends ChangeNotifier {
  String get socketUrl => AppConfig.baseUrl;
  io.Socket? _socket;
  bool _isConnected = false;

  // Callbacks registered by external listeners
  Function(dynamic)? onWalletUpdate;
  Function(dynamic)? onKickOut;

  io.Socket? get socket => _socket;
  bool get isConnected => _isConnected;

  void connect(String token) {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }

    _socket = io.io(socketUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .enableAutoConnect()
      .setReconnectionDelay(1000)
      .setReconnectionDelayMax(5000)
      .build()
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      notifyListeners();
      debugPrint("[WebSocket] Connected successfully to game engine.");
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      notifyListeners();
      debugPrint("[WebSocket] Disconnected from game engine.");
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      notifyListeners();
      debugPrint("[WebSocket] Connect error: $err");
    });

    // Register wallet_update listener directly on socket creation
    _socket!.off("wallet_update");
    _socket!.on("wallet_update", (data) {
      debugPrint("[WebSocket] wallet_update received: $data");
      onWalletUpdate?.call(data);
    });

    // Register kick_out listener directly on socket creation
    // This fires BEFORE the disconnect event, so we can act immediately
    _socket!.off("kick_out");
    _socket!.on("kick_out", (data) {
      debugPrint("[WebSocket] kick_out received: $data");
      onKickOut?.call(data);
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
