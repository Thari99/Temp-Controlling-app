import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/sensor_data.dart';

/// Custom MQTT 3.1.1 client over WebSocket Secure.
/// Mirrors the working JavaScript implementation exactly:
///   mqtt.connect("wss://HOST:8884/mqtt", { username, password,
///     protocolVersion:4, clean:true, keepalive:60 })
class MqttService {
  static const _url =
      'wss://6e4b5c50425d4e0eadef818304c3f7cb.s1.eu.hivemq.cloud:8884/mqtt';
  static const _username = 'Rajitha';
  static const _password = 'Rajitha@Rise25';
  static const _topicData = 'esp32/dht11/data';
  static const _topicStatus = 'esp32/dht11/status';

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;
  Completer<bool>? _connCompleter;

  final _dataController = StreamController<SensorData>.broadcast();
  final _connController = StreamController<bool>.broadcast();

  Stream<SensorData> get onData => _dataController.stream;
  Stream<bool> get onConnectionChange => _connController.stream;
  bool get isConnected => _connected;

  Future<bool> connect() async {
    // Clean up any previous connection
    try { _channel?.sink.close(); } catch (_) {}
    await _sub?.cancel();
    _connected = false;
    _connCompleter = Completer<bool>();

    final clientId = 'et${DateTime.now().millisecondsSinceEpoch % 99999}';
    print('[MQTT] Connecting id=$clientId url=$_url');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(_url),
        protocols: ['mqtt'], // Sec-WebSocket-Protocol: mqtt — required by HiveMQ
      );

