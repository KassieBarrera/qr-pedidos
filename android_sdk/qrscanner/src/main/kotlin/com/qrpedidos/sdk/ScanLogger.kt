package com.qrpedidos.sdk

import android.util.Log
import java.util.concurrent.atomic.AtomicLong

internal enum class LogLevel { D, I, W, E }

/** Destino de los logs de diagnostico. Mantiene a [ScanSessionManager] libre de Android. */
internal fun interface ScanLogger {
    fun log(level: LogLevel, message: String, error: Throwable?)
}

internal val NoLogger = ScanLogger { _, _, _ -> }

internal fun ScanLogger.d(message: String) = log(LogLevel.D, message, null)
internal fun ScanLogger.i(message: String) = log(LogLevel.I, message, null)
internal fun ScanLogger.w(message: String) = log(LogLevel.W, message, null)
internal fun ScanLogger.e(message: String, error: Throwable? = null) = log(LogLevel.E, message, error)

/** Escribe en Logcat con el tag `QrSdk`. Se puede silenciar con [QrScanner.setLoggingEnabled]. */
internal object SdkLog : ScanLogger {
    const val TAG = "QrSdk"

    @Volatile
    var enabled = true

    override fun log(level: LogLevel, message: String, error: Throwable?) {
        if (!enabled) return
        when (level) {
            LogLevel.D -> Log.d(TAG, message)
            LogLevel.I -> Log.i(TAG, message)
            LogLevel.W -> Log.w(TAG, message)
            LogLevel.E -> if (error != null) Log.e(TAG, message, error) else Log.e(TAG, message)
        }
    }
}

/** Texto libre apto para `msg="..."`: sin comillas ni saltos de linea. */
internal fun logText(text: String?): String =
    (text ?: "").replace('"', '\'').replace('\n', ' ').take(120)

/** Deja pasar como mucho un evento por intervalo (para logs en bucles por fotograma). */
internal class LogRateLimiter(private val intervalMs: Long = 2_000L) {
    private val last = AtomicLong(Long.MIN_VALUE)

    fun allow(nowMs: Long = System.nanoTime() / 1_000_000L): Boolean {
        while (true) {
            val prev = last.get()
            if (prev != Long.MIN_VALUE && nowMs - prev < intervalMs) return false
            if (last.compareAndSet(prev, nowMs)) return true
        }
    }
}
