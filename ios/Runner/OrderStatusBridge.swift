import Flutter
import UIKit

/// iOS counterpart of Android's OrderStatusBridge / MainActivity integration.
/// Attaches a FlutterMethodChannel so that native code (e.g. a future iOS
/// extension) can invoke "onOrderStatusReceived" on the Dart side while the
/// app process is alive — mirroring the Android MethodChannel bridge.
final class OrderStatusBridge {
  static let shared = OrderStatusBridge()

  private let channelName = "com.najizgo.app/order_status"
  private var channel: FlutterMethodChannel?

  private init() {}

  func attach(controller: FlutterViewController) {
    channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.binaryMessenger
    )
  }

  /// Forwards an order-status payload to the Dart layer.
  /// Returns true when a channel is available (app process alive), false otherwise.
  @discardableResult
  func tryInvokeFlutter(_ payload: [String: Any]) -> Bool {
    guard let channel = channel else { return false }
    DispatchQueue.main.async {
      channel.invokeMethod("onOrderStatusReceived", arguments: payload)
    }
    return true
  }
}
