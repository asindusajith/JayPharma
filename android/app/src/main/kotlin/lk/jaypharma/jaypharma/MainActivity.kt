package lk.jaypharma.jaypharma

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.jaypharma.app/kiosk"
    private val PREFS_NAME = "JayPharmaKiosk"
    private val KEY_KIOSK = "kiosk_enabled"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableAppLock" -> {
                    val success = setKioskMode(true)
                    result.success(success)
                }
                "disableAppLock" -> {
                    val success = setKioskMode(false)
                    result.success(success)
                }
                "isAppLockEnabled" -> {
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    result.success(prefs.getBoolean(KEY_KIOSK, false))
                }
                "openHomeSettings" -> {
                    openHomeSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_KIOSK, false)) {
            try {
                startLockTask()
            } catch (e: Exception) {
                // Pinning might require device confirmation or root/admin
            }
        }
    }

    private fun setKioskMode(enable: Boolean): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_KIOSK, enable).apply()

        // 1. Enable or Disable Home Launcher component alias
        try {
            val component = ComponentName(this, "lk.jaypharma.jaypharma.KioskHomeLauncher")
            val state = if (enable) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            packageManager.setComponentEnabledSetting(component, state, PackageManager.DONT_KILL_APP)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 2. Start or Stop Screen Pinning (Lock Task Mode)
        try {
            if (enable) {
                startLockTask()
            } else {
                stopLockTask()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return true
    }

    private fun openHomeSettings() {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
            } else {
                Intent(Settings.ACTION_HOME_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            } catch (e2: Exception) {
                e2.printStackTrace()
            }
        }
    }
}
