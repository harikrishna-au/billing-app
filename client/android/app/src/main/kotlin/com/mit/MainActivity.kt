package com.mit

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.RemoteException
import android.text.Layout
import android.util.Log
import android.os.Build
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
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    // ── Channel names ────────────────────────────────────────────────────────
    private val PRINTER_CHANNEL = "com.smartpos.sdk/printer"
    private val PLUTUS_CHANNEL  = "PLUTUS-API"

    // ── Pine Labs MasterApp constants ────────────────────────────────────────
    private val PLUTUS_SMART_ACTION  = "com.pinelabs.masterapp.SERVER"
    private val PLUTUS_SMART_PACKAGE = "com.pinelabs.masterapp"
    private val REQUEST_KEY          = "MASTERAPPREQUEST"
    private val RESPONSE_KEY         = "MASTERAPPRESPONSE"
    private val MSG_CODE             = 1001   // Pine Labs Messenger message code

    // ── SmartPOS direct-printer state ────────────────────────────────────────
    private lateinit var mDriverManager: DriverManager
    private lateinit var mSys: Sys
    private lateinit var mPrinter: Printer
    private var isSdkInitialized = false
    private val executor = Executors.newSingleThreadExecutor()

    // ── Active Plutus Messenger request ─────────────────────────────────────
    // Only one request (transaction OR print) is allowed at a time.
    private var pendingResult:   Result? = null
    private var pendingPayload:  String? = null
    private var pendingLabel:    String  = ""
    private var mServerMessenger: Messenger? = null
    private var isServiceBound = false

    // ── Per-request ServiceConnection ───────────────────────────────────────
    // A fresh connection is created for every transaction / print call so there
    // is no stale-binding risk between calls (mirrors the reference sample exactly).
    private var activeServiceConnection: ServiceConnection? = null

    private fun buildServiceConnection(): ServiceConnection {
        return object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
                Log.d("Plutus", "MASTERAPP service connected ($pendingLabel)")
                mServerMessenger = Messenger(service)
                isServiceBound   = true

                val payload = pendingPayload
                val pending = pendingResult
                if (payload != null && pending != null) {
                    sendViaMessenger(payload, pending)
                } else {
                    Log.w("Plutus", "Service connected but no pending request — unbinding")
                    pending?.error("NO_PAYLOAD", "No payload queued", null)
                    resetAndUnbind()
                }
            }

            override fun onServiceDisconnected(name: ComponentName?) {
                Log.d("Plutus", "MASTERAPP service disconnected ($pendingLabel)")
                mServerMessenger = null
                isServiceBound   = false
            }
        }
    }

    // ── Incoming response handler ─────────────────────────────────────────────
    private inner class PlutusResponseHandler : Handler(Looper.getMainLooper()) {
        override fun handleMessage(msg: Message) {
            val value = msg.data.getString(RESPONSE_KEY)
            Log.d("Plutus", "MASTERAPPRESPONSE ($pendingLabel): $value")

            val pending = pendingResult
            resetAndUnbind()

            if (pending == null) {
                Log.w("Plutus", "MASTERAPPRESPONSE: no pending result to resolve — ignored")
                return
            }
            if (value.isNullOrBlank()) {
                Log.w("Plutus", "MASTERAPPRESPONSE: empty — MasterApp may have failed")
                pending.error("EMPTY_RESPONSE", "MasterApp returned empty response for $pendingLabel", null)
            } else {
                pending.success(value)
            }
        }
    }

    // ── Core Messenger send ───────────────────────────────────────────────────
    private fun sendViaMessenger(payload: String, result: Result) {
        val server = mServerMessenger
        if (server == null) {
            result.error("NO_MESSENGER", "Server messenger is null", null)
            resetAndUnbind()
            return
        }
        try {
            Log.d("Plutus", "MASTERAPPREQUEST ($pendingLabel): $payload")
            val msg = Message.obtain(null, MSG_CODE)
            val data = Bundle()
            data.putString(REQUEST_KEY, payload)
            msg.data    = data
            msg.replyTo = Messenger(PlutusResponseHandler())
            server.send(msg)
        } catch (e: RemoteException) {
            Log.e("Plutus", "Messenger send failed", e)
            result.error("SEND_FAILED", e.localizedMessage, null)
            resetAndUnbind()
        }
    }

    // ── Start a Messenger request (transaction or print) ──────────────────────
    private fun startMessengerRequest(payload: String, label: String, result: Result) {
        if (!isPlutusMasterAppInstalled()) {
            result.error("PLUTUS_NOT_INSTALLED", "Pine Labs MasterApp is not installed", null)
            return
        }
        if (pendingResult != null) {
            result.error("BUSY", "Another Plutus request ($pendingLabel) is already in progress", null)
            return
        }

        pendingResult  = result
        pendingPayload = payload
        pendingLabel   = label

        val conn = buildServiceConnection()
        activeServiceConnection = conn

        val intent = Intent().apply {
            action = PLUTUS_SMART_ACTION
            setPackage(PLUTUS_SMART_PACKAGE)
        }
        Log.d("Plutus", "Binding MasterApp service for $label")
        val ok = bindService(intent, conn, Context.BIND_AUTO_CREATE)
        if (!ok) {
            Log.e("Plutus", "bindService returned false for $label")
            result.error("BIND_FAILED", "Could not bind to Pine Labs MasterApp", null)
            resetAndUnbind()
        }
    }

    private fun resetAndUnbind() {
        pendingResult  = null
        pendingPayload = null
        pendingLabel   = ""
        mServerMessenger = null
        if (isServiceBound) {
            activeServiceConnection?.let {
                try { unbindService(it) } catch (_: Exception) {}
            }
            isServiceBound = false
        }
        activeServiceConnection = null
    }

    // ── Flutter engine setup ──────────────────────────────────────────────────
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── SmartPOS direct printer channel ──────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRINTER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initSdk" -> {
                        executor.execute {
                            initSdk()
                            runOnUiThread {
                                if (isSdkInitialized)
                                    result.success("SDK Initialized Successfully")
                                else
                                    result.error("SDK_INIT_FAILED", "Failed to initialize SDK", null)
                            }
                        }
                    }
                    "printText" -> {
                        val text   = call.argument<String>("text")
                        val size   = call.argument<Int>("size") ?: 24
                        val isBold = call.argument<Boolean>("isBold") ?: false
                        val align  = call.argument<Int>("align") ?: 0
                        executor.execute {
                            if (!isSdkInitialized) initSdk()
                            if (!isSdkInitialized) {
                                runOnUiThread {
                                    result.error("SDK_NOT_INIT", "SDK not initialized", null)
                                }
                                return@execute
                            }
                            val status = printText(text, size, isBold, align)
                            runOnUiThread {
                                if (status == SdkResult.SDK_OK)
                                    result.success("Printed Successfully")
                                else
                                    result.error("PRINT_FAILED", "Status: $status", null)
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
                    else -> result.notImplemented()
                }
            }

        // ── Pine Labs Plutus channel ──────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLUTUS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // Warm-up bind — Flutter calls this before a transaction/print
                    // to establish the service connection early. We reuse the same
                    // Messenger IPC flow: bind → resolve immediately on connect.
                    "bindToService" -> {
                        if (!isPlutusMasterAppInstalled()) {
                            result.error("PLUTUS_NOT_INSTALLED", "Pine Labs MasterApp not installed", null)
                            return@setMethodCallHandler
                        }
                        // Bind a temporary connection just to warm up; resolve as soon
                        // as onServiceConnected fires, then unbind immediately.
                        val warmupConn = object : ServiceConnection {
                            override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
                                Log.d("Plutus", "Warm-up bind connected")
                                result.success("SERVICE_CONNECTED")
                                try { unbindService(this) } catch (_: Exception) {}
                            }
                            override fun onServiceDisconnected(name: ComponentName?) {}
                        }
                        val intent = Intent().apply {
                            action = PLUTUS_SMART_ACTION
                            setPackage(PLUTUS_SMART_PACKAGE)
                        }
                        val ok = bindService(intent, warmupConn, Context.BIND_AUTO_CREATE)
                        if (!ok) {
                            Log.w("Plutus", "Warm-up bind failed — non-fatal")
                            result.success("SERVICE_TIMEOUT")
                        }
                    }

                    "startTransaction" -> {
                        val payload = call.argument<String>("transactionData")
                        if (payload.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing transactionData", null)
                            return@setMethodCallHandler
                        }
                        startMessengerRequest(payload, "transaction", result)
                    }

                    "startPrintJob" -> {
                        val payload = call.argument<String>("printData")
                        if (payload.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing printData", null)
                            return@setMethodCallHandler
                        }
                        startMessengerRequest(payload, "print", result)
                    }

                    "getTerminalInfo" -> result.success(readTerminalInfoMap())

                    else -> result.notImplemented()
                }
            }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun isPlutusMasterAppInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo(PLUTUS_SMART_PACKAGE, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun readTerminalInfoMap(): Map<String, String> {
        val serial = readHardwareSerial()
        return mapOf(
            "serial"          to serial,
            "model"           to Build.MODEL,
            "manufacturer"    to Build.MANUFACTURER,
            "paydroidVersion" to readSystemProperty("ro.build.display.id"),
        )
    }

    private fun readHardwareSerial(): String {
        val fromProp = readSystemProperty("ro.serialno")
        if (fromProp.isNotBlank() && fromProp != "unknown") return fromProp
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Build.getSerial()
            else @Suppress("DEPRECATION") Build.SERIAL
        } catch (_: Exception) { "" }
    }

    private fun readSystemProperty(key: String): String {
        return try {
            val clazz = Class.forName("android.os.SystemProperties")
            val get   = clazz.getMethod("get", String::class.java)
            (get.invoke(null, key) as? String).orEmpty()
        } catch (_: Exception) { "" }
    }

    // ── SmartPOS SDK ──────────────────────────────────────────────────────────

    private fun initSdk() {
        if (isSdkInitialized) return
        mDriverManager = DriverManager.getInstance()
        mSys           = mDriverManager.baseSysDevice
        mSys.sysPowerOn()
        try { Thread.sleep(2000) } catch (e: InterruptedException) { e.printStackTrace() }
        var status = mSys.sdkInit()
        if (status != SdkResult.SDK_OK) {
            try { Thread.sleep(1500) } catch (e: InterruptedException) { e.printStackTrace() }
            status = mSys.sdkInit()
        }
        if (status == SdkResult.SDK_OK) {
            isSdkInitialized = true
            mPrinter         = mDriverManager.printer
        } else {
            Log.e("SmartPos", "Failed to init SDK: $status")
        }
    }

    private fun printText(text: String?, size: Int, isBold: Boolean, align: Int): Int {
        if (text == null) return -1
        val printStatus = mPrinter.printerStatus
        if (printStatus == SdkResult.SDK_PRN_STATUS_PAPEROUT) return printStatus
        val format = PrnStrFormat()
        format.textSize = size
        format.style    = if (isBold) PrnTextStyle.BOLD else PrnTextStyle.NORMAL
        format.ali      = when (align) {
            1    -> Layout.Alignment.ALIGN_CENTER
            2    -> Layout.Alignment.ALIGN_OPPOSITE
            else -> Layout.Alignment.ALIGN_NORMAL
        }
        mPrinter.setPrintAppendString(text, format)
        return mPrinter.setPrintStart()
    }

    override fun onDestroy() {
        super.onDestroy()
        resetAndUnbind()
    }
}
