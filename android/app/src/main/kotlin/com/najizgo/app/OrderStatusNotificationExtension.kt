package com.najizgo.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.BitmapFactory
import android.os.Build
import androidx.annotation.Keep
import androidx.core.app.NotificationCompat
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension
import org.json.JSONObject
import java.io.File

@Keep
class OrderStatusNotificationExtension : INotificationServiceExtension {
    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val additional = event.notification.additionalData
        val payload = buildPayload(event, additional) ?: return
        if (payload["type"]?.toString() != "order_status") return

        val orderType = payload["order_type"]?.toString()?.lowercase().orEmpty()
        val pushBody = event.notification.body?.trim().takeUnless { it.isNullOrEmpty() }.orEmpty()
        var body = payload["body"]?.toString()?.trim().takeUnless { it.isNullOrEmpty() }
            ?: pushBody

        if (orderType == "taxi") {
            val taxiStatus = resolveTaxiNotificationStatus(payload, body)
            if (!ALLOWED_TAXI_STATUSES.contains(taxiStatus)) return
            payload["status"] = taxiStatus
            body = taxiStatusBody(taxiStatus)
        }

        event.preventDefault()

        val title = payload["title"]?.toString()?.trim().takeUnless { it.isNullOrEmpty() }
            ?: event.notification.title?.trim().takeUnless { it.isNullOrEmpty() }
            ?: "NajizGo"
        payload["title"] = title
        payload["body"] = body

        if (OrderStatusBridge.tryInvokeFlutter(payload)) {
            return
        }

