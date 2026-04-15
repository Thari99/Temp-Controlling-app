class SensorData {
  final double temperatureC;
  final double temperatureF;
  final double humidity;
  final String device;
  final String deviceStatus;
  final bool isOnline;
  final DateTime lastUpdated;

  SensorData({
    required this.temperatureC,
    required this.temperatureF,
    required this.humidity,
    required this.device,
    required this.deviceStatus,
    required this.isOnline,
    required this.lastUpdated,
  });

  factory SensorData.offline() => SensorData(
        temperatureC: 0,
        temperatureF: 0,
        humidity: 0,
        device: 'esp32-dht11',
        deviceStatus: 'offline',
        isOnline: false,
        lastUpdated: DateTime.now(),
      );

  factory SensorData.fromJson(Map<String, dynamic> json) => SensorData(
        temperatureC: (json['temperature_c'] as num).toDouble(),
        temperatureF: (json['temperature_f'] as num).toDouble(),
        humidity: (json['humidity'] as num).toDouble(),
        device: json['device'] as String? ?? 'esp32-dht11',
        deviceStatus: json['status'] as String? ?? 'ok',
        isOnline: true,
        lastUpdated: DateTime.now(),
      );
}
