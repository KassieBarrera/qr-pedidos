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
internal class ScanSessionManager(
    private val logger: ScanLogger = NoLogger,
    private val dispatcher: (Runnable) -> Unit,
) {

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
            logger.w("session.rejected reason=scanInProgress active=${activeId()}")
            deliver(
                callback,
                ScanResult.Failure(ScanErrorCode.SCAN_IN_PROGRESS, "Ya hay un escaneo en curso.")
            )
            return null
        }
        logger.i("session.begin session=${session.id}")
        return session.id
    }

    private fun activeId(): Long? = synchronized(lock) { current?.id }

    /**
     * La actividad registra sus ganchos. Devuelve false si [sessionId] ya no es la sesion activa
     * (la actividad debe cerrarse sin entregar nada).
     */
    fun attach(sessionId: Long, closeHook: () -> Unit, releaseHook: () -> Unit): Boolean =
        synchronized(lock) {
            val s = current
            if (s == null || s.id != sessionId) {
                logger.w("session.attach session=$sessionId ok=false")
                return false
            }
            s.closeHook = closeHook
            s.releaseHook = releaseHook
            logger.d("session.attach session=$sessionId ok=true")
            true
        }

    fun succeed(sessionId: Long, productId: Long): Boolean =
        complete(sessionId, ScanResult.Success(productId), null)

    fun fail(sessionId: Long, error: ScanErrorCode, message: String): Boolean =
        complete(sessionId, ScanResult.Failure(error, message), null)

    /** Cancela la sesion [sessionId] si sigue activa. [source] solo se usa para el log. */
    fun cancel(sessionId: Long, source: String = "api"): Boolean =
        complete(sessionId, ScanResult.Failure(ScanErrorCode.CANCELLED, "Escaneo cancelado."), source)

    /** Cancela la sesion activa, sea cual sea. false si no habia ninguna. */
    fun cancelActive(): Boolean {
        val id = synchronized(lock) { current?.id } ?: return false
        return cancel(id, "api")
    }

    private fun complete(sessionId: Long, result: ScanResult, cancelSource: String?): Boolean {
        var ignoredReason: String? = null
        val session = synchronized(lock) {
            val s = current
            when {
                s == null -> ignoredReason = "alreadyTerminated"
                s.id != sessionId -> ignoredReason = "staleId"
                !s.terminated.compareAndSet(false, true) -> ignoredReason = "alreadyTerminated"
            }
            if (ignoredReason == null) current = null
            s
        }
        if (ignoredReason != null || session == null) {
            logger.d("session.ignored session=$sessionId reason=$ignoredReason")
            return false
        }
        when {
            result is ScanResult.Success ->
                logger.i("session.complete session=${session.id} result=success productId=${result.productId}")
            result is ScanResult.Failure && result.error == ScanErrorCode.CANCELLED ->
                logger.w("session.cancel session=${session.id} source=${cancelSource ?: "api"}")
            result is ScanResult.Failure ->
                logger.w("session.complete session=${session.id} result=failure code=${result.error.code}")
        }
        val close = session.closeHook
        val release = session.releaseHook
        session.closeHook = null
        session.releaseHook = null
        deliver(session.callback, result)
        // Liberar recursos y cerrar la vista tras entregar; cada gancho corre una sola vez.
        if (release != null) dispatcher(Runnable {
            logger.d("session.release session=${session.id}")
            release()
        })
        if (close != null) dispatcher(Runnable { close() })
        return true
    }

    private fun deliver(callback: ScanCallback, result: ScanResult) {
        dispatcher(Runnable { callback.onResult(result) })
    }
}
