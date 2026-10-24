package app.work_time_manager

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Vor `super`: das quick_actions-Plugin liest den Start-Intent beim Anbinden.
        AssistantTimerIntent.normalize(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        AssistantTimerIntent.normalize(intent)
        super.onNewIntent(intent)
    }
}
