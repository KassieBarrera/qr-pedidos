package com.qrpedidos.sdk

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Detalle de implementacion del SDK; no es API publica. */
internal class QrScannerActivity : ComponentActivity() {

    internal companion object {
        const val EXTRA_SESSION_ID = "com.qrpedidos.sdk.SESSION_ID"
    }

    private val sessions get() = QrScanner.sessions
    private var sessionId = -1L

    /** true cuando esta actividad ya no debe procesar detecciones. */
    private val finished = AtomicBoolean(false)
    private val released = AtomicBoolean(false)

    /** true mientras el diálogo de permiso del sistema está visible (solo hilo principal). */
    private var awaitingPermission = false

    private var cameraProvider: ProcessCameraProvider? = null
    private var barcodeScanner: BarcodeScanner? = null
    private var cameraExecutor: ExecutorService? = null

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            awaitingPermission = false
            if (finished.get()) return@registerForActivityResult
            if (granted) startCamera()
            else sessions.fail(sessionId, ScanErrorCode.PERMISSION_DENIED, "Permiso de cámara denegado.")
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sessionId = intent.getLongExtra(EXTRA_SESSION_ID, -1L)

        // Recreada (p. ej. tras muerte del proceso) sin sesion activa con este id: no hay a quien entregar.
        val attached = sessions.attach(
            sessionId,
            closeHook = { finish() },
            releaseHook = { releaseResources() },
        )
        if (!attached) {
            finished.set(true)
            finish()
            return
        }

        setContentView(buildUi())

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                sessions.cancel(sessionId)
            }
        })

        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            sessions.fail(sessionId, ScanErrorCode.CAMERA_UNAVAILABLE, "El dispositivo no tiene cámara.")
            return
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            startCamera()
        } else {
            awaitingPermission = true
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    private lateinit var previewView: PreviewView

    private fun startCamera() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            if (finished.get()) return@addListener
            try {
                val provider = future.get()
                cameraProvider = provider

                val scanner = BarcodeScanning.getClient(
                    BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE).build()
                )
                val executor = Executors.newSingleThreadExecutor()
                barcodeScanner = scanner
                cameraExecutor = executor

                val preview = Preview.Builder().build().also {
                    it.surfaceProvider = previewView.surfaceProvider
                }
                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                analysis.setAnalyzer(executor) { proxy -> analyze(scanner, proxy) }

                provider.unbindAll()
                provider.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
            } catch (e: Exception) {
                sessions.fail(
                    sessionId,
                    ScanErrorCode.CAMERA_UNAVAILABLE,
                    "No se pudo abrir la cámara: ${e.message}",
                )
            }
        }, ContextCompat.getMainExecutor(this))
    }

    @androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
    private fun analyze(scanner: BarcodeScanner, proxy: ImageProxy) {
        val media = proxy.image
        if (media == null || finished.get()) {
            proxy.close()
            return
        }
        try {
            val image = InputImage.fromMediaImage(media, proxy.imageInfo.rotationDegrees)
            scanner.process(image)
                .addOnSuccessListener { barcodes ->
                    if (finished.get()) return@addOnSuccessListener // resultado tardio de ML Kit
                    val values = barcodes.mapNotNull { it.rawValue }
                    if (values.isEmpty()) return@addOnSuccessListener
                    val productId = values.firstNotNullOfOrNull { QrValidator.validate(it) }
                    if (productId != null) {
                        finished.set(true)
                        sessions.succeed(sessionId, productId)
                    } else {
                        finished.set(true)
                        sessions.fail(
                            sessionId,
                            ScanErrorCode.INVALID_QR,
                            "El código QR no es un código de producto válido.",
                        )
                    }
                }
                // Un fallo puntual de un fotograma no detiene el escaneo.
                .addOnCompleteListener { proxy.close() }
        } catch (e: Exception) {
            proxy.close()
        }
    }

    /** Idempotente: libera camara, detector y hilo. */
    private fun releaseResources() {
        finished.set(true)
        if (!released.compareAndSet(false, true)) return
        try { cameraProvider?.unbindAll() } catch (_: Exception) {}
        try { barcodeScanner?.close() } catch (_: Exception) {}
        cameraExecutor?.shutdown()
        cameraProvider = null
        barcodeScanner = null
        cameraExecutor = null
    }

    override fun onStop() {
        super.onStop()
        // Segundo plano: se cancela de forma controlada (no se restaura), salvo mientras el
        // diálogo de permiso del sistema deja esta actividad detenida.
        if (!isChangingConfigurations && !awaitingPermission) sessions.cancel(sessionId)
    }

    override fun onDestroy() {
        // Si se destruye sin resultado entregado, se cancela; no-op si la sesion ya termino o es otra.
        sessions.cancel(sessionId)
        releaseResources()
        super.onDestroy()
    }

    // ---------------------------------------------------------------- UI

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private fun buildUi(): View {
        previewView = PreviewView(this)
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        root.addView(previewView, matchParent())

        val frameSize = dp(250)
        val frame = View(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(16).toFloat()
                setStroke(dp(3), Color.WHITE)
                setColor(Color.TRANSPARENT)
            }
        }
        root.addView(frame, FrameLayout.LayoutParams(frameSize, frameSize, Gravity.CENTER))

        val hint = TextView(this).apply {
            text = "Apunta al código QR del producto"
            setTextColor(Color.WHITE)
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(8), dp(16), dp(8))
            setBackgroundColor(0x99000000.toInt())
        }
        root.addView(
            hint,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ).apply { topMargin = frameSize / 2 + dp(40) },
        )

        val cancel = Button(this).apply {
            text = "Cancelar"
            minimumHeight = dp(48)
            minHeight = dp(48)
            minimumWidth = dp(120)
            minWidth = dp(120)
            contentDescription = "Cancelar escaneo"
            setOnClickListener { sessions.cancel(sessionId) }
        }
        val cancelParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
        ).apply { bottomMargin = dp(32) }
        root.addView(cancel, cancelParams)

        // Respeta las barras del sistema (edge-to-edge en SDK 35+).
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            cancelParams.bottomMargin = dp(32) + bars.bottom
            cancel.layoutParams = cancelParams
            insets
        }
        return root
    }

    private fun matchParent() = FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT,
    )
}
