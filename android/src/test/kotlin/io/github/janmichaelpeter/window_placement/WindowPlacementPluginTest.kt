package io.github.janmichaelpeter.window_placement

import io.flutter.plugin.common.EventChannel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class WindowPlacementPluginTest {
    @Test
    fun getGeometry_withoutActivity_returnsNull() {
        assertNull(WindowPlacementPlugin().getGeometry())
    }

    @Test
    fun getEnvironment_withoutActivity_isUnavailable() {
        assertEquals(WindowSnapshot(geometry = null, traits = null), WindowPlacementPlugin().getEnvironment())
    }

    @Test
    fun environmentChanges_withoutActivity_sendsUnavailableOnce() {
        val plugin = WindowPlacementPlugin()
        val events = mutableListOf<Any?>()
        val sink =
            object : EventChannel.EventSink {
                override fun success(event: Any?) {
                    events.add(event)
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}

                override fun endOfStream() {}
            }
        plugin.environmentChanges.onListen(null, PigeonEventSink(sink))
        plugin.onDetachedFromActivity()
        assertEquals(listOf<Any?>(WindowSnapshot(geometry = null, traits = null)), events)
    }
}
