package io.github.janmichaelpeter.window_placement

import kotlin.test.Test
import kotlin.test.assertNull

internal class WindowPlacementPluginTest {
    @Test
    fun getGeometry_withoutActivity_returnsNull() {
        assertNull(WindowPlacementPlugin().getGeometry())
    }
}
