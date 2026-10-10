package com.qrpedidos.sdk

/** Codigos de error estables. [code] es el valor que viaja por el puente. */
enum class ScanErrorCode(val code: String) {
    PERMISSION_DENIED("permissionDenied"),
    CAMERA_UNAVAILABLE("cameraUnavailable"),
    INVALID_QR("invalidQr"),
    CANCELLED("cancelled"),
    SCAN_IN_PROGRESS("scanInProgress"),
}

/** Resultado terminal de una sesion de escaneo. */
sealed interface ScanResult {
    data class Success(val productId: Long) : ScanResult
    data class Failure(val error: ScanErrorCode, val message: String) : ScanResult
}

/** Recibe exactamente un resultado por sesion, siempre en el hilo principal. */
fun interface ScanCallback {
    fun onResult(result: ScanResult)
}
