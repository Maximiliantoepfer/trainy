package com.example.trainy

import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.*

/** Deterministic session reducer. Time arguments are monotonic seconds. */
class CardioEngine(val state: JSONObject, private val speak: (String) -> Unit) {
    private var lastTick: Double? = null
    private var stillSince: Double? = null
    private var outsideSince: Double? = null
    private var lastCorrection = -1000.0
    private var lastFix = -1000.0
    private var previous: Fix? = null
    private val speeds = mutableListOf<Pair<Double, Double>>()
    data class Fix(val lat: Double, val lon: Double, val accuracy: Double, val time: Double)
    private val steps get() = state.getJSONArray("steps")
    private val index get() = state.optInt("index")
    private val current get() = steps.getJSONObject(index)
    private fun value(key: String) = state.optDouble(key, 0.0)
    private fun text(key: String) = state.optJSONObject("messages")?.optString(key, key) ?: key
    private fun emit(key: String) { speak(text(key)) }

    fun tick(now: Double) {
        val dt = lastTick?.let { (now - it).coerceIn(0.0, 5.0) } ?: 0.0
        lastTick = now
        if (state.optString("status") == "completed") return
        state.put("elapsedSeconds", value("elapsedSeconds") + dt)
        if (!state.optBoolean("indoor")) {
            val stale = now - lastFix > 15
            val old = state.optString("gps")
            state.put("gps", if (stale) "gpsLost" else "gpsReady")
            if (stale) {
                state.remove("speed"); stillSince = null; outsideSince = null
                if (old == "gpsReady") emit("gpsLost")
            }
        }
        if (state.optString("status") != "active") return
        if (state.optDouble("countdown", 0.0) > 0) {
            state.put("countdown", max(0.0, value("countdown") - dt))
            if (value("countdown") == 0.0) speak(current.optString("startCue"))
            return
        }
        state.put("activeSeconds", value("activeSeconds") + dt)
        if (state.optString("gps") == "gpsReady" && !state.optBoolean("indoor")) state.put("gpsCoveredSeconds", value("gpsCoveredSeconds") + dt)
        state.put("stepSeconds", value("stepSeconds") + dt)
        if (state.optBoolean("autoPause") && !state.optBoolean("indoor") &&
            !current.optBoolean("standingRecovery") && current.optString("movement") != "walk" && current.optString("movement") != "rest" && state.optString("gps") == "gpsReady") {
            if (state.optDouble("motionSpeed", 1.0) < .35) {
                if (stillSince == null) stillSince = now
                if (now - stillSince!! >= 10) { pause(true); return }
            } else stillSince = null
        }
        advance()
        if (state.optString("status") != "active") return
        val step = current
        val progress = if (step.optString("goal") == "distance") value("stepMeters") else value("stepSeconds")
        val amount = step.getDouble("amount")
        if (progress >= amount / 2 && !state.optBoolean("half") && amount >= if (step.optString("goal") == "distance") 300 else 60) {
            state.put("half", true); speak(step.optString("halfCue", text("half")))
        }
        val near = if (step.optString("goal") == "distance") 100.0 else 15.0
        if (amount >= near * 3 && amount - progress <= near && !state.optBoolean("near")) {
            state.put("near", true); speak(step.optString("nearCue", text("nearEnd")))
        }
        coach(now)
    }

    fun location(lat: Double, lon: Double, accuracy: Double, speed: Double?, now: Double, wallMillis: Long): JSONObject? {
        if (state.optString("status") == "completed" || state.optBoolean("indoor") ||
            !lat.isFinite() || !lon.isFinite() || abs(lat) > 90 || abs(lon) > 180 || !accuracy.isFinite() || accuracy < 0 || accuracy > 35) return null
        val old = previous
        val fix = Fix(lat, lon, accuracy, now)
        val gap = if (old == null) 0.0 else now - old.time
        val distance = if (old == null) 0.0 else haversine(old.lat, old.lon, lat, lon)
        val maxSpeed = if (state.optString("sport") == "cycling") 35.0 else 12.0
        if (gap <= 0 && old != null) return null
        if (old != null && gap <= 15 && distance / gap > maxSpeed) return null
        previous = fix; lastFix = now
        val measured = speed?.takeIf { it.isFinite() && it >= 0 && it <= maxSpeed }
            ?: if (old != null && gap <= 15 && distance > max(3.0, accuracy / 2)) distance / gap else 0.0
        speeds.add(now to measured); speeds.removeAll { now - it.first > 15 }
        state.put("speed", speeds.map { it.second }.average())
        state.put("motionSpeed", measured)
        state.put("gps", "gpsReady")
        val wasActive = state.optString("status") == "active"
        if (state.optString("status") == "paused" && state.optBoolean("autoPaused") && measured > .7) resume()
        if (wasActive && state.optString("status") == "active" && value("countdown") == 0.0 && gap in .01..15.0 && measured >= .35) {
            state.put("distanceMeters", value("distanceMeters") + distance)
            state.put("stepMeters", value("stepMeters") + distance)
        }
        val seq = state.optInt("sequence", -1) + 1
        state.put("sequence", seq)
        return JSONObject().put("sequence", seq).put("timestamp", wallMillis)
            .put("latitude", lat).put("longitude", lon).put("accuracy", accuracy)
            .put("speed", measured).put("source", "phone_gps")
    }

