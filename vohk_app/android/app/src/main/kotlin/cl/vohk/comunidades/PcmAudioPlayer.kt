package cl.vohk.comunidades

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ArrayBlockingQueue
import kotlin.concurrent.thread

class PcmAudioPlayer(context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "cl.vohk.comunidades/intercom_pcm_player"
        private const val QUEUE_CAPACITY = 32
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val audioQueue = ArrayBlockingQueue<ByteArray>(QUEUE_CAPACITY)
    private var audioTrack: AudioTrack? = null
    private var worker: Thread? = null
    private var previousAudioMode: Int? = null
    private var previousSpeakerphone: Boolean? = null

    @Volatile
    private var running = false

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "open" -> {
                    val sampleRate = call.argument<Int>("sampleRate") ?: 8000
                    open(sampleRate)
                    result.success(null)
                }

                "write" -> {
                    val pcm = call.arguments as? ByteArray
                    if (pcm == null || !running) {
                        result.success(false)
                    } else {
                        if (!audioQueue.offer(pcm.copyOf())) {
                            audioQueue.poll()
                            audioQueue.offer(pcm.copyOf())
                        }
                        result.success(true)
                    }
                }

                "close" -> {
                    close()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("PCM_PLAYER", error.message, null)
        }
    }

    private fun open(sampleRate: Int) {
        close()

        val channelMask = AudioFormat.CHANNEL_OUT_MONO
        val encoding = AudioFormat.ENCODING_PCM_16BIT
        val minimumSize = AudioTrack.getMinBufferSize(sampleRate, channelMask, encoding)
        require(minimumSize > 0) { "Unsupported PCM format: $sampleRate Hz mono" }
        val bufferSize = maxOf(minimumSize, 4096)

        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val format = AudioFormat.Builder()
            .setEncoding(encoding)
            .setSampleRate(sampleRate)
            .setChannelMask(channelMask)
            .build()

        val track = AudioTrack(
            attributes,
            format,
            bufferSize,
            AudioTrack.MODE_STREAM,
            AudioManager.AUDIO_SESSION_ID_GENERATE,
        )
        check(track.state == AudioTrack.STATE_INITIALIZED) { "Android could not initialize PCM playback" }

        previousAudioMode = audioManager.mode
        previousSpeakerphone = audioManager.isSpeakerphoneOn
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        audioManager.isSpeakerphoneOn = true

        audioTrack = track
        running = true
        track.play()
        worker = thread(start = true, isDaemon = true, name = "intercom-pcm-player") {
            while (running) {
                try {
                    val pcm = audioQueue.take()
                    var offset = 0
                    while (running && offset < pcm.size) {
                        val written = track.write(pcm, offset, pcm.size - offset, AudioTrack.WRITE_BLOCKING)
                        if (written <= 0) break
                        offset += written
                    }
                } catch (_: InterruptedException) {
                    break
                } catch (_: IllegalStateException) {
                    break
                }
            }
        }
    }

    fun close() {
        running = false
        audioQueue.clear()
        worker?.interrupt()
        worker = null

        audioTrack?.let { track ->
            runCatching { track.pause() }
            runCatching { track.flush() }
            runCatching { track.stop() }
            runCatching { track.release() }
        }
        audioTrack = null

        previousSpeakerphone?.let { audioManager.isSpeakerphoneOn = it }
        previousAudioMode?.let { audioManager.mode = it }
        previousSpeakerphone = null
        previousAudioMode = null
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        close()
    }
}
