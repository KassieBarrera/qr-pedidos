package com.qrpedidos.sdk

import java.util.concurrent.atomic.AtomicBoolean

/**
 * Logica de sesiones de escaneo en JVM puro (sin dependencias de Android).
 *
 * Garantias:
 *  - A lo sumo un resultado terminal por sesion.
 *  - Una sola sesion activa; un segundo [begin] recibe SCAN_IN_PROGRESS sin tocar la activa.
 *  - Cada sesion tiene un id: una actividad vieja no puede completar una sesion nueva.
 *  - Los ganchos de cierre y de liberacion se invocan una vez, al terminar la sesion.
 *
 * Callbacks y ganchos se entregan mediante [dispatcher] (hilo principal en produccion).
 * El estado ([isScanning]) se actualiza de forma sincrona, antes de la entrega.
 */
internal class ScanSessionManager(private val dispatcher: (Runnable) -> Unit) {

    internal class Session(val id: Long, val callback: ScanCallback) {
        val terminated = AtomicBoolean(false)
        var closeHook: (() -> Unit)? = null
        var releaseHook: (() -> Unit)? = null
    }

    private val lock = Any()
    private var nextId = 1L
    private var current: Session? = null

    val isScanning: Boolean
        get() = synchronized(lock) { current != null }

    /** Abre una sesion. Devuelve su id, o null si ya habia una activa (el nuevo callback recibe SCAN_IN_PROGRESS). */
    fun begin(callback: ScanCallback): Long? {
        val session = synchronized(lock) {
            if (current != null) null else Session(nextId++, callback).also { current = it }
        }
        if (session == null) {
            deliver(
                callback,
                ScanResult.Failure(ScanErrorCode.SCAN_IN_PROGRESS, "Ya hay un escaneo en curso.")
            )
            return null
        }
        return session.id
    }

    /**
     * La actividad registra sus ganchos. Devuelve false si [sessionId] ya no es la sesion activa
     * (la actividad debe cerrarse sin entregar nada).
     */
    fun attach(sessionId: Long, closeHook: () -> Unit, releaseHook: () -> Unit): Boolean =
        synchronized(lock) {
            val s = current
            if (s == null || s.id != sessionId) return false
            s.closeHook = closeHook
            s.releaseHook = releaseHook
            true
        }

    fun succeed(sessionId: Long, productId: Long): Boolean =
        complete(sessionId, ScanResult.Success(productId))

    fun fail(sessionId: Long, error: ScanErrorCode, message: String): Boolean =
        complete(sessionId, ScanResult.Failure(error, message))

    /** Cancela la sesion [sessionId] si sigue activa. */
    fun cancel(sessionId: Long): Boolean =
        fail(sessionId, ScanErrorCode.CANCELLED, "Escaneo cancelado.")

    /** Cancela la sesion activa, sea cual sea. false si no habia ninguna. */
    fun cancelActive(): Boolean {
        val id = synchronized(lock) { current?.id } ?: return false
        return cancel(id)
    }

    private fun complete(sessionId: Long, result: ScanResult): Boolean {
        val session = synchronized(lock) {
            val s = current
            if (s == null || s.id != sessionId || !s.terminated.compareAndSet(false, true)) return false
            current = null
            s
        }
        val close = session.closeHook
        val release = session.releaseHook
        session.closeHook = null
        session.releaseHook = null
        deliver(session.callback, result)
        // Liberar recursos y cerrar la vista tras entregar; cada gancho corre una sola vez.
        if (release != null) dispatcher(Runnable { release() })
        if (close != null) dispatcher(Runnable { close() })
        return true
    }

    private fun deliver(callback: ScanCallback, result: ScanResult) {
        dispatcher(Runnable { callback.onResult(result) })
    }
}
