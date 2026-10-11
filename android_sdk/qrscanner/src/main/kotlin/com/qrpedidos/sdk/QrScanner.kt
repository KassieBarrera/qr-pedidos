package com.qrpedidos.sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper

/** Punto de entrada del SDK. Agnostico de Flutter, pedidos y REST. */
object QrScanner {

    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    internal val sessions = ScanSessionManager(SdkLog) { runnable -> mainHandler.post(runnable) }

    /** Abre la vista de captura. Entrega exactamente un resultado en el hilo principal. */
    fun startScan(context: Context, callback: ScanCallback) {
        val id = sessions.begin(callback) ?: return
        try {
            val intent = Intent(context, QrScannerActivity::class.java)
                .putExtra(QrScannerActivity.EXTRA_SESSION_ID, id)
            if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            SdkLog.e("session.startActivity.failed session=$id msg=\"${logText(e.message)}\"", e)
            sessions.fail(id, ScanErrorCode.CAMERA_UNAVAILABLE, "No se pudo abrir el escáner: ${e.message}")
        }
    }

    /** Cancela la sesion activa (su callback recibe CANCELLED) y cierra la vista. false si no habia sesion. */
    fun cancelScan(): Boolean = sessions.cancelActive()

    /** Activa o silencia los logs de Logcat del SDK (tag `QrSdk`). Por defecto activados. */
    fun setLoggingEnabled(enabled: Boolean) {
        SdkLog.enabled = enabled
    }

    val isScanning: Boolean
        get() = sessions.isScanning
}