        showCachedFallback(event.context, payload, title, body)
    }

    private fun buildPayload(
        event: INotificationReceivedEvent,
        additional: org.json.JSONObject?,
    ): MutableMap<String, Any?>? {
        if (additional == null) return null

        val payload = mutableMapOf<String, Any?>()
        val keys = additional.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            payload[key] = additional.opt(key)
        }

        val nestedData = additional.optJSONObject("data")
        if (nestedData != null) {
            val nestedKeys = nestedData.keys()
            while (nestedKeys.hasNext()) {
                val key = nestedKeys.next()
                payload.putIfAbsent(key, nestedData.opt(key))
            }
        }

        payload.putIfAbsent("title", event.notification.title)
        payload.putIfAbsent("body", event.notification.body)
        return payload
    }

    private fun showCachedFallback(
        context: Context,
        payload: Map<String, Any?>,
        title: String,
        body: String,
    ) {
        val orderId = payload["order_id"]?.toString()?.toIntOrNull() ?: return
        val channelId = "orders_progress_channel"
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "تتبع الطلبات",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.enableVibration(false)
            channel.enableLights(false)
            channel.setSound(null, null)
            manager.createNotificationChannel(channel)
        }

        val cacheDir = File(context.cacheDir, "order_notif")
        val metaFile = File(cacheDir, "$orderId.json")
        var step = 0
        var stepTotal = defaultStepTotal(payload)
        var isFinished = false
        var resolvedTitle = title
        var resolvedBody = body
        if (metaFile.exists()) {
            try {
                val meta = JSONObject(metaFile.readText())
                step = meta.optInt("step", 0)
                stepTotal = meta.optInt("step_total", stepTotal).coerceAtLeast(1)
                isFinished = meta.optBoolean("is_finished", false)
                resolvedTitle = meta.optString("title", title)
                resolvedBody = meta.optString("body", body)
            } catch (_: Exception) {
            }
        } else {
            val progress = resolveProgressFromPayload(payload)
            step = progress.first
            stepTotal = progress.second
            isFinished = progress.third
        }

        val notificationId = payload["android_notification_id"]?.toString()?.toIntOrNull()
            ?: orderId
        val groupKey = payload["android_group"]?.toString()?.trim().takeUnless { it.isNullOrEmpty() }
            ?: "order_updates"

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(resolvedTitle)
            .setContentText(resolvedBody)
            .setOnlyAlertOnce(true)
            .setOngoing(!isFinished)
            .setAutoCancel(isFinished)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setColor(0xFFFF9800.toInt())
            .setGroup(groupKey)
            .setProgress(
                stepTotal,
                if (isFinished) stepTotal else step.coerceIn(0, stepTotal),
                false,
            )

        val pngFile = File(cacheDir, "$orderId.png")
        if (pngFile.exists()) {
            val bitmap = BitmapFactory.decodeFile(pngFile.absolutePath)
            if (bitmap != null) {
                builder.setStyle(
                    NotificationCompat.BigPictureStyle()
                        .bigPicture(bitmap)
                        .setSummaryText(resolvedTitle),
                )
                builder.setLargeIcon(bitmap)
            }
        }

        manager.notify(notificationId and 0x7fffffff, builder.build())
    }

    private fun defaultStepTotal(payload: Map<String, Any?>): Int {
        val serviceName = payload["service_name"]?.toString()?.lowercase().orEmpty()
        val isStore = serviceName == "store" || serviceName == "stores" || serviceName == "stores"
        return when (payload["order_type"]?.toString()?.lowercase()) {
            "taxi" -> 5
            "shipping" -> 5
            else -> if (isStore) 4 else 5
        }
    }

    private fun resolveProgressFromPayload(payload: Map<String, Any?>): Triple<Int, Int, Boolean> {
        val orderType = payload["order_type"]?.toString()?.lowercase().orEmpty()
        if (orderType == "taxi") {
            val status = resolveTaxiNotificationStatus(
                payload,
                payload["body"]?.toString(),
            )
            if (!ALLOWED_TAXI_STATUSES.contains(status)) {
                return Triple(0, 5, false)
            }
            val step = mapTaxi(status)
            val isFinished = status == "delivered" ||
                status == "cancelled" ||
                status == "canceled"
            return Triple(step, 5, isFinished)
        }

        val serviceName = payload["service_name"]?.toString()?.lowercase().orEmpty()
        val status = normalizeStatus(payload["status"]?.toString())
        val dispatch = normalizeStatus(payload["dispatch_status"]?.toString())
        val effective = resolveEffectiveStatus(status, dispatch)
        val stepTotal = defaultStepTotal(payload)
        val step = mapStatusToStep(
            status = effective,
            stepTotal = stepTotal,
            orderType = orderType,
            isStore = serviceName == "store",
        )
        val isFinished = effective in TERMINAL_STATUSES
        return Triple(step, stepTotal, isFinished)
    }

    private fun resolveEffectiveStatus(status: String, dispatch: String): String {
        if (status in ARRIVAL_HINTS) return status
        if (dispatch in ARRIVAL_HINTS) return dispatch
        if (status.isNotEmpty()) return status
        return dispatch
    }

    private fun normalizeStatus(raw: String?): String {
        if (raw.isNullOrBlank()) return ""
        return raw.trim().lowercase().replace('-', '_').replace(' ', '_')
    }

    private fun mapStatusToStep(
        status: String,
        stepTotal: Int,
        orderType: String,
        isStore: Boolean,
    ): Int {
        val max = if (stepTotal <= 0) 5 else stepTotal
        return when (orderType) {
            "taxi" -> mapTaxi(status)
            "shipping" -> mapShipping(status, max)
            else -> mapFood(status, max, isStore)
        }.coerceIn(0, max)
    }

    private fun mapFood(status: String, max: Int, isStore: Boolean): Int {
        if (isStore) {
            return when (status) {
                "pending", "no_driver" -> 0
                "accepted", "assigned", "preparing" -> 1
                "ready", "on_the_way_to_pickup", "picked_up" -> 2
                "on_way" -> 3
                "arrived", "waiting", "arrived_waiting", "driver_arrived",
                "at_destination", "at_pickup", "waiting_at_destination", "waiting_at_pickup",
                -> 3
                "delivered", "completed", "cancelled", "canceled" -> max
                else -> 1
            }
        }

        return when (status) {
            "pending", "no_driver" -> 0
            "accepted", "assigned" -> 1
            "preparing", "ready" -> 2
            "on_the_way_to_pickup" -> 3
            "picked_up" -> 3
            "on_way" -> if (max > 4) 4 else (max - 1).coerceAtLeast(1)
            "arrived", "waiting", "arrived_waiting", "driver_arrived",
            "at_destination", "at_pickup", "waiting_at_destination", "waiting_at_pickup",
            -> if (max > 4) 4 else (max - 1).coerceAtLeast(1)
            "delivered", "completed", "cancelled", "canceled" -> max
            else -> 1
        }
    }

    private fun mapShipping(status: String, max: Int): Int = when (status) {
        "pending", "no_driver" -> 0
        "accepted", "assigned", "preparing" -> 1
        "on_the_way_to_pickup" -> 2
        "picked_up" -> 3
        "on_way" -> 4
        "arrived", "waiting", "arrived_waiting", "driver_arrived",
        "at_destination", "at_pickup", "waiting_at_destination", "waiting_at_pickup",
        -> 4
        "delivered", "completed", "cancelled", "canceled" -> max
        else -> 1
    }

    private fun mapTaxi(status: String): Int = when (status) {
        "pending" -> 0
        "accepted" -> 1
        "on_the_way_to_pickup" -> 2
        "on_way" -> 3
        "delivered" -> 4
        "cancelled", "canceled" -> 4
        else -> 1
    }

    private fun resolveStatusForMessage(status: String?, dispatchStatus: String?): String {
        val normalizedStatus = normalizeStatus(status).takeIf { it.isNotEmpty() }
        val normalizedDispatch = normalizeStatus(dispatchStatus).takeIf { it.isNotEmpty() }

        if (normalizedStatus != null && normalizedStatus in STATUS_MESSAGE_ARRIVAL_HINTS) {
            return normalizedStatus
        }
        if (normalizedDispatch != null && normalizedDispatch in STATUS_MESSAGE_ARRIVAL_HINTS) {
            return normalizedDispatch
        }
        return normalizedStatus ?: normalizedDispatch ?: ""
    }

    private fun inferStatusFromBackendMessage(body: String?): String? {
        val text = body?.trim().orEmpty()
        if (text.isEmpty()) return null
        BACKEND_TAXI_MESSAGES.entries.firstOrNull { it.value == text }?.key?.let { return it }
        LEGACY_TAXI_MESSAGE_TO_STATUS[text]?.let { return it }
        return null
    }

    private fun resolveTaxiNotificationStatus(payload: Map<String, Any?>, body: String?): String {
        inferStatusFromBackendMessage(body)?.let { inferred ->
            if (ALLOWED_TAXI_STATUSES.contains(inferred)) return inferred
        }
        return resolveStatusForMessage(
            payload["status"]?.toString(),
            payload["dispatch_status"]?.toString()
                ?: payload["driver_status"]?.toString(),
        )
    }

    private fun taxiStatusBody(statusRaw: String?): String = when (statusRaw) {
        "pending" -> "تم استلام طلبك وهو قيد المراجعة"
        "accepted" -> "تم قبول الطلب"
        "on_the_way_to_pickup" -> "تم قبول الطلب والسائق متجه إليك"
        "on_way" -> "بدأت الرحلة"
        "delivered" -> "تم التوصيل"
        "cancelled", "canceled" -> "تم إلغاء الطلب"
        else -> "تم تحديث حالة طلبك"
    }

    companion object {
        private val LEGACY_TAXI_MESSAGE_TO_STATUS = mapOf(
            "السائق في الطريق إليك" to "on_the_way_to_pickup",
            "السائق متجه للاستلام" to "on_the_way_to_pickup",
        )

        private val BACKEND_TAXI_MESSAGES = mapOf(
            "pending" to "تم استلام طلبك وهو قيد المراجعة",
            "accepted" to "تم قبول الطلب",
            "on_the_way_to_pickup" to "تم قبول الطلب والسائق متجه إليك",
            "on_way" to "بدأت الرحلة",
            "delivered" to "تم التوصيل",
            "cancelled" to "تم إلغاء الطلب",
        )

        private val STATUS_MESSAGE_ARRIVAL_HINTS = setOf(
            "arrived",
            "waiting",
            "arrived_waiting",
            "driver_arrived",
            "at_destination",
            "at_pickup",
            "waiting_at_destination",
            "waiting_at_pickup",
            "picked_up",
            "preparing",
        )

        private val ALLOWED_TAXI_STATUSES = setOf(
            "pending",
            "accepted",
            "on_the_way_to_pickup",
            "on_way",
            "delivered",
            "cancelled",
            "canceled",
        )

        private val ARRIVAL_HINTS = setOf(
            "arrived",
            "waiting",
            "arrived_waiting",
            "driver_arrived",
            "at_destination",
            "at_pickup",
            "waiting_at_destination",
            "waiting_at_pickup",
        )

        private val TERMINAL_STATUSES = setOf(
            "delivered",
            "completed",
            "cancelled",
            "canceled",
        )
    }
}
