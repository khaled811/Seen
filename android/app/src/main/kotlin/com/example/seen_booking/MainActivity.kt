package com.example.seen_booking

import android.hardware.GeomagneticField
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Qibla compass: the sensor reports magnetic north, so the app needs the
        // local declination to point at the Kaaba accurately.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "seen_booking/declination")
            .setMethodCallHandler { call, result ->
                if (call.method == "declination") {
                    val lat = call.argument<Double>("lat")
                    val lng = call.argument<Double>("lng")
                    if (lat == null || lng == null) {
                        result.error("bad_args", "lat and lng are required", null)
                    } else {
                        val field = GeomagneticField(
                            lat.toFloat(), lng.toFloat(), 0f, System.currentTimeMillis()
                        )
                        result.success(field.declination.toDouble())
                    }
                } else {
                    result.notImplemented()
                }
            }
        // Sensitive values (a revealed passport number): no screenshots or app-switcher preview
        // while one is visible.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "seen_booking/secure_screen")
            .setMethodCallHandler { call, result ->
                if (call.method == "set") {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
