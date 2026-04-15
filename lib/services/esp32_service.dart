import 'dart:convert';
import 'package:http/http.dart' as http;

class SensorData {
  final double temperature;
  final double humidity;
  final bool isOnline;
  final DateTime lastUpdated;

  SensorData({
    required this.temperature,
    required this.humidity,
    required this.isOnline,
    required this.lastUpdated,
  });

  factory SensorData.offline() {
    return SensorData(
      temperature: 0,
      humidity: 0,
      isOnline: false,
      lastUpdated: DateTime.now(),
    );
  }

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      isOnline: true,
      lastUpdated: DateTime.now(),
    );
  }
}

class Esp32Service {
  // Change this to your ESP32's IP address
  static const String _baseUrl = 'http://192.168.1.100';
  static const Duration _timeout = Duration(seconds: 5);

  Future<SensorData> fetchSensorData() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/data'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return SensorData.fromJson(json);
      }
      return SensorData.offline();
    } catch (_) {
      return SensorData.offline();
    }
  }
}
