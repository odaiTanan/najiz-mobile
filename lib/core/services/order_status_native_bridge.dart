import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef OrderStatusNativeHandler = Future<void> Function(
  Map<String, dynamic> payload, {
  String? title,
  String? body,
});

/// Receives order_status payloads from Android when the app process is alive.
class OrderStatusNativeBridge {
  OrderStatusNativeBridge._();

  static const MethodChannel _channel =
      MethodChannel('com.najizgo.app/order_status');

  static OrderStatusNativeHandler? _handler;

  static void register(OrderStatusNativeHandler handler) {
    _handler = handler;
    if (kIsWeb) return;
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static Future<void> _onMethodCall(MethodCall call) async {
    if (call.method != 'onOrderStatusReceived') return;
    final handler = _handler;
    if (handler == null) return;

    final args = call.arguments;
    if (args is! Map) return;

    final payload = args.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await handler(
      Map<String, dynamic>.from(payload),
      title: payload['title']?.toString(),
      body: payload['body']?.toString(),
    );
  }
}
