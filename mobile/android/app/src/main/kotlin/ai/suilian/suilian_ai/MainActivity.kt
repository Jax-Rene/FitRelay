package ai.suilian.suilian_ai

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ai.suilian.suilian_ai/rest_timer",
        ).setMethodCallHandler { call, result ->
            if (call.method != "playCompletionSound") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val tone = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
            tone.startTone(ToneGenerator.TONE_PROP_BEEP2, 900)
            Handler(Looper.getMainLooper()).postDelayed({ tone.release() }, 1000)
            result.success(null)
        }
    }
}
