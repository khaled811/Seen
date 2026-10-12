package com.example.seen_booking

import android.hardware.GeomagneticField
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
    }
}
