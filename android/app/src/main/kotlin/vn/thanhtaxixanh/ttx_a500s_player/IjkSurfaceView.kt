package vn.thanhtaxixanh.ttx_a500s_player

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.platform.PlatformView
import tv.danmaku.ijk.media.player.IMediaPlayer
import tv.danmaku.ijk.media.player.IjkMediaPlayer
import kotlin.math.min

/**
 * Video is decoded/rendered entirely in native Android.
 * No raw video frames travel through Flutter's MethodChannel.
 *
 * This is a standalone IJKPlayer implementation, NOT a copy of 70mai's
 * proprietary app/native libraries.
 */
class IjkSurfaceView(
    context: Context,
    private val viewId: Int,
    private val emitEvent: (Map<String, Any?>) -> Unit,
    private val removed: () -> Unit
) : PlatformView, SurfaceHolder.Callback {
    private val layout = FrameLayout(context)
    private val surface = SurfaceView(context)
    private val handler = Handler(Looper.getMainLooper())
    private var player: IjkMediaPlayer? = null
    private var url: String? = null
    private var transport: String = "tcp"
    private var profile: String = "balanced"
    private var requested = false
    private var surfaceReady = false
    private var disposed = false
    private var retryPending = false
    private var retryAttempt = 0
    private var retryEvents = 0
    private var bufferEvents = 0
    private var currentState = "idle"
    private var attemptStartedAt = 0L
    private var bufferStartedAt = 0L
    private var renderingStarted = false
    private var firstFrameStartupMs: Long = 0L
    // Linker/JNI failure is process-local and cannot be fixed by RTSP retry.
    private var fatalNativeMessage: String? = null

    private val watchdog = object : Runnable {
        override fun run() {
            if (disposed) return
            val now = SystemClock.elapsedRealtime()
            if (requested && !retryPending && surfaceReady) {
                if (currentState == "connecting" &&
                    now - attemptStartedAt > 16000L
                ) {
                    scheduleReconnect("RTSP không phản hồi sau 16 giây")
                } else if (currentState == "buffering" &&
                    now - bufferStartedAt > 9000L
                ) {
                    scheduleReconnect("Bộ đệm dừng hơn 9 giây")
                }
            }
            handler.postDelayed(this, 1500L)
        }
    }

    init {
        layout.addView(
            surface,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )
        surface.holder.addCallback(this)
        handler.postDelayed(watchdog, 1500L)
    }

    override fun getView(): View = layout

    fun open(streamUrl: String, streamTransport: String, bufferProfile: String) {
        check(!disposed) { "Surface đã bị đóng" }
        fatalNativeMessage?.let {
            signal("native_error", it)
            return
        }
        require(streamUrl.startsWith("rtsp://", ignoreCase = true))
        require(streamTransport == "tcp" || streamTransport == "udp")
        require(bufferProfile in listOf("ultra", "low", "balanced", "smooth"))
        url = streamUrl
        transport = streamTransport
        profile = bufferProfile
        requested = true
        retryAttempt = 0
        retryEvents = 0
        bufferEvents = 0
        // A surface can be created after MethodChannel.open completes.
        if (surfaceReady) begin()
        else signal("waiting_surface", "Đang tạo SurfaceView để nhận video...")
    }

    private fun begin() {
        if (disposed || !requested || !surfaceReady) return
        releasePlayer()
        val targetUrl = url ?: return
        attemptStartedAt = SystemClock.elapsedRealtime()
        renderingStarted = false
        firstFrameStartupMs = 0L
        signal("connecting", "IJKPlayer mở RTSP: $targetUrl")
        try {
            val newPlayer = IjkMediaPlayer()
            player = newPlayer
            configure(newPlayer)
            newPlayer.setOnPreparedListener { current ->
                if (player !== newPlayer || !requested) return@setOnPreparedListener
                signal("prepared", "Đã nhận SDP; đang đợi khung hình đầu tiên")
                current.start()
            }
            newPlayer.setOnInfoListener { _, what, _ ->
                if (player !== newPlayer || !requested) return@setOnInfoListener true
                when (what) {
                    IMediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START -> {
                        renderingStarted = true
                        firstFrameStartupMs = SystemClock.elapsedRealtime() - attemptStartedAt
                        retryAttempt = 0
                        bufferStartedAt = 0L
                        signal("playing", "Đã hiển thị khung hình trực tiếp")
                    }
                    IMediaPlayer.MEDIA_INFO_BUFFERING_START -> {
                        bufferStartedAt = SystemClock.elapsedRealtime()
                        bufferEvents++
                        signal("buffering", "Đang chờ dữ liệu RTP...")
                    }
                    IMediaPlayer.MEDIA_INFO_BUFFERING_END -> {
                        bufferStartedAt = 0L
                        signal(
                            if (renderingStarted) "playing" else "prepared",
                            "Luồng RTP đã được khôi phục"
                        )
                    }
                }
                true
            }
            newPlayer.setOnErrorListener { _, what, extra ->
                if (player !== newPlayer || !requested) return@setOnErrorListener true
                scheduleReconnect("IJK error: what=$what extra=$extra")
                true
            }
            newPlayer.setOnCompletionListener {
                if (player === newPlayer && requested) {
                    scheduleReconnect("RTSP đã kết thúc; đang nối lại")
                }
            }
            newPlayer.setDisplay(surface.holder)
            newPlayer.setScreenOnWhilePlaying(true)
            newPlayer.setDataSource(targetUrl)
            newPlayer.prepareAsync()
        } catch (error: LinkageError) {
            // JNI_OnLoad, NoSuchMethodError, UnsatisfiedLinkError etc are
            // permanent within the current app process. Stop retry loops.
            val reason = "IJK JNI không tương thích: ${error.javaClass.simpleName}: ${error.message ?: "không có chi tiết"}. " +
                "Dừng tự nối lại. Đóng hẳn ứng dụng rồi mở lại sau khi cập nhật APK."
            fatalNativeMessage = reason
            requested = false
            retryPending = false
            releasePlayer()
            android.util.Log.e("TTX-IJK", "Fatal IJK native/JNI initialization error", error)
            signal("native_error", reason)
        } catch (error: Throwable) {
            scheduleReconnect("Không khởi tạo được IJK: ${error.message}")
        }
    }

    private fun configure(p: IjkMediaPlayer) {
        val ultra = profile == "ultra"
        val low = profile == "low"
        val smooth = profile == "smooth"
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "rtsp_transport", transport)
        // Baseline profiles preserve the V1.3 settings that played on A500S.
        p.setOption(
            IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzeduration",
            if (ultra) 150000L else 700000L
        )
        p.setOption(
            IjkMediaPlayer.OPT_CATEGORY_FORMAT, "probesize",
            if (ultra) 8192L else 32768L
        )
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "flush_packets", 1L)
        if (low || ultra) {
            p.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "fflags", "nobuffer")
        }
        if (ultra) {
            // FFmpeg RTSP jitter/reordering: potentially lowers delay, but
            // can cause visible artifacts on weak Wi-Fi. Opt-in only.
            p.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "max_delay", 100000L)
            p.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "reorder_queue_size", 0L)
        }
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec", 1L)
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-auto-rotate", 1L)
        p.setOption(
            IjkMediaPlayer.OPT_CATEGORY_PLAYER,
            "mediacodec-handle-resolution-change",
            1L
        )
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", if (ultra) 3L else 1L)
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", 1L)
        p.setOption(
            IjkMediaPlayer.OPT_CATEGORY_PLAYER,
            "packet-buffering",
            0L // Live RTSP: avoid an indefinite IJK packet buffering gate
        )
        p.setOption(
            IjkMediaPlayer.OPT_CATEGORY_PLAYER,
            "min-frames",
            if (ultra) 1L else if (low) 2L else if (smooth) 8L else 4L
        )
        p.setOption(
            IjkMediaPlayer.OPT_CATEGORY_PLAYER,
            "max_cached_duration",
            if (ultra) 120L else if (low) 250L else if (smooth) 900L else 500L
        )
        p.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "infbuf", 1L)
    }

    private fun scheduleReconnect(reason: String) {
        if (!requested || disposed || retryPending) return
        // When RTSP never decoded even a single frame, exponential reconnect
        // cannot repair an invalid stream or FFmpeg demuxer.
        if (!renderingStarted && retryAttempt >= 3) {
            requested = false
            retryPending = false
            releasePlayer()
            signal(
                "stream_error",
                "$reason · Dừng sau 3 lần thử không có hình. " +
                    "Hãy dùng nút Kiểm tra RTSP để xác định phản hồi của A500S."
            )
            return
        }
        retryPending = true
        retryEvents++
        val delaySec = min(16, 1 shl min(4, retryAttempt))
        retryAttempt++
        signal("reconnecting", "$reason · thử lại sau $delaySec giây")
        releasePlayer()
        handler.postDelayed({
            retryPending = false
            if (requested && !disposed && surfaceReady) begin()
        }, delaySec * 1000L)
    }

    private fun releasePlayer() {
        val old = player
        player = null
        if (old != null) {
            try {
                old.setOnPreparedListener(null)
                old.setOnInfoListener(null)
                old.setOnErrorListener(null)
                old.setOnCompletionListener(null)
                old.stop()
                old.release()
            } catch (_: Throwable) {
                // Native RTSP teardown can race with Wi-Fi disconnect.
            }
        }
        surface.keepScreenOn = false
    }

    private fun signal(state: String, message: String) {
        currentState = state
        emitEvent(
            mapOf(
                "viewId" to viewId,
                "state" to state,
                "message" to message
            )
        )
    }

    fun stats(): Map<String, Any> {
        val current = player
        val decodeFps = try { current?.videoDecodeFramesPerSecond?.toDouble() ?: 0.0 }
            catch (_: Throwable) { 0.0 }
        val outputFps = try { current?.videoOutputFramesPerSecond?.toDouble() ?: 0.0 }
            catch (_: Throwable) { 0.0 }
        val cache = try { current?.videoCachedDuration ?: 0L }
            catch (_: Throwable) { 0L }
        val tcpSpeed = try { current?.tcpSpeed ?: 0L }
            catch (_: Throwable) { 0L }
        return mapOf(
            "decodeFps" to decodeFps,
            "outputFps" to outputFps,
            "cachedMs" to cache,
            "tcpKbps" to (tcpSpeed / 1024),
            "bufferEvents" to bufferEvents,
            "retries" to retryEvents,
            "state" to currentState,
            "hardwareRequested" to true,
            "firstFrameMs" to firstFrameStartupMs,
            "videoWidth" to (current?.videoWidth ?: 0),
            "videoHeight" to (current?.videoHeight ?: 0)
        )
    }

    fun close() {
        requested = false
        retryPending = false
        handler.removeCallbacksAndMessages(null)
        releasePlayer()
        signal("stopped", "Đã dừng RTSP")
        if (!disposed) handler.postDelayed(watchdog, 1500L)
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        surfaceReady = true
        if (requested && player == null && !retryPending) begin()
    }

    override fun surfaceChanged(
        holder: SurfaceHolder,
        format: Int,
        width: Int,
        height: Int
    ) {
        // Native Window handles frame scaling; avoid copying frames to Dart.
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        surfaceReady = false
        releasePlayer()
        if (requested) signal("waiting_surface", "Surface bị hủy, chờ khôi phục")
    }

    override fun dispose() {
        if (disposed) return
        disposed = true
        requested = false
        handler.removeCallbacksAndMessages(null)
        releasePlayer()
        surface.holder.removeCallback(this)
        removed()
    }
}