    private fun coach(now: Double) {
        val s = current
        if (value("stepSeconds") < 20 || state.optString("gps") != "gpsReady" ||
            s.optString("primaryTarget") != "pace" || s.isNull("minSpeed") || s.isNull("maxSpeed")) return
        val speed = state.optDouble("speed", 0.0)
        if (speed <= .35) { outsideSince = null; return }
        val pace = 1000 / speed
        val tooFast = pace < 1000 / s.getDouble("maxSpeed") - 20
        val tooSlow = pace > 1000 / s.getDouble("minSpeed") + 20
        if (!tooFast && !tooSlow) { outsideSince = null; return }
        if (outsideSince == null) outsideSince = now
        if (now - outsideSince!! >= 10 && now - lastCorrection >= 45) {
            emit(if (tooFast) "slower" else "faster"); lastCorrection = now; outsideSince = null
        }
    }

    private fun record(partial: Boolean = false) {
        val s = current
        state.getJSONArray("results").put(JSONObject().put("id", s.getString("id"))
            .put("name", s.optString("displayName")).put("index", index)
            .put("seconds", value("stepSeconds")).put("meters", value("stepMeters"))
            .put("partial", partial))
    }
    private fun advance() {
        while (state.optString("status") == "active") {
            val s = current
            val isDistance = s.getString("goal") == "distance"
            val progress = if (isDistance) value("stepMeters") else value("stepSeconds")
            if (progress < s.getDouble("amount")) return
            val fraction = (s.getDouble("amount") / progress).coerceIn(0.0, 1.0)
            val carrySeconds = value("stepSeconds") * (1 - fraction)
            val carryMeters = value("stepMeters") * (1 - fraction)
            state.put("stepSeconds", value("stepSeconds") - carrySeconds)
                .put("stepMeters", value("stepMeters") - carryMeters)
            record()
            speak(s.optString("endCue", text("completed")))
            if (value("stepSeconds") > 0 && value("stepMeters") > 0) {
                val unit = state.optDouble("unitMeters", 1000.0)
                if (state.optString("sport") == "cycling") {
                    val speed = value("stepMeters") / value("stepSeconds") * 3600 / unit
                    speak("${text("average")}: ${String.format(java.util.Locale.forLanguageTag(state.optString("locale", "en")), "%.1f", speed)} ${if (unit > 1500) "mph" else "km/h"}")
                } else {
                    val paceSeconds = (unit * value("stepSeconds") / value("stepMeters")).roundToInt()
                    speak("${text("average")}: ${paceSeconds / 60}:${(paceSeconds % 60).toString().padStart(2, '0')} ${if (unit > 1500) "/mi" else "/km"}")
                }
            }
            if (index + 1 >= steps.length()) {
                state.put("activeSeconds", max(0.0, value("activeSeconds") - carrySeconds))
                    .put("distanceMeters", max(0.0, value("distanceMeters") - carryMeters))
                complete(); return
            }
            state.put("index", index + 1).put("stepSeconds", carrySeconds).put("stepMeters", carryMeters)
                .put("half", false).put("near", false)
            stillSince = null; outsideSince = null
            speak(current.optString("startCue"))
        }
    }
    fun pause(automatic: Boolean = false) {
        if (state.optString("status") != "active") return
        state.put("status", "paused").put("autoPaused", automatic); emit("paused")
    }
    fun resume() {
        if (state.optString("status") != "paused") return
        state.put("status", "active").put("autoPaused", false)
        stillSince = null; previous = null; speeds.clear(); outsideSince = null; lastTick = null; emit("resume")
    }
    fun finish() {
        if (state.optString("status") == "completed") return
        if (value("stepSeconds") > 0 || value("stepMeters") > 0) record(true)
        complete()
    }
    private fun complete() { state.put("status", "completed").put("endedAt", System.currentTimeMillis()); emit("completed") }
    companion object {
        fun fresh(snapshot: JSONObject): JSONObject {
            require(snapshot.optInt("version") == 1 && snapshot.getJSONArray("steps").length() > 0)
            snapshot.put("status", "active").put("index", 0).put("activeSeconds", 0.0)
                .put("elapsedSeconds", 0.0).put("distanceMeters", 0.0).put("stepSeconds", 0.0)
                .put("stepMeters", 0.0).put("countdown", 3.0).put("results", JSONArray())
                .put("gps", "gpsWaiting").put("sequence", -1)
            return snapshot
        }
        fun haversine(a: Double, b: Double, c: Double, d: Double): Double {
            val p = Math.PI / 180
            val h = sin((c-a)*p/2).pow(2) + cos(a*p)*cos(c*p)*sin((d-b)*p/2).pow(2)
            return 6371000 * 2 * asin(sqrt(h.coerceIn(0.0, 1.0)))
        }
    }
}
