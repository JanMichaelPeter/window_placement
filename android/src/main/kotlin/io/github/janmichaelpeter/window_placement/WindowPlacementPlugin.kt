package io.github.janmichaelpeter.window_placement

import android.annotation.SuppressLint
import android.app.Activity
import android.graphics.Rect
import android.os.Build
import android.view.View
import android.view.ViewTreeObserver
import androidx.window.layout.WindowMetricsCalculator
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

class WindowPlacementPlugin :
    FlutterPlugin,
    ActivityAware,
    WindowPlacementHostApi {
    private var activity: Activity? = null
    private var sink: PigeonEventSink<WindowGeometry>? = null
    private var lastGeometry: WindowGeometry? = null

    // Re-checks after every layout pass; covers split ratio changes, side swaps and rotation.
    private val layoutChangeListener =
        View.OnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> emitIfChanged() }
    private val globalLayoutListener = ViewTreeObserver.OnGlobalLayoutListener { emitIfChanged() }

    private val geometryChanges =
        object : GeometryChangesStreamHandler() {
            override fun onListen(p0: Any?, sink: PigeonEventSink<WindowGeometry>) {
                this@WindowPlacementPlugin.sink = sink
                lastGeometry = null
                addListeners()
                emitIfChanged()
            }

            override fun onCancel(p0: Any?) {
                removeListeners()
                sink = null
            }
        }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        WindowPlacementHostApi.setUp(binding.binaryMessenger, this)
        GeometryChangesStreamHandler.register(binding.binaryMessenger, geometryChanges)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        WindowPlacementHostApi.setUp(binding.binaryMessenger, null)
    }

    override fun getGeometry(): WindowGeometry? = currentGeometry()

    // ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        if (sink != null) {
            addListeners()
            emitIfChanged()
        }
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        removeListeners()
        activity = null
    }

    // Geometry

    internal fun currentGeometry(): WindowGeometry? {
        val activity = activity ?: return null
        val calculator = WindowMetricsCalculator.getOrCreate()
        val window = calculator.computeCurrentWindowMetrics(activity).bounds
        val screen = calculator.computeMaximumWindowMetrics(activity).bounds
        val insets = displayInsets(activity)
        val density = activity.resources.displayMetrics.density.toDouble()
        return WindowGeometry(
            windowX = (window.left - screen.left) / density,
            windowY = (window.top - screen.top) / density,
            windowWidth = window.width() / density,
            windowHeight = window.height() / density,
            screenWidth = screen.width() / density,
            screenHeight = screen.height() / density,
            screenInsetLeft = insets.left / density,
            screenInsetTop = insets.top / density,
            screenInsetRight = insets.right / density,
            screenInsetBottom = insets.bottom / density,
            isMultiWindow = activity.isInMultiWindowMode || activity.isInPictureInPictureMode,
        )
    }

    /** System bars / cutouts of the display; windows docked to an edge may stop at these. */
    @SuppressLint("DiscouragedApi", "InternalInsetResource")
    private fun displayInsets(activity: Activity): Rect {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val insets = activity.windowManager.maximumWindowMetrics.windowInsets.getInsetsIgnoringVisibility(
                android.view.WindowInsets.Type.systemBars() or android.view.WindowInsets.Type.displayCutout()
            )
            return Rect(insets.left, insets.top, insets.right, insets.bottom)
        }
        val res = activity.resources
        fun dimen(name: String): Int {
            val id = res.getIdentifier(name, "dimen", "android")
            return if (id > 0) res.getDimensionPixelSize(id) else 0
        }
        return Rect(0, dimen("status_bar_height"), 0, dimen("navigation_bar_height"))
    }

    private fun emitIfChanged() {
        val sink = sink ?: return
        val geometry = currentGeometry() ?: return
        if (geometry == lastGeometry) return
        lastGeometry = geometry
        sink.success(geometry)
    }

    private fun addListeners() {
        val decorView = activity?.window?.decorView ?: return
        removeListeners()
        decorView.addOnLayoutChangeListener(layoutChangeListener)
        decorView.viewTreeObserver.addOnGlobalLayoutListener(globalLayoutListener)
    }

    private fun removeListeners() {
        val decorView = activity?.window?.decorView ?: return
        decorView.removeOnLayoutChangeListener(layoutChangeListener)
        if (decorView.viewTreeObserver.isAlive) {
            decorView.viewTreeObserver.removeOnGlobalLayoutListener(globalLayoutListener)
        }
    }
}
