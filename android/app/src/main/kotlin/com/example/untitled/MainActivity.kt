package com.example.smart_storage_manager

import android.os.StatFs
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import 'package:flutter/services.dart';

class MainActivity : FlutterActivity() {

    private val CHANNEL = "smart_storage/storage"

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            if (call.method == "getStorageInfo") {

                val stat = StatFs(
                    Environment.getDataDirectory().path
                )

                val total = stat.totalBytes
                val free = stat.availableBytes
                val used = total - free

                result.success(
                    mapOf(
                        "total" to total,
                        "free" to free,
                        "used" to used
                    )
                )

            } else {
                result.notImplemented()
            }
        }
    }
}