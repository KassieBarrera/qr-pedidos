package com.qrpedidos.sdk

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ScanSessionManagerTest {

    private val manager = ScanSessionManager { it.run() } // despachador sincrono

    private class Recorder : ScanCallback {
        val results = mutableListOf<ScanResult>()
        @Synchronized override fun onResult(result: ScanResult) { results.add(result) }
        @Synchronized fun count() = results.size
    }

    private class Hooks {
        val closes = AtomicInteger()
        val releases = AtomicInteger()
    }

    private fun attach(id: Long, hooks: Hooks) =
        manager.attach(id, { hooks.closes.incrementAndGet() }, { hooks.releases.incrementAndGet() })

    private fun failure(r: ScanResult) = (r as ScanResult.Failure).error

    @Test
    fun successDeliversProductId() {
        val cb = Recorder()
        val id = manager.begin(cb)!!
        assertTrue(manager.isScanning)
        assertTrue(manager.succeed(id, 42L))
        assertEquals(listOf<ScanResult>(ScanResult.Success(42L)), cb.results)
        assertFalse(manager.isScanning)
    }

    @Test
    fun repeatedDetectionsDeliverOnlyOnce() {
        val cb = Recorder()
        val id = manager.begin(cb)!!
        assertTrue(manager.succeed(id, 1L))
        assertFalse(manager.succeed(id, 2L))
        assertFalse(manager.fail(id, ScanErrorCode.INVALID_QR, "x"))
        assertEquals(1, cb.count())
        assertEquals(ScanResult.Success(1L), cb.results[0])
    }

    @Test
    fun concurrentDetectionsDeliverOnlyOnce() {
        val cb = Recorder()
        val hooks = Hooks()
        val id = manager.begin(cb)!!
        attach(id, hooks)
        val threads = 16
        val pool = Executors.newFixedThreadPool(threads)
        val start = CountDownLatch(1)
        val done = CountDownLatch(threads)
        val winners = AtomicInteger()
        repeat(threads) { i ->
            pool.execute {
                start.await()
                val won = when (i % 3) {
                    0 -> manager.succeed(id, i.toLong() + 1)
                    1 -> manager.fail(id, ScanErrorCode.INVALID_QR, "x")
                    else -> manager.cancel(id)
                }
                if (won) winners.incrementAndGet()
                done.countDown()
            }
        }
        start.countDown()
        assertTrue(done.await(5, TimeUnit.SECONDS))
        pool.shutdown()
        assertEquals(1, winners.get())
        assertEquals(1, cb.count())
        assertEquals(1, hooks.releases.get())
        assertEquals(1, hooks.closes.get())
        assertFalse(manager.isScanning)
    }

    @Test
    fun secondStartGetsScanInProgressAndActiveSessionIsIntact() {
        val first = Recorder()
        val second = Recorder()
        val hooks = Hooks()
        val id = manager.begin(first)!!
        attach(id, hooks)

        assertNull(manager.begin(second))

        assertEquals(1, second.count())
        assertEquals(ScanErrorCode.SCAN_IN_PROGRESS, failure(second.results[0]))
        assertEquals(0, first.count())
        assertEquals(0, hooks.closes.get())
        assertEquals(0, hooks.releases.get())
        assertTrue(manager.isScanning)

        assertTrue(manager.succeed(id, 7L))
        assertEquals(listOf<ScanResult>(ScanResult.Success(7L)), first.results)
        assertEquals(1, second.count())
    }

    @Test
    fun cancelDeliversCancelledAndClosesView() {
        val cb = Recorder()
        val hooks = Hooks()
        val id = manager.begin(cb)!!
        attach(id, hooks)

        assertTrue(manager.cancelActive())

        assertEquals(ScanErrorCode.CANCELLED, failure(cb.results.single()))
        assertEquals(1, hooks.closes.get())
        assertEquals(1, hooks.releases.get())
        assertFalse(manager.isScanning)
    }

    @Test
    fun cancelWithoutSessionReturnsFalse() {
        assertFalse(manager.cancelActive())
    }

    @Test
    fun cancelAfterSuccessIsIgnored() {
        val cb = Recorder()
        val id = manager.begin(cb)!!
        manager.succeed(id, 5L)
        assertFalse(manager.cancelActive())
        assertFalse(manager.cancel(id))
        assertEquals(listOf<ScanResult>(ScanResult.Success(5L)), cb.results)
    }

    @Test
    fun resourcesAreReleasedExactlyOnce() {
        val cb = Recorder()
        val hooks = Hooks()
        val id = manager.begin(cb)!!
        attach(id, hooks)
        manager.succeed(id, 1L)
        manager.cancel(id)
        manager.fail(id, ScanErrorCode.CAMERA_UNAVAILABLE, "x")
        manager.succeed(id, 2L)
        assertEquals(1, hooks.releases.get())
        assertEquals(1, hooks.closes.get())
    }

    @Test
    fun staleSessionIdCannotCompleteNewSession() {
        val oldCb = Recorder()
        val oldId = manager.begin(oldCb)!!
        manager.cancel(oldId)

        val newCb = Recorder()
        val newHooks = Hooks()
        val newId = manager.begin(newCb)!!
        assertNotNull(newId)
        attach(newId, newHooks)

        assertFalse(manager.succeed(oldId, 99L))
        assertFalse(manager.cancel(oldId))
        assertFalse(manager.fail(oldId, ScanErrorCode.INVALID_QR, "x"))
        assertFalse(manager.attach(oldId, {}, {}))

        assertEquals(0, newCb.count())
        assertEquals(0, newHooks.releases.get())
        assertTrue(manager.isScanning)
        assertEquals(1, oldCb.count())
    }

    @Test
    fun attachToUnknownSessionIsRejected() {
        assertFalse(manager.attach(123L, {}, {}))
        val id = manager.begin(Recorder())!!
        manager.cancel(id)
        assertFalse(manager.attach(id, {}, {}))
    }

    @Test
    fun canStartNewSessionAfterTermination() {
        val first = Recorder()
        manager.succeed(manager.begin(first)!!, 1L)
        val second = Recorder()
        val id2 = manager.begin(second)
        assertNotNull(id2)
        manager.succeed(id2!!, 2L)
        assertEquals(ScanResult.Success(2L), second.results.single())
    }

    @Test
    fun isScanningIsUpdatedBeforeDeliveryAllowingRestartInCallback() {
        var restarted: Long? = null
        val id = manager.begin { restarted = manager.begin { } }!!
        manager.cancel(id)
        assertNotNull(restarted)
    }

    @Test
    fun deliveryGoesThroughDispatcher() {
        val queue = ArrayDeque<Runnable>()
        val m = ScanSessionManager { queue.add(it) }
        val cb = Recorder()
        val id = m.begin(cb)!!
        m.succeed(id, 3L)
        assertEquals(0, cb.count())
        assertFalse(m.isScanning)
        queue.forEach { it.run() }
        assertEquals(1, cb.count())
    }
}
