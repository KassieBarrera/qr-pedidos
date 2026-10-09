package com.qrpedidos.sdk

object QrValidator {

    private val pattern = Regex("^product:([1-9][0-9]*)$")

    fun validate(qrContent: String): Long? {
        val match = pattern.matchEntire(qrContent)
            ?: return null

        val id = match.groupValues[1].toLongOrNull()
            ?: return null

        return id.takeIf { it > 0 }
    }
}
