package vn.thanhtaxixanh.ttx_a500s_player

import android.net.Network
import android.util.Log
import java.io.ByteArrayOutputStream
import java.io.BufferedInputStream
import java.net.InetSocketAddress
import java.net.URI
import java.nio.charset.StandardCharsets

/**
 * Read-only RTSP protocol diagnosis on the actual Android Wi-Fi Network.
 *
 * A500S LIVE555 may return Content-Base with a dynamic track path.
 * Do not rewrite the user's DESCRIBE URL to that Content-Base.
 */
class RtspProbe(private val wifiNetwork: Network) {
    fun check(url: String): Map<String, Any?> {
        val reply = mutableMapOf<String, Any?>(
            "tcp" to "chưa kết nối",
            "options" to "chưa thử",
            "describe" to "chưa thử",
            "contentType" to "",
            "contentBase" to "",
            "codec" to "",
            "track" to ""
        )
        val uri = try { URI(url) } catch (e: Exception) {
            reply["error"] = "URL không hợp lệ: ${e.message}"
            return reply
        }
        val host = uri.host
        val port = if (uri.port > 0) uri.port else 554
        if (uri.scheme != "rtsp" || host.isNullOrBlank() || port !in 1..65535) {
            reply["error"] = "Chỉ hỗ trợ rtsp://host[:port]/path"
            return reply
        }
        try {
            // Probe independently: a LIVE555 server might close after OPTIONS.
            val options = request(host, port, url, "OPTIONS", 1)
            reply["tcp"] = "đã kết nối"
            reply["options"] = options.statusLine
        } catch (e: Exception) {
            reply["error"] = "TCP/OPTIONS: ${e.javaClass.simpleName}: ${e.message}"
            return reply
        }
        try {
            val desc = request(host, port, url, "DESCRIBE", 2)
            reply["describe"] = desc.statusLine
            reply["contentType"] = desc.headers["content-type"] ?: ""
            reply["contentBase"] = desc.headers["content-base"] ?: ""
            reply["codec"] = Regex("a=rtpmap:[^\\s]+", RegexOption.IGNORE_CASE)
                .find(desc.body)?.value ?: ""
            reply["track"] = desc.body.lineSequence()
                .firstOrNull { it.startsWith("a=control:") && it != "a=control:*" } ?: ""
            if (!desc.statusLine.contains("200")) {
                reply["error"] = "RTSP DESCRIBE không thành công: ${desc.statusLine}"
            } else if (reply["codec"].toString().isEmpty()) {
                reply["error"] = "DESCRIBE 200 nhưng SDP không có codec: kiểm tra firmware và session."
            }
        } catch (e: Exception) {
            reply["error"] = "RTSP DESCRIBE: ${e.javaClass.simpleName}: ${e.message}"
        }
        return reply
    }

    private data class Response(
        val statusLine: String,
        val headers: Map<String, String>,
        val body: String
    )

    private fun request(
        host: String,
        port: Int,
        url: String,
        method: String,
        cseq: Int
    ): Response {
        val socket = wifiNetwork.socketFactory.createSocket()
        socket.use { s ->
            s.connect(InetSocketAddress(host, port), 2700)
            s.soTimeout = 3000
            val headers = buildString {
                append("$method $url RTSP/1.0\r\n")
                append("CSeq: $cseq\r\n")
                append("User-Agent: TTX-A500S-RTSP-Probe/1.2\r\n")
                if (method == "DESCRIBE") append("Accept: application/sdp\r\n")
                append("Connection: close\r\n\r\n")
            }
            s.getOutputStream().write(headers.toByteArray(StandardCharsets.US_ASCII))
            s.getOutputStream().flush()
            val input = BufferedInputStream(s.getInputStream())
            val raw = ByteArrayOutputStream()
            var matched = 0
            while (raw.size() < 16384) {
                val n = input.read()
                if (n < 0) break
                raw.write(n)
                matched = if ((matched == 0 || matched == 2) && n == 13) {
                    matched + 1
                } else if ((matched == 1 || matched == 3) && n == 10) {
                    matched + 1
                } else 0
                if (matched == 4) break
            }
            val headerText = raw.toString("ISO-8859-1")
            val rows = headerText.split("\r\n")
            val status = rows.firstOrNull()?.trim() ?: "không có phản hồi"
            val map = mutableMapOf<String, String>()
            rows.drop(1).forEach { row ->
                val i = row.indexOf(':')
                if (i > 0) map[row.substring(0, i).trim().lowercase()] =
                    row.substring(i + 1).trim()
            }
            val size = (map["content-length"]?.toIntOrNull() ?: 0).coerceIn(0, 8192)
            val bytes = ByteArray(size)
            var count = 0
            while (count < size) {
                val n = input.read(bytes, count, size - count)
                if (n < 0) break
                count += n
            }
            Log.i("TTX-RTSP", "$method status=$status content-base=${map["content-base"]}")
            return Response(
                status,
                map,
                String(bytes, 0, count, StandardCharsets.UTF_8)
            )
        }
    }
}
