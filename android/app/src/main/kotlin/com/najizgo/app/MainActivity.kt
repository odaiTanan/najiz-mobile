package com.najizgo.app

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        OrderStatusBridge.attach(flutterEngine)
    }
}

object OrderStatusBridge {
    private const val CHANNEL = "com.najizgo.app/order_status"
    private var channel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
    }

    fun tryInvokeFlutter(payload: Map<String, Any?>): Boolean {
        val activeChannel = channel ?: return false
        mainHandler.post {
            try {
                activeChannel.invokeMethod("onOrderStatusReceived", payload)
            } catch (_: Exception) {
                // Flutter may not be ready yet; native fallback handles display.
            }
        }
        return true
    }
}
