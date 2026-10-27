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
    private data class Speed(val time: Double, val value: Double, val weight: Double)
    private val speeds = mutableListOf<Speed>()
    private val positions = mutableListOf<Pair<Double, Double>>()
    private var measuredDistance = 0.0
    private var lastSample: Double? = null
    data class Fix(val lat: Double, val lon: Double, val accuracy: Double, val time: Double)
    private val steps get() = state.getJSONArray("steps")
    private val index get() = state.optInt("index")
    private val continuing get() = state.optBoolean("goalReached")
    private val current get() = if (continuing) JSONObject().put("id", "continuation")
        .put("displayName", text("continueEasy")).put("movement", "run").put("intensity", "easy")
        .put("primaryTarget", "effort") else steps.getJSONObject(index)
    private fun rule(key: String, fallback: Double) = state.optJSONObject("trackingRules")?.optDouble(key, fallback) ?: fallback
    private fun value(key: String) = state.optDouble(key, 0.0)
    private fun amount(): Double {
        val s = current
        val amount = if (!s.isNull("routeTotalMeters"))
            max(0.0, s.getDouble("routeTotalMeters") - (value("distanceMeters") - value("stepMeters")))
            else s.getDouble("amount")
        state.put("stepTargetAmount", amount)
        return amount
    }
    private fun text(key: String) = state.optJSONObject("messages")?.optString(key, key) ?: key
    private fun cue(message: String, kind: String, priority: Int = 30, unique: Boolean = true) {
        if (message.isBlank() || !state.optBoolean("audioEnabled", true)) return
        val id = "${state.optString("sessionId")}:$index:$kind"
        val sent = state.optJSONArray("cueIds") ?: JSONArray().also { state.put("cueIds", it) }
        if (unique && (0 until sent.length()).any { sent.optString(it) == id }) return
        if (unique) sent.put(id)
        state.put("audioEvent", JSONObject().put("id", id).put("index", index)
            .put("priority", priority).put("expires", value("elapsedSeconds") + 8).put("text", message))
        speak(message)
    }
    private fun emit(key: String) { cue(text(key), key, if (key in listOf("completed", "paused", "resume")) 100 else 40, key == "completed") }

    fun tick(now: Double) {
        var dt = lastTick?.let { max(0.0, now - it) } ?: 0.0
        lastTick = now
        if (state.optString("status") == "completed") return
        state.put("elapsedSeconds", value("elapsedSeconds") + dt)
        if (!state.optBoolean("indoor")) {
            val stale = now - lastFix > 15
            val old = state.optString("gps")
            state.put("gps", if (stale) "gpsLost" else "gpsReady")
            if (stale) {
                state.remove("speed"); state.put("paceQuality", "uncertain"); stillSince = null; outsideSince = null
                if (old == "gpsReady") emit("gpsLost")
            }
        }
        if (state.optString("status") != "active") return
        if (state.optDouble("countdown", 0.0) > 0) {
            val waiting = value("countdown")
            state.put("countdown", max(0.0, value("countdown") - dt))
            dt = max(0.0, dt - waiting)
            if (value("countdown") == 0.0) {
                previous = null
                cue(current.optString("startCue"), "start", 90)
            }
            if (dt == 0.0) return
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
        advance(dt, 0.0)
        if (state.optString("status") != "active" || continuing) return
        val step = current
        val progress = if (step.optString("goal") == "distance") value("stepMeters") else value("stepSeconds")
        val amount = amount()
        if (progress >= amount / 2 && !state.optBoolean("half") && amount >= if (step.optString("goal") == "distance") 300 else 60) {
            state.put("half", true); cue(step.optString("halfCue", text("half")), "half")
        }
        val near = if (step.optString("goal") == "distance") 100.0 else 15.0
        if (amount >= near * 3 && amount - progress <= near && !state.optBoolean("near")) {
            state.put("near", true); cue(step.optString("nearCue", text("nearEnd")), "near", 50)
        }
        coach(now)
    }

    fun location(lat: Double, lon: Double, accuracy: Double, speed: Double?, now: Double, wallMillis: Long,
                 speedAccuracy: Double? = null, receivedAt: Double = now): JSONObject? {
        if (state.optString("status") == "completed" || state.optBoolean("indoor") ||
            !lat.isFinite() || !lon.isFinite() || abs(lat) > 90 || abs(lon) > 180 || !accuracy.isFinite() || accuracy < 0 || accuracy > 35) return null
        if (receivedAt - now > 5 || now > receivedAt + 1 || (lastSample != null && now <= lastSample!!)) return null
        val sampleGap = lastSample?.let { now - it } ?: 0.0
        val old = previous
        val fix = Fix(lat, lon, accuracy, now)
        val gap = if (old == null) 0.0 else now - old.time
        val distance = if (old == null) 0.0 else haversine(old.lat, old.lon, lat, lon)
        val maxSpeed = if (state.optString("sport") == "cycling") 35.0 else 12.0
        if (gap <= 0 && old != null) return null
        if (old != null && gap <= 15 && distance / gap > maxSpeed) return null
        val reported = speed?.takeIf { it.isFinite() && it >= 0 && it <= maxSpeed }
        // Accumulate small fixes against an anchor. This measures slow running while
        // keeping sub-accuracy stationary jitter from becoming distance.
        val resolved = old == null || gap > 15 || distance >= max(3.0, max(accuracy, old.accuracy) / 2)
        if (resolved) previous = fix
        lastFix = now
        lastSample = now
        val measured = reported ?: if (old != null && gap in .01..15.0) distance / gap else 0.0
        if (sampleGap > 15) { speeds.clear(); positions.clear() }
        val acceptedDistance = if (resolved && gap in .01..15.0 && measured >= .35) distance else 0.0
        measuredDistance += acceptedDistance
        updatePace(now, sampleGap, reported, speedAccuracy, accuracy)
        state.put("motionSpeed", measured)
        state.put("gps", "gpsReady")
        val wasActive = state.optString("status") == "active"
        if (state.optString("status") == "paused" && state.optBoolean("autoPaused") && measured > .7) resume()
        val active = wasActive && state.optString("status") == "active" && value("countdown") == 0.0
        if (active && acceptedDistance > 0) {
            // A timer may already have completed time sections since the last
            // accepted fix. Attribute their share retrospectively, never all
            // of the measurement to the newly opened distance section.
            val currentSeconds = min(gap, value("stepSeconds"))
            var pastSeconds = gap - currentSeconds
            val results = state.getJSONArray("results")
            for (i in results.length() - 1 downTo 0) {
                if (pastSeconds <= 0) break
                val result = results.getJSONObject(i)
                val seconds = min(pastSeconds, result.optDouble("seconds", 0.0))
                result.put("meters", result.optDouble("meters", 0.0) + distance * seconds / gap)
                pastSeconds -= seconds
            }
            val currentDistance = if (pastSeconds == gap) distance else distance * currentSeconds / gap
            state.put("distanceMeters", value("distanceMeters") + distance)
            state.put("stepMeters", value("stepMeters") + currentDistance)
            advance(currentSeconds, currentDistance)
        }
        val seq = state.optInt("sequence", -1) + 1
        state.put("sequence", seq)
        return JSONObject().put("sequence", seq).put("timestamp", wallMillis)
            .put("latitude", lat).put("longitude", lon).put("accuracy", accuracy)
            .put("speed", measured).put("source", "phone_gps").put("active", active)
            .put("measurementVersion", 2).put("measuredAt", now).put("receivedAt", receivedAt)
            .put("speedAccuracy", speedAccuracy ?: JSONObject.NULL).put("acceptedMeters", acceptedDistance)
            .put("paceQuality", state.optString("paceQuality"))
            .put("gap", gap > 15)
    }

    private fun updatePace(now: Double, dt: Double, reported: Double?, uncertainty: Double?, accuracy: Double) {
        val window = rule("paceWindowSeconds", 15.0)
        val good = reported != null && uncertainty != null && uncertainty.isFinite() &&
            uncertainty >= 0 && uncertainty <= max(.2, reported * .15)
        if (good) speeds.add(Speed(now, reported!!, dt.coerceIn(.01, 5.0)))
        speeds.removeAll { now - it.time > window }
        positions.add(now to measuredDistance)
        positions.removeAll { now - it.first > rule("positionWindowSeconds", 30.0) }
        val span = now - positions.first().first
        val meters = measuredDistance - positions.first().second
        val positional = if (span >= 20 && accuracy <= 15 && meters >= max(10.0, accuracy * 4)) meters / span else null
        val weight = speeds.sumOf { it.weight }
        var estimate: Double? = null
        if (good && weight >= min(5.0, window)) {
            var accumulated = 0.0
            estimate = speeds.sortedBy { it.value }.firstOrNull {
                accumulated += it.weight; accumulated >= weight / 2
            }?.value
        } else if (positional != null) estimate = positional
        val inconsistent = estimate != null && good && positional != null &&
            abs(estimate - positional) > max(.5, estimate * .3)
        state.put("paceQuality", if (estimate != null && !inconsistent) "reliable" else "uncertain")
        if (estimate != null && !inconsistent) state.put("speed", estimate) else state.remove("speed")
    }

    private fun coach(now: Double) {
        val s = current
        if (continuing || value("stepSeconds") < rule("paceGraceSeconds", 30.0) || state.optString("gps") != "gpsReady" ||
            state.optString("paceQuality") != "reliable" || s.optString("primaryTarget") != "pace" ||
            (s.isNull("minSpeed") && s.isNull("maxSpeed"))) { outsideSince = null; return }
        val speed = state.optDouble("speed", 0.0)
        if (speed <= .35) { outsideSince = null; return }
        val pace = 1000 / speed
        val tolerance = rule("paceToleranceSecondsPerKm", 60.0)
        val tooFast = !s.isNull("maxSpeed") && s.optDouble("maxSpeed") > 0 && pace < 1000 / s.getDouble("maxSpeed") - tolerance
        val tooSlow = s.optString("intensity") !in listOf("easy", "recovery") && !s.isNull("minSpeed") && s.optDouble("minSpeed") > 0 && pace > 1000 / s.getDouble("minSpeed") + tolerance
        if (!tooFast && !tooSlow) { outsideSince = null; return }
        if (outsideSince == null) outsideSince = now
        if (now - outsideSince!! >= rule("paceSustainedSeconds", 20.0) && now - lastCorrection >= rule("paceCooldownSeconds", 90.0)) {
            emit(if (tooFast) "slower" else "faster"); lastCorrection = now; outsideSince = null
        }
    }

    private fun record(partial: Boolean = false) {
        val s = current
        state.getJSONArray("results").put(JSONObject().put("id", s.getString("id"))
            .put("name", s.optString("displayName")).put("index", index)
            .put("seconds", value("stepSeconds")).put("meters", value("stepMeters"))
            .put("partial", partial && !continuing).put("continuation", continuing))
    }
    private fun advance(deltaSeconds: Double, deltaMeters: Double) {
        var intervalSeconds = deltaSeconds
        var intervalMeters = deltaMeters
        while (state.optString("status") == "active" && !continuing) {
            val s = current
            val isDistance = s.getString("goal") == "distance"
            val progress = if (isDistance) value("stepMeters") else value("stepSeconds")
            val target = amount()
            if (progress < target) return
            val delta = if (isDistance) intervalMeters else intervalSeconds
            val remaining = if (delta > 0) ((progress - target) / delta).coerceIn(0.0, 1.0) else 0.0
            val carrySeconds = intervalSeconds * remaining
            val carryMeters = intervalMeters * remaining
            state.put("stepSeconds", value("stepSeconds") - carrySeconds)
                .put("stepMeters", value("stepMeters") - carryMeters)
            record()
            if (index + 1 < steps.length()) cue(s.optString("endCue", text("completed")), "end", 80)
            if (value("stepSeconds") > 0 && value("stepMeters") > 0) {
                val unit = state.optDouble("unitMeters", 1000.0)
                if (state.optString("sport") == "cycling") {
                    val speed = value("stepMeters") / value("stepSeconds") * 3600 / unit
                    cue("${text("average")}: ${String.format(java.util.Locale.forLanguageTag(state.optString("locale", "en")), "%.1f", speed)} ${if (unit > 1500) "mph" else "km/h"}", "average")
                } else {
                    val paceSeconds = (unit * value("stepSeconds") / value("stepMeters")).roundToInt()
                    val de = state.optString("locale", "en").startsWith("de")
                    cue("${text("average")}: ${paceSeconds / 60} ${if (de) "Minuten" else "minutes"} ${paceSeconds % 60} ${if (de) "Sekunden pro" else "seconds per"} ${if (unit > 1500) { if (de) "Meile" else "mile" } else { if (de) "Kilometer" else "kilometre" }}", "average")
                }
            }
            if (index + 1 >= steps.length()) {
                state.put("goalReached", true).put("plannedHadPause", state.optBoolean("hadPause"))
                    .put("index", steps.length()).put("stepSeconds", carrySeconds).put("stepMeters", carryMeters)
                outsideSince = null
                cue(text("goalReached"), "goalReached", 100)
                return
            }
            state.put("index", index + 1).put("stepSeconds", carrySeconds).put("stepMeters", carryMeters)
                .put("half", false).put("near", false)
            stillSince = null; outsideSince = null
            intervalSeconds = carrySeconds; intervalMeters = carryMeters
            cue(current.optString("startCue"), "start", 90)
        }
    }
    fun pause(automatic: Boolean = false) {
        if (state.optString("status") != "active") return
        state.put("status", "paused").put("autoPaused", automatic); emit("paused")
        state.put("hadPause", true); previous = null
    }
    fun resume() {
        if (state.optString("status") != "paused") return
        state.put("status", "active").put("autoPaused", false)
        stillSince = null; previous = null; speeds.clear(); positions.clear(); lastSample = null
        state.remove("speed"); state.put("paceQuality", "uncertain"); outsideSince = null; lastTick = null; emit("resume")
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
