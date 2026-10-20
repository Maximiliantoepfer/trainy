package com.example.trainy

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.location.LocationManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import org.json.JSONObject

class MainActivity : FlutterFragmentActivity(), CardioHostApi {
    private var permissionReply: ((Result<String>) -> Unit)? = null
    private var permissionOutdoor = true
    private var requestedLocale = "en"
    private var preparing = false
    private val sampleCursor = CardioSampleJournal()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CardioHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
    }
    override fun capabilities() = JSONObject().put("available", true).put("indoorBackground", true).toString()
    override fun prepare(outdoor: Boolean, locale: String, callback: (Result<String>) -> Unit) {
        if (preparing) { callback(Result.failure(IllegalStateException("permission_pending"))); return }
        preparing = true; requestedLocale = locale
        if (outdoor && !gpsEnabled()) {
            preparing = false; callback(Result.success("location_disabled")); return
        }
        val needed = if (outdoor) Manifest.permission.ACCESS_FINE_LOCATION else if (Build.VERSION.SDK_INT >= 29) Manifest.permission.ACTIVITY_RECOGNITION else null
        if (needed == null || checkSelfPermission(needed) == PackageManager.PERMISSION_GRANTED) {
            probeSpeech(callback); return
        }
        if (permissionReply != null) { callback(Result.failure(IllegalStateException("permission_pending"))); return }
        permissionReply = callback
        permissionOutdoor = outdoor
        requestPermissions(if (outdoor) arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION) else arrayOf(needed), 4701)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4701) {
            val needed = if (permissionOutdoor) Manifest.permission.ACCESS_FINE_LOCATION else Manifest.permission.ACTIVITY_RECOGNITION
            val reply = permissionReply
            if (reply != null) {
                if (checkSelfPermission(needed) == PackageManager.PERMISSION_GRANTED) probeSpeech(reply)
                else { preparing = false; reply(Result.success(if (permissionOutdoor && checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) "approximate" else "denied")) }
            }
            permissionReply = null
        }
    }
    private fun probeSpeech(callback: (Result<String>) -> Unit) {
        var probe: android.speech.tts.TextToSpeech? = null
        var done = false
        fun complete(ready: Boolean) {
            if (done) return
            done = true; preparing = false; probe?.shutdown()
            callback(Result.success(if (ready) "ready" else "ready_silent"))
        }
        probe = android.speech.tts.TextToSpeech(this) { status ->
            val language = java.util.Locale.forLanguageTag(requestedLocale).language
            complete(status == android.speech.tts.TextToSpeech.SUCCESS && probe?.voices?.any {
                !it.isNetworkConnectionRequired && it.locale.language == language && !it.features.contains("notInstalled")
            } == true)
        }
        android.os.Handler(mainLooper).postDelayed({ complete(false) }, 5000)
    }
    override fun start(snapshotJson: String) {
        val existing = CardioService.read(this)
        check(existing == null) { "unacknowledged_session" }
        val data = JSONObject(snapshotJson)
        if (!data.optBoolean("indoor")) {
            check(gpsEnabled()) { "location_disabled" }
            check(checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) { "precise_location_required" }
        }
        check(data.optInt("version") == 1 && data.getJSONArray("steps").length() > 0)
        // Commit before returning to Dart. A killed launch remains recoverable.
        val fresh = CardioEngine.fresh(data)
        CardioService.write(this, fresh)
        CardioService.current = fresh
        val intent = Intent(this, CardioService::class.java).putExtra("snapshot", snapshotJson)
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
    }
    override fun state(): String? {
        val value = CardioService.read(this) ?: return null
        if (CardioService.instance == null && value.optString("status") != "completed") {
            value.put("status", "paused").put("autoPaused", false).put("recovered", true)
        }
        return value.toString()
    }
    override fun recover(runtimeJson: String) {
        check(CardioService.read(this) == null)
        val data = JSONObject(runtimeJson)
        check(data.optInt("version") == 1 && data.getJSONArray("steps").length() > 0)
        data.put("status", "paused").put("autoPaused", false).put("recovered", true)
        data.put("sequence", CardioSampleJournal.reconcile(CardioService.samplesFile(this), data.optLong("sequence", -1)))
        CardioService.write(this, data); CardioService.current = data
    }
    override fun discard() {
        CardioService.instance?.discard()
        android.util.AtomicFile(CardioService.stateFile(this)).delete()
        CardioService.samplesFile(this).delete(); CardioService.current = null
    }
    override fun samples(afterSequence: Long) = sampleCursor.read(CardioService.samplesFile(this), afterSequence, CardioService.read(this)?.optString("sessionId"))
    override fun pause() { CardioService.instance?.pause() }
    override fun resume() {
        if (CardioService.instance == null && CardioService.read(this)?.optString("status") != "completed") {
            val intent = Intent(this, CardioService::class.java)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
            android.os.Handler(mainLooper).postDelayed({ CardioService.instance?.resume() }, 500)
        } else CardioService.instance?.resume()
    }
    override fun finish() {
        val service = CardioService.instance
        if (service != null) service.finish() else {
            val value = CardioService.read(this) ?: return
            CardioEngine(value) {}.finish()
            CardioService.write(this, value); CardioService.current = value
        }
    }
    override fun acknowledge(sessionId: String) {
        val data = CardioService.read(this) ?: return
        check(data.optString("sessionId") == sessionId && data.optString("status") == "completed")
        CardioService.instance?.releaseCompleted()
        android.util.AtomicFile(CardioService.stateFile(this)).delete()
        CardioService.samplesFile(this).delete(); CardioService.current = null
    }
    private fun gpsEnabled() = (getSystemService(LOCATION_SERVICE) as LocationManager).isProviderEnabled(LocationManager.GPS_PROVIDER)
    override fun openSettings() {
        startActivity(if (!gpsEnabled()) Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
    }
}
