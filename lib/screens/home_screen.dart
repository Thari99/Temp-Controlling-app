import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  bool _showCelsius = true;

  static const _bg = Color(0xFF0C0D11);
  static const _surface = Color(0xFF13151C);
  static const _border = Color(0xFF1E2028);
  static const _textPrimary = Color(0xFFE8EAF0);
  static const _textSecondary = Color(0xFF6B7080);
  static const _tempColor = Color(0xFFE8864A);
  static const _humidColor = Color(0xFF4A8EE8);
  static const _onlineColor = Color(0xFF3DD68C);
  static const _offlineColor = Color(0xFFE85555);
  static const _mqttColor = Color(0xFF9B6DFF);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _fadeAnims = List.generate(4, (i) {
      final start = (i * 0.15).clamp(0.0, 0.6);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entryController,
          curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
              curve: Curves.easeOut),
        ),
      );
    });

    _slideAnims = List.generate(4, (i) {
      final start = (i * 0.15).clamp(0.0, 0.6);
      return Tween<Offset>(
              begin: const Offset(0, 0.1), end: Offset.zero)
          .animate(
        CurvedAnimation(
          parent: _entryController,
          curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic),
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SensorProvider>().startPolling();
      _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => FadeTransition(
        opacity: _fadeAnims[i],
        child: SlideTransition(position: _slideAnims[i], child: child),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Consumer<SensorProvider>(
          builder: (context, provider, _) {
            final data = provider.data;
            return Column(
              children: [
                _buildHeader(provider),
                Container(height: 1, color: _border),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _animated(0, _buildStatusPanel(provider)),
                        const SizedBox(height: 28),
                        _animated(1,
                            _buildSectionLabel('LIVE READINGS', data.isOnline)),
                        const SizedBox(height: 14),
                        _animated(
                          2,
                          _buildTemperatureCard(data, provider.connecting),
                        ),
                        const SizedBox(height: 12),
                        _animated(
                          3,
                          _buildMetricCard(
                            title: 'HUMIDITY',
                            rawValue:
                                data.isOnline ? data.humidity : null,
                            unit: '%',
                            color: _humidColor,
                            icon: Icons.water_drop_outlined,
                            min: 0,
                            max: 100,
                            statusLabel: data.isOnline
                                ? _humidStatus(data.humidity)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildFooter(provider.mqttConnected),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(SensorProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/RISI_Logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EnviroTrack',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'ESP32 · DHT11 Sensor',
                style: GoogleFonts.inter(
                    fontSize: 11, color: _textSecondary),
              ),
            ],
          ),
          const Spacer(),
          if (provider.connecting)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _mqttColor,
              ),
            )
          else
            GestureDetector(
              onTap: () => provider.startPolling(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.refresh_rounded,
                    color: _textSecondary, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel(SensorProvider provider) {
    final data = provider.data;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // Row 1: Device online/offline
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                _buildDot(data.isOnline, _pulseController),
                const SizedBox(width: 10),
                Text(
                  data.isOnline ? 'Device Online' : 'Device Offline',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: data.isOnline ? _onlineColor : _offlineColor,
                  ),
                ),
                const Spacer(),
                _buildBadge(
                  data.isOnline ? 'Active' : 'No Data',
                  data.isOnline ? _onlineColor : _offlineColor,
                ),
              ],
            ),
          ),
          Container(height: 1, color: _border),
          // Row 2: MQTT broker status
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: provider.mqttConnected
                        ? _mqttColor
                        : _offlineColor,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'MQTT Broker',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                Text(
                  '·',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: _textSecondary),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'HiveMQ Cloud',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: _textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildBadge(
                  provider.mqttConnected ? 'Connected' : 'Disconnected',
                  provider.mqttConnected ? _mqttColor : _offlineColor,
                ),
              ],
            ),
          ),
          Container(height: 1, color: _border),
          // Row 3: Metadata
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: Row(
              children: [
                _buildInfoChip(
                  Icons.memory_outlined,
                  'Device',
                  data.isOnline ? data.device : '—',
                ),
                const SizedBox(width: 20),
                _buildInfoChip(
                  Icons.access_time_outlined,
                  'Updated',
                  data.isOnline ? _formatTime(data.lastUpdated) : '—',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isOnline, AnimationController pulse) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final p = pulse.value;
        return SizedBox(
          width: 22,
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isOnline)
                Container(
                  width: 18 * (0.6 + p * 0.4),
                  height: 18 * (0.6 + p * 0.4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _onlineColor
                        .withValues(alpha: 0.15 * (1 - p)),
                  ),
                ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? _onlineColor : _offlineColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: _textSecondary),
        const SizedBox(width: 5),
        Text(
          '$label · ',
          style: GoogleFonts.inter(fontSize: 11, color: _textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: _textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text, bool isOnline) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: _border)),
        if (isOnline) ...[
          const SizedBox(width: 10),
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: _onlineColor)),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _onlineColor,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTemperatureCard(dynamic data, bool connecting) {
    final hasValue = data.isOnline;
    final value = hasValue
        ? (_showCelsius ? data.temperatureC : data.temperatureF)
        : null;
    final displayValue =
        value != null ? value.toStringAsFixed(1) : '—';
    final unit = _showCelsius ? '°C' : '°F';
    final progress = hasValue
        ? ((_showCelsius
                    ? data.temperatureC.clamp(0.0, 50.0) / 50.0
                    : (data.temperatureF - 32).clamp(0.0, 90.0) / 90.0)
                as double)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: hasValue ? _tempColor : _border,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.thermostat_outlined,
                          size: 15,
                          color:
                              hasValue ? _tempColor : _textSecondary),
                      const SizedBox(width: 7),
                      Text(
                        'TEMPERATURE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      // °C / °F toggle
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showCelsius = !_showCelsius),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _bg,
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            children: [
                              _unitTab('°C', _showCelsius),
                              const SizedBox(width: 2),
                              Text('/',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: _textSecondary)),
                              const SizedBox(width: 2),
                              _unitTab('°F', !_showCelsius),
                            ],
                          ),
                        ),
                      ),
                      if (hasValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _tempColor.withValues(alpha: 0.1),
                          ),
                          child: Text(
                            _tempStatus(data.temperatureC),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _tempColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        displayValue,
                        style: GoogleFonts.inter(
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                          color:
                              hasValue ? _textPrimary : _textSecondary,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                      if (hasValue) ...[
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            unit,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              color: _textSecondary,
                              height: 1,
                            ),
                          ),
                        ),
                        if (!_showCelsius) ...[
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${data.temperatureC.toStringAsFixed(1)}°C',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _textSecondary,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTrack(progress, _tempColor, hasValue),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_showCelsius ? '0°C' : '32°F',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: _textSecondary)),
                      Text(_showCelsius ? '50°C' : '122°F',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: _textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitTab(String label, bool active) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        color: active ? _textPrimary : _textSecondary,
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double? rawValue,
    required String unit,
    required Color color,
    required IconData icon,
    required double min,
    required double max,
    required String? statusLabel,
  }) {
    final hasValue = rawValue != null;
    final progress = hasValue
        ? ((rawValue - min) / (max - min)).clamp(0.0, 1.0)
        : 0.0;
    final displayValue =
        hasValue ? rawValue.toStringAsFixed(1) : '—';

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                  width: 3, color: hasValue ? color : _border),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon,
                          size: 15,
                          color:
                              hasValue ? color : _textSecondary),
                      const SizedBox(width: 7),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      if (statusLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: color.withValues(alpha: 0.1),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        displayValue,
                        style: GoogleFonts.inter(
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                          color: hasValue
                              ? _textPrimary
                              : _textSecondary,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                      if (hasValue) ...[
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            unit,
                            style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w400,
                                color: _textSecondary,
                                height: 1),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTrack(progress, color, hasValue),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${min.toInt()}$unit',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: _textSecondary)),
                      Text('${max.toInt()}$unit',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: _textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrack(double progress, Color color, bool active) {
    return Stack(
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _border,
          ),
        ),
        FractionallySizedBox(
          widthFactor: progress,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: active ? color : _textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool mqttConnected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: mqttConnected
                ? _mqttColor.withValues(alpha: 0.7)
                : _textSecondary.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          mqttConnected
              ? 'MQTT · Live push updates'
              : 'MQTT · Disconnected',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: mqttConnected
                ? _textSecondary.withValues(alpha: 0.7)
                : _textSecondary.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  String _tempStatus(double t) {
    if (t < 15) return 'Too Cold';
    if (t < 22) return 'Cool';
    if (t < 28) return 'Optimal';
    if (t < 35) return 'Warm';
    return 'Too Hot';
  }

  String _humidStatus(double h) {
    if (h < 40) return 'Too Dry';
    if (h < 60) return 'Comfortable';
    if (h < 80) return 'Optimal';
    return 'Too Humid';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
