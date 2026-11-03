package vn.thanhtaxixanh.ttx_a500s_player

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var factory: IjkViewFactory
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val networkManager by lazy {
        getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }
    private var processBound = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        factory = IjkViewFactory(this) { payload ->
            mainHandler.post {
                if (payload["state"] == "native_error") restoreNetwork()
                eventSink?.success(payload)
            }
        }
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "vn.thanhtaxixanh.a500s/ijk_surface",
            factory
        )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "vn.thanhtaxixanh.a500s/ijk_events"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "vn.thanhtaxixanh.a500s/ijk_control"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "wifiStatus" -> result.success(wifiStatus())
                "probeRtsp" -> {
                    val url = call.argument<String>("url")
                    val transport = call.argument<String>("transport") ?: "tcp"
                    val wifi = cameraWifi()
                    if (url == null || wifi == null) {
                        result.error("NO_WIFI", "Kết nối Wi-Fi 70mai trước khi kiểm tra RTSP", null)
                    } else {
                        // Do not probe network on Flutter/UI thread.
                        Thread {
                            val outcome = RtspProbe(wifi).check(url, transport)
                            mainHandler.post {
                                result.success(outcome)
                            }
                        }.start()
                    }
                }
                "open" -> {
                    val id = call.argument<Int>("viewId")
                    val url = call.argument<String>("url")
                    val transport = call.argument<String>("transport") ?: "tcp"
                    val profile = call.argument<String>("profile") ?: "balanced"
                    val view = id?.let { factory.get(it) }
                    if (view == null || url.isNullOrBlank()) {
                        result.error("INVALID", "View hoặc RTSP URL không hợp lệ", null)
                    } else if (!url.startsWith("rtsp://", ignoreCase = true)) {
                        result.error("INVALID", "Chỉ hỗ trợ RTSP camera nội bộ", null)
                    } else if (!bindToCameraWifi()) {
                        result.error(
                            "NO_WIFI",
                            "Kết nối điện thoại với hotspot A500S trước khi phát.",
                            null
                        )
                    } else {
                        try {
                            view.open(url, transport, profile)
                            result.success(null)
                        } catch (e: Exception) {
                            restoreNetwork()
                            result.error("IJK_INIT", e.message, null)
                        }
                    }
                }
                "close" -> {
                    call.argument<Int>("viewId")?.let { factory.get(it)?.close() }
                    restoreNetwork()
                    result.success(null)
                }
                "stats" -> {
                    val id = call.argument<Int>("viewId")
                    result.success(id?.let { factory.get(it)?.stats() } ?: emptyMap<String, Any>())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun cameraWifi(): Network? = networkManager.allNetworks.firstOrNull { network ->
        val capabilities = networkManager.getNetworkCapabilities(network)
        capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
    }

    private fun bindToCameraWifi(): Boolean {
        val wifiNetwork = cameraWifi() ?: return false
        processBound = networkManager.bindProcessToNetwork(wifiNetwork)
        return processBound
    }

    private fun restoreNetwork() {
        if (processBound) {
            networkManager.bindProcessToNetwork(null)
            processBound = false
        }
    }

    private fun wifiStatus(): Map<String, Any?> {
        val net = cameraWifi()
        val gateway = net?.let {
            networkManager.getLinkProperties(it)
                ?.routes
                ?.firstOrNull { route -> route.isDefaultRoute }
                ?.gateway
                ?.hostAddress
        }
        return mapOf(
            "available" to (net != null),
            "gateway" to gateway,
            "bound" to processBound
        )
    }

    override fun onDestroy() {
        if (::factory.isInitialized) factory.releaseAll()
        restoreNetwork()
        super.onDestroy()
    }
}
