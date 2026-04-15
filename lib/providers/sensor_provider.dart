import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/sensor_data.dart';
import '../services/mqtt_service.dart';

class SensorProvider extends ChangeNotifier {
  final MqttService _mqtt = MqttService();

  SensorData _data = SensorData.offline();
  bool _mqttConnected = false;
  bool _connecting = true;

  SensorData get data => _data;
  bool get mqttConnected => _mqttConnected;
  bool get connecting => _connecting;

  StreamSubscription<SensorData>? _dataSub;
  StreamSubscription<bool>? _connSub;

  Future<void> startPolling() async {
    _connecting = true;
    _data = SensorData.offline();
    notifyListeners();

    await _dataSub?.cancel();
    await _connSub?.cancel();

    _connSub = _mqtt.onConnectionChange.listen((connected) {
      _mqttConnected = connected;
      if (!connected) _data = SensorData.offline();
      _connecting = false;
      notifyListeners();
    });

    _dataSub = _mqtt.onData.listen((sensorData) {
      _data = sensorData;
      _mqttConnected = true;
      _connecting = false;
      notifyListeners();
    });

    final connected = await _mqtt.connect();
    if (!connected) {
      _mqttConnected = false;
      _connecting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _connSub?.cancel();
    _mqtt.disconnect();
    super.dispose();
  }
}
