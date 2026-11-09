package lk.jaypharma.jaypharma

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val KIOSK_CHANNEL = "com.jaypharma.app/kiosk"
    private val BT_CHANNEL = "com.jaypharma.app/bluetooth"
    private val PREFS_NAME = "JayPharmaKiosk"
    private val KEY_KIOSK = "kiosk_enabled"
    private val BT_PERMISSION_REQ_CODE = 4101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Kiosk / Dedicated POS Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KIOSK_CHANNEL).setMethodCallHandler { call, result ->
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

        // 2. Direct Bluetooth POS Printer Helper Channel (Native Fallback & Permission Manager)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBluetoothEnabled" -> {
                    try {
                        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val adapter = bm?.adapter ?: BluetoothAdapter.getDefaultAdapter()
                        result.success(adapter?.isEnabled == true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "hasBluetoothPermissions" -> {
                    result.success(checkBtPermissions())
                }
                "requestBluetoothPermissions" -> {
                    requestBtPermissions()
                    result.success(true)
                }
                "getBondedDevices" -> {
                    try {
                        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val adapter = bm?.adapter ?: BluetoothAdapter.getDefaultAdapter()
                        val list = mutableListOf<Map<String, String>>()
                        val bonded = adapter?.bondedDevices
                        bonded?.forEach { dev ->
                            val devName = try {
                                val n = dev.name
                                if (!n.isNullOrBlank()) n else "Bluetooth Device"
                            } catch (_: Exception) {
                                "Bluetooth Device"
                            }
                            list.add(mapOf(
                                "name" to devName,
                                "address" to dev.address
                            ))
                        }
                        result.success(list)
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, String>>())
                    }
                }
                "scanNearbyDevices" -> {
                    try {
                        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val adapter = bm?.adapter ?: BluetoothAdapter.getDefaultAdapter()
                        val list = mutableListOf<Map<String, String>>()

                        // 1. Bonded devices first
                        adapter?.bondedDevices?.forEach { dev ->
                            val n = try { dev.name?.takeIf { it.isNotBlank() } ?: "Bluetooth Device" } catch (_: Exception) { "Bluetooth Device" }
                            list.add(mapOf("name" to n, "address" to dev.address))
                        }

                        // 2. Discover nearby broadcasting Bluetooth devices
                        if (adapter != null && adapter.isEnabled) {
                            val discovered = mutableListOf<Map<String, String>>()
                            val receiver = object : BroadcastReceiver() {
                                override fun onReceive(c: Context?, intent: Intent?) {
                                    if (BluetoothDevice.ACTION_FOUND == intent?.action) {
                                        val dev = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                                        } else {
                                            @Suppress("DEPRECATION")
                                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                                        }
                                        if (dev != null) {
                                            val name = try { dev.name?.takeIf { it.isNotBlank() } ?: "Nearby Printer" } catch (_: Exception) { "Nearby Printer" }
                                            val addr = dev.address
                                            if (!addr.isNullOrBlank() && list.none { it["address"] == addr } && discovered.none { it["address"] == addr }) {
                                                discovered.add(mapOf("name" to name, "address" to addr))
                                            }
                                        }
                                    }
                                }
                            }
                            registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_FOUND))
                            adapter.startDiscovery()

                            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                try {
                                    adapter.cancelDiscovery()
                                    unregisterReceiver(receiver)
                                } catch (_: Exception) {}
                                list.addAll(discovered)
                                result.success(list)
                            }, 3500)
                            return@setMethodCallHandler
                        }
                        result.success(list)
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, String>>())
                    }
                }
                "openBluetoothSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkBtPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestBtPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.BLUETOOTH_SCAN
                ),
                BT_PERMISSION_REQ_CODE
            )
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.BLUETOOTH,
                    Manifest.permission.BLUETOOTH_ADMIN,
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ),
                BT_PERMISSION_REQ_CODE
            )
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
