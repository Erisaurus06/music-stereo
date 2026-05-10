import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkRadar {
  static final ValueNotifier<bool> isOnline = ValueNotifier(true);

  static Future<void> init() async {
    final List<ConnectivityResult> result = await Connectivity()
        .checkConnectivity();
    _updateStatus(result);
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> res) {
      _updateStatus(res);
    });
  }

  static void _updateStatus(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.none)) {
      isOnline.value = false;
      debugPrint("🚫 RADAR: MODO OFFLINE ACTIVADO");
    } else {
      isOnline.value = true;
      debugPrint("🌐 RADAR: CONEXIÓN ESTABLECIDA");
    }
  }
}
