package com.qrpedidos.qr_scanner_bridge

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.qrpedidos.sdk.QrScanner
import com.qrpedidos.sdk.ScanCallback
import com.qrpedidos.sdk.ScanErrorCode
import com.qrpedidos.sdk.ScanResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Puente Flutter <-> SDK nativo de lectura QR.
 * Contrato: docs/CONTRATO_SCANNER.md (canal, métodos y códigos).
 *
 * Todo el estado mutable (`pending`, `activity`) se toca solo en el hilo principal.
 */
class QrScannerBridgePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Llamada `scanProduct` en vuelo de este puente. */
    private var pending: PendingCall? = null

    /** Envuelve un [Result] garantizando que se responda exactamente una vez. */
    private class PendingCall(private val result: Result) {
        private var done = false

        fun success(value: Any?) {
            if (done) return
            done = true
            result.success(value)
        }

        fun error(code: String, message: String?) {
            if (done) return
            done = true
            result.error(code, message, null)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "scanProduct" -> scanProduct(result)
            "cancelScan" -> cancelScan(result)
            else -> result.notImplemented()
        }
    }

    private fun scanProduct(result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                ScanErrorCode.CAMERA_UNAVAILABLE.code,
                "No hay una actividad disponible para abrir el escáner.",
                null,
            )
            return
        }
        if (pending != null) {
            // Se rechaza solo la llamada nueva; la pendiente no se toca.
            result.error(
                ScanErrorCode.SCAN_IN_PROGRESS.code,
                "Ya hay un escaneo en curso.",
                null,
            )
            return
        }

        val call = PendingCall(result)
        pending = call
        try {
            QrScanner.startScan(currentActivity, ScanCallback { scanResult ->
                // Cada callback responde únicamente a su propia llamada.
                runOnMain { deliver(call, scanResult) }
            })
        } catch (e: Exception) {
            release(call)
            call.error(
                ScanErrorCode.CAMERA_UNAVAILABLE.code,
                e.message ?: "No se pudo iniciar el escáner.",
            )
        }
    }

    private fun deliver(call: PendingCall, scanResult: ScanResult) {
        // Libera la ranura solo si sigue siendo la de esta llamada.
        release(call)
        when (scanResult) {
            is ScanResult.Success -> call.success(mapOf("productId" to scanResult.productId))
            is ScanResult.Failure -> call.error(scanResult.error.code, scanResult.message)
        }
    }

    private fun release(call: PendingCall) {
        if (pending === call) pending = null
    }

    private fun cancelScan(result: Result) {
        // La llamada scanProduct pendiente recibe `cancelled` por el callback del SDK.
        val cancelled = try {
            QrScanner.cancelScan()
        } catch (_: Exception) {
            false
        }
        result.success(cancelled)
    }

    /**
     * Cancela la sesión del SDK (solo si este puente tiene una llamada en vuelo, para no
     * cancelar la sesión de otro motor) y garantiza que nada quede colgado.
     */
    private fun cancelAndFlush() {
        val call = pending ?: return
        pending = null
        try {
            QrScanner.cancelScan()
        } catch (_: Exception) {
            // El SDK puede fallar durante el desmontaje; se responde igualmente.
        }
        try {
            call.error(ScanErrorCode.CANCELLED.code, "Escaneo cancelado.")
        } catch (_: Exception) {
            // El motor puede estar ya destruido.
        }
    }

    private fun runOnMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post(block)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        cancelAndFlush()
        activity = null
    }

    override fun onDetachedFromActivity() {
        cancelAndFlush()
        activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        cancelAndFlush()
        channel?.setMethodCallHandler(null)
        channel = null
    }

    companion object {
        const val CHANNEL_NAME = "com.qrpedidos/qr_scanner"
    }
}
