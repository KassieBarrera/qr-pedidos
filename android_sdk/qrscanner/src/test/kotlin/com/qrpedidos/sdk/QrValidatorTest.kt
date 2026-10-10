package com.qrpedidos.sdk

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class QrValidatorTest {

    @Test
    fun validQrReturnsProductId() {
        assertEquals(1L, QrValidator.validate("product:1"))
        assertEquals(25L, QrValidator.validate("product:25"))
        assertEquals(1234567890L, QrValidator.validate("product:1234567890"))
    }

    @Test
    fun maxLongIsValid() {
        assertEquals(Long.MAX_VALUE, QrValidator.validate("product:9223372036854775807"))
    }

    @Test
    fun invalidFormatsReturnNull() {
        listOf(
            "product:0",
            "product:-1",
            "product:01",
            "PRODUCT:1",
            "product:abc",
            "hola",
            "product: 1",
            "product:1 ",
            "product:1\n",
            "product:",
            " product:1",
            "product:1.5",
            "",
        ).forEach { assertNull("'$it' deberia ser invalido", QrValidator.validate(it)) }
    }

    @Test
    fun outOfRangeReturnsNull() {
        assertNull(QrValidator.validate("product:9223372036854775808"))
        assertNull(QrValidator.validate("product:999999999999999999999999999"))
    }
}