      // Wait for WebSocket handshake to complete
      await _channel!.ready;
      print('[MQTT] WebSocket connected. Sending CONNECT packet...');
    } catch (e) {
      print('[MQTT] WebSocket connection failed: $e');
      return false;
    }

    // Start listening BEFORE sending CONNECT (to catch CONNACK)
    _sub = _channel!.stream.listen(
      _onData,
      onError: (e) {
        print('[MQTT] Stream error: $e');
        _setDisconnected();
        if (_connCompleter?.isCompleted == false) _connCompleter?.complete(false);
      },
      onDone: () {
        print('[MQTT] Stream closed');
        _setDisconnected();
      },
      cancelOnError: false,
    );

    // Send MQTT CONNECT packet
    _channel!.sink.add(_buildConnect(clientId));

    // Wait for CONNACK (10 second timeout)
    final result = await _connCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        print('[MQTT] Timeout waiting for CONNACK');
        return false;
      },
    );

    return result;
  }

  void _onData(dynamic raw) {
    Uint8List bytes;
    if (raw is Uint8List) {
      bytes = raw;
    } else if (raw is List<int>) {
      bytes = Uint8List.fromList(raw);
    } else {
      print('[MQTT] Unexpected data type: ${raw.runtimeType}');
      return;
    }

    if (bytes.isEmpty) return;
    final type = (bytes[0] >> 4) & 0x0F;
    print('[MQTT] Frame: type=$type len=${bytes.length} hex=${bytes.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    switch (type) {
      case 2:  _handleConnack(bytes); break;
      case 3:  _handlePublish(bytes); break;
      case 9:  print('[MQTT] SUBACK'); break;
      case 12: _sendPingresp(); break;
      case 13: print('[MQTT] PINGRESP'); break;
      default: print('[MQTT] Unhandled packet type $type');
    }
  }

  void _handleConnack(Uint8List data) {
    // CONNACK: 0x20, 0x02, sessionPresent, returnCode
    if (data.length < 4) return;
    final returnCode = data[3];
    print('[MQTT] CONNACK returnCode=$returnCode');
    if (returnCode == 0) {
      _connected = true;
      _connController.add(true);
      _subscribe(_topicData, 1);
      _subscribe(_topicStatus, 2);
      print('[MQTT] Connected and subscribed');
      _connCompleter?.complete(true);
    } else {
      final reason = _connackReason(returnCode);
      print('[MQTT] Connection refused: $reason');
      _connCompleter?.complete(false);
    }
  }

  void _handlePublish(Uint8List data) {
    final flags = data[0] & 0x0F;

    // Decode remaining length
    int multiplier = 1, remainingLength = 0, lenBytes = 0;
    for (int i = 1; i < data.length && lenBytes < 4; i++) {
      remainingLength += (data[i] & 0x7F) * multiplier;
      lenBytes++;
      multiplier *= 128;
      if ((data[i] & 0x80) == 0) break;
    }

    int offset = 1 + lenBytes;
    if (offset + 2 > data.length) return;

    final topicLen = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    if (offset + topicLen > data.length) return;

    final topic = utf8.decode(data.sublist(offset, offset + topicLen));
    offset += topicLen;

    final qos = (flags >> 1) & 0x03;
    if (qos > 0 && offset + 2 <= data.length) offset += 2; // skip packet ID

    final endOffset = (1 + lenBytes + remainingLength).clamp(offset, data.length);
    final payload = utf8.decode(data.sublist(offset, endOffset),
        allowMalformed: true);

    print('[MQTT] PUBLISH topic=$topic payload=$payload');

    if (topic == _topicData) {
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        _dataController.add(SensorData.fromJson(json));
      } catch (e) {
        print('[MQTT] JSON parse error: $e');
      }
    }
    // esp32/dht11/status topic sends plain text — no JSON parsing needed
  }

  void _subscribe(String topic, int packetId) {
    print('[MQTT] SUBSCRIBE $topic');
    _channel?.sink.add(_buildSubscribe(topic, packetId));
  }

  void _sendPingresp() {
    print('[MQTT] Sending PINGRESP');
    _channel?.sink.add(Uint8List.fromList([0xD0, 0x00]));
  }

  void _setDisconnected() {
    if (_connected) {
      _connected = false;
      if (!_connController.isClosed) _connController.add(false);
    }
  }

  // ─── Packet builders ────────────────────────────────────────────────────────

  /// MQTT 3.1.1 CONNECT packet
  /// Connect flags = 0xC2 = 1100 0010
  ///   bit7: username=1, bit6: password=1, bit5: willRetain=0,
  ///   bit4-3: willQoS=00, bit2: willFlag=0, bit1: cleanSession=1, bit0: 0
  Uint8List _buildConnect(String clientId) {
    final body = BytesBuilder();
    _writeStr(body, 'MQTT'); // Protocol Name
    body.addByte(0x04);      // Protocol Level — MQTT 3.1.1
    body.addByte(0xC2);      // Connect Flags: username + password + clean
    body.addByte(0x00);      // Keep Alive MSB
    body.addByte(0x3C);      // Keep Alive LSB = 60s
    _writeStr(body, clientId);
    _writeStr(body, _username);
    _writeStr(body, _password);

    final bodyBytes = body.toBytes();
    final pkt = BytesBuilder();
    pkt.addByte(0x10); // CONNECT fixed header
    _writeVarLen(pkt, bodyBytes.length);
    pkt.add(bodyBytes);
    return pkt.toBytes();
  }

  /// MQTT SUBSCRIBE packet
  Uint8List _buildSubscribe(String topic, int packetId) {
    final body = BytesBuilder();
    body.addByte(packetId >> 8);
    body.addByte(packetId & 0xFF);
    _writeStr(body, topic);
    body.addByte(0x00); // QoS 0

    final bodyBytes = body.toBytes();
    final pkt = BytesBuilder();
    pkt.addByte(0x82); // SUBSCRIBE fixed header
    _writeVarLen(pkt, bodyBytes.length);
    pkt.add(bodyBytes);
    return pkt.toBytes();
  }

  /// Write UTF-8 string with 2-byte length prefix
  void _writeStr(BytesBuilder buf, String s) {
    final bytes = utf8.encode(s);
    buf.addByte(bytes.length >> 8);
    buf.addByte(bytes.length & 0xFF);
    buf.add(bytes);
  }

  /// Write MQTT variable-length remaining length
  void _writeVarLen(BytesBuilder buf, int len) {
    do {
      int b = len % 128;
      len ~/= 128;
      if (len > 0) b |= 0x80;
      buf.addByte(b);
    } while (len > 0);
  }

  String _connackReason(int code) {
    switch (code) {
      case 1: return 'Unacceptable protocol version';
      case 2: return 'Identifier rejected';
      case 3: return 'Server unavailable';
      case 4: return 'Bad username or password';
      case 5: return 'Not authorized';
      default: return 'Unknown ($code)';
    }
  }

  void disconnect() {
    _setDisconnected();
    try { _channel?.sink.close(); } catch (_) {}
    _sub?.cancel();
    if (!_dataController.isClosed) _dataController.close();
    if (!_connController.isClosed) _connController.close();
  }
}
