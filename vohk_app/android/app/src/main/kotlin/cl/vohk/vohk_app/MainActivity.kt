package cl.vohk.vohk_app

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import com.twilio.twilio_voice.service.TVConnectionService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "VohkMainActivity"
        private const val CHANNEL = "cl.vohk.vohk_app/incoming_call"
        private const val METHOD_CONSUME_PENDING =
            "consumePendingIncomingCall"
        private const val METHOD_INCOMING_CALL_OPENED =
            "incomingCallOpened"
    }

    private var incomingCallChannel: MethodChannel? = null
    private var pendingIncomingCall: HashMap<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        pendingIncomingCall = payloadFromIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        incomingCallChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_CONSUME_PENDING -> {
                        val payload = pendingIncomingCall
                        pendingIncomingCall = null
                        result.success(payload)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val payload = payloadFromIntent(intent) ?: return
        pendingIncomingCall = payload

        incomingCallChannel?.invokeMethod(
            METHOD_INCOMING_CALL_OPENED,
            payload,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (pendingIncomingCall == payload) {
                        pendingIncomingCall = null
                    }
                }

                override fun error(
                    errorCode: String,
                    errorMessage: String?,
                    errorDetails: Any?,
                ) {
                    Log.e(
                        TAG,
                        "Unable to deliver incoming call: $errorCode $errorMessage",
                    )
                }

                override fun notImplemented() {
                    Log.w(
                        TAG,
                        "Flutter incoming-call handler is not ready.",
                    )
                }
            },
        )
    }

    private fun payloadFromIntent(
        intent: Intent?,
    ): HashMap<String, String>? {
        if (
            intent?.action !=
            TVConnectionService.ACTION_OPEN_INCOMING_CALL
        ) {
            return null
        }

        val callSid = intent.getStringExtra(
            TVConnectionService.EXTRA_CALL_HANDLE
        )

        val payload = hashMapOf<String, String>()

        if (!callSid.isNullOrBlank()) {
            payload["call_sid"] = callSid
        }

        intent.extras?.keySet()?.forEach { key ->
            val value = intent.extras?.get(key)
            if (value is String && value.isNotBlank()) {
                payload[key] = value
            }
        }

        if (payload.isEmpty()) {
            return null
        }

        return payload
    }
}