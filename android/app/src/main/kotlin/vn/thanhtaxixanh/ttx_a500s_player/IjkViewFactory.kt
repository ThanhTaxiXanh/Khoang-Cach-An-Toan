package vn.thanhtaxixanh.ttx_a500s_player

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class IjkViewFactory(
    private val context: Context,
    private val emit: (Map<String, Any?>) -> Unit
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private val views = mutableMapOf<Int, IjkSurfaceView>()

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val view = IjkSurfaceView(context, viewId, emit) { views.remove(viewId) }
        views[viewId] = view
        return view
    }

    fun get(viewId: Int): IjkSurfaceView? = views[viewId]

    fun releaseAll() {
        views.values.toList().forEach { it.dispose() }
        views.clear()
    }
}
