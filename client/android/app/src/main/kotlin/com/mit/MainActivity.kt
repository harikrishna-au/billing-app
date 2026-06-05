package com.mit

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.util.Log
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import com.zcs.sdk.DriverManager
import com.zcs.sdk.Printer
import com.zcs.sdk.Sys
import com.zcs.sdk.SdkResult
import com.zcs.sdk.print.PrnStrFormat
import com.zcs.sdk.print.PrnTextStyle
import android.text.Layout
import android.os.Build
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val PRINTER_CHANNEL = "com.smartpos.sdk/printer"
    private val PLUTUS_CHANNEL = "PLUTUS-API"

    // Plutus Smart (MasterApp) integration constants (Hybrid Intent flow)
    private val PLUTUS_SMART_ACTION = "com.pinelabs.masterapp.SERVER"
    private val PLUTUS_SMART_PACKAGE = "com.pinelabs.masterapp"
    private val PLUTUS_HYBRID_ACTION = "com.pinelabs.masterapp.HYBRID_REQUEST"
    private val PLUTUS_REQUEST_KEY = "REQUEST_DATA"
    private val PLUTUS_RESPONSE_KEY = "RESPONSE_DATA"

    private lateinit var mDriverManager: DriverManager
    private lateinit var mSys: Sys
    private lateinit var mPrinter: Printer
    private var isSdkInitialized = false
    private val executor = Executors.newSingleThreadExecutor()

    // Plutus service bind state (some terminals require bind before hybrid intent)
    private var isPlutusServiceBound = false
    private var plutusBinder: IBinder? = null
    private var pendingPlutusBindResult: Result? = null
    private var pendingPlutusResult: Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val plutusBindTimeout = Runnable {
        pendingPlutusBindResult?.let { pending ->
            pendingPlutusBindResult = null
            pending.error("SERVICE_NOT_BOUND", "Pine Labs service did not connect within 3 seconds", null)
        }
    }

    private val plutusServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            Log.d("Plutus", "Service connected: $name")
            plutusBinder = service
            isPlutusServiceBound = true
            mainHandler.removeCallbacks(plutusBindTimeout)
            pendingPlutusBindResult?.success("SERVICE_CONNECTED")
            pendingPlutusBindResult = null
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            Log.d("Plutus", "Service disconnected: $name")
            plutusBinder = null
            isPlutusServiceBound = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Printer channel (existing) ───────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRINTER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initSdk" -> {
                    executor.execute {
                        initSdk()
                        runOnUiThread {
                            if (isSdkInitialized) {
                                result.success("SDK Initialized Successfully")
                            } else {
                                result.error("SDK_INIT_FAILED", "Failed to initialize SDK", null)
                            }
                        }
                    }
                }
                "printText" -> {
                    val text = call.argument<String>("text")
                    val size = call.argument<Int>("size") ?: 24
                    val isBold = call.argument<Boolean>("isBold") ?: false
                    val align = call.argument<Int>("align") ?: 0

                    executor.execute {
                        if (!isSdkInitialized) initSdk()
                        if (!isSdkInitialized) {
                            runOnUiThread {
                                result.error("SDK_NOT_INIT", "SDK not initialized", null)
                            }
                            return@execute
                        }
                        val printStatus = printText(text, size, isBold, align)
                        runOnUiThread {
                            if (printStatus == SdkResult.SDK_OK) {
                                result.success("Printed Successfully")
                            } else {
                                result.error("PRINT_FAILED", "Printing failed with status: $printStatus", null)
                            }
                        }
                    }
                }
                "cutPaper" -> {
                    executor.execute {
                        if (!isSdkInitialized) initSdk()
                        runOnUiThread {
                            if (!isSdkInitialized || !::mPrinter.isInitialized) {
                                result.error("SDK_NOT_INIT", "SDK not initialized", null)
                                return@runOnUiThread
                            }
                            mPrinter.openPrnCutter(1.toByte())
                            result.success(true)
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // ── Plutus Smart channel (new) ──────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLUTUS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "bindToService" -> bindToPlutusService(result)
                "startTransaction" -> {
                    val payload = call.argument<String>("transactionData")
                    if (payload.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Missing transactionData", null)
                        return@setMethodCallHandler
                    }
                    startPlutusIntent(payload, requestCode = 1001, result = result)
                }
                "startPrintJob" -> {
                    val payload = call.argument<String>("printData")
                    if (payload.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Missing printData", null)
                        return@setMethodCallHandler
                    }
                    startPlutusIntent(payload, requestCode = 1002, result = result)
                }
                "getTerminalInfo" -> {
                    result.success(readTerminalInfoMap())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun bindToPlutusService(result: Result) {
        try {
            if (!isPlutusMasterAppInstalled()) {
                result.error("PLUTUS_NOT_INSTALLED", "Pine Labs MasterApp is not installed on this terminal", null)
                return
            }
            if (isPlutusServiceBound) {
                result.success("SERVICE_CONNECTED")
                return
            }
            if (pendingPlutusBindResult != null) {
                result.error("BIND_IN_PROGRESS", "Pine Labs service binding is already in progress", null)
                return
            }
            val intent = Intent().apply {
                action = PLUTUS_SMART_ACTION
                setPackage(PLUTUS_SMART_PACKAGE)
            }
            pendingPlutusBindResult = result
            val ok = bindService(intent, plutusServiceConnection, Context.BIND_AUTO_CREATE)
            if (ok) {
                mainHandler.postDelayed(plutusBindTimeout, 3000)
            } else {
                pendingPlutusBindResult = null
                result.error("BIND_FAILED", "Failed to initiate service binding", null)
            }
        } catch (e: Exception) {
            pendingPlutusBindResult = null
            result.error("BINDING_ERROR", e.localizedMessage, null)
        }
    }

    private fun startPlutusIntent(payload: String, requestCode: Int, result: Result) {
        try {
            if (!isPlutusMasterAppInstalled()) {
                result.error("PLUTUS_NOT_INSTALLED", "Pine Labs MasterApp is not installed on this terminal", null)
                return
            }
            if (!isPlutusServiceBound) {
                result.error("SERVICE_NOT_BOUND", "Pine Labs service is not connected. Bind before sending HYBRID_REQUEST.", null)
                return
            }
            // Only allow one pending request at a time (same pattern as the sample repo).
            if (pendingPlutusResult != null) {
                result.error("BUSY", "Another Plutus request is already in progress", null)
                return
            }
            pendingPlutusResult = result

            val intent = Intent(PLUTUS_HYBRID_ACTION).apply {
                setPackage(PLUTUS_SMART_PACKAGE)
                putExtra(PLUTUS_REQUEST_KEY, payload)
                // Some builds read the caller package name explicitly.
                putExtra("packageName", applicationContext.packageName)
            }
            startActivityForResult(intent, requestCode)
        } catch (e: Exception) {
            pendingPlutusResult = null
            result.error("PLUTUS_INTENT_ERROR", e.localizedMessage, null)
        }
    }

    private fun readTerminalInfoMap(): Map<String, String> {
        val serial = readHardwareSerial()
        return mapOf(
            "serial" to serial,
            "model" to (Build.MODEL ?: ""),
            "manufacturer" to (Build.MANUFACTURER ?: ""),
            "paydroidVersion" to readSystemProperty("ro.build.display.id"),
        )
    }

    private fun readHardwareSerial(): String {
        val fromProp = readSystemProperty("ro.serialno")
        if (fromProp.isNotBlank() && fromProp != "unknown") return fromProp
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Build.getSerial()
            } else {
                @Suppress("DEPRECATION")
                Build.SERIAL
            }
        } catch (_: Exception) {
            ""
        }
    }

    private fun readSystemProperty(key: String): String {
        return try {
            val clazz = Class.forName("android.os.SystemProperties")
            val get = clazz.getMethod("get", String::class.java)
            (get.invoke(null, key) as? String).orEmpty()
        } catch (_: Exception) {
            ""
        }
    }

    private fun isPlutusMasterAppInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo(PLUTUS_SMART_PACKAGE, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun initSdk() {
        if (isSdkInitialized) return

        mDriverManager = DriverManager.getInstance()
        mSys = mDriverManager.baseSysDevice

        // Power on the printer hardware first, then wait for UART to become ready.
        mSys.sysPowerOn()
        try { Thread.sleep(2000) } catch (e: InterruptedException) { e.printStackTrace() }

        var status = mSys.sdkInit()
        if (status != SdkResult.SDK_OK) {
            // One more retry after an additional wait.
            try { Thread.sleep(1500) } catch (e: InterruptedException) { e.printStackTrace() }
            status = mSys.sdkInit()
        }

        if (status == SdkResult.SDK_OK) {
            isSdkInitialized = true
            mPrinter = mDriverManager.printer
        } else {
            Log.e("SmartPos", "Failed to init SDK: $status")
        }
    }

    private fun printText(text: String?, size: Int, isBold: Boolean, align: Int): Int {
        if (text == null) return -1

        var printStatus = mPrinter.printerStatus
        if (printStatus == SdkResult.SDK_PRN_STATUS_PAPEROUT) {
            return SdkResult.SDK_PRN_STATUS_PAPEROUT
        }

        val format = PrnStrFormat()
        format.textSize = size
        format.style = if (isBold) PrnTextStyle.BOLD else PrnTextStyle.NORMAL

        when (align) {
            0 -> format.ali = Layout.Alignment.ALIGN_NORMAL
            1 -> format.ali = Layout.Alignment.ALIGN_CENTER
            2 -> format.ali = Layout.Alignment.ALIGN_OPPOSITE
            else -> format.ali = Layout.Alignment.ALIGN_NORMAL
        }

        mPrinter.setPrintAppendString(text, format)
        printStatus = mPrinter.setPrintStart()
        return printStatus
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 1001 && requestCode != 1002) return

        val pending = pendingPlutusResult ?: return
        try {
            if (resultCode == RESULT_OK && data != null) {
                val responseData = data.getStringExtra(PLUTUS_RESPONSE_KEY)
                pending.success(responseData)
            } else {
                val msg = if (requestCode == 1001) "Transaction failed" else "Print job failed"
                pending.error("FAILED", msg, null)
            }
        } catch (e: Exception) {
            pending.error("ERROR", e.localizedMessage, null)
        } finally {
            pendingPlutusResult = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isPlutusServiceBound) {
            unbindService(plutusServiceConnection)
            isPlutusServiceBound = false
        }
    }
}
