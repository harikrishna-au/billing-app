package com.example.flutter_getx_boilerplate

import android.os.Bundle
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
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.text.Layout
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.smartpos.sdk/printer"
    private lateinit var mDriverManager: DriverManager
    private lateinit var mSys: Sys
    private lateinit var mPrinter: Printer
    private var isSdkInitialized = false
    private val executor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
    }

    private fun initSdk() {
        if (isSdkInitialized) return

        mDriverManager = DriverManager.getInstance()
        mSys = mDriverManager.baseSysDevice

        var status = mSys.sdkInit()
        if (status != SdkResult.SDK_OK) {
            mSys.sysPowerOn()
            try {
                Thread.sleep(1000)
            } catch (e: InterruptedException) {
                e.printStackTrace()
            }
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
}
