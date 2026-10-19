package com.example.trainy

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.*
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.*
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.AtomicFile
import org.json.*
import java.io.File
import java.util.Locale

class CardioService : Service(), LocationListener {
    private val handler = Handler(Looper.getMainLooper())
    private var engine: CardioEngine? = null
    private var tts: TextToSpeech? = null
    private var speechReady = false
    private val pendingSpeech = mutableListOf<String>()
    private var queuedSpeech = 0
    private val audio by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }
    private val audioAttributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
    private val audioFocus: AudioFocusRequest by lazy { AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        .setAudioAttributes(audioAttributes).setOnAudioFocusChangeListener { change ->
            if (change < 0) { tts?.stop(); queuedSpeech = 0; audio.abandonAudioFocusRequest(audioFocus); engine?.state?.put("audioUnavailable", true) }
        }.build() }
    private var lastPersist = 0L
    private var wakeLock: PowerManager.WakeLock? = null
    private val locations get() = getSystemService(LOCATION_SERVICE) as LocationManager
    private val ticker = object : Runnable {
        override fun run() {
            val e = engine ?: return
            e.tick(SystemClock.elapsedRealtime() / 1000.0)
            current = e.state
            if (SystemClock.elapsedRealtime() - lastPersist >= 1000) persist()
            if (e.state.optString("status") == "completed") { persist(); handler.postDelayed({ stopSelf() }, 10000); return }
            handler.postDelayed(this, 500)
        }
    }
    override fun onCreate() {
        super.onCreate(); instance = this
        wakeLock = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "trainy:cardio").apply { acquire(12 * 60 * 60 * 1000L) }
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val locale = Locale.forLanguageTag(engine?.state?.optString("locale") ?: "en")
                val voice = tts?.voices?.firstOrNull { !it.isNetworkConnectionRequired && it.locale.language == locale.language && !it.features.contains("notInstalled") }
                if (voice != null) {
                    tts?.voice = voice; speechReady = true
                    tts?.setAudioAttributes(audioAttributes)
                    tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(id: String?) {}
                        override fun onDone(id: String?) = releaseSpeechFocus()
                        @Deprecated("Legacy callback") override fun onError(id: String?) = releaseSpeechFocus()
                    })
                    pendingSpeech.toList().forEach { say(it) }; pendingSpeech.clear()
                } else engine?.state?.put("audioUnavailable", true)
            } else engine?.state?.put("audioUnavailable", true)
        }
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("cardio", "Trainy", NotificationManager.IMPORTANCE_LOW))
        val launch = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "cardio") else Notification.Builder(this)
        val raw = intent?.getStringExtra("snapshot")
        val initial = if (raw != null) JSONObject(raw) else read(this)
        if (initial == null || initial.optString("status") == "completed") { stopSelf(); return START_NOT_STICKY }
        val notification = builder.setContentTitle("Trainy").setContentText(initial.optString("name", "Trainy"))
            .setSmallIcon(android.R.drawable.ic_media_play).setContentIntent(launch).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(4701, notification, if (initial.optBoolean("indoor")) ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH else ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        else if (Build.VERSION.SDK_INT >= 29 && !initial.optBoolean("indoor")) startForeground(4701, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        else startForeground(4701, notification)
        if (engine == null) {
            handler.removeCallbacksAndMessages(null)
            val data = if (raw != null) CardioEngine.fresh(JSONObject(raw)) else read(this)?.apply {
                put("status", "paused"); put("autoPaused", false); put("recovered", true)
            }
            if (data == null) { stopSelf(); return START_NOT_STICKY }
            if (raw == null) data.put("sequence", CardioSampleJournal.reconcile(samplesFile(this), data.optLong("sequence", -1)))
            engine = CardioEngine(data, ::say); current = data; persist()
            if (!data.optBoolean("indoor") && checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                try { locations.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000, 0f, this) }
                catch (_: Exception) { data.put("gps", "gpsLost") }
            }
            handler.post(ticker)
        }
        return START_STICKY
    }
    private fun say(message: String) {
        if (message.isBlank()) return
        if (!speechReady) { if (pendingSpeech.size < 3) pendingSpeech.add(message); return }
        if (queuedSpeech == 0 && audio.requestAudioFocus(audioFocus) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            engine?.state?.put("audioUnavailable", true); return
        }
        queuedSpeech++
        if (tts?.speak(message, TextToSpeech.QUEUE_ADD, null, java.util.UUID.randomUUID().toString()) == TextToSpeech.ERROR) releaseSpeechFocus()
    }
    private fun releaseSpeechFocus() { handler.post {
        queuedSpeech = (queuedSpeech - 1).coerceAtLeast(0)
        if (queuedSpeech == 0) audio.abandonAudioFocusRequest(audioFocus)
    } }
    override fun onLocationChanged(location: Location) {
        if ((SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1e9 > 5) return
        val sample = engine?.location(location.latitude, location.longitude, location.accuracy.toDouble(),
            if (location.hasSpeed()) location.speed.toDouble() else null,
            SystemClock.elapsedRealtime() / 1000.0, location.time) ?: return
        try { samplesFile(this).appendText(sample.toString() + "\n") }
        catch (_: Exception) { engine?.pause(); engine?.state?.put("storageError", true) }
    }
    override fun onProviderDisabled(provider: String) { engine?.state?.put("gps", "gpsLost") }
    override fun onProviderEnabled(provider: String) {}
    @Deprecated("Legacy callback")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    fun pause() { engine?.pause(); persist() }
    fun resume() { engine?.resume(); persist() }
    fun finish() { engine?.finish(); persist(); handler.postDelayed({ stopSelf() }, 10000) }
    fun releaseCompleted() {
        if (engine?.state?.optString("status") == "completed") {
            engine = null; handler.removeCallbacks(ticker); locations.removeUpdates(this)
            // Let the last spoken cue finish, but never re-persist an acknowledged journal.
            handler.postDelayed({ stopSelf() }, 10000)
        }
    }
    fun discard() {
        engine = null; current = null; handler.removeCallbacksAndMessages(null)
        locations.removeUpdates(this); stopSelf()
    }
    private fun persist() {
        val value = engine?.state ?: return
        try {
            write(this, value)
            lastPersist = SystemClock.elapsedRealtime(); current = value
        } catch (_: Exception) { value.put("storageError", true); engine?.pause() }
    }
    override fun onDestroy() {
        handler.removeCallbacks(ticker); locations.removeUpdates(this)
        persist(); tts?.stop(); tts?.shutdown(); audio.abandonAudioFocusRequest(audioFocus); if (wakeLock?.isHeld == true) wakeLock?.release(); instance = null
        super.onDestroy()
    }
    override fun onBind(intent: Intent?): IBinder? = null
    companion object {
        var instance: CardioService? = null
        var current: JSONObject? = null
        fun stateFile(context: Context) = File(context.filesDir, "cardio-session.json")
        fun samplesFile(context: Context) = File(context.filesDir, "cardio-samples.jsonl")
        fun write(context: Context, value: JSONObject) {
            val file = AtomicFile(stateFile(context)); val stream = file.startWrite()
            try { stream.write(value.toString().toByteArray()); file.finishWrite(stream) }
            catch (e: Exception) { file.failWrite(stream); throw e }
        }
        fun read(context: Context): JSONObject? = current ?: try {
            JSONObject(String(AtomicFile(stateFile(context)).readFully()))
        } catch (_: Exception) { null }
    }
}
