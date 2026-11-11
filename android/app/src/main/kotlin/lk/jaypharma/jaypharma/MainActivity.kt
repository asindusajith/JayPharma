package lk.jaypharma.jaypharma

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import java.io.OutputStream
import java.util.UUID
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

    // Persistent RFCOMM Bluetooth POS Socket Cache
    private var printerSocket: BluetoothSocket? = null
    private var printerOutputStream: OutputStream? = null
    private var connectedAddress: String? = null

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
                "cancelDiscovery" -> {
                    try {
                        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val adapter = bm?.adapter ?: BluetoothAdapter.getDefaultAdapter()
                        adapter?.cancelDiscovery()
                        result.success(true)
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
                    val list = mutableListOf<Map<String, String>>()
                    try {
                        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val adapter = bm?.adapter ?: BluetoothAdapter.getDefaultAdapter()
                        adapter?.bondedDevices?.forEach { dev ->
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
                    } catch (e: Exception) {
                        android.util.Log.w("JayPharmaBT", "getBondedDevices error: ${e.message}")
                    }
                    result.success(list)
                }
                "scanNearbyDevices" -> {
                    val list = mutableListOf<Map<String, String>>()
                    val discovered = mutableListOf<Map<String, String>>()
                    try {
                        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val adapter = bm?.adapter ?: BluetoothAdapter.getDefaultAdapter()

                        // 1. Bonded devices first
                        try {
                            adapter?.bondedDevices?.forEach { dev ->
                                val n = try { dev.name?.takeIf { it.isNotBlank() } ?: "Bluetooth Device" } catch (_: Exception) { "Bluetooth Device" }
                                val addr = dev.address
                                if (!addr.isNullOrBlank() && list.none { it["address"] == addr }) {
                                    list.add(mapOf("name" to n, "address" to addr))
                                }
                            }
                        } catch (e: Exception) {
                            android.util.Log.w("JayPharmaBT", "Error reading bonded devices: ${e.message}")
                        }

                        // 2. Discover nearby broadcasting Bluetooth devices (Classic + BLE)
                        if (adapter != null && adapter.isEnabled) {
                            var receiverRegistered = false
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

                            val leCallback = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                object : android.bluetooth.le.ScanCallback() {
                                    override fun onScanResult(callbackType: Int, scanResult: android.bluetooth.le.ScanResult?) {
                                        val dev = scanResult?.device ?: return
                                        val name = try {
                                            val rawName = dev.name ?: scanResult.scanRecord?.deviceName
                                            if (!rawName.isNullOrBlank()) rawName else "BLE Printer"
                                        } catch (_: Exception) { "BLE Printer" }
                                        val addr = dev.address
                                        if (!addr.isNullOrBlank() && list.none { it["address"] == addr } && discovered.none { it["address"] == addr }) {
                                            discovered.add(mapOf("name" to name, "address" to addr))
                                        }
                                    }
                                }
                            } else null

                            try {
                                registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_FOUND))
                                receiverRegistered = true
                                try { adapter.cancelDiscovery() } catch (_: Exception) {}
                                adapter.startDiscovery()
                            } catch (e: Exception) {
                                android.util.Log.w("JayPharmaBT", "startDiscovery failed: ${e.message}")
                            }

                            try {
                                if (leCallback != null) {
                                    adapter.bluetoothLeScanner?.startScan(leCallback)
                                }
                            } catch (e: Exception) {
                                android.util.Log.w("JayPharmaBT", "BLE scan failed: ${e.message}")
                            }

                            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                try {
                                    adapter.cancelDiscovery()
                                } catch (_: Exception) {}
                                if (receiverRegistered) {
                                    try {
                                        unregisterReceiver(receiver)
                                    } catch (_: Exception) {}
                                }
                                try {
                                    if (leCallback != null) {
                                        adapter.bluetoothLeScanner?.stopScan(leCallback)
                                    }
                                } catch (_: Exception) {}

                                list.addAll(discovered)
                                result.success(list)
                            }, 3500)
                            return@setMethodCallHandler
                        }
                        result.success(list)
                    } catch (e: Exception) {
                        result.success(list)
                    }
                }
                "pairDevice" -> {
                    val addr = call.argument<String>("address")
                    if (addr.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        try {
                            val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                            val adapter = bm?.adapter ?: BluetoothAdapter.getDefaultAdapter()
                            val dev = adapter?.getRemoteDevice(addr)
                            val ok = dev?.createBond() ?: false
                            result.success(ok)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = android.net.Uri.fromParts("package", packageName, null)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
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
                "isPrinterConnected" -> {
                    val isConn = printerSocket?.isConnected == true && printerOutputStream != null
                    result.success(isConn)
                }
                "connectPrinter" -> {
                    val addr = call.argument<String>("address")
                    Thread {
                        var success = false
                        try {
                            val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                            val adapter = bm?.adapter ?: BluetoothAdapter.getDefaultAdapter()
                            if (adapter != null && adapter.isEnabled) {
                                var targetAddress = addr
                                if (targetAddress.isNullOrBlank()) {
                                    val bonded = adapter.bondedDevices
                                    val printer = bonded?.firstOrNull { dev ->
                                        val n = (dev.name ?: "").uppercase()
                                        n.contains("MTP") || n.contains("POS") || n.contains("RPP") || n.contains("PRINT") || n.contains("THERMAL")
                                    } ?: bonded?.firstOrNull()
                                    targetAddress = printer?.address
                                }

                                if (!targetAddress.isNullOrBlank()) {
                                    if (printerSocket?.isConnected == true && connectedAddress == targetAddress) {
                                        runOnUiThread { result.success(true) }
                                        return@Thread
                                    }

                                    try { printerSocket?.close() } catch (_: Exception) {}
                                    val device = adapter.getRemoteDevice(targetAddress)
                                    try { adapter.cancelDiscovery() } catch (_: Exception) {}

                                    var socket: BluetoothSocket? = null
                                    try {
                                        val sppUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
                                        socket = device.createRfcommSocketToServiceRecord(sppUuid)
                                        socket.connect()
                                    } catch (_: Exception) {
                                        socket = null
                                    }

                                    if (socket == null || !socket.isConnected) {
                                        try {
                                            val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                                            socket = m.invoke(device, 1) as BluetoothSocket
                                            socket.connect()
                                        } catch (_: Exception) {
                                            socket = null
                                        }
                                    }

                                    if (socket != null && socket.isConnected) {
                                        printerSocket = socket
                                        printerOutputStream = socket.outputStream
                                        connectedAddress = targetAddress
                                        success = true
                                    }
                                }
                            }
                        } catch (_: Exception) {
                            success = false
                        }
                        runOnUiThread { result.success(success) }
                    }.start()
                }
                "disconnectPrinter" -> {
                    try {
                        printerOutputStream?.close()
                        printerSocket?.close()
                    } catch (_: Exception) {}
                    printerOutputStream = null
                    printerSocket = null
                    connectedAddress = null
                    result.success(true)
                }
                "printRawBytes" -> {
                    val addr = call.argument<String>("address")
                    val rawBytes: ByteArray? = when (val b = call.argument<Any>("bytes")) {
                        is ByteArray -> b
                        is List<*> -> {
                            val arr = ByteArray(b.size)
                            for (i in b.indices) {
                                arr[i] = ((b[i] as? Number)?.toInt() ?: 0).toByte()
                            }
                            arr
                        }
                        else -> null
                    }

                    if (rawBytes == null || rawBytes.isEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    Thread {
                        var success = false
                        try {
                            val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                            val adapter = bm?.adapter ?: BluetoothAdapter.getDefaultAdapter()
                            if (adapter == null || !adapter.isEnabled) {
                                runOnUiThread { result.success(false) }
                                return@Thread
                            }

                            var targetAddress = addr
                            if (targetAddress.isNullOrBlank()) {
                                val bonded = adapter.bondedDevices
                                val printer = bonded?.firstOrNull { dev ->
                                    val n = (dev.name ?: "").uppercase()
                                    n.contains("MTP") || n.contains("POS") || n.contains("RPP") || n.contains("PRINT") || n.contains("THERMAL")
                                } ?: bonded?.firstOrNull()
                                targetAddress = printer?.address
                            }

                            if (targetAddress.isNullOrBlank()) {
                                runOnUiThread { result.success(false) }
                                return@Thread
                            }

                            // 1. If existing socket is open to target address, write directly
                            if (printerSocket?.isConnected == true && printerOutputStream != null && connectedAddress == targetAddress) {
                                try {
                                    printerOutputStream?.write(rawBytes)
                                    printerOutputStream?.flush()
                                    success = true
                                } catch (e: Exception) {
                                    try { printerSocket?.close() } catch (_: Exception) {}
                                    printerSocket = null
                                    printerOutputStream = null
                                    connectedAddress = null
                                }
                            }

                            // 2. Open new RFCOMM connection if not already written
                            if (!success) {
                                val device = adapter.getRemoteDevice(targetAddress)
                                try { adapter.cancelDiscovery() } catch (_: Exception) {}

                                var socket: BluetoothSocket? = null
                                // Attempt 1: Standard SPP UUID
                                try {
                                    val sppUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
                                    socket = device.createRfcommSocketToServiceRecord(sppUuid)
                                    socket.connect()
                                } catch (e1: Exception) {
                                    socket = null
                                }

                                // Attempt 2: Channel 1 Reflection (Universal for portable Chinese POS/MTP thermal printers)
                                if (socket == null || !socket.isConnected) {
                                    try {
                                        val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                                        socket = m.invoke(device, 1) as BluetoothSocket
                                        socket.connect()
                                    } catch (e2: Exception) {
                                        socket = null
                                    }
                                }

                                if (socket != null && socket.isConnected) {
                                    val stream = socket.outputStream
                                    stream.write(rawBytes)
                                    stream.flush()

                                    // Cache connection for instant successive prints
                                    printerSocket = socket
                                    printerOutputStream = stream
                                    connectedAddress = targetAddress
                                    success = true
                                }
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("JayPharmaBT", "printRawBytes error: ${e.message}")
                            try { printerSocket?.close() } catch (_: Exception) {}
                            printerSocket = null
                            printerOutputStream = null
                            connectedAddress = null
                            success = false
                        }
                        runOnUiThread { result.success(success) }
                    }.start()
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
                    Manifest.permission.BLUETOOTH_SCAN,
                    Manifest.permission.ACCESS_FINE_LOCATION
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
