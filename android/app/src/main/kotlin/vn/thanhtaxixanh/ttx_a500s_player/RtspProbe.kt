package vn.thanhtaxixanh.ttx_a500s_player

import android.net.Network
import android.os.SystemClock
import android.util.Log
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetSocketAddress
import java.net.Socket
import java.net.SocketTimeoutException
import java.net.URI
import java.nio.charset.StandardCharsets

/**
 * A500S full-session RTSP probe.
 * OPTIONS + DESCRIBE + SETUP(Content-Base + track) + PLAY + bounded RTP sampling.
 * Uses the already-connected, authorised Android camera Wi-Fi network only.
 *
 * The temporary RTSP session is always TEARDOWNed. It does not record video.
 * Do not run concurrently with the normal IJKPlayer session; the camera may
 * allow only one preview session at a time.
 */
class RtspProbe(private val wifiNetwork: Network) {
    private data class Response(
        val statusLine: String,
        val headers: Map<String, String>,
        val body: String
    ) {
        val ok: Boolean get() = statusLine.startsWith("RTSP/1.0 200 ")
        val session: String get() = headers["session"]?.substringBefore(';')?.trim().orEmpty()
    }

    private data class UdpPair(val rtp: DatagramSocket, val rtcp: DatagramSocket)

    fun check(url: String, transport: String): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>(
            "tcp" to "chưa kết nối",
            "transport" to transport.uppercase(),
            "options" to "chưa thử",
            "describe" to "chưa thử",
            "setup" to "chưa thử",
            "play" to "chưa thử",
            "contentType" to "",
            "contentBase" to "",
            "codec" to "",
            "track" to "",
            "setupUrl" to "",
            "serverTransport" to "",
            "session" to "",
            "rtpPackets" to 0,
            "rtpBytes" to 0,
            "idrSeen" to false
        )

        val parsed = try { URI(url) } catch (_: Exception) { null }
        val host = parsed?.host
        val port = parsed?.port?.takeIf { it > 0 } ?: 554
        if (parsed?.scheme?.lowercase() != "rtsp" || host.isNullOrBlank()
            || port !in 1..65535 || transport !in listOf("tcp", "udp")) {
            result["error"] = "RTSP URL hoặc giao thức không hợp lệ"
            return result
        }

