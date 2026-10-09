package com.qrpedidos.sdk

import org.junit.Assert.*
import org.junit.Test

class QrValidatorTest {

    @Test
    fun validQrReturnsProductId() {
        assertEquals(1L, QrValidator.validate("product:1"))
        assertEquals(25L, QrValidator.validate("product:25"))
    }

    @Test
    fun invalidQrReturnsNull() {
        val invalidValues = listOf(
            "product:0",
            "product:-1",
            "product:01",
            "PRODUCT:1",
            "product:abc",
            "hola",
            "product: 1"
        )

        invalidValues.forEach {
            assertNull(QrValidator.validate(it))
        }
    }

    @Test
    fun outOfRangeQrReturnsNull() {
        assertNull(
            QrValidator.validate(
                "product:999999999999999999999999999"
            )
        )
    }
}
