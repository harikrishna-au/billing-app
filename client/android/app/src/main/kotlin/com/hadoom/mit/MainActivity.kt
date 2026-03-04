package com.hadoom.mit

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.text.Layout
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.zcs.sdk.DriverManager
import com.zcs.sdk.Printer
import com.zcs.sdk.Sys
import com.zcs.sdk.SdkResult
import com.zcs.sdk.print.PrnStrFormat
import com.zcs.sdk.print.PrnTextFont
import com.zcs.sdk.print.PrnTextStyle
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    // ── Printer channel (ZCS SDK) ─────────────────────────────────────────────
    private val PRINTER_CHANNEL = "com.smartpos.sdk/printer"
    private lateinit var mDriverManager: DriverManager
    private lateinit var mSys: Sys
    private lateinit var mPrinter: Printer
    private var isSdkInitialized = false
    private val executor = Executors.newSingleThreadExecutor()

    // ── Paytm EDC channel ─────────────────────────────────────────────────────
    private val PAYTM_EDC_CHANNEL = "com.hadoom.mit/paytm_edc"

    // Packages: use debug package for testing, production for release
    private val PAYTM_PKG_PROD  = "com.paytm.pos"
    private val PAYTM_PKG_DEBUG = "com.paytm.pos.debug"
    private val PAYTM_REQUEST_CODE = 1001

    // Holds the pending Flutter result while waiting for onActivityResult
    private var pendingPaytmResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerPrinterChannel(flutterEngine)
        registerPaytmEdcChannel(flutterEngine)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Printer Channel
    // ─────────────────────────────────────────────────────────────────────────

    private fun registerPrinterChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRINTER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initSdk" -> {
                        executor.execute {
                            initSdk()
                            runOnUiThread {
                                if (isSdkInitialized) result.success("SDK Initialized Successfully")
                                else result.error("SDK_INIT_FAILED", "Failed to initialize SDK", null)
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
                                runOnUiThread { result.error("SDK_NOT_INIT", "SDK not initialized", null) }
                                return@execute
                            }
                            val status = printText(text, size, isBold, align)
                            runOnUiThread {
                                if (status == SdkResult.SDK_OK) result.success("Printed Successfully")
                                else result.error("PRINT_FAILED", "Printing failed: $status", null)
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
    }

    private fun initSdk() {
        if (isSdkInitialized) return
        mDriverManager = DriverManager.getInstance()
        mSys = mDriverManager.baseSysDevice
        mSys.sysPowerOn()
        try { Thread.sleep(2000) } catch (e: InterruptedException) { e.printStackTrace() }
        var status = mSys.sdkInit()
        if (status != SdkResult.SDK_OK) {
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
        if (mPrinter.printerStatus == SdkResult.SDK_PRN_STATUS_PAPEROUT)
            return SdkResult.SDK_PRN_STATUS_PAPEROUT
        val format = PrnStrFormat().apply {
            textSize = size
            style    = if (isBold) PrnTextStyle.BOLD else PrnTextStyle.NORMAL
            ali = when (align) {
                1    -> Layout.Alignment.ALIGN_CENTER
                2    -> Layout.Alignment.ALIGN_OPPOSITE
                else -> Layout.Alignment.ALIGN_NORMAL
            }
        }
        mPrinter.setPrintAppendString(text, format)
        return mPrinter.setPrintStart()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Paytm EDC Channel
    // ─────────────────────────────────────────────────────────────────────────

    private fun registerPaytmEdcChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PAYTM_EDC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "doPayment" -> {
                        val orderId  = call.argument<String>("orderId") ?: ""
                        val amount   = call.argument<String>("amount") ?: "0"
                        val payMode  = call.argument<String>("payMode") ?: "ALL"
                        invokePaytmEdc(orderId, amount, payMode, result)
                    }
                    "checkStatus" -> {
                        val orderId = call.argument<String>("orderId") ?: ""
                        invokePaytmEdcStatus(orderId, result)
                    }
                    "doVoid" -> {
                        val orderId = call.argument<String>("orderId") ?: ""
                        invokePaytmEdcVoid(orderId, result)
                    }
                    "isPaytmInstalled" -> {
                        val pkg = if (isDebugBuild()) PAYTM_PKG_DEBUG else PAYTM_PKG_PROD
                        result.success(isPackageInstalled(pkg))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Launches the Paytm EDC app to process a payment.
     * payMode: "CARD" | "QR" | "ALL"
     */
    private fun invokePaytmEdc(
        orderId: String,
        amount: String,
        payMode: String,
        result: MethodChannel.Result
    ) {
        val pkg = if (isDebugBuild()) PAYTM_PKG_DEBUG else PAYTM_PKG_PROD
        if (!isPackageInstalled(pkg)) {
            result.error("PAYTM_NOT_INSTALLED", "Paytm EDC app is not installed on this device", null)
            return
        }
        pendingPaytmResult = result
        val intent = Intent().apply {
            component = ComponentName(pkg, "$pkg.merchant.activity.PaymentActivity")
            putExtra("ORDER_ID", orderId)
            putExtra("AMOUNT", amount)
            putExtra("PAY_MODE", payMode)
            putExtra("CALLBACK_PKG", packageName)
            putExtra("CALLBACK_ACTION", "$packageName.PAYMENT_RESULT")
        }
        try {
            startActivityForResult(intent, PAYTM_REQUEST_CODE)
        } catch (e: Exception) {
            pendingPaytmResult = null
            result.error("INVOKE_FAILED", "Failed to start Paytm EDC: ${e.message}", null)
        }
    }

    private fun invokePaytmEdcStatus(orderId: String, result: MethodChannel.Result) {
        val pkg = if (isDebugBuild()) PAYTM_PKG_DEBUG else PAYTM_PKG_PROD
        if (!isPackageInstalled(pkg)) {
            result.error("PAYTM_NOT_INSTALLED", "Paytm EDC app is not installed", null)
            return
        }
        pendingPaytmResult = result
        val intent = Intent().apply {
            component = ComponentName(pkg, "$pkg.merchant.activity.StatusActivity")
            putExtra("ORDER_ID", orderId)
            putExtra("CALLBACK_PKG", packageName)
            putExtra("CALLBACK_ACTION", "$packageName.PAYMENT_RESULT")
        }
        try {
            startActivityForResult(intent, PAYTM_REQUEST_CODE)
        } catch (e: Exception) {
            pendingPaytmResult = null
            result.error("INVOKE_FAILED", "Failed to check status: ${e.message}", null)
        }
    }

    private fun invokePaytmEdcVoid(orderId: String, result: MethodChannel.Result) {
        val pkg = if (isDebugBuild()) PAYTM_PKG_DEBUG else PAYTM_PKG_PROD
        if (!isPackageInstalled(pkg)) {
            result.error("PAYTM_NOT_INSTALLED", "Paytm EDC app is not installed", null)
            return
        }
        pendingPaytmResult = result
        val intent = Intent().apply {
            component = ComponentName(pkg, "$pkg.merchant.activity.VoidActivity")
            putExtra("ORDER_ID", orderId)
            putExtra("CALLBACK_PKG", packageName)
            putExtra("CALLBACK_ACTION", "$packageName.PAYMENT_RESULT")
        }
        try {
            startActivityForResult(intent, PAYTM_REQUEST_CODE)
        } catch (e: Exception) {
            pendingPaytmResult = null
            result.error("INVOKE_FAILED", "Failed to void: ${e.message}", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PAYTM_REQUEST_CODE) return

        val pending = pendingPaytmResult ?: return
        pendingPaytmResult = null

        if (resultCode == Activity.RESULT_OK && data != null) {
            val responseMap = HashMap<String, String?>()
            data.extras?.keySet()?.forEach { key ->
                responseMap[key] = data.extras?.get(key)?.toString()
            }
            pending.success(responseMap)
        } else {
            pending.error(
                "PAYMENT_CANCELLED",
                "Payment was cancelled or failed (resultCode=$resultCode)",
                null
            )
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun isDebugBuild(): Boolean {
        return (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }
}