        var udp: UdpPair? = null
        var session = ""
        var setupUrl = ""
        try {
            wifiNetwork.socketFactory.createSocket().use { socket ->
                socket.connect(InetSocketAddress(host, port), 3000)
                socket.soTimeout = 4000
                val input = BufferedInputStream(socket.getInputStream())
                result["tcp"] = "đã kết nối trên Wi-Fi camera"

                val options = exchange(socket, input, "OPTIONS", url, 1)
                result["options"] = options.statusLine
                if (!options.ok) {
                    result["error"] = "OPTIONS không chấp nhận: ${options.statusLine}"
                    return result
                }

                val describe = exchange(
                    socket, input, "DESCRIBE", url, 2,
                    mapOf("Accept" to "application/sdp")
                )
                result["describe"] = describe.statusLine
                if (!describe.ok) {
                    result["error"] = "DESCRIBE không chấp nhận: ${describe.statusLine}"
                    return result
                }

                result["contentType"] = describe.headers["content-type"].orEmpty()
                val contentBase = describe.headers["content-base"]
                    ?: describe.headers["content-location"] ?: url
                result["contentBase"] = contentBase
                val sdp = describe.body
                val codec = sdp.lineSequence()
                    .map { it.trim() }
                    .firstOrNull { it.startsWith("a=rtpmap:", ignoreCase = true) }
                    .orEmpty()
                val track = sdp.lineSequence()
                    .map { it.trim() }
                    .firstOrNull { it.startsWith("a=control:") && it != "a=control:*" }
                    .orEmpty()
                result["codec"] = codec
                result["track"] = track
                if (track.isBlank()) {
                    result["error"] = "SDP không có track media để gửi SETUP"
                    return result
                }

                // Each A500S DESCRIBE may return a different dynamic Content-Base,
                // e.g. rtsp://192.168.0.1/0000000C/ ; never cache it.
                val trackRef = track.removePrefix("a=control:").trim()
                setupUrl = URI(contentBase).resolve(trackRef).toString()
                result["setupUrl"] = setupUrl
                val transportValue = if (transport == "tcp") {
                    "RTP/AVP/TCP;unicast;interleaved=0-1"
                } else {
                    udp = makeUdpPair()
                    "RTP/AVP;unicast;client_port=${udp!!.rtp.localPort}-${udp!!.rtcp.localPort}"
                }
                val setup = exchange(
                    socket, input, "SETUP", setupUrl, 3,
                    mapOf("Transport" to transportValue)
                )
                result["setup"] = setup.statusLine
                result["serverTransport"] = setup.headers["transport"].orEmpty()
                session = setup.session
                result["session"] = if (session.isBlank()) "" else "có Session ID"
                if (!setup.ok) {
                    result["error"] = "SETUP bị từ chối; xem Transport và thử TCP/UDP còn lại"
                    return result
                }
                if (session.isEmpty()) {
                    result["error"] = "SETUP 200 nhưng server không trả Session"
                    return result
                }
                val playUrl = if (contentBase.endsWith("/")) contentBase else url
                val play = exchange(
                    socket, input, "PLAY", playUrl, 4,
                    mapOf("Session" to session, "Range" to "npt=0.000-")
                )
                result["play"] = play.statusLine
                if (!play.ok) {
                    result["error"] = "PLAY bị từ chối; camera chưa cấp luồng media"
                    return result
                }

                val count = if (transport == "tcp") {
                    receiveInterleaved(input, socket)
                } else {
                    receiveUdp(udp!!.rtp)
                }
                result["rtpPackets"] = count.first
                result["rtpBytes"] = count.second
                result["idrSeen"] = count.third
                if (count.first == 0) {
                    result["error"] = "PLAY 200 nhưng không có gói RTP trong 5 giây"
                }
                // Best effort: free scarce A500S preview slots for real playback.
                try {
                    exchange(
                        socket, input, "TEARDOWN",
                        if (contentBase.endsWith("/")) contentBase else url,
                        5, mapOf("Session" to session)
                    )
                } catch (_: Exception) {
                    // Connection close releases the session eventually.
                }
            }
        } catch (e: Exception) {
            Log.e("TTX-RTSP", "Session probe failed at setup=$setupUrl", e)
            result["error"] = "${e.javaClass.simpleName}: ${e.message ?: "không có chi tiết"}"
        } finally {
            // If an exception tears down the TCP socket, server session expires
            // on its own; explicit TEARDOWN is issued in the success path below.
            udp?.rtp?.close()
            udp?.rtcp?.close()
        }
        return result
    }

    private fun exchange(
        socket: Socket,
        input: BufferedInputStream,
        method: String,
        url: String,
        cseq: Int,
        headers: Map<String, String> = emptyMap()
    ): Response {
        val request = buildString {
            append("$method $url RTSP/1.0\r\n")
            append("CSeq: $cseq\r\n")
            append("User-Agent: Lavf58.12.100\r\n")
            for ((key, value) in headers) append("$key: $value\r\n")
            append("\r\n")
        }
        socket.getOutputStream().write(request.toByteArray(StandardCharsets.US_ASCII))
        socket.getOutputStream().flush()
        val response = readResponse(input)
        Log.i("TTX-RTSP", "$method ${response.statusLine}")
        return response
    }

    private fun readResponse(input: BufferedInputStream): Response {
        val buffer = ByteArrayOutputStream()
        var delimiter = 0
        while (buffer.size() < 16384) {
            val current = input.read()
            if (current < 0) throw IOException("RTSP server đóng kết nối khi nhận header")
            buffer.write(current)
            delimiter = when {
                (delimiter == 0 || delimiter == 2) && current == 13 -> delimiter + 1
                (delimiter == 1 || delimiter == 3) && current == 10 -> delimiter + 1
                else -> 0
            }
            if (delimiter == 4) break
        }
        if (delimiter != 4) throw IOException("RTSP header quá lớn hoặc chưa hoàn tất")
        val rows = buffer.toString("ISO-8859-1").split("\r\n")
        val status = rows.firstOrNull().orEmpty()
        val headers = mutableMapOf<String, String>()
        rows.drop(1).forEach { row ->
            val at = row.indexOf(':')
            if (at > 0) headers[row.substring(0, at).trim().lowercase()] =
                row.substring(at + 1).trim()
        }
        val declaredSize = headers["content-length"]?.toIntOrNull() ?: 0
        if (declaredSize !in 0..32768) throw IOException("Kích thước SDP không hợp lệ")
        val bytes = ByteArray(declaredSize)
        readFully(input, bytes)
        return Response(status, headers, String(bytes, StandardCharsets.UTF_8))
    }

    private fun readFully(input: BufferedInputStream, out: ByteArray) {
        var offset = 0
        while (offset < out.size) {
            val n = input.read(out, offset, out.size - offset)
            if (n < 0) throw IOException("RTSP/RTP kết thúc khi đang đọc dữ liệu")
            offset += n
        }
    }

    private fun makeUdpPair(): UdpPair {
        repeat(48) {
            val a = DatagramSocket(null)
            val b = DatagramSocket(null)
            try {
                a.bind(InetSocketAddress(0))
                if (a.localPort % 2 != 0 || a.localPort >= 65534) {
                    a.close()
                    b.close()
                    return@repeat
                }
                b.bind(InetSocketAddress(a.localPort + 1))
                wifiNetwork.bindSocket(a)
                wifiNetwork.bindSocket(b)
                return UdpPair(a, b)
            } catch (_: Exception) {
                a.close()
                b.close()
            }
        }
        throw IOException("Không cấp được cặp cổng RTP/RTCP UDP")
    }

    private fun receiveUdp(socket: DatagramSocket): Triple<Int, Int, Boolean> {
        val end = SystemClock.elapsedRealtime() + 5000
        var packets = 0
        var size = 0
        var idr = false
        val bytes = ByteArray(4096)
        socket.soTimeout = 650
        while (SystemClock.elapsedRealtime() < end) {
            try {
                val packet = DatagramPacket(bytes, bytes.size)
                socket.receive(packet)
                if (packet.length >= 12 && (bytes[0].toInt() and 0xC0) == 0x80) {
                    packets++
                    size += packet.length
                    if (isIdr(bytes, packet.length)) idr = true
                }
            } catch (_: SocketTimeoutException) {
                // More samples until the five-second cap.
            }
        }
        return Triple(packets, size, idr)
    }

    private fun receiveInterleaved(
        input: BufferedInputStream,
        socket: Socket
    ): Triple<Int, Int, Boolean> {
        val end = SystemClock.elapsedRealtime() + 5000
        var packets = 0
        var total = 0
        var idr = false
        socket.soTimeout = 650
        while (SystemClock.elapsedRealtime() < end) {
            try {
                val magic = input.read()
                if (magic < 0) break
                if (magic != 36) continue // '$' denotes RTSP-interleaved RTP.
                val channel = input.read()
                val hi = input.read()
                val lo = input.read()
                if (channel < 0 || hi < 0 || lo < 0) break
                val length = (hi shl 8) or lo
                if (length !in 1..65535) break
                val bytes = ByteArray(length)
                readFully(input, bytes)
                if (channel % 2 == 0 && length >= 12 &&
                    (bytes[0].toInt() and 0xC0) == 0x80) {
                    packets++
                    total += length
                    if (isIdr(bytes, length)) idr = true
                }
            } catch (_: SocketTimeoutException) {
                // No data yet; continue sampling.
            }
        }
        return Triple(packets, total, idr)
    }

    private fun isIdr(bytes: ByteArray, length: Int): Boolean {
        if (length < 14) return false
        val csrcCount = bytes[0].toInt() and 0x0F
        var h = 12 + csrcCount * 4
        if (h >= length) return false
        if ((bytes[0].toInt() and 0x10) != 0) {
            if (h + 4 > length) return false
            val extensionWords = ((bytes[h + 2].toInt() and 0xFF) shl 8) or
                (bytes[h + 3].toInt() and 0xFF)
            h += 4 + extensionWords * 4
        }
        if (h >= length) return false
        val nal = bytes[h].toInt() and 0x1F
        return nal == 5 || (nal == 28 && h + 1 < length &&
            (bytes[h + 1].toInt() and 0x1F) == 5)
    }
}
